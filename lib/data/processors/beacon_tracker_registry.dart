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

  /// Xem ghi chú ở [_sweep]. Mặc định TẮT: đây là dụng cụ đo, không phải log
  /// vận hành — 1 dòng/giây sẽ dìm chết mọi log khác nếu để bật.
  static const bool _kHeartbeat =
      bool.fromEnvironment('BLE_HEARTBEAT', defaultValue: false);

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
      if (_trackers.length >= _maxTrackers && !_makeRoomFor(reading)) {
        return; // ceiling reached and the newcomer is the weakest — ignore it
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

  /// Free one slot for [incoming], or report that it doesn't deserve one.
  ///
  /// WHY THIS EXISTS. The old policy was "at the ceiling, drop the newcomer".
  /// That is the wrong beacon to drop, and the failure is permanent rather than
  /// transient: incumbents keep advertising, so they never reach the eviction
  /// threshold, so the population freezes as "the first [_maxTrackers] beacons
  /// this device happened to hear". A visitor could then stand directly in
  /// front of an exhibit whose beacon is invisible for the rest of the tour —
  /// and it fails worst exactly where it matters most, in a large open hall
  /// where many beacons are in RF range at once.
  ///
  /// The old justification ("the UUID filter upstream already limits traffic")
  /// does not apply. That guard lives in ZonePresenceService._onReading and
  /// filters to the MUSEUM's UUID — but every museum beacon shares that one
  /// UUID, so the ceiling is consumed entirely by legitimate beacons.
  ///
  /// New policy: the ceiling bounds MEMORY, so who occupies it should be
  /// decided by usefulness, not arrival order. Evict the weakest incumbent, and
  /// only if the newcomer is actually stronger — so a distant stray can't evict
  /// a beacon the visitor is standing next to, and a saturated registry still
  /// converges on the NEAREST [_maxTrackers] beacons.
  ///
  /// Comparison is on RAW rssi: the newcomer has no Kalman estimate yet, and
  /// one raw sample is the only thing the two have in common.
  bool _makeRoomFor(BeaconReading incoming) {
    int? weakestKey;
    double weakestRssi = double.infinity;
    for (final e in _trackers.entries) {
      final rssi = e.value.smoothedRssi;
      if (rssi < weakestRssi) {
        weakestRssi = rssi;
        weakestKey = e.key;
      }
    }

    if (weakestKey == null) return false; // ceiling is 0 — nothing to do
    if (incoming.rssi <= weakestRssi) {
      if (kDebugMode) {
        debugPrint('[Registry] saturated ($_maxTrackers) — ${incoming.rssi} dBm '
            'is weaker than the weakest tracked (${weakestRssi.toStringAsFixed(1)}), keep it out');
      }
      return false;
    }

    _trackers.remove(weakestKey);
    if (kDebugMode) {
      debugPrint('[Registry] saturated ($_maxTrackers) — evict weakest '
          '$weakestKey (${weakestRssi.toStringAsFixed(1)} dBm) for a '
          '${incoming.rssi} dBm newcomer');
    }
    return true;
  }

  /// 1 Hz temporal authority: evict dead trackers, then emit the heartbeat
  /// snapshot unconditionally.
  void _sweep(Timer _) {
    if (_controller.isClosed) return;
    final now = _now();

    // NHỊP TIM CHẨN ĐOÁN — bật bằng --dart-define=BLE_HEARTBEAT=true.
    //
    // Trả lời đúng MỘT câu hỏi, câu duy nhất không thể suy ra từ log có sẵn:
    // khi màn hình tắt và app im tiếng, tiến trình còn SỐNG hay đã bị đóng băng?
    //   • Nhịp tiếp tục, live=0 ⇒ isolate sống, timer chạy, nhưng KHÔNG có gói
    //     beacon nào tới. Vấn đề ở tầng giao kết quả quét (chính sách Android).
    //   • Nhịp NGỪNG hẳn      ⇒ cả tiến trình bị treo. Đây là lớp tiết kiệm pin
    //     riêng của ROM (MIUI/HyperOS), foreground service không cứu được —
    //     phải whitelist trong cài đặt máy.
    // Log [iBeacon] một mình KHÔNG phân biệt được hai ca này: cả hai đều tắt log.
    // Đặt ở sweep 1 Hz vì đây là nhịp duy nhất chạy độc lập với sóng BLE.
    if (_kHeartbeat) {
      debugPrint('[Heartbeat] ${now.toIso8601String()} live=${_trackers.length}');
    }

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
  ///
  /// Publishes ONE final empty snapshot before going quiet. Without it the last
  /// value consumers ever saw is the populated one from just before the stop,
  /// and since the heartbeat is what drives every downstream expiry clock
  /// (NearbyZonesTracker's hold window, the arbiter's silence timers), they
  /// would hold that stale world FOREVER — no further snapshot ever arrives to
  /// age it out.
  ///
  /// This is what made stopping the pipeline on Bluetooth-off freeze the exhibit
  /// list mid-tour, while the older "let the radio go silent" path drained
  /// correctly: silence still produced empty heartbeats, an explicit stop did
  /// not. A stopped registry must state that it now knows nothing.
  void stop() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _trackers.clear();
    _emitSnapshot(); // "we hear nothing" — lets downstream clocks start draining
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