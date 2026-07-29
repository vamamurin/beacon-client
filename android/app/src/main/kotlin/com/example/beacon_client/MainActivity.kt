package com.example.beacon_client

import android.content.Intent
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity

/**
 * VÌ SAO CÓ CODE Ở ĐÂY THAY VÌ MỘT DÒNG `class MainActivity : AudioServiceActivity()`.
 *
 * Đường chuẩn AOSP để bắt "khách vuốt tắt app ở màn đa nhiệm" là
 * Service.onTaskRemoved. Ta đã nối nó xuống Dart (MuseumAudioHandler
 * .onTaskRemoved) và đo thực địa trên Redmi Note 12 (HyperOS): sự kiện KHÔNG
 * BAO GIỜ được giao — log chẩn đoán trong hàm đó không in ra một lần nào qua ba
 * lần vuốt. ROM này đơn giản là không gọi nó.
 *
 * Hệ quả quan sát được, cùng một PID xuyên suốt:
 *   • Vuốt lần 1 — keep-alive service chết (cờ android:stopWithTask được AMS xử
 *     lý ở tầng hệ thống, không cần onTaskRemoved), nhưng FGS của audio_service
 *     sống tiếp ⇒ VẪN PHÁT THUYẾT MINH.
 *   • Vuốt lần 2 — engine bị huỷ, audio tắt, nhưng TIẾN TRÌNH VẪN SỐNG.
 *   • Chỉ "Buộc dừng" mới thật sự kết thúc.
 *
 * Nên ta chuyển sang một tín hiệu KHÔNG đi qua Service: vòng đời Activity.
 * onDestroy trong-tiến-trình luôn được giao, mọi ROM, vì nó là hợp đồng của
 * framework chứ không phải quyết định của ActivityManager nhà sản xuất.
 *
 * PHÂN BIỆT "NGƯỜI DÙNG RỜI ĐI" VỚI "HỆ THỐNG DỰNG LẠI" — cả hai đều gọi
 * onDestroy, và giết nhầm ca thứ hai là hỏng app:
 *   • isFinishing = true  ⇒ vuốt ở đa nhiệm, hoặc Back thoát, hoặc finish().
 *     Đây là Ý ĐỊNH của người dùng.
 *   • isChangingConfigurations = true ⇒ xoay màn/đổi theme hệ thống. KHÔNG giết.
 *   • Cả hai false ⇒ hệ thống thu hồi bộ nhớ, Activity sẽ được dựng lại. KHÔNG
 *     giết — đây chính là kịch bản màn-hình-tắt-lâu mà cả tính năng chạy ngầm
 *     tồn tại để phục vụ.
 *
 * KHÔNG gọi ngược xuống Dart ở đây: tại thời điểm onDestroy, FlutterEngine
 * đang bị gỡ (log thực địa cho thấy onDetachedFromEngine ngay sau
 * onDetachedFromActivity), nên mọi lời gọi qua channel là đua với teardown.
 * Thay vào đó dữ liệu đã được bảo toàn TRƯỚC: main.dart flush analytics ở
 * AppLifecycleState.paused — luôn xảy ra trước khi Activity bị huỷ.
 */
class MainActivity : AudioServiceActivity() {

    override fun onDestroy() {
        // Đọc TRƯỚC super.onDestroy(): sau đó trạng thái Activity không còn
        // đáng tin để hỏi.
        val userIsLeaving = isFinishing && !isChangingConfigurations
        super.onDestroy()

        if (!userIsLeaving) return

        Log.i(TAG, "Activity finished (vuốt tắt/Back) — tắt hẳn app")

        // Hạ hai foreground service trước khi giết, để không bỏ lại notification
        // mồ côi trong khoảng thời gian AMS dọn tiến trình.
        stopServiceQuietly(
            "com.pravera.flutter_foreground_task.service.ForegroundService")
        stopServiceQuietly("com.ryanheise.audioservice.AudioService")

        // Ngang "Buộc dừng": tiến trình chết ⇒ FlutterEngine cache, isolate Dart,
        // quét BLE, ExoPlayer và mọi service đi theo. Không có đường nào nhẹ hơn
        // mà tất định, vì engine thuộc sở hữu của FlutterEngineCache chứ không
        // phải Activity (xem AppGraph.shutdownCompletely).
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    /** Tên lớp dạng chuỗi: hai service này thuộc plugin, không phải API công khai. */
    private fun stopServiceQuietly(className: String) {
        try {
            stopService(Intent().setClassName(this, className))
        } catch (e: Exception) {
            Log.w(TAG, "stopService($className) thất bại: ${e.message}")
        }
    }

    private companion object {
        const val TAG = "BeaconMainActivity"
    }
}
