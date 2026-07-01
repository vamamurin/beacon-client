import 'package:beacon_client/domain/interfaces/i_bluetooth_gate.dart';
import 'package:beacon_client/domain/models/startup_status.dart';

/// Gate giả cho môi trường dev/demo không có phần cứng BLE (khớp với
/// [MockBeaconScanner]). Luôn báo `ready` và adapter `on`.
class MockBluetoothGate implements IBluetoothGate {
  @override
  Future<StartupStatus> ensureReady() async => StartupStatus.ready;

  @override
  Stream<bool> get adapterOn => Stream<bool>.value(true);

  @override
  Future<bool> openSettings() async => false;

  @override
  Future<bool> hasPermissions() async => true;

  @override
  void dispose() {}
}
