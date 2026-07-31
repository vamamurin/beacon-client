// FILE: /lib/data/scanners/pending_intent_beacon_scanner.dart
//
// ĐƯỜNG THỨ HAI để lấy gói iBeacon, thay cho [RealBeaconScanner].
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO CÓ FILE NÀY
// ═══════════════════════════════════════════════════════════════════════════
//
// `dumpsys bluetooth_manager` trên Redmi Note 12 (HyperOS) đã loại sạch mọi
// tham số của `startScan`:
//   • Chế độ quét KHÔNG bị ánh xạ lại — 100% thời gian ở LOW_LATENCY,
//     0ms Opportunistic. Giả thuyết downgrade: chết.
//   • Cả ba hình dạng filter đều bị suspend. Phiên KHÔNG filter cho 5217 kết
//     quả, NHIỀU NHẤT toàn log. Giả thuyết filter: chết.
//   • Sáu chu kỳ restart 15 giây liên tiếp, 0 kết quả mỗi chu kỳ, 4/6 chu kỳ
//     không hề bị suspend. Kiến trúc CycledLeScanner: chết.
// Và log chỉ ra thứ không có trong AOSP: `Opened Cloud Control Items` với
// `screenState`, `checkForeground`, `backgroundTimeout`, `trackBackgroundScans`
// — tầng điều tiết quét BLE riêng của HyperOS, cấu hình từ cloud.
//
// Điểm chung của mọi thứ đã thua: chúng đều là client kiểu ScanCallback, do
// TIẾN TRÌNH APP giữ. `startScan(filters, settings, PendingIntent)` (API 26+)
// đăng ký phiên quét cho HỆ THỐNG giữ — loại client khác trong stack, và là cơ
// chế mà các app tìm-đồ (Tile, Chipolo) dùng để chạy nền. Đây là khác biệt cấu
// trúc, không phải một tham số khác.
//
// ⚠ CHƯA KIỂM CHỨNG trên máy có governor này. MẶC ĐỊNH TẮT. Bật để thử:
//     --dart-define=BLE_PENDING_INTENT=true
// Cần gạt thứ hai, thử khi riêng PendingIntent vẫn thua (batch scan đi nhánh
// mBatchClients, khác nhánh regular scan):
//     --dart-define=BLE_REPORT_DELAY_MS=2000

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:beacon_client/data/scanners/ibeacon_parser.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

class PendingIntentBeaconScanner implements IBeaconScanner {
  PendingIntentBeaconScanner({
    String? scanMode,
    bool? useHardwareFilter,
    int? companyId,
    Duration? reportDelay,
  })  : scanMode = scanMode ?? _kScanModeDefault,
        useHardwareFilter = useHardwareFilter ?? true,
        companyId = companyId ?? kAppleCompanyId,
        reportDelay = reportDelay ??
            const Duration(milliseconds: _kReportDelayMsDefault);

  static const MethodChannel _method =
      MethodChannel('beacon_client/pending_scan');
  static const EventChannel _events =
      EventChannel('beacon_client/pending_scan_events');

  /// Bật cơ chế này lúc build. Xem ghi chú đầu file.
  static const bool kEnabled =
      bool.fromEnvironment('BLE_PENDING_INTENT', defaultValue: false);

  static const String _kScanModeDefault =
      String.fromEnvironment('BLE_SCAN_MODE', defaultValue: 'lowLatency');

  static const int _kReportDelayMsDefault =
      int.fromEnvironment('BLE_REPORT_DELAY_MS', defaultValue: 0);

  final String scanMode;
  final bool useHardwareFilter;
  final int companyId;

  /// 0 = giao ngay từng gói. >0 = quét theo LÔ: controller gom kết quả rồi trả
  /// một lần. Đánh đổi là độ trễ đúng bằng khoảng gom, nên đừng đặt quá
  /// [_kMaxSaneReportDelay] — vào khu mà 5 giây sau mới phát tiếng thì khách đã
  /// đi qua hiện vật rồi.
  final Duration reportDelay;

  static const Duration _kMaxSaneReportDelay = Duration(seconds: 3);

  final _controller = StreamController<BeaconReading>.broadcast();
  StreamSubscription<dynamic>? _eventSub;

  /// Dedupe theo mốc gói, hệt [RealBeaconScanner]. Cần ở CẢ HAI đường vì cùng
  /// một lý do: một beacon đứng yên phát 10 lần/giây, và pipeline phía sau đo
  /// tuổi gói — xử lý lại một gói cũ là làm tươi nhầm một beacon có thể đã tắt.
  final Map<String, DateTime> _lastProcessed = {};
  static const int _kDedupeCap = 4096;

  @override
  Stream<BeaconReading> get readings => _controller.stream;

  @override
  Future<void> startScan() async {
    await _eventSub?.cancel();
    _lastProcessed.clear();

    _eventSub = _events.receiveBroadcastStream().listen(
          _onEvent,
          onError: (Object e, StackTrace st) {
            debugPrint('[iBeacon/PI] event stream lỗi: $e');
          },
        );

    final delayMs = reportDelay > _kMaxSaneReportDelay
        ? _kMaxSaneReportDelay.inMilliseconds
        : reportDelay.inMilliseconds;

    await _method.invokeMethod<bool>('start', {
      'scanMode': scanMode,
      'useFilter': useHardwareFilter,
      'companyId': companyId,
      'reportDelayMillis': delayMs,
    });
    debugPrint(
        '[iBeacon/PI] bật: mode=$scanMode filter=$useHardwareFilter delay=${delayMs}ms');
  }

  @override
  Future<void> stopScan() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _lastProcessed.clear();
    try {
      await _method.invokeMethod<bool>('stop');
    } catch (e) {
      debugPrint('[iBeacon/PI] stop thất bại: $e');
    }
  }

  void _onEvent(dynamic event) {
    if (_controller.isClosed || event is! Map) return;

    final error = event['error'];
    if (error is int) {
      // Lỗi của PendingIntent scan tới qua CHÍNH kênh kết quả, không qua giá
      // trị trả về của startScan — nên im lặng ở đây là mù hẳn.
      debugPrint('[iBeacon/PI] hệ thống từ chối phiên quét: errorCode=$error');
      return;
    }

    final results = event['results'];
    if (results is! List) return;

    if (_lastProcessed.length > _kDedupeCap) _lastProcessed.clear();

    for (final raw in results) {
      if (raw is! Map) continue;

      final id = raw['id'] as String?;
      final rssi = raw['rssi'] as int?;
      final tsMs = raw['tsMs'] as int?;
      final data = raw['data'];
      if (id == null || rssi == null || tsMs == null || data is! Uint8List) {
        continue;
      }

      final ts = DateTime.fromMillisecondsSinceEpoch(tsMs);
      final prev = _lastProcessed[id];
      if (prev != null && !ts.isAfter(prev)) continue;
      _lastProcessed[id] = ts;

      final reading = parseIBeacon(
        deviceId: id,
        appleData: data,
        rssi: rssi,
        timestamp: ts,
      );
      if (reading != null && !_controller.isClosed) {
        _controller.add(reading);
      }
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    _lastProcessed.clear();
    // Không await được trong dispose đồng bộ; bắn và quên là chấp nhận được vì
    // MainActivity.onDestroy cũng huỷ phiên quét ở tầng native — đó mới là
    // đường bảo đảm, vì phiên quét này sống qua cả cái chết của tiến trình.
    _method.invokeMethod<bool>('stop').catchError((Object _) => false);
    if (!_controller.isClosed) _controller.close();
  }
}
