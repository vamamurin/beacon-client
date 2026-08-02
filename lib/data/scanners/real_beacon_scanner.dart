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
// CHẠY NGẦM KHI MÀN HÌNH TẮT — CẤU HÌNH ĐÃ ĐƯỢC KIỂM CHỨNG TRÊN MÁY THẬT
//
// Redmi Note 12 (HyperOS): tắt màn, bước vào khu, app TỰ PHÁT thuyết minh mà
// không cần chạm màn hình. Cấu hình cho ra kết quả đó, và giờ là MẶC ĐỊNH:
//
//     scanMode        = lowLatency          (xem [scanMode])
//     restartInterval = 15 giây             (xem [restartInterval])
//     useHardwareFilter = true, shape ibeacon
//   + trên máy đó: MIUI Autostart BẬT, Battery saver = Không giới hạn
//
// ĐÃ TÁCH BIẾN — [restartInterval] LÀ THỨ GÁNH, KHÔNG PHẢI THIẾT LẬP MIUI.
// Giữ nguyên Autostart + Không giới hạn, build với `BLE_SCAN_RESTART_SEC=0`:
// LỖI TÁI PHÁT. Bật lại 15 giây: hết lỗi. Cùng máy, cùng thiết lập ROM, một
// biến duy nhất. Hệ quả quan trọng cho bản phát hành cho khách: bản vá nằm
// TRONG CODE, không phụ thuộc vào thiết lập mà ta không đặt hộ người dùng được.
//
// Redmi A1 (Android 12, vốn không dính lỗi) chạy bình thường với cấu hình này —
// không hồi quy.
//
// ĐỪNG suy ra nguyên nhân từ `dumpsys` nữa. Đợt này đã ba lần rút ra kết luận
// nhân quả từ số liệu dumpsys — chế độ quét, hình dạng filter, vòng restart —
// và cả ba đều SAI. Số liệu dumpsys đọc được trạng thái, không đọc được nhân
// quả; chỉ test chức năng (tắt màn, bước vào khu, có tiếng hay không) mới trả
// lời được câu hỏi thật sự.
//
// YÊU CẦU PHIÊN BẢN: MsdFilter/`withMsd` có từ flutter_blue_plus ^1.32.0.

// MARK: - 1. IMPORTS & DEPENDENCIES (Khai báo thư viện)
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:beacon_client/data/scanners/ibeacon_parser.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

class RealBeaconScanner implements IBeaconScanner {
  RealBeaconScanner({
    AndroidScanMode? scanMode,
    this.appleCompanyId = kAppleCompanyId,
    bool? useHardwareFilter,
    Duration? restartInterval,
  })  : scanMode = scanMode ?? _kScanModeDefault,
        useHardwareFilter = useHardwareFilter ?? _kUseHwFilterDefault,
        restartInterval = _sanitizeRestart(
            restartInterval ??
                (_kRestartSecDefault > 0
                    ? const Duration(seconds: _kRestartSecDefault)
                    : null));

  /// Ép sàn [_kMinRestartSec]. Truyền số nhỏ hơn không phải là tinh chỉnh táo
  /// bạo mà là tự bắn vào chân: Android chặn im lặng app quét quá dày.
  static Duration? _sanitizeRestart(Duration? d) {
    if (d == null) return null;
    const floor = Duration(seconds: _kMinRestartSec);
    return d < floor ? floor : d;
  }

  // MARK: - 2. STATE VARIABLES & GETTERS (Biến nội bộ & Cổng truy xuất)
  // ============================================================================

  /// Chế độ quét Android. **MẶC ĐỊNH `lowLatency`.**
  ///
  /// Đây là chế độ có trong cấu hình đã chạy được khi màn tắt trên Redmi Note
  /// 12 (cùng với [restartInterval] = 15s). Không có bằng chứng nào cho thấy
  /// đổi chế độ quét ảnh hưởng tới lỗi màn-tắt, nên giữ chế độ nhạy nhất:
  /// vào khu là bắt được ngay, không phải chờ hết một chu kỳ duty-cycle.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// MỘT KẾT LUẬN SAI ĐÃ TỪNG NẰM Ở ĐÂY — ĐỌC TRƯỚC KHI ĐỔI LẠI
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Bản trước đặt mặc định `balanced` với lập luận: `dumpsys` cho thấy app ta
  /// quét 100% LOW_LATENCY và bị treo 82% thời gian, trong khi Play Services
  /// (BALANCED/AMBIENT) và `android.uid.bluetooth` (LOW_POWER) gần như không
  /// treo ⇒ LOW_LATENCY là thủ phạm.
  ///
  /// Lập luận đó SAI ở hai chỗ:
  ///   • Hai đối chứng kia là UID HỆ THỐNG. Chúng không bị treo vì có
  ///     NETWORK_SETTINGS/scan-without-location, tức bỏ qua toàn bộ cổng chặn
  ///     screen-off — không phải nhờ chế độ quét. So một app thường với UID hệ
  ///     thống thì chế độ quét không phải "biến duy nhất khác nhau", nó chỉ là
  ///     biến duy nhất NHÌN THẤY ĐƯỢC.
  ///   • Và log của chính lần đo đó cho thấy chế độ quét KHÔNG HỀ bị ánh xạ
  ///     lại: `Scan time with mode` = 0/0/0/N/0 ở mọi entry. Không có "treo
  ///     client LOW_LATENCY" nào xảy ra cả.
  ///
  /// Thực địa chốt lại: build với `lowLatency` + restart 15s thì màn tắt CHẠY.
  ///
  /// Đổi lúc build để đối chứng (cả ba đều CHƯA được kiểm chứng là chạy):
  ///   --dart-define=BLE_SCAN_MODE=balanced   (~25% duty)
  ///   --dart-define=BLE_SCAN_MODE=lowPower   (~10% duty)
  final AndroidScanMode scanMode;

  static const String _kScanModeName =
      String.fromEnvironment('BLE_SCAN_MODE', defaultValue: 'lowLatency');

  // Ternary lồng chứ không phải switch-expression: switch KHÔNG phải biểu thức
  // hằng trong Dart, mà cái này BẮT BUỘC phải là const để `bool/String
  // .fromEnvironment` được giải lúc biên dịch.
  static const AndroidScanMode _kScanModeDefault =
      _kScanModeName == 'lowLatency'
          ? AndroidScanMode.lowLatency
          : _kScanModeName == 'lowPower'
              ? AndroidScanMode.lowPower
              : _kScanModeName == 'opportunistic'
                  ? AndroidScanMode.opportunistic
                  : AndroidScanMode.balanced;

  /// Company id lọc ở tầng phần cứng. Mặc định Apple (0x004C) vì iBeacon là
  /// định dạng của Apple. Để inject được cho test / firmware phi-Apple hiếm gặp.
  final int appleCompanyId;

  /// CÓ bật ScanFilter phần cứng hay KHÔNG. **MẶC ĐỊNH `true`.**
  ///
  /// Filter là `MsdFilter(Apple 0x004C, data: [0x02, 0x15], mask: [0xFF, 0xFF])`
  /// — prefix của gói iBeacon. Nó cắt nhiễu Continuity (AirPods/Handoff) ngay ở
  /// chip, giảm số gói phải parse ở Dart. Phần rác còn lại do [parseIBeacon] và
  /// guard UUID bảo tàng ở `ZonePresenceService._onReading` loại.
  ///
  /// ⚠ FILTER KHÔNG LIÊN QUAN TỚI LỖI MÀN-TẮT — đừng đụng vào nó khi lỗi đó
  /// tái phát. Một ghi chú dài từng nằm ở đây khẳng định "màn tắt = không có
  /// kết quả nếu quét không lọc" (quy tắc `requiresScreenOn` của AOSP), nhưng
  /// `dumpsys` trên chính máy hỏng đã bác bỏ: phiên quét bị treo với CẢ BA dạng
  /// filter, và phiên KHÔNG filter lại cho 5217 kết quả — nhiều nhất toàn log.
  /// Thứ chữa được lỗi đó là [restartInterval].
  ///
  /// Tắt để chẩn đoán khi nghi filter chặn nhầm beacon (vd firmware lạ không
  /// theo đúng prefix iBeacon):
  ///   flutter run --dart-define=BLE_HW_FILTER=false
  final bool useHardwareFilter;

  /// Giá trị mặc định của [useHardwareFilter], đọc lúc build.
  static const bool _kUseHwFilterDefault =
      bool.fromEnvironment('BLE_HW_FILTER', defaultValue: true);

  /// Chu kỳ tự dựng lại phiên quét. **MẶC ĐỊNH 15 GIÂY** — đây là thứ duy nhất
  /// trong cả đợt điều tra đã được thực địa xác nhận là CHẠY.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// VÌ SAO NÓ ĂN, VÀ VÌ SAO ĐỪNG TẮT
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Ý tưởng: đừng trông chờ một phiên quét sống sót qua ranh giới màn-tắt, mà
  /// ĐĂNG KÝ LẠI phiên mới theo chu kỳ. Trên nhiều ROM, một phiên bắt đầu KHI
  /// màn hình ĐÃ tắt hành xử khác hẳn một phiên đang chạy lúc màn hình tắt.
  /// Đây là kiến trúc của AndroidBeaconLibrary (CycledLeScanner) và là lý do
  /// thư viện đó chạy được ở nền trên các ROM khó.
  ///
  /// Thực địa Redmi Note 12 (HyperOS) đã A/B TÁCH BẠCH đúng một biến này, giữ
  /// nguyên mọi thứ khác kể cả thiết lập MIUI:
  ///   • `BLE_SCAN_RESTART_SEC=15` → tắt màn, bước vào khu, TỰ PHÁT thuyết minh.
  ///   • `BLE_SCAN_RESTART_SEC=0`  → lỗi TÁI PHÁT, câm cho tới khi chạm màn hình.
  /// Đây là kết luận nhân quả DUY NHẤT của cả đợt được chứng minh bằng thực
  /// nghiệm chứ không phải suy ra từ `dumpsys`.
  ///
  /// ĐỪNG "tối ưu" nó đi vì thấy dựng lại phiên quét mỗi 15 giây là lãng phí.
  /// Sóng radio vẫn quét liên tục y hệt; chi phí thật là hai lời gọi binder mỗi
  /// 15 giây cộng một khoảng hở vài chục mili-giây. Đổi lại là app chạy được khi
  /// màn tắt. Đây cũng đúng là kiến trúc CycledLeScanner của
  /// AndroidBeaconLibrary, không phải mẹo tự nghĩ.
  ///
  /// ⚠ MỘT LẦN `dumpsys` TỪNG LÀM TƯỞNG LÀ NÓ KHÔNG ĂN. Bản ghi lúc 15:15 cho
  /// sáu chu kỳ 15 giây liên tiếp với 0 kết quả mỗi chu kỳ, và điều đó đã bị
  /// đọc thành "vòng restart bị bác bỏ". Sai: cùng phiên đó tổng cộng vẫn có
  /// 387 kết quả, tức beacon chỉ không trong tầm ở 90 giây cuối. Đừng kết luận
  /// từ một cửa sổ dumpsys mà không biết beacon có đang phát trong tầm hay
  /// không.
  ///
  /// ⚠ TRẦN CỦA ANDROID: app gọi `startScan` quá 5 lần trong 30 giây bị đánh
  /// dấu "scanning too frequently" và phiên quét bị CHẶN IM LẶNG 30 giây — bật
  /// quá dày sẽ làm mọi thứ TỆ HƠN. 15 giây cho 5 lần trải trên 60 giây, dư
  /// biên gấp đôi. Sàn cứng [_kMinRestartSec] chặn việc vô tình đặt sát ngưỡng.
  ///
  /// Tắt để đối chứng (dùng để tách biến với thiết lập MIUI — xem đầu file):
  ///   --dart-define=BLE_SCAN_RESTART_SEC=0
  final Duration? restartInterval;

  /// Sàn cứng cho [restartInterval] — xem trần 5-lần/30-giây ở trên. Để 10 chứ
  /// không phải 8: 5 lần cách nhau 8 giây trải đúng 32 giây, hơn ngưỡng 30 giây
  /// vỏn vẹn 2 giây và một lần startScan chậm là đủ để rơi xuống dưới.
  static const int _kMinRestartSec = 10;

  /// 0 (hoặc số âm) = TẮT hẳn chu kỳ. Xem [restartInterval] để biết vì sao
  /// mặc định là 15 chứ không phải tắt.
  static const int _kRestartSecDefault =
      int.fromEnvironment('BLE_SCAN_RESTART_SEC', defaultValue: 15);

  final _controller = StreamController<BeaconReading>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;

  /// Hẹn giờ MỘT LẦN, được lên dây lại ở cuối mỗi [startScan]. Dùng one-shot
  /// thay cho periodic để hai chu kỳ restart không bao giờ chồng lên nhau khi
  /// một lần startScan chậm.
  Timer? _restartTimer;

  /// Số hiệu phiên, tăng ở MỌI [startScan] và [stopScan].
  ///
  /// VÌ SAO CẦN: [startScan] có ba điểm `await`, và [stopScan] có thể chạy xen
  /// vào giữa. Nếu không có mốc này thì một `startScan` đang bay sẽ chạy nốt
  /// tới `_armRestartCycle()` SAU khi stop đã xoá đồng hồ — quét zombie sống
  /// tiếp qua cả lúc tour kết thúc, và trên máy bảo tàng nghĩa là ăn pin âm
  /// thầm cho tới khi ai đó buộc dừng app. Mỗi lần qua `await`, phiên tự hỏi
  /// mình còn là phiên hiện hành không.
  int _generation = 0;

  /// P0-2: mốc thời gian gói MỚI NHẤT đã xử lý, theo từng thiết bị. Entry
  /// trong danh sách tích lũy có timeStamp không nhích lên = gói cũ bị phát
  /// lại → bỏ qua. Reset mỗi start/stop.
  final Map<String, DateTime> _lastProcessed = {};

  /// Trần phòng thủ cho map dedupe ở môi trường cực đông thiết bị BLE lạ
  /// (hội chợ). Vượt trần → xóa trắng; giá phải trả chỉ là parse lặp một
  /// lượt, không sai logic (dedupe là tối ưu, không phải điều kiện đúng đắn).
  static const int _kDedupeCap = 4096;

  @override
  Stream<BeaconReading> get readings => _controller.stream;

  // MARK: - 3. HARDWARE CONTROL (Điều khiển Ăng-ten vật lý)
  // ============================================================================
  @override
  Future<void> startScan() async {
    final gen = ++_generation;

    // Flush Android BT cache: dừng scan cũ trước khi start mới.
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    if (gen != _generation) return;

    // Hủy subscription cũ trước khi listen lại để tránh rò rỉ _scanSub
    // nếu startScan() bị gọi lặp mà chưa qua stopScan().
    await _scanSub?.cancel();
    _scanSub = null;
    if (gen != _generation) return;
    _lastProcessed.clear(); // phiên scan mới → dedupe mới

    await FlutterBluePlus.startScan(
      // Prefix gói iBeacon: Apple + 0x02 0x15, mask 2 byte đầu. Cắt nhiễu
      // Continuity ngay ở chip — xem [useHardwareFilter]. Rỗng = quét không lọc.
      withMsd: !useHardwareFilter
          ? const []
          : [
              MsdFilter(appleCompanyId,
                  data: const [0x02, 0x15], mask: const [0xFF, 0xFF]),
            ],
      continuousUpdates: true,
      // lowLatency = scan liên tục, không duty-cycle, Android default là balanced (~5s delay)
      androidScanMode: scanMode,
    );

    // stopScan() xen vào giữa lúc đang start: dừng lại phiên vừa mở rồi thoát,
    // KHÔNG lắng nghe và KHÔNG lên dây đồng hồ. Không có dòng này thì stop chạy
    // xong mà máy vẫn quét.
    if (gen != _generation) {
      await FlutterBluePlus.stopScan();
      return;
    }

    // onScanResults (không phải scanResults): kết quả được xóa giữa các phiên
    // scan → stop/start không phát lại danh sách phiên trước. onError bắt lỗi
    // scan bất đồng bộ (adapter tắt giữa chừng) thay vì để rơi vào zone handler.
    _scanSub = FlutterBluePlus.onScanResults.listen(
      _onScanResults,
      onError: (Object e, StackTrace st) {
        if (kDebugMode) debugPrint('[iBeacon] scan stream error: $e');
      },
    );

    _armRestartCycle();
  }

  /// Lên dây lại đồng hồ chu kỳ. No-op khi [restartInterval] null (mặc định).
  void _armRestartCycle() {
    _restartTimer?.cancel();
    _restartTimer = null;
    final period = restartInterval;
    if (period == null || _controller.isClosed) return;
    _restartTimer = Timer(period, _cycleRestart);
  }

  /// Dựng lại phiên quét từ đầu. Tái dùng [startScan] nguyên vẹn — nó đã tự
  /// dừng phiên cũ, hủy subscription, xóa dedupe và lên dây lại đồng hồ, nên
  /// một chu kỳ đúng bằng một lần khởi động sạch.
  ///
  /// Đường THÀNH CÔNG im lặng, chỉ log lúc HỎNG. Bản trước in một dòng mỗi chu
  /// kỳ và KHÔNG bọc kDebugMode — hợp lý khi chu kỳ còn là thí nghiệm bật tay,
  /// nhưng từ lúc nó thành mặc định thì đó là 4 dòng/phút chạy vĩnh viễn trên
  /// máy khách, đủ để dìm chết mọi log khác đúng lúc cần chẩn đoán thật.
  void _cycleRestart() {
    if (_controller.isClosed) return;
    final gen = _generation;
    startScan().catchError((Object e) {
      debugPrint('[iBeacon] chu kỳ restart thất bại: $e');
      // startScan ném TRƯỚC khi lên dây → tự lên dây lại, nhưng chỉ khi chưa ai
      // dừng quét trong lúc đó. Thiếu guard này thì một lần start hỏng đúng lúc
      // stopScan chạy sẽ hồi sinh cả chu kỳ.
      if (gen == _generation - 1) _armRestartCycle();
    });
  }

  @override
  Future<void> stopScan() async {
    // Vô hiệu hoá mọi startScan đang bay — xem [_generation].
    _generation++;
    _restartTimer?.cancel();
    _restartTimer = null;
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
  /// Bóc vỏ manufacturer-data của Apple rồi giao phần giải mã cho
  /// [parseIBeacon] — bộ luật Strict Mode, xem ghi chú ở ibeacon_parser.dart.
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

    return parseIBeacon(
      deviceId: id,
      appleData: appleData,
      rssi: result.rssi,
      // P0-2 lớp (2): mốc thời gian của GÓI SÓNG (phần cứng nhận), không phải
      // lúc parse. Staleness 3s / eviction 12s / zoneSilence giờ đo tuổi thật.
      timestamp: result.timeStamp,
    );
  }

  // MARK: - 6. DISPOSAL & CLEANUP (Dọn dẹp RAM)
  // ============================================================================
  @override
  void dispose() {
    _generation++; // vô hiệu hoá startScan đang bay — xem [_generation]
    _restartTimer?.cancel();
    _restartTimer = null;
    _scanSub?.cancel();
    _scanSub = null;
    _lastProcessed.clear();
    FlutterBluePlus.stopScan();
    if (!_controller.isClosed) _controller.close();
  }
}