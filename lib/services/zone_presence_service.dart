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
    void Function(Object error)? onScanFailure,
  })  : _scanner = scanner,
        _repo = repository,
        _museumUuid = museumUuidLower,
        _registry = registry,
        _arbiter = arbiter,
        _onScanFailure = onScanFailure;

  final IBeaconScanner _scanner;
  final IZoneRepository _repo;
  final String _museumUuid;
  final BeaconTrackerRegistry _registry;
  final ZoneArbiter _arbiter;

  /// Called when the radio refuses to start (adapter switched off, permission
  /// revoked while running). Lets the composition root re-derive BLE readiness
  /// so the Gate can show a real status instead of the app failing silently.
  final void Function(Object error)? _onScanFailure;

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

  /// Wall-clock của gói beacon mới nhất (mọi major, kể cả desk) mà arbiter đã
  /// nghe — hoặc null khi chưa nghe gì từ lúc pipeline khởi động. POLL bởi
  /// SessionController mỗi sweep 1 Hz (P1-1): arbiter luôn giữ giá trị tươi
  /// trong `current` kể cả khi presence không đổi nên không emit.
  DateTime? get lastBeaconAt => _arbiter.current.lastBeaconAt;

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
    unawaited(_startScanGuarded());
  }

  /// `startScan()` is async and THROWS on a hostile radio (adapter switched off
  /// between the readiness check and here, permission revoked mid-run). Left
  /// unawaited and uncaught that becomes an unhandled async error: the visitor
  /// sees a tour that silently stops finding beacons, and the Gate keeps
  /// claiming everything is ready.
  ///
  /// Reachable in normal use — AppGraph.retryBluetooth() calls start() right
  /// after ensureReady(), and the adapter can go down inside that window.
  ///
  /// On failure we drop back to "not running" so a later retry (button, resume,
  /// or the adapterOn watcher) genuinely re-attempts instead of short-circuiting
  /// on the idempotence guard.
  Future<void> _startScanGuarded() async {
    try {
      await _scanner.startScan();
    } catch (e) {
      _running = false;
      if (kDebugMode) debugPrint('[ZonePresenceService] startScan failed: $e');
      _onScanFailure?.call(e);
    }
  }

  /// Re-announce the CURRENTLY confirmed zone as a fresh [EnteredZone], if any.
  ///
  /// Called when a tour starts (gate -> touring). The arbiter only emits on a
  /// CHANGE, so a visitor who was already standing inside a zone at the moment
  /// they press Start would otherwise get no event — no intro, no grace close,
  /// and the audio controller would never learn its active zone. Resetting the
  /// diff anchor and replaying the arbiter's current presence produces exactly
  /// the EnteredZone that "just walked in" would, through the SAME event stream
  /// the router and session already consume.
  ///
  /// No-op when there's no confirmed zone (standby, or resting at the desk —
  /// the desk major is arbitrated separately and never becomes currentMajor),
  /// so the start-grace that protects a visitor lingering on the dock is kept.
  void resyncCurrentZone() {
    if (!_running) return;
    _lastMajor = null; // make the next diff look like a fresh acquisition
    _onPresence(_arbiter.current);
  }

  /// FIX P1 — đưa TOÀN BỘ đường radio về trắng cho một tour mới.
  ///
  /// Gọi ở đầu mỗi tour, TRƯỚC [resyncCurrentZone]. Xoá state phiên của arbiter
  /// (xem [ZoneArbiter.resetForNewSession]) và cả mốc diff ở tầng này, để tour
  /// mới không thừa hưởng "khu hiện tại" mà máy đã chốt trong lúc nằm ở dock.
  ///
  /// Hệ quả có chủ đích: sau reset, [resyncCurrentZone] thành no-op (arbiter
  /// đang standby). Khách đứng sẵn trong một khu lúc bấm Bắt đầu sẽ chờ tối đa
  /// một nhịp snapshot (~1 s) rồi nhận EnteredZone tự nhiên từ luật 1 — đúng
  /// đường đi thật, thay vì một sự kiện được dựng lại từ state cũ.
  void resetForNewSession() {
    _arbiter.resetForNewSession();
    _lastMajor = null;
    _lastStatus = ZoneStatus.standby;
    if (kDebugMode) debugPrint('[ZonePresenceService] reset cho phiên mới');
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

  /// Halt the pipeline AND declare that we now know nothing.
  ///
  /// Different intent from [stop]. `stop` is a battery PAUSE and deliberately
  /// preserves the diff anchor so a quick resume doesn't re-fire EnteredZone for
  /// a zone the visitor never left. This one is for when the radio is genuinely
  /// unavailable (adapter switched off): continuing to display a zone the device
  /// provably cannot hear is worse than showing standby.
  ///
  /// Drains synchronously instead of letting the silence timers expire, because
  /// those timers are driven by the very heartbeat we are about to stop.
  void stopAndClear() {
    stop();
    _arbiter.resetForNewSession(); // wipe confirmed zone / lockout / candidate
    if (_lastMajor != null) {
      _emitEvent(const LeftToStandby()); // audio + session hear about it
      _lastMajor = null;
    }
    if (_lastStatus != ZoneStatus.standby) {
      _lastStatus = ZoneStatus.standby;
      if (!_status.isClosed) _status.add(ZoneStatus.standby);
    }
  }

  /// Pause the pipeline (e.g. app backgrounded). Keeps subscriptions so
  /// resume via [start] is cheap; stops scanning to save battery.
  void stop() {
    if (!_running) return;
    _running = false;
    unawaited(_stopScanGuarded());
    _registry.stop();
    // Presence diff state intentionally preserved so a quick resume doesn't
    // re-fire an EnteredZone for the same zone the visitor never left.
  }

  /// Stopping a radio that is already down throws on some ROMs. A failure to
  /// stop is never actionable — we are tearing down either way — so it is
  /// swallowed rather than propagated to an unhandled zone.
  Future<void> _stopScanGuarded() async {
    try {
      await _scanner.stopScan();
    } catch (e) {
      if (kDebugMode) debugPrint('[ZonePresenceService] stopScan failed: $e');
    }
  }

  Future<void> dispose() async {
    _running = false;
    await _readingSub?.cancel();
    await _signalSub?.cancel();
    await _presenceSub?.cancel();
    await _stopScanGuarded();
    _registry.dispose();
    _arbiter.dispose();
    if (!_events.isClosed) await _events.close();
    if (!_status.isClosed) await _status.close();
  }
}