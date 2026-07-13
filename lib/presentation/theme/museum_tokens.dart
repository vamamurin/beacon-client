// Destination: lib/presentation/theme/museum_tokens.dart
//
// Design tokens, instance-based. Thay cho `static const` trong AppColors, vốn
// không thể mang hai giá trị cùng lúc.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI HỌ TOKEN — đọc kỹ trước khi thêm field mới
// ═══════════════════════════════════════════════════════════════════════════
//
//   ┌─ SURFACE FAMILY ─ đổi theo theme
//   │  surface, ink, inkMuted, inkFaint, line, ctaFill, ctaLabel, ctaDisabled
//   │  → chữ và nền đặt trên NỀN CỦA ỨNG DỤNG
//   │
//   └─ ON-IMAGE FAMILY ─ không đổi giữa dark và light
//      inkOnImage, mutedOnImage, artistOnImage, scrimBack, lineOnImage,
//      ctaOnImageFill, ctaOnImageInk, *Veil
//      → chữ và lớp phủ đặt trên ẢNH HIỆN VẬT
//
// Ảnh hiện vật không sáng lên khi bật light theme. Nếu `inkOnImage` đi theo
// `ink`, light mode sẽ cho chữ đen trên ảnh tối — không đọc được. Cái bẫy này
// chỉ lộ ra khi thực sự có theme sáng, và là lý do việc token hoá phải làm
// TRƯỚC khi viết theme thứ hai.
//
// Họ on-image dùng cho mọi chữ nằm TRÊN ẢNH (card, hero, player). Màn Gate
// từng thuộc trọn họ này khi còn là ảnh full màn; từ khi chuyển sang collage
// hai khung ảnh trên nền phẳng, Gate đã quay về họ surface + `welcomeBackdrop`
// (đi theo theme) — xem doc gate_screen.dart.
// Nên Gate giữ tông tối ở mọi theme. Đó là hành vi đúng, không phải bug.
//
// highContrast VẪN được phép làm đậm veil và sáng chữ on-image: mục tiêu của nó
// là độ tương phản, không phải sắc thái. Vì vậy chúng là token khai báo ở mọi
// preset, không phải hằng số toàn cục — dark và light chỉ tình cờ trùng giá trị.
//
// ═══════════════════════════════════════════════════════════════════════════
// MỌI FIELD ĐỀU `required`, KHÔNG CÓ DEFAULT
// ═══════════════════════════════════════════════════════════════════════════
//
// Đây là cơ chế mở rộng, không phải sự khắt khe vô cớ. Thêm một token mới sẽ
// làm CẢ BA preset không compile cho tới khi mỗi preset tự quyết định giá trị
// của mình. Nếu có default, một preset sẽ âm thầm mượn màu của dark và lỗi chỉ
// lộ ra khi ai đó nhìn màn hình — thường là lúc demo.
//
// Khi thêm field, sửa ĐỦ BỐN chỗ: constructor, ba preset, copyWith, lerp.
// Quên copyWith KHÔNG gây lỗi compile: `x ?? this.x` với `x` là field của chính
// object luôn trả về field. Analyzer chỉ báo `dead_null_aware_expression` ở mức
// info — rất dễ bỏ qua, và copyWith sẽ lặng lẽ bỏ giá trị bạn truyền vào.
//
// ═══════════════════════════════════════════════════════════════════════════
// MÀU KHÔNG NẰM TRONG TextStyle
// ═══════════════════════════════════════════════════════════════════════════
//
// AppText.* là `static const` và KHÔNG khai báo `color`. Mỗi call site tự chọn
// họ token:
//
//   Text(name,  style: AppText.cardTitle.copyWith(color: t.inkOnImage))  // ảnh
//   Text(title, style: AppText.sheetTitle.copyWith(color: t.ink))        // nền
//
// Điều này làm mất `const Text(...)` ở phần lớn chỗ. Đó là chi phí có ý thức:
// light theme khiến hai trường hợp trên KHÁC nhau, và compiler không chọn hộ
// được. Một TextStyle mang sẵn màu sẽ âm thầm sai ở một trong hai chỗ.
//
// Ngoại lệ: `Text` không copyWith sẽ merge với DefaultTextStyle của cây
// (TextStyle.inherit = true) và nhận `ink` từ ThemeData.textTheme. Chỉ dùng lối
// tắt đó khi widget chắc chắn nằm trên `surface`.

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class MuseumTokens extends ThemeExtension<MuseumTokens> {
  const MuseumTokens({
    // ── surface family: đổi theo theme ──
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.ctaFill,
    required this.ctaLabel,
    required this.ctaDisabled,

    // ── on-image family: chữ / viền / lớp phủ trên ảnh hiện vật ──
    required this.inkOnImage,
    required this.mutedOnImage,
    required this.artistOnImage,
    required this.scrimBack,
    required this.lineOnImage,
    required this.ctaOnImageFill,
    required this.ctaOnImageInk,
    required this.tourCardVeil,
    required this.playerVeil,
    required this.heroVeil,

    // ── điểm nhấn ──
    required this.accent,

    // ── nền màn chào ──
    required this.welcomeBackdrop,
    required this.welcomeAmbient,
    required this.welcomeBandLower,
    required this.welcomeBandUpper,
    required this.frameShadow,

    // ── hình học ──
    required this.radiusSharp,
    required this.gutter,
  });

  // ── surface family ────────────────────────────────────────────────────────

  /// Nền toàn ứng dụng.
  final Color surface;

  /// Chữ chính, tiêu đề, viền, icon.
  final Color ink;

  /// Chữ phụ: meta, thân bài, mô tả dưới tiêu đề.
  final Color inkMuted;

  /// Chữ mờ nhất còn đọc được: nhãn thông số, hint, icon empty-state.
  /// KHÔNG dùng cho nội dung khách cần đọc kỹ.
  final Color inkFaint;

  /// Đường kẻ hairline giữa các hàng.
  final Color line;

  /// Nền nút CTA đặt trên `surface` (hint bar ở màn 3).
  final Color ctaFill;

  /// Chữ trên [ctaFill]. Luôn tương phản với nó.
  final Color ctaLabel;

  /// Nền nút CTA khi chưa đủ điều kiện bấm.
  final Color ctaDisabled;

  // ── on-image family ───────────────────────────────────────────────────────

  /// Tiêu đề, icon, thanh progress đặt trên ảnh. Trắng ở MỌI theme.
  final Color inkOnImage;

  /// Meta / timecode trên ảnh. Trước refactor tồn tại hai giá trị chênh nhau
  /// một đơn vị (#D0D0D0, #CFCFCF) cho cùng vai trò này, và cả hai đều không
  /// phải AppColors.subText vốn đã có sẵn.
  final Color mutedOnImage;

  /// Dòng nghệ sĩ / niên đại in nghiêng trên ảnh player.
  final Color artistOnImage;

  /// Nền tròn của nút back đặt trên ảnh.
  final Color scrimBack;

  /// Viền khung staff ở Gate, rail của thanh progress. Bán trong suốt, vì thứ
  /// nằm dưới nó là ảnh chứ không phải `surface`.
  final Color lineOnImage;

  /// Nền nút tròn / CTA đặt TRÊN ẢNH: play, num badge, nút "Bắt đầu tham quan".
  final Color ctaOnImageFill;

  /// Icon và chữ đặt trên [ctaOnImageFill].
  final Color ctaOnImageInk;

  /// Veil thẻ zone ở màn 2.
  final LinearGradient tourCardVeil;

  /// Veil màn player: tối đỉnh + tối đáy, trong ở giữa.
  final LinearGradient playerVeil;

  /// Veil ảnh hero 250px của danh sách hiện vật.
  final LinearGradient heroVeil;

  // ── điểm nhấn ─────────────────────────────────────────────────────────────

  /// Màu nhấn DUY NHẤT của ứng dụng — tông đồng/đất, hợp không gian bảo tàng.
  /// Dùng tiết chế: vạch nhấn ở Gate, và sau này là trạng thái "Đang ở đây" /
  /// progress fill nếu quyết định mở rộng. KHÔNG dùng làm nền chữ dài.
  ///
  /// Đủ tương phản trên cả `surface` tối lẫn ảnh có veil, nên khai báo một
  /// lần cho cả hai họ. highContrast dùng biến thể sáng hơn — mục tiêu của
  /// preset đó là độ tương phản, không phải sắc thái.
  final Color accent;

  // ── nền màn chào ─────────────────────────────────────────────────────────

  /// Nền phía sau collage hai vùng ảnh ở Gate — ĐI THEO THEME.
  ///
  /// Lịch sử: khi Gate còn là ảnh full màn, cả màn thuộc họ on-image và không
  /// đổi theo theme. Từ khi chuyển sang collage (hai khung ảnh tự chứa trên
  /// nền phẳng), chữ của Gate nằm trên nền NÀY chứ không nằm trên ảnh nữa —
  /// tiền đề của on-image biến mất, nên Gate quay về quy tắc chung: đổi màu
  /// theo theme, chữ dùng họ surface (ink/inkMuted).
  ///
  /// Không dùng thẳng `surface` vì màn chào cố ý ấm hơn phần còn lại của app
  /// (tông tường phòng trưng bày, hoà với accent). Độ chói giữ TƯƠNG ĐƯƠNG
  /// surface của preset để ink/inkMuted/inkFaint đạt tương phản y như trên
  /// surface; riêng `line` KHÔNG dùng được trên nền này — xem gate_screen.
  final Color welcomeBackdrop;

  /// Lớp phủ trên ảnh-nền-mờ (ambient) của Gate: CHÍNH LÀ màu backdrop kèm
  /// alpha theo preset. Alpha là "âm lượng" của ảnh nền — thấp hơn ⇒ ảnh lộ
  /// nhiều hơn. Bất biến phải giữ khi chỉnh: đủ đặc để chữ ink/inkMuted vẫn
  /// được coi là nằm trên backdrop (họ surface), KHÔNG phải trên ảnh.
  /// highContrast đặt alpha = 100%: ambient tự tắt thành nền phẳng, không
  /// cần nhánh điều kiện nào trong widget.
  final Color welcomeAmbient;

  /// HAI KHỐI MÀU BỐ CỤC của tường chào — dải dưới (~42% chiều cao) và dải
  /// trên (~14%), phủ lên nền/ambient, nằm DƯỚI hai khung ảnh. Vai trò thuần
  /// bố cục: chia tường thành các mảng tông khác nhau để nền không đơn điệu;
  /// CẠNH CỨNG LÀ CHỦ ĐÍCH (ngôn ngữ color-block, khác với scrim gradient).
  ///
  /// Mỗi preset chọn "khối" theo nghĩa của mình: preset tối = mảng sẫm bán
  /// trong suốt; preset giấy = mảng giấy trầm hơn vài bậc (mực alpha thấp —
  /// mảng tối đậm trên giấy sẽ thành vệt bẩn); highContrast = trong suốt,
  /// preset đó phẳng tuyệt đối (cùng triết lý với [frameShadow]).
  final Color welcomeBandLower;

  /// Xem [welcomeBandLower]. Dải trên nhạt hơn dải dưới ở mọi preset — đỉnh
  /// màn chỉ có một dòng kicker, không cần khối nặng.
  final Color welcomeBandUpper;

  /// Bóng đổ của khung ảnh trên tường chào (chiều sâu gallery-wall). Chỉ MÀU
  /// là token; blur/offset là hình học, sống ở gate_screen. Tường sáng cần
  /// bóng nhạt hơn tường tối; highContrast trong suốt — preset đó phẳng
  /// tuyệt đối, và bóng đen trên nền đen cũng vô hình.
  final Color frameShadow;

  // ── hình học ──────────────────────────────────────────────────────────────

  /// 2px — chữ ký thị giác của thiết kế: gần vuông. MỘT giá trị, không phải một
  /// thang đo. Đừng thêm radiusLarge cho tới khi thiết kế thật sự cần.
  final double radiusSharp;

  /// Lề nội dung ngang.
  ///
  /// TODO(step-5): các màn hình vẫn hard-code 18 (màn 1/2/3) và 20 (màn 4).
  /// Chênh 2px giữa các màn trong cùng một app: hoặc là chủ đích (player rộng
  /// hơn), hoặc là lỗi sao chép từ mockup. Quyết định, rồi thay hết bằng token
  /// này — hoặc thêm `gutterWide` và ghi lý do. Một token không widget nào đọc
  /// thì không bao giờ được kiểm chứng, và sẽ sai lặng lẽ.
  final double gutter;

  BorderRadius get sharpAll => BorderRadius.circular(radiusSharp);

  // ═════════════════════════════════════════════════════════════════════════
  // PRESETS
  // ═════════════════════════════════════════════════════════════════════════

  /// Mặc định. Rijksmuseum-style: nền gần đen, chữ trắng. Đúng cho phòng trưng
  /// bày tối, và không làm phiền khách đứng cạnh.
  static const MuseumTokens dark = MuseumTokens(
    surface: Color(0xFF141414),
    ink: Color(0xFFFFFFFF),
    inkMuted: Color(0xFFCFCFCF),
    inkFaint: Color(0xFF9B9B9B),
    line: Color(0xFF222222),
    ctaFill: Color(0xFFFFFFFF),
    ctaLabel: Color(0xFF000000),
    ctaDisabled: Color(0xFF6E6E6E),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFCFCFCF),
    artistOnImage: Color(0xFFC8C8C8),
    scrimBack: Color(0x66000000),
    lineOnImage: Color(0x59FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeil,
    playerVeil: _playerVeil,
    heroVeil: _heroVeil,

    accent: Color(0xFFC99A5B),

    welcomeBackdrop: Color(0xFF181A1F),
    welcomeAmbient: Color(0xB3181A1F), 
    welcomeBandLower: Color(0xFF5E3226), 
    welcomeBandUpper: Color(0xFF244740), 
    frameShadow: Color(0x80000000), 

    radiusSharp: 2,
    gutter: 18,
  );

  /// Nền giấy, chữ mực. Yêu cầu từ phía sản phẩm.
  ///
  /// LƯU Ý VẬN HÀNH: màn hình sáng trong phòng trưng bày tối gây chói cho người
  /// cầm máy và làm phiền khách đứng cạnh. Theme này tồn tại vì được yêu cầu,
  /// không vì nó là lựa chọn tốt cho môi trường bảo tàng. Nếu sau này có dữ
  /// liệu sử dụng, hãy kiểm xem có ai thật sự bật nó trước khi duy trì tiếp.
  ///
  /// Toàn bộ họ on-image giữ nguyên giá trị của [dark]: ảnh hiện vật không sáng
  /// lên theo theme, nên chữ trên nó cũng không được đổi.
  static const MuseumTokens light = MuseumTokens(
    surface: Color(0xFFF7F7F5),
    ink: Color(0xFF141414),
    inkMuted: Color(0xFF5A5A5A),
    inkFaint: Color(0xFF7A7A7A),
    line: Color(0xFFE0E0DC),
    ctaFill: Color(0xFF141414),
    ctaLabel: Color(0xFFF7F7F5),
    ctaDisabled: Color(0xFFBFBFBF),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFCFCFCF),
    artistOnImage: Color(0xFFC8C8C8),
    scrimBack: Color(0x66000000),
    lineOnImage: Color(0x59FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeil,
    playerVeil: _playerVeil,
    heroVeil: _heroVeil,

    accent: Color(0xFFC99A5B),

    welcomeBackdrop: Color(0xFFF1F3ED),
    welcomeAmbient: Color(0xB3181A1F),
    welcomeBandUpper: Color(0xFFCDE0C4),
    welcomeBandLower: Color.fromARGB(255, 162, 128, 125),
    frameShadow: Color(0x80000000),


    radiusSharp: 2,
    gutter: 18,
  );

  /// Tương phản tối đa. Nhân khẩu học bảo tàng lệch về người lớn tuổi; đây là
  /// theme có lý do sản phẩm rõ ràng nhất sau [dark].
  ///
  /// Khác [dark] ở ba điểm: nền đen tuyệt đối (không #141414), không dùng xám
  /// mờ cho chữ phụ, và veil đậm hơn để chữ trên ảnh luôn tách khỏi nền.
  static const MuseumTokens highContrast = MuseumTokens(
    surface: Color(0xFF000000),
    ink: Color(0xFFFFFFFF),
    inkMuted: Color(0xFFF0F0F0),
    inkFaint: Color(0xFFD0D0D0),
    line: Color(0xFF6E6E6E),
    ctaFill: Color(0xFFFFFFFF),
    ctaLabel: Color(0xFF000000),
    ctaDisabled: Color(0xFF4A4A4A),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFF0F0F0),
    artistOnImage: Color(0xFFF0F0F0),
    scrimBack: Color(0xCC000000),
    lineOnImage: Color(0x99FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeilStrong,
    playerVeil: _playerVeilStrong,
    heroVeil: _heroVeilStrong,

    accent: Color(0xFFE3B87E),

    // Đen tuyệt đối = surface của preset: tương phản trước, sắc thái sau.
    welcomeBackdrop: Color(0xFF000000),
    welcomeAmbient: Color(0xFF000000), // ĐẶC — ambient tắt, xem doc của field
    welcomeBandLower: Color(0x00000000), // phẳng tuyệt đối
    welcomeBandUpper: Color(0x00000000),
    frameShadow: Color(0x00000000), // phẳng tuyệt đối

    radiusSharp: 2,
    gutter: 18,
  );

  // ── veil dùng chung (dark + light) ────────────────────────────────────────

  static const LinearGradient _tourCardVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xD1000000), Color(0x14000000)],
    stops: [0.0, 0.60],
  );

  static const LinearGradient _playerVeil = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x8C000000),
      Color(0x00000000),
      Color(0x00000000),
      Color(0xE6000000),
      Color(0xFF000000),
    ],
    stops: [0.0, 0.22, 0.45, 0.78, 1.0],
  );

  static const LinearGradient _heroVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF000000), Color(0x26000000)],
    stops: [0.04, 0.60],
  );

  // ── biến thể đậm cho highContrast ─────────────────────────────────────────
  //
  // Mỗi biến thể giữ ĐÚNG số stops như bản thường. LinearGradient.lerp không
  // nội suy được giữa hai gradient khác số stops — chuyển theme sẽ giật. Thêm
  // một stop ở đây thì phải thêm cả ở bản thường.

  static const LinearGradient _tourCardVeilStrong = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xF2000000), Color(0x66000000)],
    stops: [0.0, 0.60],
  );

  static const LinearGradient _playerVeilStrong = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xCC000000),
      Color(0x33000000),
      Color(0x33000000),
      Color(0xF2000000),
      Color(0xFF000000),
    ],
    stops: [0.0, 0.22, 0.45, 0.78, 1.0],
  );

  static const LinearGradient _heroVeilStrong = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF000000), Color(0x80000000)],
    stops: [0.04, 0.60],
  );

  // ═════════════════════════════════════════════════════════════════════════
  // ThemeExtension
  // ═════════════════════════════════════════════════════════════════════════

  @override
  MuseumTokens copyWith({
    Color? surface,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? line,
    Color? ctaFill,
    Color? ctaLabel,
    Color? ctaDisabled,
    Color? inkOnImage,
    Color? mutedOnImage,
    Color? artistOnImage,
    Color? scrimBack,
    Color? lineOnImage,
    Color? ctaOnImageFill,
    Color? ctaOnImageInk,
    LinearGradient? tourCardVeil,
    LinearGradient? playerVeil,
    LinearGradient? heroVeil,
    Color? accent,
    Color? welcomeBackdrop,
    Color? welcomeAmbient,
    Color? welcomeBandLower,
    Color? welcomeBandUpper,
    Color? frameShadow,
    double? radiusSharp,
    double? gutter,
  }) {
    return MuseumTokens(
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      ctaFill: ctaFill ?? this.ctaFill,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      ctaDisabled: ctaDisabled ?? this.ctaDisabled,
      inkOnImage: inkOnImage ?? this.inkOnImage,
      mutedOnImage: mutedOnImage ?? this.mutedOnImage,
      artistOnImage: artistOnImage ?? this.artistOnImage,
      scrimBack: scrimBack ?? this.scrimBack,
      lineOnImage: lineOnImage ?? this.lineOnImage,
      ctaOnImageFill: ctaOnImageFill ?? this.ctaOnImageFill,
      ctaOnImageInk: ctaOnImageInk ?? this.ctaOnImageInk,
      tourCardVeil: tourCardVeil ?? this.tourCardVeil,
      playerVeil: playerVeil ?? this.playerVeil,
      heroVeil: heroVeil ?? this.heroVeil,
      accent: accent ?? this.accent,
      welcomeBackdrop: welcomeBackdrop ?? this.welcomeBackdrop,
      welcomeAmbient: welcomeAmbient ?? this.welcomeAmbient,
      welcomeBandLower: welcomeBandLower ?? this.welcomeBandLower,
      welcomeBandUpper: welcomeBandUpper ?? this.welcomeBandUpper,
      frameShadow: frameShadow ?? this.frameShadow,
      radiusSharp: radiusSharp ?? this.radiusSharp,
      gutter: gutter ?? this.gutter,
    );
  }

  @override
  MuseumTokens lerp(covariant MuseumTokens? other, double t) {
    if (other == null) return this;
    return MuseumTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      ctaFill: Color.lerp(ctaFill, other.ctaFill, t)!,
      ctaLabel: Color.lerp(ctaLabel, other.ctaLabel, t)!,
      ctaDisabled: Color.lerp(ctaDisabled, other.ctaDisabled, t)!,
      inkOnImage: Color.lerp(inkOnImage, other.inkOnImage, t)!,
      mutedOnImage: Color.lerp(mutedOnImage, other.mutedOnImage, t)!,
      artistOnImage: Color.lerp(artistOnImage, other.artistOnImage, t)!,
      scrimBack: Color.lerp(scrimBack, other.scrimBack, t)!,
      lineOnImage: Color.lerp(lineOnImage, other.lineOnImage, t)!,
      ctaOnImageFill: Color.lerp(ctaOnImageFill, other.ctaOnImageFill, t)!,
      ctaOnImageInk: Color.lerp(ctaOnImageInk, other.ctaOnImageInk, t)!,
      tourCardVeil: LinearGradient.lerp(tourCardVeil, other.tourCardVeil, t)!,
      playerVeil: LinearGradient.lerp(playerVeil, other.playerVeil, t)!,
      heroVeil: LinearGradient.lerp(heroVeil, other.heroVeil, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      welcomeBackdrop: Color.lerp(welcomeBackdrop, other.welcomeBackdrop, t)!,
      welcomeAmbient: Color.lerp(welcomeAmbient, other.welcomeAmbient, t)!,
      welcomeBandLower:
          Color.lerp(welcomeBandLower, other.welcomeBandLower, t)!,
      welcomeBandUpper:
          Color.lerp(welcomeBandUpper, other.welcomeBandUpper, t)!,
      frameShadow: Color.lerp(frameShadow, other.frameShadow, t)!,
      radiusSharp: lerpDouble(radiusSharp, other.radiusSharp, t)!,
      gutter: lerpDouble(gutter, other.gutter, t)!,
    );
  }
}

/// Đọc token trong widget: `final t = context.tokens;`
///
/// `Theme.of(context).extension<MuseumTokens>()!` ở mọi call site vừa dài vừa
/// dễ quên dấu `!`. Nếu extension chưa đăng ký trong ThemeData, cả hai dạng đều
/// ném — và đó là điều ta muốn: một màn hình không có token là lỗi cấu hình,
/// không phải trạng thái cần xử lý duyên dáng.
extension MuseumTokensX on BuildContext {
  MuseumTokens get tokens => Theme.of(this).extension<MuseumTokens>()!;
}