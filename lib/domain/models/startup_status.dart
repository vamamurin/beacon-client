/// Kết quả tường minh của bước "Gatekeeper" trước khi BLE pipeline được phép chạy.
///
/// Thay cho cờ nhị phân initializing/received cũ (vốn không phân biệt được
/// "đang quét" với "bị chặn vì thiếu quyền / tắt Bluetooth"), enum này cho UI
/// một nhánh riêng cho từng lý do hỏng, kèm CTA phù hợp.
enum StartupStatus {
  /// Chưa giải quyết xong gate (đang xin quyền / đọc adapter).
  checking,

  /// Đủ điều kiện: quyền đã cấp + adapter Bluetooth đang bật → an toàn để quét.
  ready,

  /// Người dùng từ chối quyền BLE/Location → không thể quét.
  permissionDenied,

  /// Quyền bị từ chối VĨNH VIỄN ("Don't ask again" / cấm trong Settings).
  /// request() sẽ không còn hiện hộp thoại → CTA phải là "Mở cài đặt".
  permissionPermanentlyDenied,

  /// Bluetooth adapter đang tắt. Có thể phục hồi khi người dùng bật lại.
  bluetoothOff,

  /// Thiết bị không hỗ trợ BLE (không thể phục hồi bằng thao tác người dùng).
  unsupported,
}
