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
// `height` của các tiêu đề serif cũng đã nới (1.02 -> 1.10). Ở textScaler 1.3x,
// Playfair 28px với height 1.02 cắt mất phần trên của dấu tiếng Việt (ấ, ầ, ế).
// Đây là bug thật, chỉ thấy khi bật cỡ chữ lớn của hệ thống.

import 'package:flutter/material.dart';

abstract final class AppFonts {
  static const String serif = 'CormorantGaramond';
  static const String sans = 'Inter';
}

abstract final class AppText {
  // ── serif titles (Playfair Display) ──────────────────────────────────────

  /// Hero title của KHU TRƯNG BÀY (màn 3 — người dùng duy nhất còn lại sau
  /// khi Gate chuyển sang [welcomeTitle]). 32 vì hero giờ cao 80% màn hình,
  /// và tên khu thường ngắn hơn tên hiện vật. height nới từ 1.02 để dấu tiếng
  /// Việt không bị cắt khi hệ thống phóng chữ.
  // static const TextStyle heroTitle = TextStyle(
  //   fontFamily: AppFonts.serif,
  //   fontWeight: FontWeight.w600,
  //   fontSize: 32,
  //   height: 1.12,
  // );

  /// Tiêu đề màn chào (Gate) — CỐ Ý tách khỏi [heroTitle]: Gate là màn duy
  /// nhất có ~55% không gian trống nên chịu được cỡ 34; màn 3 dùng [heroTitle]
  /// 28 trên hero 250px thì không. Đổi cỡ ở đây không được ảnh hưởng màn 3.
  // static const TextStyle welcomeTitle = TextStyle(
  //   fontFamily: AppFonts.serif,
  //   fontWeight: FontWeight.w600,
  //   fontSize: 34,
  //   height: 1.12,
  // );

  /// Welcome / hero title. height nới từ 1.02 để dấu tiếng Việt không bị cắt
  /// khi hệ thống phóng chữ.
  static const TextStyle heroTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.10,
  );

  /// Tiêu đề màn chào (Gate) — CỐ Ý tách khỏi [heroTitle]: Gate là màn duy
  /// nhất có ~55% không gian trống nên chịu được cỡ 34; màn 3 dùng [heroTitle]
  /// 28 trên hero 250px thì không. Đổi cỡ ở đây không được ảnh hưởng màn 3.
  static const TextStyle welcomeTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.12,
  );

  static const TextStyle museumName = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.12,
  );

  static const TextStyle welcomeSubTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.12,
  );

  /// Zone card title.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.15,
  );

  /// Sheet title ("Khu vực của bạn").
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.15,
  );

  /// Player exhibit name.
  static const TextStyle playerTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.12,
  );

  /// Exhibit-list row name.
  static const TextStyle stopName = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.2,
  );

  /// Museum wordmark. height 0.92 -> 1.0: dưới 1.0 là ascender bị xén.
  static const TextStyle wordmark = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1.0,
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