// FILE: /lib/data/gateways/real_bluetooth_gate.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:beacon_client/domain/interfaces/i_bluetooth_gate.dart';
import 'package:beacon_client/domain/models/startup_status.dart';

/// Triển khai gate thật cho Android (mirror các giả định Android-centric đã có
/// trong [RealBeaconScanner]/[DebugRadarScreen]: AndroidScanMode, BLUETOOTH_SCAN).
///
/// Thay thế hàm rời `requestBluetoothPermissions()` cũ: trước đây kết quả
/// `.request()` bị vứt đi và app vẫn quét dù bị từ chối/adapter tắt → hỏng câm.
/// Ở đây mọi nhánh hỏng được mô hình hoá thành [StartupStatus] tường minh.
class RealBluetoothGate implements IBluetoothGate {
  /// Adapter on/off, dùng cho phục hồi runtime. Map thẳng từ luồng phần cứng.
  @override
  Stream<bool> get adapterOn =>
      FlutterBluePlus.adapterState.map((s) => s == BluetoothAdapterState.on);

  @override
  Future<StartupStatus> ensureReady() async {
    // 1) Năng lực phần cứng — máy có BLE không?
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      if (kDebugMode) debugPrint('[Gate] thiết bị không hỗ trợ BLE');
      return StartupStatus.unsupported;
    }

    // 2) Quyền runtime (Android 12+: scan/connect; mọi API level: location cho
    //    BLE discovery). KHÁC bản cũ: kết quả được KIỂM TRA, không vứt đi.
    final permIssue = await _requestPermissions();
    if (permIssue != null) return permIssue;

    // 3) Nguồn adapter. Chờ tới khi adapterState thoát khỏi `unknown`
    //    (trạng thái lúc mới khởi tạo), có timeout để không treo mãi.
    final state = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => BluetoothAdapterState.unknown,
        );

    if (state != BluetoothAdapterState.on) {
      if (kDebugMode) debugPrint('[Gate] adapter chưa bật: $state');
      return StartupStatus.bluetoothOff;
    }

    return StartupStatus.ready;
  }

  /// `bluetoothScan` + `location` là hai quyền thực sự gate BLE discovery trên
  /// Android. Trên các bản < 12, scan/connect là normal permission → trả
  /// `granted`/`restricted` mà không hiện dialog, vẫn pass điều kiện isGranted.
  Future<StartupStatus?> _requestPermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final scan = results[Permission.bluetoothScan] ?? PermissionStatus.denied;
    final loc = results[Permission.location] ?? PermissionStatus.denied;
    
    if (scan.isGranted && loc.isGranted) return null; // đủ quyền

    // Nếu bất kỳ quyền nào bị cấm vĩnh viễn / restricted → không xin lại được.
    final permanently = scan == PermissionStatus.permanentlyDenied ||
        loc == PermissionStatus.permanentlyDenied ||
        scan == PermissionStatus.restricted ||
        loc == PermissionStatus.restricted;

    return permanently
        ? StartupStatus.permissionPermanentlyDenied
        : StartupStatus.permissionDenied;
  }

  @override
  Future<bool> hasPermissions() async {
    // .status KHÔNG hiện dialog (khác .request()) → an toàn để gọi mỗi resume.
    final scan = await Permission.bluetoothScan.status;
    final loc = await Permission.location.status;
    return scan.isGranted && loc.isGranted;
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  @override
  void dispose() {}
}
