// Destination: lib/domain/interfaces/i_headphone_monitor.dart

/// Reports headphone availability and the "audio became noisy" event.
///
/// "Headphones" here means ANY private-listening route — wired jack OR
/// Bluetooth audio (the client-device future case) — not just a 3.5 mm plug.
/// The tour controller consumes this for two confirmed policies:
///   • autoplayRequiresHeadphones: no route ⇒ reading mode, never autoplay
///     out loud;
///   • becomingNoisy: route removed mid-playback ⇒ pause immediately (the
///     Spotify/Apple Music gold standard), and DO NOT auto-resume on replug —
///     wait for an explicit play.
abstract interface class IHeadphoneMonitor {
  /// Whether a private-listening route is currently connected. Synchronous
  /// read for the gate screen's initial autoplay decision.
  bool get isConnected;

  /// Connection changes: true = a route became available, false = removed.
  /// The false edge is the "becoming noisy" signal the controller pauses on.
  Stream<bool> get onConnectionChanged;

  /// Begin monitoring. Idempotent.
  Future<void> start();

  /// Đọc LẠI tuyến nghe thật từ hệ thống và sửa [isConnected] nếu nó đã lệch.
  ///
  /// Vì sao cần: [isConnected] là một cờ CHỐT, chỉ đổi theo sự kiện cạnh
  /// (becomingNoisy hạ nó, devicesChanged nâng nó). becomingNoisy là tín hiệu
  /// MỘT CHIỀU — không có sự kiện ngược lại — nên chỉ cần nó bắn nhầm một lần
  /// (ví dụ khi audio session bị gỡ lúc tour kết thúc) là cờ kẹt ở false vĩnh
  /// viễn: tai nghe chưa từng bị rút nên devicesChanged sẽ không bao giờ tới
  /// để sửa. Hậu quả: autoplay chết trong khi bấm tay vẫn phát.
  ///
  /// Gọi ở các mốc mà một lần đọc chậm vài trăm ms là vô hại và một cờ sai là
  /// tai hại — cụ thể là khi phiên về màn Gate, trước lúc khách bấm Bắt đầu.
  Future<void> refresh();

  Future<void> dispose();
}