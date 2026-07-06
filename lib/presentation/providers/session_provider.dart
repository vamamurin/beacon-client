// Destination: lib/presentation/providers/session_provider.dart
//
// Thin ChangeNotifier over SessionController's state stream. The UI listens to
// this provider; it never touches the controller's internals. Intents (start
// tour, staff end) are forwarded through explicit methods so the widget layer
// has one clear surface.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/session_controller.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider(this._controller) {
    _sub = _controller.state.listen((s) {
      _state = s;
      notifyListeners();
    });
    _state = _controller.current;
  }

  final SessionController _controller;
  late StreamSubscription<SessionState> _sub;

  SessionState _state = SessionState.initial;
  SessionState get state => _state;

  bool get isAtGate => _state.isAtGate;
  bool get isTouring => _state.isTouring;
  SessionPhase get phase => _state.phase;

  /// Visitor pressed "Bắt đầu tham quan" on the gate.
  void startTour() => _controller.userStartedTour();

  /// Staff manual end (hidden control).
  void endTour() => _controller.staffEndSession();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
