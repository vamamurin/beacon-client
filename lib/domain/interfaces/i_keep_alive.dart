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
  Future<void> start();

  /// Tắt keep-alive (idempotent: gọi khi đã tắt là no-op).
  Future<void> stop();
}