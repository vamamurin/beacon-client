import 'package:beacon_client/core/constants.dart';
import 'package:beacon_client/domain/models/proximity_info.dart';

/// Hysteresis state machine that prevents UI flickering when the user stands
/// near a zone boundary.
///
/// Entry thresholds are tighter than exit thresholds, so a user has to move
/// noticeably away before a zone downgrade is emitted.
///
///   e.g. near3m → near5m transition only fires at > 3.3 m, not 3.0 m.
class ProximityStateMachine {
  ProximityZone _state = ProximityZone.outOfRange;

  ProximityZone get currentZone => _state;

  ProximityZone process(double distance) {
    switch (_state) {
      case ProximityZone.outOfRange:
        if (distance <= AppConstants.zone2Entry) _state = ProximityZone.near5m;

      case ProximityZone.near5m:
        if (distance <= AppConstants.zone3Entry) {
          _state = ProximityZone.near3m;
        } else if (distance > AppConstants.zone2Exit) {
          _state = ProximityZone.outOfRange;
        }

      case ProximityZone.near3m:
        if (distance <= AppConstants.zone4Entry) {
          _state = ProximityZone.near2m;
        } else if (distance > AppConstants.zone3Exit) {
          _state = ProximityZone.near5m;
        }

      case ProximityZone.near2m:
        if (distance > AppConstants.zone4Exit) _state = ProximityZone.near3m;
    }

    return _state;
  }

  void reset() => _state = ProximityZone.outOfRange;
}
