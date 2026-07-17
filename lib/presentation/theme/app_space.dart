// Destination: lib/presentation/theme/app_space.dart (NEW)
import 'package:flutter/material.dart';
//
// ═══════════════════════════════════════════════════════════════════════════
// LƯỚI 4dp — MỌI KHOẢNG CÁCH LẤY TỪ ĐÂY
// ═══════════════════════════════════════════════════════════════════════════
//
// Trước file này, bốn màn dùng lẫn lộn: gutter 18 (gate, list), 20 (detail),
// 14 (zone card), 12 (player top); nhịp dọc rải rác 3, 5, 6, 10, 13, 14, 26.
// Không con số nào sai riêng lẻ. Cái sai là chúng KHÔNG NÓI CHUYỆN VỚI NHAU —
// mắt cảm nhận được sự lệch 18/20 dù không gọi tên được, và đó chính xác là
// khác biệt giữa "sạch" và "chuyên nghiệp".
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO LÀ STATIC CONST, KHÔNG PHẢI TOKEN THEME
// ═══════════════════════════════════════════════════════════════════════════
//
// MuseumTokens.gutter tồn tại từ trước và mang giá trị GIỐNG NHAU ở cả ba
// preset — nó chưa bao giờ thật sự là "token theme". Khoảng cách là HÌNH HỌC,
// không phải sắc độ: đổi theme không được làm bố cục nhảy.
//
// Lý do kỹ thuật quan trọng hơn: `t.gutter` không phải const, nên
// `EdgeInsets.fromLTRB(t.gutter, ...)` GIẾT `const` ở mọi call site. AppSpace
// là static const ⇒ mọi EdgeInsets trong app quay lại được const. Đây là lý
// do chính đáng nhất để KHÔNG đưa spacing vào ThemeExtension.
//
// MuseumTokens.gutter: giữ lại cho tương thích, nhưng ĐẶT = AppSpace.gutter ở
// cả ba preset và coi file này là nguồn. Nếu sau này không còn call site nào
// đọc t.gutter, hãy xoá field đó.
//
// ═══════════════════════════════════════════════════════════════════════════
// LUẬT ÁP DỤNG — đọc trước khi thêm một con số mới
// ═══════════════════════════════════════════════════════════════════════════
//
// 2. LƯỚI NÀY QUẢN BỐ CỤC, KHÔNG QUẢN CHỮ. Đây là ranh giới quan trọng nhất
//    của file, và nó từng bị viết sai (xem "SỬA LUẬT" bên dưới).
//
//    a) KHOẢNG CÁCH BỐ CỤC — khe giữa các KHỐI, lề, padding thẻ. Ba mức, và
//       chỉ ba:
//         • x3 (12) — trong một khối
//         • x6 (24) — giữa hai khối
//         • x8 (32) / x12 (48) — giữa hai phần của màn
//       Ba mức là đủ để mắt dựng lại cấu trúc. Bốn mức trở lên thì không.
//
//    b) KHOẢNG CÁCH GIỮA CÁC DÒNG CHỮ — vạch→tiêu đề, tiêu đề→lede, kicker→
//       tiêu đề. CHÚNG KHÔNG THUỘC LUẬT (a). Chữ đã mang sẵn `height` (leading)
//       của riêng nó, nên khe ĐO ĐƯỢC không bằng khe MẮT THẤY: một hình chữ
//       nhật đặc có 0 đệm quang học, còn một dòng chữ Cormorant có cả một
//       khoảng trống trên cap-height do ascender dài. Muốn hai khe TRÔNG bằng
//       nhau thì hai số đo PHẢI khác nhau.
//
//       Vì vậy x2 (8) giữa "quý khách" và lede ở Gate là HỢP LỆ, dù 8 không
//       nằm trong ba mức của (a). Nó không phải khe bố cục — nó là bù trừ
//       quang học, và nó chạy trên hệ leading, không chạy trên lưới này.
//
//       LUẬT THAY THẾ cho (b) — chỉ một, và nó là luật về TRẬT TỰ chứ không
//       phải về CON SỐ: khe phải TĂNG DẦN theo mức tách rời. Ở Gate:
//         tiêu đề↔phụ đề (0)  <  vạch↔tiêu đề (12)  =  phụ đề↔lede (12)
//         <  khối chữ↔CTA (24)
//
//       LUẬT THẬT chỉ có MỘT, và nó không phải "thứ tự tăng dần nghiêm ngặt":
//
//           khe TRÊN một đoạn phải lớn hơn HẲN khe TRONG đoạn đó.
//
//       Nếu không, đoạn văn thôi đọc như một khối riêng và tụt xuống thành
//       "một dòng nữa của tiêu đề". Đó là điều kiện duy nhất, và nó là điều
//       kiện QUANG HỌC — nó nói về khe HIỆU DỤNG (khe + leading), không nói về
//       con số trong `SizedBox`.
//
//       ĐÃ SỬA (giữ lại để không ai "sửa" ngược): bản trước ghi ví dụ
//       `phụ đề↔lede (8)` và kèm cảnh báo của chính nó —
//
//           "lede là 13/1.55 ⇒ khe giữa hai dòng của chính nó ≈ 7–8dp. Khe 8
//            phía trên nó cộng leading ≈ 13dp, tức chỉ ~1.6×. Đủ, nhưng SÁT —
//            đó là con số cần nhìn nếu sau này thấy khối chữ Gate dính."
//
//       Rồi có người ĐÃ NHÌN, và nâng 8 → 12. Đó là gate_screen hôm nay, và nó
//       ĐÚNG: 12 + leading ≈ 19dp so với 7–8dp bên trong lede = ~2.5×, thoải
//       mái thay vì sát. Người đó làm đúng thứ doc dặn; chỉ là không ai quay
//       lại sửa doc, nên suốt thời gian sau đó doc và code mâu thuẫn nhau và
//       CẢ HAI đều trông như nguồn sự thật.
//
//       Hệ quả: `vạch↔tiêu đề` và `phụ đề↔lede` giờ BẰNG NHAU (12 = 12). Thứ
//       tự tăng dần nghiêm ngặt GÃY — và không sao, vì nó chưa bao giờ là luật.
//       Nó là một ví dụ bị đọc nhầm thành luật. Khối tiêu đề giờ có 12 ở cả
//       hai phía: nó đọc ra là một đơn vị cân xứng.
//
//       CÂU HỎI CÒN MỞ (chỉ mắt trả lời được, số không): vạch 88×2 GIỚI THIỆU
//       tiêu đề, nên có lẽ nó phải DÍNH tiêu đề hơn là lede dính phụ đề — tức
//       vạch↔tiêu đề nên nhỏ hơn 12. Nhưng thang chỉ có x2 (8) dưới x3, và 8
//       là con số vừa bị loại vì quá sát ở chỗ kia. Nếu bao giờ thấy vạch
//       "trôi" khỏi tiêu đề, đó là chỗ để nhìn — và câu trả lời có thể là thang
//       cần một nấc 10, chứ không phải khe này cần đổi.
//
// SỬA LUẬT (giữ lại để không tái phạm): bản đầu của file này viết "BA MỨC
// NHỊP DỌC, và chỉ ba" cho MỌI khoảng cách, gộp cả chữ. Đó là lỗi PHẠM TRÙ —
// cùng loại với việc bắt cỡ icon phải chia hết cho 4. Lưới đo khoảng cách
// giữa các VẬT; leading đo khoảng cách giữa các DÒNG. Một luật cứng đến mức
// cấm bù trừ quang học thì nó không còn phục vụ thiết kế, nó chỉ phục vụ
// chính nó.
//
// 3. KHÔNG BAO GIỜ viết số thô cho khoảng cách BỐ CỤC. Nếu thang này thiếu
//    giá trị bạn cần, hãy DỪNG LẠI và hỏi vì sao — 9 trên 10 lần câu trả lời
//    là bạn đang cố vá một vấn đề khác bằng khoảng trắng.
//
// 4. MỘT ĐƯỜNG DỌC TRÁI CHO CẢ MÀN = [gutter]. Chữ, nút, vạch nhấn, và — đây
//    là phần bị bỏ sót — MÉP ẢNH cũng phải ngồi trên đường đó, hoặc tràn hẳn
//    ra 0. Không có lựa chọn thứ ba (xem doc _WelcomeCollage).
//
// 5. HÌNH VUÔNG/TRÒN của cùng một vai trò dùng chung một cỡ: [tap] cho mọi
//    vùng chạm phụ, [thumb] cho mọi ảnh nhỏ dẫn hàng.
//
// 6. CỠ GLYPH KHÔNG THUỘC LƯỚI NÀY. Icon Material sống trên thang riêng của
//    nó (18/24/36/48); một icon 20dp "đúng lưới 4dp" trông sai lệch hơn một
//    icon 18dp đúng thang Material. Cùng lý lẽ với (2b).
//
// 7. Ngoại lệ hợp lệ DUY NHẤT với số thô: kích thước theo TỶ LỆ màn hình
//    (h * 0.50) trong bố cục collage/hero. Đó là compositional, không phải
//    spacing — chúng không thuộc lưới 4dp và không nên bị ép vào.

abstract final class AppSpace {
  /// Đơn vị lưới. Mọi giá trị dưới đây chia hết cho nó.
  static const double unit = 4;

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;

  // ── vai trò (alias có tên, để call site đọc ra Ý ĐỊNH chứ không phải số) ──

  /// Lề trái/phải của MỌI màn. 20 chứ không phải 18: 18 không nằm trên lưới
  /// 4dp, và màn 4 (detail) vốn đã dùng 20 — chọn 20 là đồng bộ về phía số
  /// ĐÚNG thay vì về phía số ĐÔNG.
  static const double gutter = x5;

  /// Vùng chạm tối thiểu. Cũng là cỡ chuẩn của mọi nút icon tròn phụ (back).
  /// 48 là sàn a11y — _StaffButton trước đây cao 44, tức là DƯỚI sàn.
  static const double tap = x12;

  /// Nút CTA chính (Gate). 72 = 4×18: giữ nguyên trọng lượng thị giác của số
  /// 70 cũ nhưng nằm trên lưới.
  static const double ctaHeight = 72;

  /// Nút tròn chính trên ảnh (intro khu, play): 56 = 4×14.
  static const double actionCircle = 56;

  /// Ảnh vuông dẫn hàng danh sách: 56 = 4×14, khớp [actionCircle] — hai vai
  /// trò khác nhau nhưng cùng "một ô lưới lớn", nên nhịp ngang của màn 3 lặp
  /// lại được ở hai chỗ.
  static const double thumb = 56;

  /// Badge số hiện vật: 36 = 4×9.
  ///
  /// CÓ TÊN RIÊNG, KHÔNG PHẢI `x9`: thang x1..x12 là thang KHOẢNG CÁCH. 36 ở
  /// đây là kích thước một VẬT THỂ, và nó không được phép trở thành một nấc
  /// spacing hợp lệ — thêm x9 vào thang là mở cửa cho mọi bội số của 4, tức
  /// là xoá luôn cái thang. Vật thể có tên; khoảng cách có số.
  ///
  /// KHÔNG dùng [tap]: badge không phải vùng chạm (cả hàng mới là).
  static const double badge = 36;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MỘT NGUỒN SÁNG CHO CẢ APP
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Bóng đổ không phải trang trí — nó là PHÁT BIỂU về vị trí của vật trong
/// không gian, và mắt người đọc phát biểu đó nhanh hơn đọc chữ. Hai vật cùng
/// màn mà đổ bóng về hai hướng thì không gian đó không tồn tại, và cảm giác
/// "sai" xuất hiện trước khi người xem kịp gọi tên.
///
/// LỖI ĐÃ SỬA: khung ảnh Gate dùng Offset(-6, 8) — bóng xuống-TRÁI, đèn ở
/// trên-PHẢI. Badge màn 3 dùng Offset(2, 2) — bóng xuống-PHẢI, đèn ở
/// trên-TRÁI. Hai mặt trời trong một bảo tàng.
///
/// ĐÈN Ở TRÊN-PHẢI, mọi bóng đổ xuống-trái. Chọn hướng này vì bố cục Gate đã
/// được dựng quanh nó (bóng khung 2 hắt lên mép khung 1 tạo lớp lang) — đổi
/// hướng đèn là phải dựng lại collage.
///
/// MÀU bóng vẫn là token theo theme ([MuseumTokens.frameShadow]); chỉ HÌNH HỌC
/// sống ở đây. Ở highContrast frameShadow trong suốt ⇒ mọi bóng tự tắt, và đó
/// là chủ đích.
abstract final class AppShadow {
  /// Bóng của khung ảnh lớn (collage Gate).
  static const Offset frameOffset = Offset(-6, 8);
  static const double frameBlur = 12;

  /// Bóng của vật nhỏ (badge khi nổi lên). ĐÚNG MỘT NỬA [frameOffset] về cả
  /// hướng lẫn độ lớn: cùng đèn, gần mặt phẳng hơn.
  static const Offset liftOffset = Offset(-3, 4);
  static const double liftBlur = 6;
}