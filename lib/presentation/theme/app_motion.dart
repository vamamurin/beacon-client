// Destination: lib/presentation/theme/app_motion.dart
//
// Thang CHUYỂN ĐỘNG — kệ thứ tư, cạnh [AppSpace] (khoảng cách), [AppText]
// (chữ) và [MuseumTokens] (màu). Cùng một lý lẽ đã dựng nên ba kệ kia, chỉ
// khác đơn vị: ở đây là thời gian và gia tốc.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO DỰNG KỆ TRƯỚC KHI CÓ ĐỒ
// ═══════════════════════════════════════════════════════════════════════════
// Lúc file này ra đời, cả app có ĐÚNG MỘT hiệu ứng UI: fade 180ms khi mở ảnh
// lớn ở màn 4. Hai chỗ động còn lại (vòng đếm ngược ở banner đổi khu, pulse
// radar ở màn 2) không phải hiệu ứng — thời lượng của chúng do DỮ LIỆU quyết
// định, không phải do gu thẩm mỹ.
//
// Nghĩa là kệ này dựng lúc còn trống. Đó là chủ ý: doc của [AppText] đã kể
// chuyện "một style thứ mười tám không ai biết là có", và [AppSpace] ra đời
// sau khi khoảng cách đã rải khắp nơi. Duration và Curve là CÙNG MỘT LOẠI
// hằng số — chỉ là chưa kịp đau. Dựng kệ khi có một món thì rẻ; dựng khi đã
// có hai mươi món thì là một đợt refactor.
//
// ═══════════════════════════════════════════════════════════════════════════
// TỪ VỰNG NHỎ — VÀ ĐÓ LÀ QUYẾT ĐỊNH SẢN PHẨM, KHÔNG PHẢI LƯỜI
// ═══════════════════════════════════════════════════════════════════════════
// Ba thời lượng, ba đường cong. Không có `bounce`, không `elastic`, không
// `overshoot`.
//
// Khách của app này phần lớn lớn tuổi, đang ĐỨNG, trong phòng trưng bày tối,
// tay cầm một chiếc máy mượn mà họ chưa từng dùng. Ở bối cảnh đó một
// transition dài hoặc nảy không đọc ra là "mượt" — nó đọc ra là MÁY LAG, và
// phản xạ tiếp theo của khách là bấm thêm lần nữa. Chuyển động ở đây có đúng
// một việc: nói cho khách biết thứ vừa xuất hiện ĐẾN TỪ ĐÂU. Xong việc đó thì
// biến đi càng nhanh càng tốt.
//
// ═══════════════════════════════════════════════════════════════════════════
// LUẬT (cùng họ với luật 7 của AppSpace: không số thô cho khoảng cách)
// ═══════════════════════════════════════════════════════════════════════════
// KHÔNG `Duration(milliseconds: …)` hay `Curves.…` thô tại call site của tầng
// presentation. Cần một giá trị chưa có ở đây ⇒ thêm vào đây kèm lý do, đừng
// bịa tại chỗ. Ngoại lệ DUY NHẤT: thời lượng do dữ liệu quyết định (vòng đếm
// ngược chạy theo deadline thật) — đó không phải gu, đó là sự kiện.

import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  // ── thời lượng ────────────────────────────────────────────────────────────

  /// Phản hồi tức thì trên một vật ĐANG hiện diện: đổi màu, chấm chỉ số dịch
  /// sang, nhấn nút. Dưới ~100ms mắt không kịp thấy là có chuyển động (chỉ
  /// thấy "đã đổi"); trên ~150ms bắt đầu thấy trễ so với ngón tay.
  static const Duration fast = Duration(milliseconds: 120);

  /// MẶC ĐỊNH của app: một vật xuất hiện hoặc biến mất trong cùng một màn —
  /// overlay, banner, fade, trượt vào. Chọn trước tiên; chỉ đổi khi có lý do.
  static const Duration base = Duration(milliseconds: 220);

  /// Chuyển màn và shared element (ảnh nở từ thẻ ra toàn màn hình). Dài hơn vì
  /// quãng đường dài hơn — mắt cần theo kịp vật đang bay để hiểu nó đi từ đâu
  /// tới đâu; đó là toàn bộ mục đích của loại chuyển động này.
  static const Duration slow = Duration(milliseconds: 320);

  // ── đường cong ────────────────────────────────────────────────────────────
  //
  // Ba vai, không phải ba sở thích. Chọn theo VẬT đang chuyển động đang làm gì.

  /// Vật ĐI VÀO màn: nhanh ngay từ đầu rồi hãm lại. Khách thấy nó gần như tức
  /// thì, phần đuôi chỉ để hạ cánh cho êm.
  static const Curve enter = Curves.easeOutCubic;

  /// Vật RỜI KHỎI màn: chậm rồi nhanh dần. Thứ đang biến mất không đáng để
  /// khách chờ — tăng tốc rồi khuất.
  static const Curve exit = Curves.easeInCubic;

  /// Vật ĐANG CÓ MẶT, chỉ đổi chỗ hoặc đổi cỡ: êm ở cả hai đầu. Đây là đường
  /// cong của Hero và của mọi thứ dịch chuyển trong khi vẫn hiển thị.
  static const Curve move = Curves.easeInOutCubic;

  // ── giảm chuyển động ──────────────────────────────────────────────────────

  /// [d] đã tôn trọng tùy chọn "Giảm chuyển động" của hệ điều hành ⇒ trả
  /// [Duration.zero] khi khách đã bật.
  ///
  /// KHÔNG PHẢI THÊM THẮT: người bật tùy chọn này thường bật vì chuyển động
  /// gây CHÓNG MẶT hoặc buồn nôn (rối loạn tiền đình, chứng đau nửa đầu). Một
  /// bảo tàng đặt máy vào tay khách rồi phóng to ảnh ngang màn hình mà không
  /// hỏi hệ điều hành là đang bỏ qua đúng nhóm người ít có khả năng phàn nàn
  /// nhất — cùng lý lẽ đã dẫn tới `onIncrease/onDecrease` trên thanh tiến
  /// trình và `ExcludeSemantics` trên badge số ở màn 4.
  ///
  /// Dùng ở CHỖ DỰNG animation (route builder, AnimationController), không
  /// dùng trong `build` của widget vẽ mỗi frame.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
