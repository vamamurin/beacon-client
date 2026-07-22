// Destination: lib/data/processors/beacon_tracker_registry.dart (REPLACES file)
//
// What changed vs the previous version (zone-first refactor, Phase 1 Step 3):
//   OUTPUT:  List<ActiveBeacon> leaderboard (sorted by metres, per-beacon)
//            → List<ZoneSignal> snapshot (aggregated PER MAJOR, sorted by dB).
//   EMISSION PHILOSOPHY — deliberately REVERSED: the old registry fed the UI
//            directly, so signature-gating was essential. This registry feeds
//            the ZoneArbiter, which consumes snapshots as a CLOCK (dwell and
//            lockout are time-based). It therefore emits UNGATED:
//              • a 1 Hz heartbeat on every sweep (even if nothing changed,
//                even if the snapshot is empty), plus
//              • an immediate emit when a NEW beacon appears (zone-entry
//                latency: first packet → candidate starts without waiting up
//                to 1 s for the next tick).
//            UI-facing change-gating now lives one layer up, on ZonePresence.
//   CLOCK:   DateTime.now() is injected (`now` ctor param) so sweeps are
//            deterministic under FakeAsync in tests.
//   KEPT:    O(1) hot path, create-on-sight trackers, staleness demotion /
//            eviction sweep, maxTrackers flood ceiling, stop()/dispose()
//            semantics, no-await-across-mutation concurrency rule.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/processors/beacon_tracker.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/zone_signal.dart';

class BeaconTrackerRegistry {
  BeaconTrackerRegistry({
    Duration stalenessThreshold = const Duration(seconds: 3),
    Duration evictionThreshold = const Duration(seconds: 12),
    Duration sweepInterval = const Duration(seconds: 1),
    int maxTrackers = 64,
    double kalmanProcessNoise = 0.008,
    double kalmanMeasurementNoise = 4.0,
    DateTime Function()? now,
  })  : _stalenessThreshold = stalenessThreshold,
        _evictionThreshold = evictionThreshold,
        _sweepInterval = sweepInterval,
        _maxTrackers = maxTrackers,
        _kalmanProcessNoise = kalmanProcessNoise,
        _kalmanMeasurementNoise = kalmanMeasurementNoise,
        _now = now ?? DateTime.now;

  /// Beacon silent longer than this → excluded from the aggregate (its zone
  /// may still be carried by sibling minors). ~30 missed packets at 100 ms.
  final Duration _stalenessThreshold;

  /// Silent longer than this → tracker evicted (GC). ≫ staleness so a briefly
  /// occluded beacon keeps warm Kalman state instead of cold-restarting.
  final Duration _evictionThreshold;

  final Duration _sweepInterval;

  /// Defensive ceiling against scan flooding (UUID filter upstream already
  /// limits traffic to museum packets).
  final int _maxTrackers;
  
  final double _kalmanProcessNoise;
  final double _kalmanMeasurementNoise;

  /// Injected time authority — swap for a fake in tests.
  final DateTime Function() _now;

  final Map<int, BeaconTracker> _trackers = {}; // O(1) by packed key
  final _controller = StreamController<List<ZoneSignal>>.broadcast();
  Timer? _sweepTimer;

  /// Per-major aggregate snapshots, strongest zone first.
  /// Contract: 1 Hz heartbeat + immediate emit on new-beacon sighting.
  /// NOT change-gated — see header note.
  Stream<List<ZoneSignal>> get zoneSignals => _controller.stream;

  /// Live tracker count — debug/ops surface and test hook.
  @visibleForTesting
  int get trackerCount => _trackers.length;

  /// Idempotent. Begins the 1 Hz sweep (the pipeline's heartbeat).
  void start() {
    _sweepTimer ??= Timer.periodic(_sweepInterval, _sweep);
  }

  /// HOT PATH — O(1): packed-key lookup + one Kalman step. Projection stays
  /// off the per-packet path except for the rare new-beacon case.
  void onReading(BeaconReading reading) {
    if (_controller.isClosed) return;

    final key = BeaconTracker.packKey(reading.major, reading.minor);
    final existing = _trackers[key];

    if (existing == null) {
      if (_trackers.length >= _maxTrackers) {
        if (kDebugMode) {
          debugPrint('[Registry] saturated ($_maxTrackers) — drop new $key');
        }
        return;
      }
      
      _trackers[key] = BeaconTracker(
        reading,
        processNoise: _kalmanProcessNoise,
        measurementNoise: _kalmanMeasurementNoise,
      );

      if (kDebugMode) {
        debugPrint('[Registry] + tracker $key (live=${_trackers.length})');
      }
      _emitSnapshot(); // NEW SIGHTING → publish immediately (entry latency)
      return;
    }

    existing.update(reading); // O(1); next heartbeat carries the new value
  }

  /// 1 Hz temporal authority: evict dead trackers, then emit the heartbeat
  /// snapshot unconditionally.
  void _sweep(Timer _) {
    if (_controller.isClosed) return;
    final now = _now();

    for (final key in _trackers.keys.toList(growable: false)) {
      final t = _trackers[key];
      if (t == null) continue;
      if (t.isStaleAt(now, _evictionThreshold)) {
        _trackers.remove(key);
        if (kDebugMode) {
          debugPrint('[Registry] - evict $key '
              '(silent > ${_evictionThreshold.inSeconds}s)');
        }
      }
    }

    _emitSnapshot();
  }

  /// Aggregate live (non-stale) trackers by major and publish. O(N) over a
  /// population bounded by museum beacons in RF range — trivially cheap at
  /// 1 Hz + rare sightings.
  void _emitSnapshot() {
    if (_controller.isClosed) return;
    final now = _now();

    final byMajor = <int, _MajorAgg>{};
    for (final t in _trackers.values) {
      if (t.isStaleAt(now, _stalenessThreshold)) continue; // silent ⇒ no vote
      final agg = byMajor.putIfAbsent(t.major, () => _MajorAgg());
      agg.rssiByMinor[t.minor] = t.smoothedRssi;
      if (t.smoothedRssi > agg.maxRssi) {
        agg.maxRssi = t.smoothedRssi;
        // C1: measuredPower đi CẶP với rssiDb — cùng lấy từ beacon mạnh nhất,
        // để phép ước lượng khoảng cách downstream dùng đúng hiệu chuẩn của
        // chính phần cứng đang đại diện cho zone.
        agg.measuredPower = t.measuredPower;
      }
      if (agg.lastSeen == null || t.lastSeen.isAfter(agg.lastSeen!)) {
        agg.lastSeen = t.lastSeen;
      }
    }

    final snapshot = <ZoneSignal>[
      for (final e in byMajor.entries)
        ZoneSignal(
          major: e.key,
          rssiDb: e.value.maxRssi,
          rssiByMinor: Map.unmodifiable(e.value.rssiByMinor),
          lastSeenAt: e.value.lastSeen!,
          measuredPowerDbm: e.value.measuredPower,
        ),
    ]..sort((a, b) => b.rssiDb.compareTo(a.rssiDb)); // strongest first

    _controller.add(snapshot);
  }

  /// Cancel the sweep and drop all state (stop→start cycle).
  void stop() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _trackers.clear();
  }

  void dispose() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _trackers.clear();
    if (!_controller.isClosed) _controller.close();
  }
}

/// Mutable scratch cell used only inside one _emitSnapshot pass.
class _MajorAgg {
  double maxRssi = double.negativeInfinity;
  int measuredPower = -59; // C1: của minor mạnh nhất, cập nhật cùng maxRssi
  final Map<int, double> rssiByMinor = {};
  DateTime? lastSeen;
}