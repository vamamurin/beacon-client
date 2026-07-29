// Destination: lib/data/platform/foreground_task_keep_alive.dart (NEW)
//
// Impl [IKeepAlive] bằng flutter_foreground_task (^10.0.0). Đây là foreground
// service THỨ HAI của app (bên cạnh audio_service). Trách nhiệm DUY NHẤT: giữ
// tiến trình ở mức foreground suốt tour để tiến trình được miễn Doze — nhờ đó
// BLE + timer + audio sống được khi màn tắt, kể cả lúc standby chưa phát gì.
// Nó KHÔNG chạy logic gì trong isolate task; TaskHandler chỉ là vỏ bắt buộc.
//
// Đánh đổi đã được chấp nhận: trong lúc audio thực sự phát, có thể có HAI
// notification (keep-alive + media của audio_service). Máy cho mượn màn tắt bỏ
// túi nên khách không thấy.
//
// foregroundServiceType = specialUse|location (khai trong AndroidManifest):
//   • specialUse thay vì connectedDevice/dataSync vì nó KHÔNG có kiểm tra
//     runtime (connectedDevice đòi thiết bị đang kết nối — quét BLE thuần có
//     thể trượt) và KHÔNG bị giới hạn 6 giờ/24 giờ (dataSync trên Android 15).
//   • location là thứ THỰC SỰ mở được đường quét khi màn tắt: BLE scan ở app
//     này bị gate qua appop ACCESS_FINE_LOCATION, và từ Android 11 appop đó chỉ
//     mở khi process có PROCESS_CAPABILITY_FOREGROUND_LOCATION — chỉ FGS type
//     location mới cấp. Ghi chú đầy đủ nằm ở AndroidManifest.
// Với app sideload cho bảo tàng, cặp này là lựa chọn an toàn nhất.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:beacon_client/domain/interfaces/i_keep_alive.dart';

/// Callback TOP-LEVEL bắt buộc của flutter_foreground_task: chạy trong isolate
/// task, chỉ gắn một TaskHandler gần như rỗng. @pragma giữ nó khỏi tree-shake.
@pragma('vm:entry-point')
void tourKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

/// TaskHandler — ta không cần isolate task làm gì, chỉ cần service sống. Ngoại
/// lệ DUY NHẤT là nút "Kết thúc tham quan": sự kiện bấm nút được giao vào
/// ISOLATE TASK, không phải isolate chính, nên phải bắc cầu về bằng
/// sendDataToMain (đầu kia là [ForegroundTaskKeepAlive._onTaskData]).
class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == ForegroundTaskKeepAlive.kEndTourButtonId) {
      FlutterForegroundTask.sendDataToMain(
          ForegroundTaskKeepAlive.kEndTourSignal);
    }
  }
}

class ForegroundTaskKeepAlive implements IKeepAlive {
  /// ID service tùy ý, chỉ cần ổn định trong app.
  static const int _serviceId = 2847;

  /// ID nút "Kết thúc tham quan" trên notification, và tín hiệu tương ứng bắc
  /// từ isolate task về isolate chính. Public vì [_KeepAliveTaskHandler] chạy
  /// ở isolate KHÁC và phải dùng đúng hằng này.
  static const String kEndTourButtonId = 'end_tour';
  static const String kEndTourSignal = 'keepAlive.endTour';

  /// Handler do composition root cắm vào (xem [onEndRequested]).
  void Function()? _onEnd;

  /// init() chỉ cần chạy MỘT lần cho cả vòng đời tiến trình. Gọi lazy ở start()
  /// (lúc bắt đầu tour, app đang tiền cảnh nên mọi thao tác FGS đều hợp lệ) nên
  /// main.dart không phải biết tới keep-alive.
  static bool _configured = false;

  static void _ensureConfigured({
    String? channelName,
    String? channelDescription,
  }) {
    if (_configured) return;
    _configured = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tour_keep_alive',
        // Đã resolve theo ngôn ngữ ở composition root; default VI nếu không có.
        // LƯU Ý: Android cache tên/mô tả kênh sau lần tạo đầu — đổi ngôn ngữ ở
        // các tour sau KHÔNG cập nhật tên kênh (giới hạn nền tảng), chỉ
        // title/text của notification (đặt ở startService) mới đổi được.
        channelName: channelName ?? 'Giữ phiên tham quan',
        channelDescription: channelDescription ??
            'Giữ ứng dụng chạy để bắt beacon khi màn hình tắt.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Không cần sự kiện lặp; để 10 phút cho rẻ (onRepeatEvent là no-op).
        eventAction: ForegroundTaskEventAction.repeat(600000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true, // <-- giữ CPU thức khi màn tắt (mấu chốt)
        allowWifiLock: false,

        // ⚠ CỐ Ý KHÔNG ĐẶT `stopWithTask` Ở ĐÂY. Đây là một cái bẫy đã từng
        // sập, đừng "sửa lại" nếu không đọc hết đoạn này.
        //
        // Ta VẪN muốn vuốt-tắt-ở-đa-nhiệm giết được service, và ta VẪN đạt
        // được điều đó — bằng android:stopWithTask="true" trong AndroidManifest.
        // ForegroundServiceUtils.isSetStopWithTaskFlag đọc SharedPreferences
        // trước rồi mới tới cờ manifest, nên cả hai đường đều dẫn tới
        // `onTaskRemoved -> stopSelf()`. Khác biệt nằm ở TÁC DỤNG PHỤ của
        // đường prefs, trong ForegroundService.onStartCommand:
        //
        //     if (prefs.contains(STOP_WITH_TASK) && prefs.getBoolean(...))
        //         TrackVisibilityUtils.install(app) { stopForegroundService() }
        //
        // TrackVisibilityUtils bắn callback đó ở onActivityPaused ĐẦU TIÊN mà
        // không còn activity nào resumed. TẮT MÀN HÌNH chính là sự kiện đó.
        // Tệ hơn: `resumed` rỗng ngay lúc đăng ký (MainActivity đã resumed từ
        // trước khi service start, nên không có onActivityResumed nào để đếm),
        // nên lần pause đầu tiên là fire — kể cả bấm Home hay mở đa nhiệm.
        // stopForegroundService() = cancelRestartAlarm + releaseLockMode +
        // stopForeground + stopSelf ⇒ keep-alive tự sát và THẢ WAKE LOCK đúng
        // lúc cần nhất, còn allowAutoRestart:false bảo đảm nó không sống lại.
        // keepAlive.start() chỉ chạy ở cạnh gate->touring nên mất là mất cả tour.
        //
        // Đặt null (mặc định) ⇒ plugin remove() khoá khỏi prefs ⇒ chỉ còn đường
        // manifest ⇒ có stopSelf lúc vuốt tắt, KHÔNG có TrackVisibilityUtils.

        // Chặn đường hồi sinh thứ hai, trong onDestroy. Máy hướng dẫn bảo tàng
        // không có kịch bản nào cần service tự sống lại — tour kết thúc là kết
        // thúc. (Khoá này độc lập với STOP_WITH_TASK, không dính bẫy ở trên.)
        allowAutoRestart: false,
      ),
    );
  }

  /// Cầu nối từ isolate task về đây. Chỉ nhận đúng tín hiệu ta tự phát ra;
  /// mọi payload lạ bị bỏ qua thay vì đoán mò.
  void _onTaskData(Object data) {
    if (data == kEndTourSignal) _onEnd?.call();
  }

  @override
  void onEndRequested(void Function()? handler) => _onEnd = handler;

  @override
  Future<void> start({
    String? channelName,
    String? channelDescription,
    String? notificationTitle,
    String? notificationText,
    String? endButtonText,
  }) async {
    _ensureConfigured(
      channelName: channelName,
      channelDescription: channelDescription,
    );
    // Tear-off của method instance là == với chính nó trong Dart, nên
    // addTaskDataCallback dedupe được và removeTaskDataCallback ở [stop] gỡ
    // đúng cái đã thêm — kể cả sau khi AppRestarter dựng lại graph.
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        // KHÔNG truyền serviceTypes: để trống ⇒ plugin dùng
        // FOREGROUND_SERVICE_TYPE_MANIFEST = hợp của specialUse|location khai
        // trong AndroidManifest. Truyền tay sẽ đi qua bảng ánh xạ theo SDK của
        // plugin, nơi specialUse chỉ tồn tại từ API 34 — trên Android 13 nó
        // lặng lẽ rơi mất. Xem ghi chú ở AndroidManifest.
        notificationTitle: notificationTitle ?? 'Đang tham quan',
        notificationText:
            notificationText ?? 'Giữ kết nối beacon khi màn hình tắt',
        notificationIcon: null, // dùng icon app mặc định
        notificationButtons: endButtonText == null
            ? null
            : [NotificationButton(id: kEndTourButtonId, text: endButtonText)],
        callback: tourKeepAliveCallback,
      );
      if (kDebugMode) debugPrint('[KeepAlive] started');
    } catch (e) {
      // Nếu OS từ chối (kiểm tra runtime FGS-type, thiếu quyền, v.v.) thì app +
      // BLE VẪN chạy — chỉ mất keep-alive khi màn tắt lúc im lặng. Không để lỗi
      // này phá tour.
      if (kDebugMode) debugPrint('[KeepAlive] startService thất bại: $e');
    }
  }

  @override
  Future<void> stop() async {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        if (kDebugMode) debugPrint('[KeepAlive] stopped');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[KeepAlive] stopService thất bại: $e');
    }
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (e) {
      if (kDebugMode) debugPrint('[KeepAlive] đọc battery-opt thất bại: $e');
      return false;
    }
  }

  @override
  Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (e) {
      if (kDebugMode) debugPrint('[KeepAlive] xin battery-opt thất bại: $e');
    }
    // Đọc lại thay vì tin giá trị trả về: hộp thoại có thể bị ROM nuốt, và cái
    // ta thực sự quan tâm là TRẠNG THÁI SAU CÙNG.
    return isBatteryOptimizationIgnored();
  }
}

/// No-op cho mock/desktop: không đụng API Android. Dùng ở RunMode.mock.
class NoopKeepAlive implements IKeepAlive {
  const NoopKeepAlive();

  @override
  Future<void> start({
    String? channelName,
    String? channelDescription,
    String? notificationTitle,
    String? notificationText,
    String? endButtonText,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void onEndRequested(void Function()? handler) {}

  /// Desktop/mock coi như đã "miễn tối ưu pin": không có khái niệm đó, và trả
  /// true giữ cho màn Cài đặt không hiện cảnh báo giả.
  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => true;
}