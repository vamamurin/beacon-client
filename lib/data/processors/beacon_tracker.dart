// Destination: lib/data/processors/beacon_tracker.dart (REPLACES current file)
//
// What changed vs the previous version (zone-first refactor, Phase 1 Step 3):
//   REMOVED: ProximityStateMachine (per-beacon distance zones are gone),
//            RSSI→metres conversion (arbitration works in dB; metres and the
//            path-loss model leave the pipeline entirely),
//            markLost() (zone demotion is no longer a tracker concept —
//            a silent beacon simply stops CONTRIBUTING to the aggregate;
//            believing/unbelieving a zone is the ZoneArbiter's job),
//            imports of constants.dart / proximity_info.dart.
//   KEPT:    one KalmanFilter per physical beacon (the filter-thrashing fix —
//            beacons sharing a major are still distinct RF sources and must
//            never share a filter), packed key, O(1) synchronous update,
//            packet-timestamp staleness.

import 'package:beacon_client/data/processors/kalman_filter.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

/// Per-physical-beacon state cell: exactly one [KalmanFilter] + last-seen
/// bookkeeping. Fully isolated from every other beacon so interleaved packets
/// (A,B,A,B…) can never corrupt each other's estimate.
///
/// All operations are O(1) and fully synchronous — atomic on the Dart event
/// loop, no locks required. (Implementation rule: never introduce an `await`
/// between reads/writes of this state.)
class BeaconTracker {
  /// Packed composite key: (major << 16) | minor.
  final int key;
  final int major;
  final int minor;

  final KalmanFilter _filter;

  double _smoothedRssi = double.negativeInfinity;

  /// Non-late: the Kalman step now READS this to derive its time delta, and the
  /// constructor's own `update(initial)` call would otherwise touch it before
  /// assignment. Seeded from the first packet, so that first step sees dt = 0.
  DateTime _lastSeen;

  /// C1 — Measured Power mới nhất beacon này tự khai (Phase 2 đã validate ở
  /// Scanner). Về lý thuyết là hằng số của phần cứng; lấy theo gói mới nhất
  /// để đổi pin/đổi cấu hình beacon có hiệu lực ngay không cần restart app.
  int _measuredPower = -59;

  BeaconTracker(
    BeaconReading initial, {
    double processNoise = 0.008,
    double measurementNoise = 4.0,
  })  : key = packKey(initial.major, initial.minor),
        major = initial.major,
        minor = initial.minor,
        _lastSeen = initial.timestamp,
        _filter = KalmanFilter(
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        ) {
    update(initial);
  }
  /// Kalman-smoothed RSSI in dBm. The ONLY signal quantity this pipeline
  /// carries from here on.
  double get smoothedRssi => _smoothedRssi;

  DateTime get lastSeen => _lastSeen;

  /// C1 — hiệu chuẩn @1m của chính beacon này (xem [_measuredPower]).
  int get measuredPower => _measuredPower;

  /// HOT PATH — feed one packet. O(1): a single Kalman step.
  /// [lastSeen] is stamped from the packet's own timestamp so the registry
  /// sweep detects signal loss against its injected clock.
  ///
  /// That same packet clock now also drives the filter: the gap between THIS
  /// packet and the previous one from THIS beacon is how much real time the
  /// estimate was allowed to go stale. Feeding it in is what stops the filter's
  /// responsiveness from silently tracking the BLE packet rate — see the header
  /// of [KalmanFilter]. Using packet timestamps rather than DateTime.now() also
  /// keeps the whole pipeline deterministic under FakeAsync.
  void update(BeaconReading reading) {
    final elapsed = reading.timestamp.difference(_lastSeen);
    _smoothedRssi = _filter.update(reading.rssi.toDouble(), elapsed: elapsed);
    _lastSeen = reading.timestamp;
    _measuredPower = reading.measuredPower;
  }

  /// True when (now − lastSeen) exceeds [limit].
  bool isStaleAt(DateTime now, Duration limit) =>
      now.difference(_lastSeen) > limit;

  static int packKey(int major, int minor) => (major << 16) | minor;
}