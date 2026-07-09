// Destination: lib/presentation/providers/zone_provider.dart (REPLACES current)
//
// Thin ChangeNotifier over an enriched zone-status stream. Gives the UI the
// current zone (resolved ZoneInfo) or null for standby/radar.
//
// Takes a Stream + initial value rather than a ZonePresenceService: the
// provider never needed the service, only its output. Depending on the concrete
// service dragged ZoneArbiter, BeaconTrackerRegistry and an IBeaconScanner into
// every widget test of screen 2. Now a test drives it with Stream.value().
//
// `initial` MUST come from the service's cached currentStatus, never from
// ZoneStatus.standby: providers are lazy, so this is constructed when ZoneScreen
// first mounts — possibly long after the arbiter settled on a zone. Seeding with
// standby would flash the radar screen for one frame while already inside a zone.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

class ZoneProvider extends ChangeNotifier {
  ZoneProvider({
    required Stream<ZoneStatus> status,
    required ZoneStatus initial,
  }) : _status = initial {
    // Seed BEFORE subscribing. The old code listened first and assigned
    // currentStatus afterwards, so a synchronously-emitting stream would have
    // its first value silently overwritten. The production broadcast stream
    // never emits sync; a test stream can.
    _sub = status.listen((s) {
      _status = s;
      notifyListeners();
    });
  }

  late final StreamSubscription<ZoneStatus> _sub;

  ZoneStatus _status;
  ZoneStatus get status => _status;

  /// Current zone, or null when in standby (show the radar screen).
  ZoneInfo? get currentZone => _status.zone;
  bool get inZone => _status.inZone;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}