// Destination: lib/presentation/theme/app_text.dart (REPLACES current)
//
// ═══════════════════════════════════════════════════════════════════════════
// KHÔNG STYLE NÀO KHAI BÁO `color`
// ═══════════════════════════════════════════════════════════════════════════
//
// Màu đến từ MuseumTokens, và mỗi call site phải tự chọn giữa hai họ:
//
//   Text(name, style: AppText.cardTitle.copyWith(color: t.inkOnImage))  // trên ảnh
//   Text(title, style: AppText.sheetTitle.copyWith(color: t.ink))       // trên nền
//
// Trông ồn hơn `AppText.cardTitle`, nhưng đó là ý đồ: light theme làm cho hai
// trường hợp trên KHÁC nhau, và compiler không thể chọn hộ. Một style mang sẵn
// màu sẽ âm thầm sai ở một trong hai chỗ.
//
// Với `Text` không copyWith, màu chảy xuống từ ThemeData.textTheme qua
// TextStyle.inherit — đó là màu `ink` mặc định của theme.
//
// ═══════════════════════════════════════════════════════════════════════════
// CỠ CHỮ — đã sửa (xem commit "fix(a11y)")
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản trước lấy px từ mockup HTML nguyên xi: kicker 8.5, timeCode 9, stopMeta
// 9.5, zone-card meta 10. CSS px trên màn hình desktop cách mắt 60cm KHÔNG
// tương đương logical px trên điện thoại cầm cách mắt 30cm. Ngưỡng khuyến nghị
// cho chữ phụ là ~12sp, và khách bảo tàng có tỉ trọng người lớn tuổi cao.
//
// `height` của các tiêu đề serif đã nới HAI LẦN, và lần thứ hai xoá kết luận
// của lần thứ nhất:
//   • lần 1 (thời Playfair): 1.02 -> 1.10. Ở textScaler 1.3x, Playfair 28px
//     với height 1.02 cắt mất phần trên của dấu tiếng Việt (ấ, ầ, ế).
//   • lần 2 (sau khi đổi sang Cormorant): 1.10–1.15 -> 1.28–1.32. Con số của
//     lần 1 chết cùng Playfair — xem doc của AppFonts ngay dưới.
// Cả hai đều là bug thật, chỉ lộ khi bật cỡ chữ lớn của hệ thống.

import 'package:flutter/material.dart';

/// ⚠ FONT SERIF ĐÃ ĐỔI PLAYFAIR DISPLAY -> CORMORANT GARAMOND. Mọi comment
/// trong file này từng nhắc "Playfair" đều đã được sửa — nhưng quan trọng hơn
/// cái tên: TOÀN BỘ các con số fontSize/height dưới đây được ĐO trên Playfair,
/// nên kết luận của chúng không tự động còn đúng.
///
/// Hai font khác nhau ở đúng chỗ giết ta:
///   • x-height: Playfair rất cao, Cormorant rất thấp ⇒ cùng fontSize thì
///     Cormorant TRÔNG nhỏ hơn hẳn. (đã giết `stopName: 15`)
///   • extenders: Cormorant có ascender/descender dài kiểu Garamond ⇒ natural
///     line height lớn hơn Playfair ⇒ mọi `height` cũ đều quá chật.
///     (đã giết `height: 1.10–1.15` ở mọi style serif)
///
/// Bài học: đổi font KHÔNG phải đổi một dòng string. Nó vô hiệu hoá mọi con số
/// đã tinh chỉnh quanh font cũ. Lần sau đổi font, soát lại cả file này.
abstract final class AppFonts {
  static const String serif = 'CormorantGaramond';
  static const String sans = 'Inter';
}

abstract final class AppText {
  // ── serif titles (Cormorant Garamond) ────────────────────────────────────
  //
  // MỌI `height` DƯỚI ĐÂY VỪA ĐƯỢC NÂNG 1.10–1.15 -> 1.28–1.32.
  //
  // Vì sao: các giá trị cũ được đo trên Playfair Display. Cormorant Garamond
  // có extenders dài hơn, và tiếng Việt là trường hợp xấu nhất của chữ Latin —
  // dấu CHỒNG trên dấu (Ầ, Ế, Ộ, Ẫ) vượt lên trên cả cap-height. Chữ HOA có
  // dấu (`museumName` -> "BẢO TÀNG") là tệ nhất, nên nó được 1.32.
  //
  // RỦI RO THẬT KHÔNG PHẢI LÀ "CẮT CHỮ": Flutter không clip, nó để glyph tràn
  // khỏi line box. Hai hậu quả thật:
  //   1. CHỒNG CHỮ ở khối "Chào mừng / quý khách" — hai Text xếp cách nhau 0.
  //      Đuôi `g` của "mừng" và dấu sắc của `ý` trong "quý" đang lao vào nhau.
  //   2. KHE QUANG HỌC SAI: nếu line box không chứa nổi glyph, dấu mũ chọc lên
  //      trên nó ⇒ khe 12dp dưới vạch accent TRÔNG hẹp hơn 12. Mọi công căn
  //      lưới ở gate_screen được đo trên một hộp chữ nói dối.
  //
  // ⚠ ĐÁNH ĐỔI PHẢI NHÌN BẰNG MẮT: nâng height làm khối "Chào mừng / quý
  // khách" GIÃN RA ~5dp. Khối đó tight vì leading đang KHÔNG an toàn — không
  // thể vừa tight vừa an toàn từ cùng một con số. Nhìn rồi chọn; nếu vẫn muốn
  // tight, cách duy nhất là gộp hai dòng vào MỘT Text hai style (TextSpan) và
  // chỉnh height ở span, đừng hạ height về mức chật.

  /// Hero title của KHU TRƯNG BÀY (màn 3 — người dùng duy nhất còn lại sau
  /// khi Gate chuyển sang [welcomeTitle]). 32 vì hero giờ cao 80% màn hình,
  /// và tên khu thường ngắn hơn tên hiện vật. height nới từ 1.02 để dấu tiếng
  /// Việt không bị cắt khi hệ thống phóng chữ.

  /// Tiêu đề màn chào (Gate) — CỐ Ý tách khỏi [heroTitle]: Gate là màn duy
  /// nhất có ~55% không gian trống nên chịu được cỡ 34; màn 3 dùng [heroTitle]
  /// 28 trên hero 250px thì không. Đổi cỡ ở đây không được ảnh hưởng màn 3.

  /// Welcome / hero title. height nới từ 1.02 để dấu tiếng Việt không bị cắt
  /// khi hệ thống phóng chữ.
  static const TextStyle heroTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.28,
  );

  /// Tiêu đề màn chào (Gate) — CỐ Ý tách khỏi [heroTitle]: Gate là màn duy
  /// nhất có ~55% không gian trống nên chịu được cỡ 34; màn 3 dùng [heroTitle]
  /// 28 trên hero 250px thì không. Đổi cỡ ở đây không được ảnh hưởng màn 3.
  static const TextStyle welcomeTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.28,
  );

  static const TextStyle museumName = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.32,
  );

  static const TextStyle welcomeSubTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.28,
  );

  /// Zone card title.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.30,
  );

  /// Sheet title ("Khu vực của bạn").
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.28,
  );

  /// Player exhibit name.
  static const TextStyle playerTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.28,
  );

  /// Exhibit-list row name.
  /// Tên hiện vật trên hàng danh sách (màn 3).
  ///
  /// 15 -> 18: ĐÂY LÀ SÀN CỦA FONT, KHÔNG PHẢI SỞ THÍCH. Cormorant Garamond
  /// là một Garamond hiển thị: x-height rất thấp, nét rất mảnh, dựng cho cỡ
  /// >= 20. Ở 15px nó thôi là chữ đọc được và thành hoa văn — và đối tượng
  /// của app này lệch về khách lớn tuổi, đúng nhóm chịu thiệt nhất.
  ///
  /// 15 KHÔNG SAI KHI NÓ ĐƯỢC VIẾT RA — nó được đo trên Playfair Display
  /// (x-height cao, nét dày). Nó chết trong lần đổi font sang Cormorant mà
  /// không ai soát lại. Cùng con bug với `height: 1.12` bên dưới.
  ///
  /// Nếu buộc phải giữ 15 (hàng quá cao): PHẢI đổi sang AppFonts.sans w500.
  /// Không có phương án thứ ba — serif 15 ở font này là không đọc được.
  ///
  /// Hệ quả bố cục: hàng cao thêm ~6dp khi tên xuống 2 dòng. Chấp nhận —
  /// thumb 56 vẫn là mỏ neo, và tên hiện vật LÀ nội dung của hàng.
  static const TextStyle stopName = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.30,
  );


  // ── sans body (Inter) ────────────────────────────────────────────────────

  /// Uppercase kicker. 8.5 -> 11. letterSpacing giữ tỉ lệ .22em.
  static const TextStyle kicker = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 2.42,
  );

  /// Meta line trên card/hero. 11 -> 12.
  static const TextStyle meta = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.3,
  );

  /// Mô tả phụ dưới tiêu đề màn hình. Gom từ 3 TextStyle inline giống nhau.
  static const TextStyle sheetSub = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.4,
  );

  /// Đoạn hướng dẫn / trạng thái nhiều dòng (empty state, sync notice).
  static const TextStyle guidance = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.5,
  );

  /// Đoạn dẫn nhập của màn chào — chỉ dẫn quan trọng nhất khách sẽ đọc, nên
  /// KHÔNG dùng [guidance] (12/w300 đọc như chữ in nhỏ). w400 vì chữ sáng
  /// trên nền tối render mảnh hơn thực tế (halation).
  static const TextStyle lede = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.55,
  );

  /// Thân bài các mục dưới fold. Gom từ _bodyStyle private ở màn 4.
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 13,
    height: 1.7,
  );

  /// Exhibit-list row sub. 9.5 -> 12.
  static const TextStyle stopMeta = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.3,
  );

  /// Player artist line.  11 -> 12.
  static const TextStyle artist = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    fontSize: 12,
    height: 1.3,
  );

  /// CTA label (uppercase).
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 0.96,
  );

  /// Player time codes. 9 -> 12. Chúng là chữ số dày đặc, cỡ 9 gần như không
  /// đọc nổi khi cầm máy đi bộ.
  static const TextStyle timeCode = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}