// FILE: /lib/data/scanners/real_beacon_scanner.dart
//
// FIX P0-2 (đợt 1): flutter_blue_plus phát danh sách TÍCH LŨY — mỗi lần bất kỳ
// thiết bị nào cập nhật, cả danh sách (kể cả beacon đã ngừng phát) được emit
// lại. Bản cũ đóng timestamp bằng DateTime.now() tại lúc parse, nên một beacon
// đã chết vẫn được "làm tươi" mãi → staleness/eviction/zoneSilence của toàn
// pipeline không bao giờ kích hoạt trên máy thật.
//
// Sửa bằng HAI lớp:
//   (1) DEDUPE theo ScanResult.timeStamp: mỗi entry chỉ được xử lý MỘT lần cho
//       mỗi gói sóng thật. Entry cũ bị re-emit trong danh sách tích lũy có
//       timeStamp không đổi → bỏ qua, không parse lại, không log lại.
//   (2) BeaconReading.timestamp = ScanResult.timeStamp (thời điểm phần cứng
//       nhận gói), KHÔNG phải DateTime.now() lúc parse. Registry so tuổi gói
//       bằng đúng đồng hồ tường như trước, nhưng giờ mốc là gói sóng thật.
//
// Dùng onScanResults thay cho scanResults: onScanResults xóa kết quả giữa các
// phiên scan, nên một chu kỳ stop→start không phát lại danh sách của phiên cũ.
// Dedupe (1) vẫn giữ như dây an toàn thứ hai.
//
// ─────────────────────────────────────────────────────────────────────────────
// FIX A (Feature A — chạy ngầm màn hình tắt), ĐÃ ĐIỀU CHỈNH:
//
//   ScanFilter phần cứng giờ MẶC ĐỊNH TẮT. Bản đầu bật filter company-id Apple
//   luôn, nhưng thực địa cho thấy trên một số máy/phiên bản flutter_blue_plus,
//   filter làm gói iBeacon dài KHÔNG tới được callback (chỉ còn gói Continuity
//   ngắn của iPhone/AirPods). Vì "chết sau 5 phút" đã được vá bằng FOREGROUND
//   SERVICE (audio_service) — không phải bằng filter — nên ưu tiên ĐÚNG (bắt
//   được beacon) và để filter là tùy chọn.
//
//   • MẶC ĐỊNH: quét không lọc (đúng hành vi cũ đã bắt được beacon).
//   • BẬT bằng: --dart-define=BLE_HW_FILTER=true → áp filter iBeacon CHÍNH XÁC
//     (Apple 0x004C + prefix 0x02 0x15) để cắt nhiễu + gia cố screen-off, dùng
//     SAU khi đã xác nhận detection chạy.
//   • Guard UUID bảo tàng vẫn nằm một chỗ ở ZonePresenceService._onReading.
//
// YÊU CẦU PHIÊN BẢN: MsdFilter/`withMsd` có từ flutter_blue_plus ^1.32.0.

// MARK: - 1. IMPORTS & DEPENDENCIES (Khai báo thư viện)
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

class RealBeaconScanner implements IBeaconScanner {
  RealBeaconScanner({
    this.scanMode = AndroidScanMode.lowLatency,
    this.appleCompanyId = _kAppleCompanyId,
    bool? useHardwareFilter,
  }) : useHardwareFilter = useHardwareFilter ?? _kUseHwFilterDefault;

  // MARK: - 2. STATE VARIABLES & GETTERS (Biến nội bộ & Cổng truy xuất)
  // ============================================================================
  final AndroidScanMode scanMode;

  /// Company id lọc ở tầng phần cứng. Mặc định Apple (0x004C) vì iBeacon là
  /// định dạng của Apple. Để inject được cho test / firmware phi-Apple hiếm gặp.
  final int appleCompanyId;

  /// FIX A (đã điều chỉnh): CÓ bật ScanFilter phần cứng hay KHÔNG.
  ///
  /// MẶC ĐỊNH `false` = quét KHÔNG lọc (đúng hành vi cũ đã từng bắt được
  /// beacon). Lý do hạ về false: một số phiên bản flutter_blue_plus dựng
  /// MsdFilter không như kỳ vọng và có thể loại nhầm gói iBeacon dài — ưu tiên
  /// ĐÚNG (bắt được beacon) hơn tối ưu. Việc "chết sau 5 phút" đã được vá bằng
  /// FOREGROUND SERVICE (audio_service), KHÔNG phải bằng filter này, nên tắt
  /// filter KHÔNG làm tái phát bug đó.
  ///
  /// Khi ĐÃ xác nhận detection chạy, BẬT lại để cắt nhiễu Continuity của
  /// iPhone/AirPods quanh đó + gia cố screen-off delivery:
  ///   flutter run --dart-define=BLE_HW_FILTER=true
  /// Lúc bật, dùng filter iBeacon CHÍNH XÁC (prefix 0x02 0x15) chứ không phải
  /// filter company-id lỏng.
  final bool useHardwareFilter;

  /// Apple Inc. Bluetooth SIG company identifier — vỏ chứa iBeacon payload.
  static const int _kAppleCompanyId = 0x004C;

  /// Giá trị mặc định của [useHardwareFilter], đọc lúc build. Muốn bật khi build
  /// bản demo/release: `--dart-define=BLE_HW_FILTER=true`.
  static const bool _kUseHwFilterDefault =
      bool.fromEnvironment('BLE_HW_FILTER', defaultValue: false);

  final _controller = StreamController<BeaconReading>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;

  /// P0-2: mốc thời gian gói MỚI NHẤT đã xử lý, theo từng thiết bị. Entry
  /// trong danh sách tích lũy có timeStamp không nhích lên = gói cũ bị phát
  /// lại → bỏ qua. Reset mỗi start/stop.
  final Map<String, DateTime> _lastProcessed = {};

  /// Trần phòng thủ cho map dedupe ở môi trường cực đông thiết bị BLE lạ
  /// (hội chợ). Vượt trần → xóa trắng; giá phải trả chỉ là parse lặp một
  /// lượt, không sai logic (dedupe là tối ưu, không phải điều kiện đúng đắn).
  static const int _kDedupeCap = 4096;

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
    _lastProcessed.clear(); // phiên scan mới → dedupe mới

    await FlutterBluePlus.startScan(
      // FIX A (điều chỉnh) — CHỈ lọc phần cứng khi [useHardwareFilter] bật.
      //   • BẬT: filter iBeacon CHÍNH XÁC — manufacturer Apple + payload bắt
      //     đầu bằng 0x02 0x15 (subtype iBeacon + length 0x15). Cho iBeacon
      //     thật qua, chặn sạch gói Continuity ngắn (AirPods/Handoff/Find My)
      //     và giúp screen-off delivery.
      //   • TẮT (mặc định): withMsd rỗng = quét MỌI quảng cáo (đúng hành vi cũ
      //     đã bắt được beacon). Guard UUID vẫn ở ZonePresenceService.
      withMsd: useHardwareFilter
          ? [
              MsdFilter(
                appleCompanyId,
                data: [0x02, 0x15],
                mask: [0xFF, 0xFF],
              ),
            ]
          : const [],
      continuousUpdates: true,
      // lowLatency = scan liên tục, không duty-cycle, Android default là balanced (~5s delay)
      androidScanMode: scanMode,
    );

    // onScanResults (không phải scanResults): kết quả được xóa giữa các phiên
    // scan → stop/start không phát lại danh sách phiên trước. onError bắt lỗi
    // scan bất đồng bộ (adapter tắt giữa chừng) thay vì để rơi vào zone handler.
    _scanSub = FlutterBluePlus.onScanResults.listen(
      _onScanResults,
      onError: (Object e, StackTrace st) {
        if (kDebugMode) debugPrint('[iBeacon] scan stream error: $e');
      },
    );
  }

  @override
  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    _lastProcessed.clear();
    await FlutterBluePlus.stopScan();
  }

  // MARK: - 4. DATA STREAM HANDLING (Hứng và Lọc luồng dữ liệu)
  // ============================================================================
  void _onScanResults(List<ScanResult> results) {
    if (_controller.isClosed) return;

    if (_lastProcessed.length > _kDedupeCap) _lastProcessed.clear();

    for (final result in results) {
      final id = result.device.remoteId.str;
      final ts = result.timeStamp;

      // P0-2 lớp (1): gói này đã xử lý rồi (danh sách tích lũy phát lại entry
      // cũ) → bỏ qua. Chỉ timeStamp NHÍCH LÊN mới là gói sóng mới.
      final prev = _lastProcessed[id];
      if (prev != null && !ts.isAfter(prev)) continue;
      _lastProcessed[id] = ts;

      final reading = _tryParseIBeacon(result);
      if (reading != null && !_controller.isClosed) {
        _controller.add(reading);
      }
    }
  }

  // MARK: - 5. iBEACON DECODING LOGIC (Giải mã Byte nhị phân chuẩn Apple)
  // ============================================================================
  /// Parse iBeacon từ ScanResult. Trả null nếu không phải iBeacon hợp lệ.
  /// Log chi tiết lý do thất bại để dễ debug qua `flutter logs`. Nhờ dedupe ở
  /// tầng trên, mỗi gói sóng thật chỉ log đúng một lần.
  BeaconReading? _tryParseIBeacon(ScanResult result) {
    final id = result.device.remoteId.str;
    final mfgData = result.advertisementData.manufacturerData;

    if (mfgData.isEmpty) {
      if (kDebugMode) {
        debugPrint('[iBeacon] $id — bỏ qua: không có manufacturer data');
      }
      return null;
    }

    // Apple Inc. company ID = 0x004C = 76
    final appleData = mfgData[appleCompanyId];
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
      // P0-2 lớp (2): mốc thời gian của GÓI SÓNG (phần cứng nhận), không phải
      // lúc parse. Staleness 3s / eviction 12s / zoneSilence giờ đo tuổi thật.
      timestamp: result.timeStamp,
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
    _lastProcessed.clear();
    FlutterBluePlus.stopScan();
    if (!_controller.isClosed) _controller.close();
  }
}