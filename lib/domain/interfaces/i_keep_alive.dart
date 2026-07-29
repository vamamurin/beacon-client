// Destination: lib/domain/interfaces/i_keep_alive.dart (NEW)
//
// HAL cho "giữ tiến trình sống suốt một tour".
//
// VÌ SAO CẦN: foreground service của audio_service chỉ được dựng ở lần PHÁT
// audio đầu tiên. Nếu khách tắt màn hình khi đang ở STANDBY (chưa từng có audio
// nào phát), FGS chưa từng lên → Android đóng băng tiến trình (Doze) và/hoặc
// chặn khởi động audio từ nền → bước vào zone cũng im lặng. Keep-alive này là
// một foreground service ĐỘC LẬP, sống suốt phase `touring` bất kể có đang phát
// hay không, nên tiến trình luôn được miễn Doze: BLE + timer 1 Hz + audio đều
// chạy được khi màn tắt, kể cả trong quãng standby im lặng.
//
// Interface thuần để: (1) mock/desktop dùng no-op (không gọi API Android),
// (2) đổi backend (flutter_foreground_task ↔ khác) không đụng phần wiring.
abstract class IKeepAlive {
  /// Bật keep-alive (idempotent: gọi khi đã chạy là no-op).
  ///
  /// Chuỗi thông báo TÙY CHỌN, đã resolve theo ngôn ngữ ở composition root
  /// (service này "mù" về ngôn ngữ — giữ ranh giới lớp). Không truyền ⇒ impl
  /// dùng default tiếng Việt nhúng. [channelName]/[channelDescription] chỉ có
  /// tác dụng ở LẦN tạo kênh đầu tiên (Android cache tên kênh sau đó).
  ///
  /// [endButtonText] là nhãn nút "Kết thúc tham quan" gắn vào notification.
  /// Truyền null ⇒ không vẽ nút.
  Future<void> start({
    String? channelName,
    String? channelDescription,
    String? notificationTitle,
    String? notificationText,
    String? endButtonText,
  });

  /// Tắt keep-alive (idempotent: gọi khi đã tắt là no-op).
  Future<void> stop();

  /// Đăng ký handler cho nút "Kết thúc tham quan" trên notification.
  ///
  /// VÌ SAO CẦN NÚT NÀY: vuốt tắt ở màn đa nhiệm KHÔNG phải hợp đồng đáng tin
  /// trên Android — mỗi ROM xử lý một kiểu, và bản thân app chạy trong một
  /// FlutterEngine cache do audio_service sở hữu (xem MuseumAudioHandler), nên
  /// Activity chết KHÔNG kéo theo isolate chết. Một nút bấm tường minh là
  /// đường thoát DUY NHẤT không phụ thuộc hành vi ROM.
  ///
  /// Gọi lại sẽ THAY handler cũ. Truyền null để gỡ.
  void onEndRequested(void Function()? handler);

  /// Thiết bị đã được miễn tối ưu hoá pin chưa? Dùng cho màn Cài đặt (nhân
  /// viên) để biết máy đã sẵn sàng bàn giao hay chưa.
  Future<bool> isBatteryOptimizationIgnored();

  /// Mở hộp thoại hệ thống xin miễn tối ưu hoá pin. Trả về trạng thái SAU khi
  /// người dùng trả lời. Đây là thao tác THIẾT LẬP MÁY (một lần/thiết bị), cố
  /// ý KHÔNG nằm trên đường đi của khách tham quan.
  Future<bool> requestIgnoreBatteryOptimization();
}