import 'package:beacon_client/domain/models/startup_status.dart';

/// Hardware Abstraction Layer cho điều kiện tiên quyết Bluetooth.
///
/// Tách riêng khỏi [IBeaconScanner] để giữ trách nhiệm đơn nhất: scanner lo
/// *đọc gói*, gate lo *điều kiện được phép đọc* (quyền + nguồn adapter). Cho
/// phép swap Mock/Real qua DI giống các HAL khác.
///
/// Implementations:
///   - [RealBluetoothGate] – permission_handler + flutter_blue_plus (Android).
///   - [MockBluetoothGate]  – luôn `ready`, cho desktop dev/demo.
abstract interface class IBluetoothGate {
  /// Xin quyền runtime + kiểm tra adapter; trả về trạng thái đã giải quyết.
  /// Gọi lúc boot và mỗi lần người dùng bấm "Thử lại".
  Future<StartupStatus> ensureReady();

  /// Luồng on/off của adapter để phục hồi runtime (người dùng bật/tắt Bluetooth
  /// trong Settings mà không cần khởi động lại app). `true` ⇔ adapter đang bật.
  Stream<bool> get adapterOn;

  Future<bool> openSettings();

  Future<bool> hasPermissions();

  void dispose();
}
