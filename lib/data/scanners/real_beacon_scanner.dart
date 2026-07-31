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

import 'package:beacon_client/data/scanners/ibeacon_parser.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

/// Hình dạng ScanFilter phần cứng. Tồn tại vì hai hình dạng này KHÁC NHAU về
/// hành vi khi Android đẩy filter xuống chip lúc màn hình tắt — xem ghi chú dài
/// ở [RealBeaconScanner.filterShape].
enum MsdFilterShape {
  /// Apple company id + prefix iBeacon `0x02 0x15` (có mask). Pattern THẬT, có
  /// cái để chip so khớp. Mặc định.
  ibeacon,

  /// Chỉ Apple company id. Android biến nó thành pattern dài 0 byte — khớp mọi
  /// gói khi lọc ở host, nhưng có thể khớp KHÔNG GÌ khi lọc offloaded.
  companyOnly,
}

class RealBeaconScanner implements IBeaconScanner {
  RealBeaconScanner({
    AndroidScanMode? scanMode,
    this.appleCompanyId = kAppleCompanyId,
    bool? useHardwareFilter,
    MsdFilterShape? filterShape,
    Duration? restartInterval,
  })  : scanMode = scanMode ?? _kScanModeDefault,
        useHardwareFilter = useHardwareFilter ?? _kUseHwFilterDefault,
        filterShape = filterShape ?? _kMsdShapeDefault,
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

  /// Chế độ quét Android. **MẶC ĐỊNH `balanced`, KHÔNG phải `lowLatency`.**
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// ĐÂY LÀ THỨ ĐÃ TREO PHIÊN QUÉT KHI MÀN HÌNH TẮT
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// `dumpsys bluetooth_manager` trên Redmi Note 12 (HyperOS/Android 15) cho
  /// một phép so sánh NỘI BỘ CÙNG MỘT MÁY, cùng khung giờ — thứ mà không lý
  /// thuyết nào thay thế được:
  ///
  ///   com.example.beacon_client (ta)
  ///     mode: 0/0/0/349039/0  ⇒ 100% LOW_LATENCY
  ///     active/suspend: 349039 / 1628557   ⇒ BỊ TREO 82% thời gian
  ///     └ Suspended Time: 1340572ms, Active Time: 81618
  ///
  ///   com.google.uid.shared (Play Services)  — BALANCED / AMBIENT_DISCOVERY
  ///     └ Suspended Time: 47ms, Active Time: 726878     ⇒ gần như không treo
  ///
  ///   android.uid.bluetooth — LOW_POWER
  ///     active/suspend: 12702248 / 1509                 ⇒ gần như không treo
  ///
  /// Biến duy nhất phân biệt ta với chúng là CHẾ ĐỘ QUÉT. ScanManager của
  /// Android treo client LOW_LATENCY khi màn hình tắt — nó là chế độ ngốn pin
  /// nhất, và hệ điều hành coi "màn tắt" là tín hiệu không ai cần nó nữa.
  ///
  /// Phép so sánh này cũng CHÔN nốt giả thuyết hình dạng filter: entry
  /// `android.uid.bluetooth` chạy `ManufacturerData=[]` — pattern RỖNG y hệt
  /// thứ ta từng nghi — mà không hề bị treo. Và cả hai dạng filter của ta
  /// (`[]` lẫn `[2,21]+mask`) đều bị treo như nhau. Filter chưa bao giờ là biến.
  ///
  /// ĐÁNH ĐỔI: balanced quét ~1024ms mỗi 4096ms (~25% duty) thay vì liên tục,
  /// nên vào khu trễ hơn vài giây. Với máy hướng dẫn bảo tàng, trễ vài giây đổi
  /// lấy việc CHẠY ĐƯỢC khi màn tắt là đổi lãi.
  ///
  /// Đổi lúc build để đối chứng:
  ///   --dart-define=BLE_SCAN_MODE=lowLatency   (hành vi cũ, bị treo)
  ///   --dart-define=BLE_SCAN_MODE=lowPower     (~10% duty, trễ nhất, an toàn nhất)
  final AndroidScanMode scanMode;

  static const String _kScanModeName =
      String.fromEnvironment('BLE_SCAN_MODE', defaultValue: 'balanced');

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
  /// ═══════════════════════════════════════════════════════════════════════
  /// VÌ SAO ĐÃ ĐẢO NGƯỢC: MÀN TẮT = KHÔNG CÓ KẾT QUẢ NẾU QUÉT KHÔNG LỌC
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Từ Android 8.1, tầng Bluetooth của hệ thống KHÔNG giao kết quả cho một
  /// phiên quét KHÔNG CÓ FILTER khi màn hình tắt; phiên quét được treo lại và
  /// chỉ hồi phục khi màn bật. Đây là quy tắc của ScanManager trong AOSP, áp ở
  /// tầng dưới app.
  ///
  /// Triệu chứng thực địa khớp từng chi tiết: Redmi Note 12 tắt màn thì bước
  /// vào khu KHÔNG phát thuyết minh, nhưng vừa bật màn (chưa cần mở khoá) là
  /// audio phát ra NGAY — vì gói beacon bắt đầu tới đúng khoảnh khắc đó. Redmi
  /// A1 không dính vì mỗi ROM/phiên bản áp quy tắc một khác.
  ///
  /// ⚠ FOREGROUND SERVICE KHÔNG MIỄN ĐƯỢC QUY TẮC NÀY. Ghi chú cũ ở đây kết
  /// luận rằng vì "chết sau 5 phút" đã được vá bằng FGS nên tắt filter là an
  /// toàn. Hai chuyện khác nhau: FGS giữ TIẾN TRÌNH sống (chống Doze), còn quy
  /// tắc này nằm ở tầng giao kết quả quét và không quan tâm app có FGS hay
  /// không. Đó là lý do keep-alive chạy hoàn hảo mà vẫn không có beacon nào.
  ///
  /// Đối chứng khi nghi filter chặn nhầm beacon:
  ///   flutter run --dart-define=BLE_HW_FILTER=false
  /// Chỉ dùng để CHẨN ĐOÁN với màn hình BẬT — bản release để false là tái phát
  /// đúng lỗi màn-tắt-không-phát-tiếng ở trên.
  final bool useHardwareFilter;

  /// HÌNH DẠNG của filter manufacturer-data. Xem [MsdFilterShape].
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// VÌ SAO CÁI NÀY TỒN TẠI, VÀ VÌ SAO MẶC ĐỊNH ĐÃ ĐỔI VỀ [ibeacon]
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Đo trên Redmi Note 12 (HyperOS, Android 15) đã LOẠI TRỪ mọi nghi phạm còn
  /// lại, bằng `dumpsys` chụp lúc màn hình đang tắt:
  ///   • keep-alive FGS sống, `types=0x40000008` = SPECIAL_USE|LOCATION ✓
  ///   • `curCapability=L--NFUA` — chữ L là PROCESS_CAPABILITY_FOREGROUND_
  ///     LOCATION, tức appop location ĐANG MỞ ✓
  ///   • `isFrozen=false`, `curProcState=4` (FOREGROUND_SERVICE) ✓
  ///   • quyền + whitelist pin của ROM đã bật ✓
  /// Vậy mà vẫn KHÔNG một gói nào tới. Cắm beacon mới toanh lúc màn tắt cũng
  /// không bắt được; bật màn khoá lên là bắt được NGAY.
  ///
  /// Log còn chốt thêm một điều: gói đầu tiên tới khi cửa sổ app VẪN không
  /// hiển thị (không có `visibilityChanged newVisibility=true` nào). Nên cổng
  /// chặn là TRẠNG THÁI DISPLAY, không phải trạng thái foreground của app —
  /// khớp với ScanManager của AOSP, vốn nghe ACTION_SCREEN_ON/OFF.
  ///
  /// Chỉ còn một mắt xích chưa soi: khi màn tắt, Android đẩy ScanFilter XUỐNG
  /// CHIP để lọc offloaded, thay vì lọc bằng phần mềm ở host. Và đây là chỗ
  /// `MsdFilter(companyId)` trần trụi trở nên nguy hiểm:
  ///
  ///     // ScanFilter.Builder — AOSP
  ///     mManufacturerData = manufacturerData == null ? new byte[0] : ...;
  ///
  /// Không có cách nào khai "chỉ company id, miễn so dữ liệu" — Android LUÔN
  /// biến nó thành pattern DÀI 0 BYTE rồi nạp xuống controller. Lọc ở host thì
  /// pattern rỗng khớp mọi thứ (vòng lặp so sánh chạy 0 lần); nạp xuống phần
  /// cứng thì pattern 0 byte là hành vi tuỳ chip, và "khớp KHÔNG GÌ CẢ" là kết
  /// cục hoàn toàn có thể. Đúng bằng cái ta quan sát: màn bật chạy, màn tắt
  /// câm, cùng một filter.
  ///
  /// Đó là lý do [MsdFilterShape.ibeacon] đưa lại `data: [0x02, 0x15]` + mask —
  /// một pattern THẬT để chip có cái mà so. Cũng chính là thứ thư viện
  /// AndroidBeaconLibrary (AltBeacon) nạp, thay vì pattern rỗng.
  ///
  /// ⚠ MỘT LẦN NỮA: CHƯA KIỂM CHỨNG. Một bản trước từng dùng data/mask và
  /// thực địa báo gói iBeacon dài không tới được callback — nhưng loạt báo cáo
  /// thực địa của đợt này đã sai vài lần (chuyện "app tự sáng màn hình" hoá ra
  /// là tính năng nhấc-máy-sáng-màn của thiết bị), nên báo cáo đó không đủ sức
  /// đóng cửa giả thuyết. Vì vậy hình dạng filter được để ĐỔI ĐƯỢC LÚC BUILD
  /// thay vì chốt cứng — A/B trong một buổi test, không phải một vòng sửa code.
  final MsdFilterShape filterShape;

  /// Giá trị mặc định của [useHardwareFilter], đọc lúc build. Mặc định TRUE —
  /// xem [useHardwareFilter] để biết vì sao tắt filter làm hỏng chế độ màn tắt.
  /// Tắt để chẩn đoán: `--dart-define=BLE_HW_FILTER=false`.
  static const bool _kUseHwFilterDefault =
      bool.fromEnvironment('BLE_HW_FILTER', defaultValue: true);

  /// Mặc định của [filterShape]. Đổi lúc build:
  ///   --dart-define=BLE_MSD_PATTERN=company   (hành vi cũ, pattern rỗng)
  static const String _kMsdPatternName =
      String.fromEnvironment('BLE_MSD_PATTERN', defaultValue: 'ibeacon');

  static const MsdFilterShape _kMsdShapeDefault =
      _kMsdPatternName == 'company'
          ? MsdFilterShape.companyOnly
          : MsdFilterShape.ibeacon;

  /// Chu kỳ tự dựng lại phiên quét, hoặc null = tắt (mặc định).
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// VÌ SAO CÓ THỨ NÀY, SAU KHI MỌI THỨ KHÁC ĐÃ BỊ LOẠI TRỪ
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Đo trên Redmi Note 12 (HyperOS/Android 15) đã loại sạch tầng quyền và
  /// tầng tiến trình: `dumpsys` lúc màn tắt cho `curCapability=L--NFUA` (appop
  /// location MỞ), keep-alive FGS sống với `types=0x40000008`
  /// (SPECIAL_USE|LOCATION), `isFrozen=false`, `curProcState=4`. Whitelist pin
  /// của ROM đã bật. Và ba dạng filter — prefix iBeacon, chỉ company id, và
  /// KHÔNG filter — đều cho ra 0 gói khi màn tắt.
  ///
  /// Nghĩa là không có tham số nào của `startScan` sửa được chuyện này: máy
  /// ngừng giao kết quả cho phiên quét ĐANG CHẠY vào đúng lúc display tắt.
  ///
  /// Thứ chưa thử: đừng dựa vào một phiên quét sống sót qua ranh giới đó, mà
  /// ĐĂNG KÝ LẠI phiên mới theo chu kỳ. Trên nhiều ROM, một phiên quét bắt đầu
  /// KHI màn hình ĐÃ tắt hành xử khác hẳn một phiên đang chạy lúc màn hình tắt.
  /// Đây chính là kiến trúc của AndroidBeaconLibrary (CycledLeScanner) và là lý
  /// do thư viện đó chạy được ở nền trên các ROM khó.
  ///
  /// ⚠ TRẦN CỦA ANDROID: app gọi `startScan` quá 5 lần trong 30 giây bị đánh
  /// dấu "scanning too frequently" và phiên quét bị CHẶN IM LẶNG 30 giây —
  /// tức là bật cái này quá dày sẽ làm mọi thứ TỆ HƠN. Vì vậy giá trị bị ép sàn
  /// 8 giây ở constructor, và 15–20 giây là vùng nên dùng.
  ///
  /// MẶC ĐỊNH TẮT: đây là thay đổi hành vi có rủi ro hồi quy trên những máy
  /// đang chạy tốt (Redmi A1). Bật để thử:
  ///   --dart-define=BLE_SCAN_RESTART_SEC=15
  final Duration? restartInterval;

  /// Sàn cứng cho [restartInterval] — xem trần 5-lần/30-giây ở trên.
  static const int _kMinRestartSec = 8;

  static const int _kRestartSecDefault =
      int.fromEnvironment('BLE_SCAN_RESTART_SEC', defaultValue: 0);

  final _controller = StreamController<BeaconReading>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;

  /// Hẹn giờ MỘT LẦN, được lên dây lại ở cuối mỗi [startScan]. Dùng one-shot
  /// thay cho periodic để hai chu kỳ restart không bao giờ chồng lên nhau khi
  /// một lần startScan chậm.
  Timer? _restartTimer;

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
      // Có filter là ĐIỀU KIỆN TIÊN QUYẾT để Android giao kết quả khi màn tắt.
      // HÌNH DẠNG của nó quyết định việc lọc offloaded có khớp được gì không —
      // xem ghi chú dài ở [filterShape].
      //   • ibeacon (mặc định): Apple + prefix 0x02 0x15, mask 2 byte đầu. Gói
      //     iBeacon thật đều qua; gói Continuity ngắn (AirPods/Handoff) bị chặn
      //     ngay ở chip. Phần rác còn lại do _tryParseIBeacon + guard UUID ở
      //     ZonePresenceService loại.
      //   • companyOnly: pattern rỗng — hành vi cũ, giữ để đối chứng.
      // TẮT hẳn: withMsd rỗng = quét không lọc. CHỈ chẩn đoán với màn hình bật.
      withMsd: !useHardwareFilter
          ? const []
          : switch (filterShape) {
              MsdFilterShape.ibeacon => [
                  MsdFilter(appleCompanyId,
                      data: const [0x02, 0x15], mask: const [0xFF, 0xFF]),
                ],
              MsdFilterShape.companyOnly => [MsdFilter(appleCompanyId)],
            },
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
  /// Log KHÔNG bọc kDebugMode: cả điểm của tính năng này là chẩn đoán trên bản
  /// release ở máy thật, và nó chỉ in mỗi [restartInterval] giây (≥ 8s).
  void _cycleRestart() {
    if (_controller.isClosed) return;
    debugPrint('[iBeacon] chu kỳ: dựng lại phiên quét');
    startScan().catchError((Object e) {
      debugPrint('[iBeacon] chu kỳ restart thất bại: $e');
      _armRestartCycle(); // startScan ném trước khi lên dây → tự lên dây lại
    });
  }

  @override
  Future<void> stopScan() async {
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
  /// [parseIBeacon] — bộ luật Strict Mode dùng CHUNG với
  /// [PendingIntentBeaconScanner], xem ghi chú ở ibeacon_parser.dart.
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
    _restartTimer?.cancel();
    _restartTimer = null;
    _scanSub?.cancel();
    _scanSub = null;
    _lastProcessed.clear();
    FlutterBluePlus.stopScan();
    if (!_controller.isClosed) _controller.close();
  }
}