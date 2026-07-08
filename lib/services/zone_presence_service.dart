// Destination: lib/services/zone_presence_service.dart
//
// The bridge between Phase 1 (radio -> ZonePresence) and Phase 2 (zone events
// -> audio). Replaces the old BeaconService. Three jobs, nothing more:
//
//   1. WIRE + own the pipeline: scanner -> registry -> arbiter, with lifecycle
//      (start / stop / dispose), same lifecycle-aware discipline BeaconService
//      had (only scan while foreground -> caller drives start/stop).
//   2. TRANSLATE the arbiter's STATE stream (ZonePresence) into zone-TRANSITION
//      events the TourAudioController understands (enterZone / changeZone /
//      leaveToStandby), by diffing successive presences. This is the service's
//      real logic.
//   3. ENRICH currentMajor into a ZoneInfo for the UI, and re-expose deskStable
//      UNTOUCHED (Phase 1 boundary: reporting only; the SessionController in
//      Phase 3 will consume it — nothing here acts on it).
//
// It ALSO re-exposes the registry's raw per-major signal heartbeat via
// [signals], for consumers that need per-minor liveness (the live exhibit list
// in Phase 4). That stream is passed straight through, ungated — whoever wants
// stable per-minor presence layers its own hysteresis (ExhibitPresenceTracker).
//
// Deliberately does NOT own audio: it emits transitions; whoever wires it to a
// TourAudioController (Phase 4) connects the two. Keeps this testable with zero
// audio dependencies.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/domain/models/zone_presence.dart';
import 'package:beacon_client/domain/models/zone_signal.dart';

/// A zone transition, derived from consecutive ZonePresence values. This is
/// the vocabulary the audio layer speaks; the service produces it, the caller
/// routes it to TourAudioController.
sealed class ZoneEvent {
  const ZoneEvent();
}

/// Entered a zone from standby (previous currentMajor was null).
class EnteredZone extends ZoneEvent {
  final int major;
  const EnteredZone(this.major);
}

/// Moved directly from one zone to another.
class ChangedZone extends ZoneEvent {
  final int fromMajor;
  final int toMajor;
  const ChangedZone(this.fromMajor, this.toMajor);
}

/// Dropped to standby (radar screen): current zone went silent past lockout.
class LeftToStandby extends ZoneEvent {
  const LeftToStandby();
}

/// UI-facing enriched view of the current radio situation. Carries the resolved
/// ZoneInfo (null in standby) plus the raw deskStable flag for Phase 3.
@immutable
class ZoneStatus {
  /// Resolved current zone, or null in standby.
  final ZoneInfo? zone;

  /// Passed through untouched from the arbiter (Phase 3 will consume it).
  final bool deskStable;

  const ZoneStatus({this.zone, this.deskStable = false});

  static const ZoneStatus standby = ZoneStatus();

  bool get inZone => zone != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZoneStatus &&
        other.zone?.major == zone?.major &&
        other.deskStable == deskStable;
  }

  @override
  int get hashCode => Object.hash(zone?.major, deskStable);
}

class ZonePresenceService {
  ZonePresenceService({
    required IBeaconScanner scanner,
    required IZoneRepository repository,
    required String museumUuidLower,
    required BeaconTrackerRegistry registry,
    required ZoneArbiter arbiter,
  })  : _scanner = scanner,
        _repo = repository,
        _museumUuid = museumUuidLower,
        _registry = registry,
        _arbiter = arbiter;

  final IBeaconScanner _scanner;
  final IZoneRepository _repo;
  final String _museumUuid;
  final BeaconTrackerRegistry _registry;
  final ZoneArbiter _arbiter;

  final _events = StreamController<ZoneEvent>.broadcast();
  final _status = StreamController<ZoneStatus>.broadcast();

  StreamSubscription<BeaconReading>? _readingSub;
  StreamSubscription<List<ZoneSignal>>? _signalSub;
  StreamSubscription<ZonePresence>? _presenceSub;

  bool _running = false;
  int? _lastMajor; // last CONFIRMED major we translated (for diffing)
  ZoneStatus _lastStatus = ZoneStatus.standby;

  /// Zone TRANSITIONS for the audio layer.
  Stream<ZoneEvent> get events => _events.stream;

  /// Enriched, change-gated status for the UI + Phase 3.
  Stream<ZoneStatus> get status => _status.stream;

  /// Raw per-major signal snapshots straight from the registry (1 Hz heartbeat
  /// + immediate on new sighting), carrying [ZoneSignal.rssiByMinor]. Ungated
  /// on purpose: consumers that need STABLE per-minor presence (the live
  /// exhibit list) apply their own hysteresis via ExhibitPresenceTracker. The
  /// arbiter path is unaffected — it consumes the same broadcast stream.
  Stream<List<ZoneSignal>> get signals => _registry.zoneSignals;

  ZoneStatus get currentStatus => _lastStatus;

  /// Warm the catalog once, then start. Mirrors BeaconService.initialize.
  Future<void> initialize() async {
    await _repo.preWarm();
    if (_events.isClosed) return;
    start();
  }

  /// Start / resume the pipeline. Idempotent. Safe to call after [stop].
  void start() {
    if (_running) return;
    _running = true;

    _presenceSub ??= _arbiter.presence.listen(_onPresence);
    _signalSub ??= _registry.zoneSignals.listen(_arbiter.onSnapshot);
    _readingSub ??=
        _scanner.readings.listen(_onReading, onError: _onError);

    _registry.start();
    _scanner.startScan();
  }

  /// UUID guard, then feed the registry hot path. O(1) per packet.
  void _onReading(BeaconReading r) {
    if (r.uuid.toLowerCase() != _museumUuid) return;
    _registry.onReading(r);
  }

  void _onError(Object e, StackTrace st) {
    if (kDebugMode) debugPrint('[ZonePresenceService] scan error: $e');
  }

  /// Diff the arbiter's presence into a zone transition + enriched status.
  void _onPresence(ZonePresence p) {
    final int? major = p.currentMajor;

    // --- transition events (only on a confirmed-major change) ---
    if (major != _lastMajor) {
      if (_lastMajor == null && major != null) {
        _emitEvent(EnteredZone(major));
      } else if (_lastMajor != null && major != null) {
        _emitEvent(ChangedZone(_lastMajor!, major));
      } else if (_lastMajor != null && major == null) {
        _emitEvent(const LeftToStandby());
      }
      _lastMajor = major;
    }

    // --- enriched status (change-gated) ---
    final zone = major == null ? null : _repo.zoneByMajor(major);
    final next = ZoneStatus(zone: zone, deskStable: p.deskStable);
    if (next != _lastStatus) {
      _lastStatus = next;
      if (!_status.isClosed) _status.add(next);
    }
  }

  void _emitEvent(ZoneEvent e) {
    if (!_events.isClosed) _events.add(e);
    if (kDebugMode) debugPrint('[ZonePresenceService] event: ${e.runtimeType}');
  }

  /// Pause the pipeline (e.g. app backgrounded). Keeps subscriptions so
  /// resume via [start] is cheap; stops scanning to save battery.
  void stop() {
    if (!_running) return;
    _running = false;
    _scanner.stopScan();
    _registry.stop();
    // Presence diff state intentionally preserved so a quick resume doesn't
    // re-fire an EnteredZone for the same zone the visitor never left.
  }

  Future<void> dispose() async {
    _running = false;
    await _readingSub?.cancel();
    await _signalSub?.cancel();
    await _presenceSub?.cancel();
    _scanner.stopScan();
    _registry.dispose();
    _arbiter.dispose();
    if (!_events.isClosed) await _events.close();
    if (!_status.isClosed) await _status.close();
  }
}