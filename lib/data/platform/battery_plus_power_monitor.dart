// Destination: lib/data/platform/battery_plus_power_monitor.dart
//
// Real IPowerMonitor over battery_plus. Maps BatteryState to the single
// boolean the session machine cares about: "is the device on the dock (power
// connected)?".
//
// IMPORTANT mapping detail: on the dock a device that has finished charging
// reports `full` or `connectedNotCharging`, NOT `charging`. Treating only
// `charging` as "docked" would misread a full battery on the dock as
// "unplugged" and wake a fresh session by mistake. So "connected" =
// charging OR full OR connectedNotCharging; "unplugged" = discharging.
//
// NOT unit-tested (plugin/hardware). FakePowerMonitor covers session logic;
// this is verified via the on-device checklist.

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_power_monitor.dart';

class BatteryPlusPowerMonitor implements IPowerMonitor {
  final Battery _battery = Battery();

  bool _charging = true; // assume docked at construction (normal boot)
  final _ctrl = StreamController<bool>.broadcast();
  StreamSubscription<BatteryState>? _sub;

  @override
  bool get isCharging => _charging;

  @override
  Stream<bool> get onChargingChanged => _ctrl.stream;

  @override
  Future<void> start() async {
    // Seed from current state.
    try {
      _charging = _isConnected(await _battery.batteryState);
    } catch (e) {
      if (kDebugMode) debugPrint('[PowerMonitor] initial read failed: $e');
    }
    _sub ??= _battery.onBatteryStateChanged.listen((state) {
      _update(_isConnected(state));
    });
  }

  /// "On the dock / power connected" — everything except actively discharging.
  bool _isConnected(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
      case BatteryState.full:
      case BatteryState.connectedNotCharging:
        return true;
      case BatteryState.discharging:
        return false;
      case BatteryState.unknown:
        // Ambiguous — keep last known rather than flip-flopping the session.
        return _charging;
    }
  }

  void _update(bool connected) {
    if (connected == _charging) return;
    _charging = connected;
    if (!_ctrl.isClosed) _ctrl.add(connected);
    if (kDebugMode) {
      debugPrint('[PowerMonitor] ${connected ? "docked" : "unplugged"}');
    }
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
