// Destination: lib/presentation/providers/pending_zone_change_provider.dart
//
// Thin ChangeNotifier over the coordinator's pending stream. The banner overlay
// listens to this; confirm/dismiss are forwarded to the coordinator. Kept
// separate from ZoneProvider because its lifetime is app-global (the banner
// shows over ANY screen), whereas ZoneProvider is scoped to screen 2.
//
// It ALSO surfaces a one-shot "navigate to zone B's exhibit list" signal after
// a CONFIRM (not a timeout auto-switch): the visitor who tapped "Chuyển" while
// on screen 3/4 of zone A should land on screen 3 of B. The signal is consumed
// by MuseumApp, which is the single owner of stack reshaping — the provider
// only reports intent; it never touches the Navigator itself.

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

  /// One-shot: the zone major the visitor just CONFIRMED a switch to, for the
  /// app to route to (screen 3 of B). Null until a confirm; cleared by
  /// [consumeConfirmedNavTarget]. Timeout auto-switches do NOT set this — the
  /// visitor didn't act, so we don't yank their screen.
  int? _confirmedNavTarget;
  int? get confirmedNavTarget => _confirmedNavTarget;

  void confirm() {
    final target = _pending?.toMajor;
    _coordinator.confirm();
    if (target != null) {
      _confirmedNavTarget = target;
      notifyListeners(); // wake MuseumApp to route
    }
  }

  /// MuseumApp calls this after it has performed the navigation, so the same
  /// target isn't re-consumed on a later rebuild.
  void consumeConfirmedNavTarget() => _confirmedNavTarget = null;

  void dismiss() => _coordinator.dismiss();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}