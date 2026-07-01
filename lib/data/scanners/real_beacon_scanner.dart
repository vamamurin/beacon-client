// FILE: /lib/data/scanners/real_beacon_scanner.dart

// MARK: - 1. IMPORTS & DEPENDENCIES (Khai báo thư viện)
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

class RealBeaconScanner implements IBeaconScanner {
  RealBeaconScanner({this.scanMode = AndroidScanMode.lowLatency});

  
  // MARK: - 2. STATE VARIABLES & GETTERS (Biến nội bộ & Cổng truy xuất)
  // ============================================================================
  final AndroidScanMode scanMode;
  final _controller = StreamController<BeaconReading>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;

  // PHASE 2: cửa sổ Measured Power hợp lệ (dBm). Ngoài vùng này coi như gói rác
  // (nhiễu sóng / bit lỗi) → drop thẳng tay theo Strict Mode. Biên bao gồm 2 đầu.
  static const int _kMeasuredPowerMin = -100;
  static const int _kMeasuredPowerMax = -20;

  @override
  Stream<BeaconReading> get readings => _controller.stream;

  // MARK: - 3. HARDWARE CONTROL (Điều khiển Ăng-ten vật lý)
  // ============================================================================
  @override
  Future<void> startScan() async {
    // Flush Android BT cache: dừng scan cũ trước khi start mới.
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    // Hủy subscription cũ trước khi listen lại để tránh rò rỉ _scanSub
    // nếu startScan() bị gọi lặp mà chưa qua stopScan().
    await _scanSub?.cancel();
    _scanSub = null;

    await FlutterBluePlus.startScan(
      continuousUpdates: true,
      // lowLatency = scan liên tục, không duty-cycle, Android default là balanced (~5s delay)
      androidScanMode: scanMode,
    );

    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResults);
  }

  @override
  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
  }

  // MARK: - 4. DATA STREAM HANDLING (Hứng và Lọc luồng dữ liệu)
  // ============================================================================
  void _onScanResults(List<ScanResult> results) {
    for (final result in results) {
      final reading = _tryParseIBeacon(result);
      if (reading != null && !_controller.isClosed) {
        _controller.add(reading);
      }
    }
  }

  // MARK: - 5. iBEACON DECODING LOGIC (Giải mã Byte nhị phân chuẩn Apple)
  // ============================================================================
  /// Parse iBeacon từ ScanResult. Trả null nếu không phải iBeacon hợp lệ.
  /// Log chi tiết lý do thất bại để dễ debug qua `flutter logs`.
  BeaconReading? _tryParseIBeacon(ScanResult result) {
    final id = result.device.remoteId.str;
    final mfgData = result.advertisementData.manufacturerData;

    if (mfgData.isEmpty) {
      if (kDebugMode) {
        debugPrint('[iBeacon] $id — bỏ qua: không có manufacturer data');
      }
      return null;
    }

    // Log tất cả company ID tìm thấy để so sánh
    if (kDebugMode) {
      for (final entry in mfgData.entries) {
        final companyHex =
            '0x${entry.key.toRadixString(16).padLeft(4, '0').toUpperCase()}';
        final hex = entry.value
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
        debugPrint(
            '[iBeacon] $id — CompanyID=$companyHex (${entry.key}) len=${entry.value.length}b → $hex');
      }
    }

    // Apple Inc. company ID = 0x004C = 76
    final appleData = mfgData[0x004C];
    if (appleData == null) {
      if (kDebugMode) {
        final found = mfgData.keys
            .map((k) => '0x${k.toRadixString(16).padLeft(4, '0').toUpperCase()}')
            .join(', ');
        debugPrint(
            '[iBeacon] $id — FAIL: không có Apple company ID (0x004C). Tìm thấy: $found');
      }
      return null;
    }

    // PHASE 2 — STRICT MODE: cần ≥23 byte để đọc Measured Power ở index 22.
    // (Trước đây check ≥22 là off-by-one: đủ cho UUID/major/minor nhưng KHÔNG đủ
    // cho byte 23 → appleData[22] sẽ ném RangeError. Guard này bảo vệ toàn bộ
    // các index 0..22 đọc bên dưới.)
    if (appleData.length < 23) {
      if (kDebugMode) {
        debugPrint(
            '[iBeacon] $id — FAIL: data quá ngắn: ${appleData.length} bytes, cần ≥23 (để có Measured Power)');
      }
      return null;
    }

    // Byte 0: iBeacon subtype phải là 0x02
    if (appleData[0] != 0x02) {
      if (kDebugMode) {
        debugPrint(
            '[iBeacon] $id — FAIL: byte[0] sai subtype=0x${appleData[0].toRadixString(16).toUpperCase()} (cần 0x02)');
      }
      return null;
    }

    // Byte 1: payload length phải là 0x15 = 21
    if (appleData[1] != 0x15) {
      if (kDebugMode) {
        debugPrint(
            '[iBeacon] $id — FAIL: byte[1] sai length=0x${appleData[1].toRadixString(16).toUpperCase()} (cần 0x15=21)');
      }
      return null;
    }

    // UUID: bytes [2..17] (16 bytes)
    final uuid =
        _bytesToUuidString(Uint8List.fromList(appleData.sublist(2, 18)));

    // Major/Minor: big-endian
    final major = (appleData[18] << 8) | appleData[19];
    final minor = (appleData[20] << 8) | appleData[21];

    // PHASE 2 — MEASURED POWER (byte 23 = index 22):
    // BLE trả uint8 (0..255) nhưng giá trị thực là int8 two's complement (âm).
    // toSigned(8) tái diễn giải đúng dấu, vd 0xC5=197 → -59. Single byte nên
    // không có vấn đề endianness, chỉ cần lo dấu.
    final measuredPower = appleData[22].toSigned(8);

    // PHASE 2 — VALIDATE giá trị: ngoài [-100, -20] dBm là rác → drop (Fail-fast).
    if (measuredPower < _kMeasuredPowerMin ||
        measuredPower > _kMeasuredPowerMax) {
      if (kDebugMode) {
        debugPrint(
            '[iBeacon] $id — FAIL: MeasuredPower=$measuredPower dBm ngoài vùng hợp lệ [$_kMeasuredPowerMin, $_kMeasuredPowerMax]');
      }
      return null;
    }

    if (kDebugMode) {
      debugPrint(
          '[iBeacon] $id — OK: uuid=$uuid major=$major minor=$minor measuredPower=$measuredPower rssi=${result.rssi}dBm');
    }

    return BeaconReading(
      uuid: uuid,
      major: major,
      minor: minor,
      rssi: result.rssi,
      measuredPower: measuredPower, // PHASE 2: per-beacon calibration từ phần cứng
      timestamp: DateTime.now(),
    );
  }

  // MARK: - 6. UTILITIES (Hàm phụ trợ định dạng)
  // ============================================================================
  String _bytesToUuidString(Uint8List bytes) {
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // MARK: - 7. DISPOSAL & CLEANUP (Dọn dẹp RAM)
  // ============================================================================
  @override
  void dispose() {
    _scanSub?.cancel();
    _scanSub = null;
    FlutterBluePlus.stopScan();
    if (!_controller.isClosed) _controller.close();
  }
}