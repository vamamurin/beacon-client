import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/proximity_info.dart';

/// Immutable, **repository-free** projection of a single tracked beacon, used to
/// build the proximity leaderboard.
///
/// SoC: [BeaconTrackerRegistry] emits these (no artifact/floor knowledge);
/// [BeaconService] enriches each into a [ProximityInfo] via the repositories.
/// Keeping this repo-free lets the tracking core be unit-tested without fixtures.
class ActiveBeacon {
  /// Packed composite key: (major << 16) | minor.
  final int key;
  final int major;
  final int minor;

  /// Latest raw advertisement backing this projection.
  final BeaconReading reading;

  /// Kalman-smoothed, path-loss distance in metres (per-beacon).
  final double smoothedDistance;

  /// Hysteresis zone from this beacon's own state machine.
  final ProximityZone zone;

  const ActiveBeacon({
    required this.key,
    required this.major,
    required this.minor,
    required this.reading,
    required this.smoothedDistance,
    required this.zone,
  });
}
