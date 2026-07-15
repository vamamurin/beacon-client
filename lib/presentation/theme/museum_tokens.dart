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
    required this.surfaceRaised,
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
    required this.accentInk,
    required this.sectionBand,

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

  /// Nền của KHỐI NÂNG đặt trên [surface]: hàng hiện vật ở màn 3, và mọi card
  /// tonal về sau. Nâng "tông", không nâng "sáng": ở preset giấy nó TRẦM hơn
  /// surface (yêu cầu sản phẩm: theme sáng không được sáng bừng cả màn), ở
  /// preset tối nó nhạt hơn surface một bậc — cả hai đều là "rời khỏi mặt
  /// nền", chỉ khác chiều.
  ///
  /// Cặp đôi với badge số ở màn 3: badge tô [surface] nên trên nền này nó đọc
  /// là đĩa LÕM. Đổi giá trị ở đây mà quên soát badge thì badge sẽ biến mất —
  /// hai màu này định nghĩa lẫn nhau.
  ///
  /// highContrast KHÔNG được để bằng surface: từ khi bỏ hairline giữa các
  /// hàng, đây là thứ DUY NHẤT phân tách hàng — preset đó cần nó rõ nhất.
  final Color surfaceRaised;

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

  /// Chữ / glyph đặt TRÊN nền [accent] (badge số đang phát, chip accent sau
  /// này). PHẢI tối: accent đồng #C99A5B với chữ trắng chỉ đạt ~2.5:1 —
  /// rớt chuẩn tương phản. Nâu gần đen ấm để không lạnh so với nền đồng.
  final Color accentInk;

  /// Dải màu ngăn khối — đường nối hero ↔ danh sách ở màn 3, và mọi seam kiểu
  /// đó về sau. Khối màu đặc, KHÔNG hoa văn: ngôn ngữ của app là hình học tối
  /// giản (radius 2, không trang trí thừa), một dải đặc là đủ và đúng.
  ///
  /// CÙNG HỌ với [welcomeBandLower]/[welcomeBandUpper] của Gate — đây là cùng
  /// một thủ pháp color-block, chỉ khác màn. Đổi tông band ở Gate thì soát cả
  /// token này, nếu không hai màn sẽ trôi khỏi nhau.
  ///
  /// highContrast trong suốt: preset đó phẳng tuyệt đối, và dải chỉ là seam
  /// trang trí — mất nó không mất thông tin nào (cùng lý lẽ với [frameShadow]
  /// và band ở Gate).
  final Color sectionBand;

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

  /// Lớp phủ trên ảnh-nền-mờ của Gate — tông TƯỜNG TRANH phía sau hai khung.
  ///
  /// ĐƯỢC PHÉP TỐI HƠN BACKDROP, KỂ CẢ Ở THEME SÁNG (quyết định sản phẩm):
  /// hai khung ảnh cần nền tối hơn chúng để nổi; ambient sáng trên theme sáng
  /// làm khung chìm vào tường. Theme sáng vì thế KHÔNG "sáng bừng cả màn" —
  /// giấy ở rìa, tường tranh trầm ở giữa, band taupe làm lớp đệm.
  ///
  /// AN TOÀN CHỮ KHÔNG DO TOKEN NÀY ĐẢM NHẬN: vùng chữ của Gate được
  /// [welcomeBandLower]/[welcomeBandUpper] (đục) + scrim đáy màu backdrop che.
  /// Nếu chỉnh alpha/độ tối ở đây, thứ phải soát lại là band và scrim, không
  /// phải màu chữ. highContrast đặt ĐẶC 100% màu nền: ambient tự tắt thành
  /// nền phẳng, không cần nhánh điều kiện nào trong widget.
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
    surface: Color(0xFF151312),
    ink: Color(0xFFFFFFFF),
    inkMuted: Color(0xFFD4CCC2),
    inkFaint: Color(0xFFA39A8E),
    line: Color(0xFF262220),
    surfaceRaised: Color(0xFF201D1A),
    ctaFill: Color(0xFFFFFFFF),
    ctaLabel: Color(0xFF151312),
    ctaDisabled: Color(0xFF6B655D),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFD6CFC5),
    artistOnImage: Color(0xFFCEC7BD),
    scrimBack: Color(0x66000000),
    lineOnImage: Color(0x59FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeil,
    playerVeil: _playerVeil,
    heroVeil: _heroVeil,

    accent: Color(0xFFC99A5B),
    accentInk: Color(0xFF201509),
    sectionBand: Color(0xFF42231B), // cùng tông band Gate

    welcomeBackdrop: Color(0xFF181A1F),
    welcomeAmbient: Color(0xB3181A1F), // ~70% — tường tranh tối, ảnh nổi
    welcomeBandLower: Color(0xFF42231B), // nâu đất — cùng giá trị bandUpper (chủ đích)
    welcomeBandUpper: Color(0xFF42231B),
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
    surface: Color(0xFFF6F3EE),
    ink: Color(0xFF171412),
    inkMuted: Color(0xFF5D554C),
    inkFaint: Color(0xFF7D7469),
    line: Color(0xFFE5DFD6),
    surfaceRaised: Color(0xFFEBE5DB), // TRẦM hơn giấy, không trắng hơn
    ctaFill: Color(0xFF171412),
    ctaLabel: Color(0xFFF6F3EE),
    ctaDisabled: Color(0xFFC4BDB3),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFD6CFC5),
    artistOnImage: Color(0xFFCEC7BD),
    scrimBack: Color(0x66000000),
    lineOnImage: Color(0x59FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeil,
    playerVeil: _playerVeil,
    heroVeil: _heroVeil,

    accent: Color(0xFFC99A5B),
    accentInk: Color(0xFF201509),
    sectionBand: Color(0xFFD9D0C3), // cùng tông band Gate (taupe)

    // Giấy ấm — cùng độ chói với surface #F7F7F5 nhưng ngả đất,
    // để hai khung ảnh nổi như tranh treo tường sáng.
    welcomeBackdrop: Color(0xFFF0EBE3),
    // TỐI trên theme sáng — CHỦ ĐÍCH, xem doc của field: đây là tường tranh,
    // ảnh cần nền tối hơn chúng để nổi. Vùng chữ được band + scrim che.
    welcomeAmbient: Color(0xB3262019),
    welcomeBandLower: Color(0xFFD9D0C3), // taupe ấm — giữa giấy và tường tối
    welcomeBandUpper: Color(0xFFD9D0C3),
    frameShadow: Color(0x4D000000), // ~30% — tường sáng, bóng nhạt hơn dark

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
    surfaceRaised: Color(0xFF1C1C1C), // phân tách hàng — xem doc của field
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
    accentInk: Color(0xFF000000), // tương phản trước, sắc thái sau
    sectionBand: Color(0x00000000), // phẳng tuyệt đối

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
    Color? surfaceRaised,
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
    Color? accentInk,
    Color? sectionBand,
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
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
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
      accentInk: accentInk ?? this.accentInk,
      sectionBand: sectionBand ?? this.sectionBand,
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
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
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
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      sectionBand: Color.lerp(sectionBand, other.sectionBand, t)!,
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