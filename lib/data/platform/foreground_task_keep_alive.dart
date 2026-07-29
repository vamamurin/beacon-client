// Destination: lib/data/platform/foreground_task_keep_alive.dart (NEW)
//
// Impl [IKeepAlive] bằng flutter_foreground_task (^9.2.2). Đây là foreground
// service THỨ HAI của app (bên cạnh audio_service). Trách nhiệm DUY NHẤT: giữ
// tiến trình ở mức foreground suốt tour để tiến trình được miễn Doze — nhờ đó
// BLE + timer + audio sống được khi màn tắt, kể cả lúc standby chưa phát gì.
// Nó KHÔNG chạy logic gì trong isolate task; TaskHandler chỉ là vỏ bắt buộc.
//
// Đánh đổi đã được chấp nhận: trong lúc audio thực sự phát, có thể có HAI
// notification (keep-alive + media của audio_service). Máy cho mượn màn tắt bỏ
// túi nên khách không thấy.
//
// foregroundServiceType = specialUse (khai trong AndroidManifest): chọn
// specialUse thay vì connectedDevice/dataSync vì nó KHÔNG có kiểm tra runtime
// (connectedDevice đòi thiết bị đang kết nối — quét BLE thuần có thể trượt) và
// KHÔNG bị giới hạn 6 giờ/24 giờ (dataSync trên Android 15). Với app sideload
// cho bảo tàng, specialUse là lựa chọn an toàn nhất. Xem FEATURE_A_SETUP.md.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:beacon_client/domain/interfaces/i_keep_alive.dart';

/// Callback TOP-LEVEL bắt buộc của flutter_foreground_task: chạy trong isolate
/// task, chỉ gắn một TaskHandler rỗng. @pragma giữ nó khỏi bị tree-shake.
@pragma('vm:entry-point')
void tourKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

/// TaskHandler rỗng — ta không cần isolate task làm gì, chỉ cần service sống.
class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class ForegroundTaskKeepAlive implements IKeepAlive {
  /// ID service tùy ý, chỉ cần ổn định trong app.
  static const int _serviceId = 2847;

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

        // VUỐT TẮT Ở ĐA NHIỆM PHẢI DỪNG HẲN.
        //
        // Đặt Ở ĐÂY chứ không chỉ dựa vào android:stopWithTask trong manifest,
        // vì ForegroundServiceUtils.isSetStopWithTaskFlag đọc theo THỨ TỰ ƯU
        // TIÊN: SharedPreferences trước, cờ manifest chỉ là fallback khi prefs
        // không chứa khoá. Để null (mặc định) là XOÁ khoá khỏi prefs, tức phó
        // mặc cho đường fallback. Đặt tường minh true thì chỉ còn MỘT nguồn sự
        // thật, không phụ thuộc việc đọc được ServiceInfo.flags hay không.
        //
        // Vì sao quan trọng: nhánh còn lại của onTaskRemoved là
        //     RestartReceiver.setRestartAlarm(this, 1000)
        // — service TỰ HẸN GIỜ SỐNG LẠI sau 1 giây. Không đặt cờ nghĩa là ta
        // đang chủ động yêu cầu nó hồi sinh, và force-stop thành cách duy nhất
        // để dừng vì nó xoá luôn alarm.
        stopWithTask: true,

        // Cùng lý do: chặn đường hồi sinh thứ hai trong onDestroy. Máy hướng
        // dẫn bảo tàng không có kịch bản nào cần service tự sống lại — tour kết
        // thúc là kết thúc.
        allowAutoRestart: false,
      ),
    );
  }

  @override
  Future<void> start({
    String? channelName,
    String? channelDescription,
    String? notificationTitle,
    String? notificationText,
  }) async {
    _ensureConfigured(
      channelName: channelName,
      channelDescription: channelDescription,
    );
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: notificationTitle ?? 'Đang tham quan',
        notificationText:
            notificationText ?? 'Giữ kết nối beacon khi màn hình tắt',
        notificationIcon: null, // dùng icon app mặc định
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
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        if (kDebugMode) debugPrint('[KeepAlive] stopped');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[KeepAlive] stopService thất bại: $e');
    }
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
  }) async {}

  @override
  Future<void> stop() async {}
}