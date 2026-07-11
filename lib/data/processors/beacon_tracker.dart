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

  final KalmanFilter _filter = KalmanFilter();

  double _smoothedRssi = double.negativeInfinity;
  late DateTime _lastSeen;

  /// C1 — Measured Power mới nhất beacon này tự khai (Phase 2 đã validate ở
  /// Scanner). Về lý thuyết là hằng số của phần cứng; lấy theo gói mới nhất
  /// để đổi pin/đổi cấu hình beacon có hiệu lực ngay không cần restart app.
  int _measuredPower = -59;

  BeaconTracker(BeaconReading initial)
      : key = packKey(initial.major, initial.minor),
        major = initial.major,
        minor = initial.minor {
    update(initial); // seed the Kalman with the first packet
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
  void update(BeaconReading reading) {
    _smoothedRssi = _filter.update(reading.rssi.toDouble());
    _lastSeen = reading.timestamp;
    _measuredPower = reading.measuredPower;
  }

  /// True when (now − lastSeen) exceeds [limit].
  bool isStaleAt(DateTime now, Duration limit) =>
      now.difference(_lastSeen) > limit;

  static int packKey(int major, int minor) => (major << 16) | minor;
}