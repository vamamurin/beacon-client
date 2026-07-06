// Destination: lib/presentation/providers/zone_provider.dart
//
// Thin ChangeNotifier over ZonePresenceService's enriched status stream. Gives
// the UI the current zone (resolved ZoneInfo) or null for standby/radar.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

class ZoneProvider extends ChangeNotifier {
  ZoneProvider(this._service) {
    _sub = _service.status.listen((s) {
      _status = s;
      notifyListeners();
    });
    _status = _service.currentStatus;
  }

  final ZonePresenceService _service;
  late StreamSubscription<ZoneStatus> _sub;

  ZoneStatus _status = ZoneStatus.standby;
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
