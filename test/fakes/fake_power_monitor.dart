// Destination: test/fakes/fake_power_monitor.dart

import 'dart:async';

import 'package:beacon_client/domain/interfaces/i_power_monitor.dart';

/// In-memory power monitor. [setCharging] simulates dock/undock so the session
/// state machine can be tested deterministically.
class FakePowerMonitor implements IPowerMonitor {
  FakePowerMonitor({bool charging = true}) : _charging = charging;

  bool _charging;
  final _ctrl = StreamController<bool>.broadcast();

  @override
  bool get isCharging => _charging;

  @override
  Stream<bool> get onChargingChanged => _ctrl.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async => _ctrl.close();

  /// Simulate plugging (true) / unplugging (false) the dock.
  void setCharging(bool value) {
    if (value == _charging) return;
    _charging = value;
    _ctrl.add(value);
  }
}
