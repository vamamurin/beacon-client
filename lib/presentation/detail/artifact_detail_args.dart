import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/proximity_info.dart';

/// Immutable snapshot handed to the Detail screen at navigation time.
///
/// Carrying a *frozen* [ProximityInfo] (itself immutable) — rather than a live
/// provider reference or a stream — is what guarantees the Detail screen stays
/// inert while background RSSI fluctuates: there is no subscription to fire and
/// no mutable field to rebuild from. The screen reads `args.info.artifact`,
/// `args.info.floor`, and (if displayed) the distance captured at tap time.
///
/// Contract: pass this as the route argument. Never pass the provider, a
/// stream, or a still-tracked mutable object — doing so would re-open the
/// reactivity the push-navigation split is meant to close.
@immutable
class ArtifactDetailArgs {
  /// The artifact + floor + distance, snapshotted at the moment of the tap.
  final ProximityInfo info;

  const ArtifactDetailArgs({required this.info});
}
