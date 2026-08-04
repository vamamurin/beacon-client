// Destination: lib/domain/models/summary_config.dart
//
// Cấu hình MÀN TỔNG KẾT + MÀN CẢM ƠN — khối `summary` và `farewell` trong
// manifest.
//
// VỊ TRÍ HAI MÀN NÀY TRONG VÒNG ĐỜI PHIÊN (quan trọng, đọc trước khi sửa):
//
//   Tổng kết  — nằm TRONG `SessionPhase.touring`. Nó là màn XÁC NHẬN, có đường
//               lui ("Quay lại tham quan"). Phiên chưa kết thúc ở đây. Vì vậy
//               [showFeedback] và [showQr] mới đặt được trên màn này: cả đánh
//               giá lẫn QR đều cần sessionId đang sống (AnalyticsRecorder xóa
//               `_sid` ngay khi rời touring).
//   Cảm ơn    — SAU khi phiên đã dọn, trong [SessionPhase.farewell]. Đó là một
//               phase THẬT của máy trạng thái, không phải một cờ ở tầng điều
//               hướng: [farewellAutoReturn] được truyền thẳng vào
//               SessionController (`farewellHold`), và chính controller giữ
//               đồng hồ. Màn hình không hẹn giờ, không tự điều hướng.

import 'package:flutter/foundation.dart';

import 'localized_text.dart';

@immutable
class SummaryConfig {
  /// Lời kết của bảo tàng, hiện ở cuối màn tổng kết. Thiếu ⇒ dùng chuỗi mặc
  /// định trong [kUiDefaults] (`summary.closingFallback`).
  final LocalizedText? closing;

  /// Hiện khối đánh giá trên màn tổng kết.
  final bool showFeedback;

  /// Hiện mã QR "mang chuyến đi về nhà".
  ///
  /// BẤT BIẾN do parser ép: true chỉ giữ nguyên khi [qrBaseUrl] hợp lệ. QR bật
  /// mà không có địa chỉ thì khách quét ra một trang trắng — tệ hơn là không có
  /// QR nào.
  final bool showQr;

  /// Địa chỉ trang đích của QR (http/https). App nối query mô tả chuyến đi vào
  /// sau; server dựng trang đọc query đó.
  final String? qrBaseUrl;

  /// Màn Cảm ơn tự quay về màn chào sau khoảng này.
  ///
  /// [Duration.zero] (mặc định) = GIỮ tới khi có người bấm. An toàn vì có một
  /// đường thoát vật lý độc lập: cắm sạc ⇒ `atDesk` ⇒ root đưa stack về Gate,
  /// nên máy bị bỏ quên vẫn sạch khi lên dock. Đặt khác 0 nếu thực địa cho thấy
  /// khách hay bỏ máy trên ghế mà không bấm gì.
  final Duration farewellAutoReturn;

  const SummaryConfig({
    this.closing,
    this.showFeedback = true,
    this.showQr = false,
    this.qrBaseUrl,
    this.farewellAutoReturn = Duration.zero,
  });

  /// Bundle chưa khai báo gì: vẫn tổng kết + vẫn hỏi đánh giá (không tốn nội
  /// dung phía bảo tàng), nhưng KHÔNG có QR vì QR cần một trang đích thật.
  static const SummaryConfig defaults = SummaryConfig();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SummaryConfig &&
          other.closing == closing &&
          other.showFeedback == showFeedback &&
          other.showQr == showQr &&
          other.qrBaseUrl == qrBaseUrl &&
          other.farewellAutoReturn == farewellAutoReturn);

  @override
  int get hashCode =>
      Object.hash(closing, showFeedback, showQr, qrBaseUrl, farewellAutoReturn);
}
