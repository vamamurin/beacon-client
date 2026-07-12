// Destination: lib/presentation/providers/pending_zone_change_provider.dart
//
// Thin ChangeNotifier over the coordinator's pending stream. The banner overlay
// listens to this; confirm/dismiss are forwarded to the coordinator. Kept
// separate from ZoneProvider because its lifetime is app-global (the banner
// shows over ANY screen), whereas ZoneProvider is scoped to screen 2.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/services/zone_change_coordinator.dart';

class PendingZoneChangeProvider extends ChangeNotifier {
  PendingZoneChangeProvider(this._coordinator) {
    _pending = _coordinator.current;
    _sub = _coordinator.pending.listen((p) {
      _pending = p;
      notifyListeners();
    });
  }

  final ZoneChangeCoordinator _coordinator;
  late final StreamSubscription<PendingZoneChange?> _sub;

  PendingZoneChange? _pending;
  PendingZoneChange? get pending => _pending;
  bool get hasPending => _pending != null;

  void confirm() => _coordinator.confirm();
  void dismiss() => _coordinator.dismiss();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}