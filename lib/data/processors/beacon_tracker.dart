import 'dart:math';

import 'package:beacon_client/core/constants.dart';
import 'package:beacon_client/data/processors/kalman_filter.dart';
import 'package:beacon_client/data/processors/proximity_state_machine.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/proximity_info.dart';

/// Per-beacon state cell. Owns exactly **one** [KalmanFilter] + **one**
/// [ProximityStateMachine], fully isolated from every other beacon.
///
/// This is the structural fix for *filter thrashing*: interleaved packets from
/// different beacons (A,B,A,B…) land in different tracker instances, so they can
/// never `reset()` each other. The old per-packet reset no longer exists.
///
/// All mutating operations are O(1) and fully synchronous (no `await`), so they
/// are atomic on the Dart event loop — no locks required.
class BeaconTracker {
  /// Packed composite key: (major << 16) | minor.
  final int key;
  final int major;
  final int minor;

  final KalmanFilter _filter = KalmanFilter();
  final ProximityStateMachine _fsm = ProximityStateMachine();

  late BeaconReading _lastReading;
  late DateTime _lastSeen;
  double _smoothedDistance = double.infinity;
  ProximityZone _zone = ProximityZone.outOfRange;

  BeaconTracker(BeaconReading initial)
      : key = _packKey(initial.major, initial.minor),
        major = initial.major,
        minor = initial.minor {
    update(initial); // seed Kalman/FSM with the first packet
  }

  // ── O(1) read accessors ──
  BeaconReading get lastReading => _lastReading;
  DateTime get lastSeen => _lastSeen;
  double get smoothedDistance => _smoothedDistance;
  ProximityZone get zone => _zone;

  /// HOT PATH — feed one packet. O(1): Kalman update + log-distance + FSM step.
  /// [lastSeen] is stamped from the packet's own timestamp (the field finally
  /// gets consumed) so the registry sweep can detect signal loss.
  void update(BeaconReading reading) {
    final smoothedRssi = _filter.update(reading.rssi.toDouble());
    _smoothedDistance = _distanceFromRssi(smoothedRssi, reading.measuredPower);
    _zone = _fsm.process(_smoothedDistance);
    _lastReading = reading;
    _lastSeen = reading.timestamp;
  }

  /// True when (now − lastSeen) exceeds [limit]. Wall-clock based; for hardened
  /// builds swap in a monotonic Stopwatch source to survive NTP jumps.
  bool isStaleAt(DateTime now, Duration limit) =>
      now.difference(_lastSeen) > limit;

  /// Signal-loss demotion (temporal-ghosting fix): force the zone to
  /// `outOfRange` when the beacon has gone silent, **bypassing** the FSM's exit
  /// hysteresis — silence alone evicts it, the user need not walk to the wide
  /// exit threshold. The FSM is reset (not the Kalman) so re-entry uses entry
  /// thresholds while warm RSSI state survives a brief occlusion.
  ///
  /// Returns true iff the zone actually changed (lets the caller gate emission).
  bool markLost() {
    if (_zone == ProximityZone.outOfRange) return false;
    _fsm.reset(); // keep FSM state == _zone (avoid desync); Kalman stays warm
    _zone = ProximityZone.outOfRange;
    return true;
  }

  static int _packKey(int major, int minor) => (major << 16) | minor;

  /// Log-Distance path-loss model: d = 10 ^ ((MeasuredPower − RSSI) / (10·n)).
  /// MeasuredPower is per-beacon (from the packet); n is the environment-wide
  /// path-loss exponent.
  static double _distanceFromRssi(double rssi, int measuredPower) {
    final exponent =
        (measuredPower - rssi) / (10.0 * AppConstants.pathLossExponent);
    return pow(10.0, exponent).toDouble().clamp(0.1, 50.0);
  }
}
