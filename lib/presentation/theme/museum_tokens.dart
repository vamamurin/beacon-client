// Destination: lib/presentation/theme/museum_tokens.dart
//
// Design tokens, instance-based. Thay cho `static const` trong AppColors, vốn
// không thể mang hai giá trị cùng lúc.
//
//
// ⚠ MỌI CON SỐ TRONG FILE NÀY ĐƯỢC ĐO TRONG MỘT NGỮ CẢNH CỤ THỂ.
// Đổi ngữ cảnh (cỡ hero, font, tỷ lệ khung) là VÔ HIỆU HOÁ con số, không
// phải chỉ làm nó lệch đi một chút. Đã dính ba lần: hero 250px→80% (veil
// đen đặc), Playfair→Cormorant (height + stopName), 0.56→0.66 (decodeWidth).
// Nếu bạn đang đổi một hằng số hình học: grep xem con số nào được đo QUANH nó.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI HỌ TOKEN — đọc kỹ trước khi thêm field mới
// ═══════════════════════════════════════════════════════════════════════════
//
//   ┌─ SURFACE FAMILY ─ đổi theo theme
//   │  surface, surfaceRaised, badgeWell, ink, inkMuted, inkFaint, line,
//   │  outline, accent, accentInk, error, errorInk, ctaFill, ctaLabel,
//   │  ctaDisabled
//   │  → chữ và nền đặt trên NỀN CỦA ỨNG DỤNG
//   │
//   └─ ON-IMAGE FAMILY ─ không đổi giữa dark và light
//      inkOnImage, mutedOnImage, artistOnImage, accentOnImage, scrimBack,
//      lineOnImage, ctaOnImageFill, ctaOnImageInk, imageFallback, *Veil
//      → chữ và lớp phủ đặt trên ẢNH HIỆN VẬT
//
// `accent` VỪA ĐƯỢC TÁCH LÀM HAI THEO ĐÚNG ĐƯỜNG NÀY. Nó từng là MỘT field cho
// cả hai họ, với lý do ghi trong doc: "đủ tương phản trên cả surface tối lẫn
// ảnh có veil". Câu đó chỉ đúng khi chưa có preset giấy — và nó là ví dụ mẫu
// cho cả khối doc này: mỗi lần một token trốn khỏi hai họ, nó sống sót đúng
// tới preset tiếp theo.
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

const LinearGradient _imageFallback = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2A2A2A), Color(0xFF0C0C0C)],
);

const LinearGradient _imageFallbackFlat = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF000000), Color(0xFF000000)],
);

@immutable
class MuseumTokens extends ThemeExtension<MuseumTokens> {
  const MuseumTokens({
    // ── surface family: đổi theo theme ──
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.outline,
    required this.surfaceRaised,
    required this.badgeWell,
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
    required this.imageFallback,
    required this.heroVeil,

    // ── điểm nhấn ──
    required this.accent,
    required this.accentOnImage,
    required this.accentInk,
    required this.error,
    required this.errorInk,
    required this.heroDissolveEnabled,

    // ── nền màn chào ──
    required this.welcomeBackdrop,
    required this.welcomeAmbient,
    required this.welcomeBandLower,
    required this.welcomeBandUpper,
    required this.shadowInk,

    // ── hình học ──
    required this.radiusSharp,
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

  /// Vạch TRANG TRÍ: đường kẻ hairline ngăn hàng, divider giữa các mục.
  ///
  /// ⚠ KHÔNG PHẢI VIỀN CỦA CONTROL. Ranh giới đó là [outline]. Phân biệt này
  /// không phải câu chữ — nó là hai ngưỡng khác nhau: vạch trang trí không có
  /// ngưỡng nào (mất nó không mất thông tin), viền control cần ≥3:1 (WCAG
  /// 1.4.11, vì nó là thứ nói cho người dùng biết control bắt đầu ở đâu).
  ///
  /// Trộn hai vai trò vào một field là cách nó đã sai: giá trị này được chỉnh
  /// cho vai trò hairline (1.17:1 ở dark — cố ý mờ, đúng cho vạch), rồi bị đem
  /// đi làm viền ô nhập URL ở Cài đặt và viền banner ở màn 2. Ở đó 1.17:1
  /// nghĩa là KHÔNG CÓ VIỀN.
  ///
  /// Ánh xạ Material: field này là `ColorScheme.outlineVariant` (vạch trang
  /// trí), KHÔNG phải `ColorScheme.outline`. Đó đúng là cách M3 chia hai vai
  /// trò, và app đã nối ngược trong suốt thời gian qua.
  final Color line;

  /// Viền / rail của CONTROL: khung thẻ nhân viên, viền nút viền, ô nhập, viền
  /// banner, track của thanh progress.
  ///
  /// SÀN CỨNG: ≥3:1 với MỌI nền mà nó có thể nằm lên — [surface],
  /// [surfaceRaised] và [welcomeBackdrop]. Đây là ngưỡng WCAG 1.4.11 cho thành
  /// phần giao diện, và nó là lý do field này tồn tại tách khỏi [line].
  ///
  /// VÌ SAO KHÔNG PHẢI `ink.withValues(alpha: ...)`: đó chính là thứ nó thay
  /// thế. Trước field này, mỗi call site tự bịa một alpha — 0.35 ở _StaffCard,
  /// 0.35 ở _StaffButton, 0.25 ở _ProgressLine, và `Colors.black @0.55` ở màn
  /// 2. Bốn con số, không con số nào được đo, và 0.35 cho ra 2.18:1 trên giấy.
  /// Một lớp phủ alpha lên một nền KHÔNG BIẾT TRƯỚC thì không thể có ngưỡng —
  /// nó chỉ có một con số trông hợp lý trên cái máy đang cầm.
  ///
  /// Cặp đôi với [line], không thay thế: vạch ngăn hàng vẫn phải mờ. Nếu bạn
  /// định dùng field này cho một divider, câu hỏi đúng là "cái này là control
  /// hay là trang trí".
  final Color outline;

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
  ///
  /// ⚠ CÒN NỢ: chênh lệch giữa field này và [surface] hiện là ΔL* ≈ 4.7 ở CẢ
  /// dark lẫn light (10.3 ở highContrast). 4.7 là mức mắt bắt được trên một
  /// MẢNG LỚN nhưng không bắt được trên vật nhỏ — nên "kệ" đọc ra được, còn
  /// một đĩa 36dp thì không. Đó là lý do [badgeWell] phải là field riêng thay
  /// vì mượn [surface] — DẤU của nó phải đúng ở cả ba preset, việc mà `surface`
  /// không làm được. Nếu sau này thấy hàng "trôi" trên nền, đây là chỗ để nắn;
  /// đó là quyết định bằng MẮT, không phải bằng ngưỡng WCAG — tỉ lệ tương phản
  /// là thước cho CHỮ, không phải cho hai mảng nền cạnh nhau.
  final Color surfaceRaised;

  /// Nền đĩa số hiện vật khi KHÔNG phát — một hố khoét NÔNG xuống
  /// [surfaceRaised].
  ///
  /// VÌ SAO KHÔNG DÙNG [surface] (bản trước dùng): ẩn dụ "đĩa lõm" đòi badge
  /// phải TỐI HƠN kệ. `surface` chỉ tình cờ thoả điều đó ở preset tối, và
  /// preset giấy làm nó ĐẢO DẤU:
  ///     dark   surface #151312 < surfaceRaised #201D1A → ΔL* −4.7 → hố ✓
  ///     light  surface #F6F3EE > surfaceRaised #EBE5DB → ΔL* +4.7 → ĐĨA NỔI ✗
  /// Sai lầm gốc không phải chọn nhầm màu, mà là để badge và nền app DÙNG
  /// CHUNG một field. Chúng không có cùng công việc; chúng chỉ tình cờ cùng
  /// màu ở preset đầu tiên.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// NÔNG — VÀ ĐÂY LÀ MỘT LẦN SỬA QUÁ TAY ĐÃ ĐƯỢC SỬA LẠI
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Bug ở light CHƯA BAO GIỜ là "hố nông quá". Nó là SAI DẤU. Lời sửa đúng
  /// là đảo dấu và giữ nguyên độ sâu. Bản trước vừa đảo dấu vừa đào sâu —
  /// ΔL* 4.7 → 8.7/11.4 — kèm một mục tiêu "ΔL* ≥ 8" tự đặt ra trong chính
  /// doc này mà không ai yêu cầu.
  ///
  /// Kết quả trên máy thật: badge HÚT MẮT. Nó không sai về ẩn dụ — nó vẫn đọc
  /// đúng là một cái hố — nó sai về ÂM LƯỢNG. Mắt đi theo tương phản cục bộ,
  /// và một đĩa 36dp sâu ΔL* 11 cạnh một hàng chữ là điểm tương phản mạnh
  /// nhất trong hàng. Đào hố sâu để ẩn dụ "rõ hơn" là tối ưu nhầm đại lượng:
  /// thứ cần rõ là TÊN HIỆN VẬT, và badge chỉ cần không cãi lại nó.
  ///
  /// MỤC TIÊU HIỆN TẠI: ΔL* ≈ 5 DƯỚI [surfaceRaised] ở mọi preset — cùng độ
  /// sâu mà preset tối vẫn luôn có và chưa ai từng phàn nàn; light giờ có
  /// đúng độ sâu đó, chỉ khác là đúng dấu.
  ///
  /// ĐÂY LÀ NÚM VẶN ÂM LƯỢNG CỦA BADGE. Nếu vẫn thấy nó cãi tên hiện vật, hạ
  /// ΔL* xuống ~3 (badge gần như phẳng, chỉ còn là một chỗ đổi tông). Nếu thấy
  /// đĩa biến mất, lên ~7. ĐỪNG bù bằng cách chỉnh màu con số: số dùng
  /// [inkFaint] và nó đã ở đúng bậc thấp nhất của thang ink.
  final Color badgeWell;


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

  /// Lớp phủ tối dưới nút back — đĩa tròn 48dp sau chevron.
  ///
  /// 0x66 (40%) Ở dark/light LÀ QUYẾT ĐỊNH THẨM MỸ ĐÃ CHỐT, nhìn trên máy thật.
  /// Đừng nâng nó lên vì một con số. Đã có người thử (0x66 → 0xCC) và bị bác:
  /// trên hero — trạng thái khách nhìn 95% thời gian — 80% biến scrim thành
  /// một ĐĨA ĐEN ĐẶC. Nó không còn là lớp phủ, nó là một cái nút dán lên ảnh.
  ///
  /// ⚠ CÁI GIÁ, ĐÃ BIẾT VÀ ĐÃ CHẤP NHẬN: khi hero thu hết, ramp hoà tan biến
  /// toolbar thành `surface`, và ở preset giấy đĩa thành #94928F. Chevron
  /// `inkOnImage` TRẮNG trên đó = 3.10:1 — lách qua sàn 3:1 của WCAG 1.4.11
  /// với biên 3%, và đọc ra là một vệt xám bạc màu.
  ///
  /// ĐÓ KHÔNG PHẢI LỖI CỦA FIELD NÀY. Hai trạng thái muốn hai thứ khác nhau —
  /// 40% ĐÚNG trên ảnh (đã có veil), và không đủ trên giấy. Một giá trị không
  /// phục vụ nổi cả hai; đó chính xác là lý do họ `ink`/`inkOnImage` tồn tại.
  /// Nâng alpha là hy sinh trạng thái nhìn nhiều để cứu trạng thái nhìn ít —
  /// một cách đổi chỗ vấn đề, không phải giải nó.
  ///
  /// LỜI GIẢI THẬT nằm ở CHEVRON, không ở scrim — ĐÃ TRIỂN KHAI, xem
  /// `_BackGlyph` + `_ZoneHeroBar.open()`: nó đổi họ theo độ mở của hero —
  /// `inkOnImage` khi đứng trên ảnh, `ink` khi đứng trên surface thật. Scrim
  /// giữ nguyên 40%; trạng thái thu cho 5.91:1 (đo thật, không phải ước tính)
  /// — chevron sẫm trên đĩa xám #94928F ở preset giấy.
  ///
  /// Ngưỡng chuyển là `open() < 0.15`, không phải nội suy liên tục: nội suy
  /// từng bị bác vì có một dải giữa chừng nơi glyph xám-trung-tính chìm vào cả
  /// hai nền — cùng "vùng chết của hoà tan" đã chứng minh bằng số ở doc
  /// `_heroTextBottom`. Ngưỡng cứng đặt ĐÚNG chỗ ramp hoà tan chạm đáy, né hẳn
  /// dải chết đó: hai bên ngưỡng đều có nền thuần.
  ///
  /// `open` được đọc từ `ScrollController` dùng chung giữa `leading` và
  /// `flexibleSpace` — trước bản sửa này hai vùng tính `open` ở hai nơi tách
  /// biệt và `leading` không có đường nào tới nó, nên chevron luôn cứng
  /// `inkOnImage` bất kể hero mở hay thu.
  ///
  /// highContrast dùng 0xCC: preset đó đổi sắc thái lấy tương phản theo luật,
  /// và nó KHÔNG phá bất biến "họ on-image đóng băng" — bất biến đó là
  /// dark == light, HC được miễn trừ có chủ đích (xem doc đầu file).
  final Color scrimBack;

  /// Viền / rail của control đặt TRÊN ẢNH. Bán trong suốt, vì thứ nằm dưới nó
  /// là ảnh chứ không phải `surface`.
  ///
  /// ⚠ DOC CŨ CỦA FIELD NÀY NÓI DỐI, giữ lại lời đính chính để không tái diễn:
  /// nó ghi "Viền khung staff ở Gate, rail của thanh progress" — cả HAI đều
  /// không còn đúng. Gate rời họ on-image khi chuyển sang collage, và hai chỗ
  /// đó im lặng chuyển sang `ink.withValues(alpha: .35/.25)` tự chế; không ai
  /// quay lại xoá doc. Cùng lô rác với `heroDissolve` và tham số `sectionBand`.
  ///
  /// Call site thật hiện nay: `exhibit_detail_screen` (màn 4). Nếu màn 4 cũng
  /// rời khỏi ảnh sau redesign thì field này chết — kiểm trước khi giữ.
  final Color lineOnImage;

  /// Nền nút tròn / CTA đặt TRÊN ẢNH: play, num badge, nút "Bắt đầu tham quan".
  final Color ctaOnImageFill;

  /// Icon và chữ đặt trên [ctaOnImageFill].
  final Color ctaOnImageInk;

  /// Veil thẻ zone ở màn 2.
  final LinearGradient tourCardVeil;

  /// Veil màn player: tối đỉnh + tối đáy, trong ở giữa.
  final LinearGradient playerVeil;

  /// Gradient vẽ thay cho ẢNH khi ảnh chưa có hoặc hỏng — nền của [HeroImage].
  ///
  /// ⚠ THUỘC HỌ ON-IMAGE, VÀ VÌ THẾ KHÔNG ĐỔI THEO THEME. Điều đó nghe như một
  /// thiếu sót; nó là cả điểm.
  ///
  /// Bốn trên năm call site của [HeroImage] có CHỮ TRẮNG nằm trên (kicker +
  /// tiêu đề hero màn 3, thẻ khu màn 2, màn 4) — chữ họ on-image, đóng băng
  /// theo doc đầu file. Nếu fallback đi theo theme thì ở preset giấy nó sáng
  /// lên, và chữ trắng BIẾN MẤT ĐÚNG LÚC ẢNH HỎNG — tức đúng lúc màn hình cần
  /// giải thích rằng có gì đó sai. Đây là cùng cái bẫy mà `inkOnImage` được
  /// dựng ra để tránh, chỉ nằm ở nhánh lỗi nên không ai gặp cho tới lúc demo.
  ///
  /// Nó là token, không phải hằng số trong [HeroImage], vì "mù theme" phải là
  /// một QUYẾT ĐỊNH ghi ở nơi các quyết định màu sống — không phải một
  /// `static const` mà không ai soát.
  ///
  /// ĐÁNH ĐỔI ĐÃ BIẾT: Gate là call site DUY NHẤT không có chữ trên ảnh, nên ở
  /// preset giấy một ảnh thiếu sẽ là chữ nhật tối trên giấy. Chấp nhận: nó chỉ
  /// hiện trước lần sync đầu, và một ô tối đọc là "ảnh chưa tải" — trung thực
  /// hơn một ô sáng đọc là "không có gì". Nếu sau này thấy chói, đường đúng là
  /// TÁCH token theo họ, KHÔNG phải làm nó sáng lên.
  ///
  /// highContrast: phẳng — hai stop cùng màu, không gradient. Chiều sâu giả
  /// không có việc gì ở preset đó, và chữ trắng trên đen là 21:1.
  final LinearGradient imageFallback;

  /// Veil ảnh hero 250px của danh sách hiện vật.
  final LinearGradient heroVeil;

  // ── điểm nhấn ─────────────────────────────────────────────────────────────

  /// Màu nhấn của ứng dụng trên NỀN CỦA APP — tông đồng/đất, hợp không gian
  /// bảo tàng. Dùng tiết chế: vạch nhấn ở Gate, vạch trạng thái rỗng, chữ
  /// "Đang phát", nền badge đang phát. KHÔNG dùng làm nền chữ dài.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// ĐÃ TÁCH LÀM HAI HỌ (trước đây là MỘT field cho cả hai)
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Doc cũ viết: "Đủ tương phản trên cả `surface` tối lẫn ảnh có veil, nên
  /// khai báo một lần cho cả hai họ." Câu đó TỰ THÚ: phép đo chỉ chạy trên
  /// nền TỐI và trên ẢNH. Preset giấy chưa bao giờ có trong phương trình, và
  /// khi nó ra đời thì con số cũ đã chết mà không ai soát:
  ///
  ///     #C99A5B trên surfaceRaised #EBE5DB = 2.01:1   (chữ cần 4.5, nền cần 3)
  ///     #C99A5B trên surface       #F6F3EE = 2.27:1
  ///     #C99A5B trên welcomeBackdrop #F0EBE3 = 2.12:1
  ///
  /// Hậu quả: "Đang phát thuyết minh" — tín hiệu quan trọng nhất của màn 3 —
  /// gần như vô hình ở theme sáng; và vạch accent, thứ được gọi là "điểm nhấn
  /// DUY NHẤT của màn hình", bùng lên 7.3:1 ở dark rồi thì thầm ở 2.1:1 trên
  /// giấy. Cùng một token, hai ý đồ khác nhau — tức là không có ý đồ nào.
  ///
  /// Đây KHÔNG phải một trục phân loại mới. Nó là ĐÚNG đường cắt mà file này
  /// đã dùng cho `ink`/`inkOnImage` và `inkMuted`/`mutedOnImage` ngay từ đầu:
  /// ảnh hiện vật không sáng lên khi bật theme sáng, nên thứ nằm trên ảnh
  /// không được đổi theo theme. `accent` đã trốn khỏi luật đó bằng một câu
  /// comment, và preset giấy đã tính sổ.
  ///
  /// light dùng #7E5620: hue 34.5° — accent #C99A5B là hue 34.4°. KHÔNG phải
  /// màu mới, là NẤC mới. Cùng một màu đồng, khác độ sáng.
  ///
  /// ⚠ KHOÁ VỚI [accentInk]: đổi field này là đổi nền mà [accentInk] đứng lên.
  /// light đã phải lật accentInk từ nâu-gần-đen sang màu giấy vì lý do đó.
  final Color accent;

  /// Màu nhấn đặt TRÊN ẢNH hiện vật (kicker "KHU TRƯNG BÀY" và vạch 88×2 của
  /// hero màn 3). KHÔNG đổi giữa dark và light — xem doc của [accent].
  ///
  /// Vì sao không gộp với [accent]: ảnh dưới veil ~70% là nền TỐI ở MỌI theme.
  /// Nếu nó đi theo [accent], light sẽ đặt #7E5620 (nâu sẫm) lên một tấm ảnh
  /// tối và kicker biến mất. Đây đúng là cái bẫy mà doc đầu file mô tả cho
  /// `inkOnImage`, chỉ khác là nó chờ ở màu nhấn.
  final Color accentOnImage;

  /// Chữ / glyph đặt TRÊN nền [accent] (glyph sóng âm của badge đang phát,
  /// chip accent sau này).
  ///
  /// ⚠ KHÔNG CÒN "LUÔN TỐI". Doc cũ ra luật "PHẢI tối: accent đồng #C99A5B với
  /// chữ trắng chỉ đạt ~2.5:1". Luật đó đúng khi [accent] là #C99A5B ở mọi
  /// preset — nó chết cùng lúc accent tách làm hai họ và light hạ accent xuống
  /// #7E5620. Trên nền sẫm đó, nâu-gần-đen #201509 chỉ còn 2.76:1; light vì
  /// vậy lật sang màu giấy và đạt 5.86:1.
  ///
  /// LUẬT ĐÚNG chỉ có một, và nó không nói gì về sắc độ: field này PHẢI tương
  /// phản ≥4.5:1 với [accent] CỦA CHÍNH PRESET ĐÓ. Mỗi preset tự tính, vì mỗi
  /// preset có một accent khác nhau. Đó là toàn bộ lý do nó là token.
  final Color accentInk;

  /// Màu của LỖI — chữ lỗi, viền ô nhập không hợp lệ, `ColorScheme.error`.
  ///
  /// VÌ SAO NÓ MỚI RA ĐỜI CÙNG BẢN SỬA `ColorScheme`: trước đây token này không
  /// tồn tại, nhưng `ColorScheme.error` thì CÓ — nó do `fromSeed` sinh ra. Tức
  /// app vẫn luôn có một màu lỗi, chỉ là KHÔNG AI CHỌN NÓ. Nó chỉ chưa lộ vì
  /// chưa widget nào đọc tới; `TextField` ở Cài đặt sẽ đọc ngay khi có
  /// validation, và màn 4 chắc chắn đọc. Một màu chưa ai chọn không phải là
  /// "chưa có màu" — nó là một quyết định thiết kế đã được giao cho thư viện.
  ///
  /// HUE ~10° Ở CẢ BA PRESET — đỏ ĐẤT NUNG, không phải #B3261E đỏ tươi của
  /// Material. Cùng gia đình ấm với [accent] (~34°, đồng). Một sắc đỏ tươi
  /// giữa bảng màu này kêu như còi báo cháy trong phòng trưng bày.
  ///
  /// Đạt ≥4.5:1 trên CẢ [surface] lẫn [surfaceRaised] ở mọi preset — nó là
  /// CHỮ, và chữ lỗi là chữ khách buộc phải đọc được.
  ///
  /// ⚠ ĐỪNG dùng nó cho `_StaffCard`. Thẻ nhân viên hiện khi thiếu quyền BLE
  /// hoặc cần đồng bộ — đó là TRẠNG THÁI, không phải lỗi, và nó cố ý dùng
  /// [ink]/[inkMuted] để không doạ khách bằng màu đỏ vì một việc bình thường.
  /// Field này dành cho lỗi thật: nhập sai, thao tác hỏng.
  final Color error;

  /// Chữ / glyph đặt TRÊN nền [error] (`ColorScheme.onError`). Cùng luật với
  /// [accentInk]: ≥4.5:1 với [error] CỦA CHÍNH PRESET ĐÓ, mỗi preset tự tính.
  final Color errorInk;

  /// Ramp hoà tan ở đáy hero (màn 3) có BẬT hay không.
  ///
  /// ĐÂY TỪNG LÀ MỘT `Color`, VÀ ĐÓ LÀ LỖI HÌNH DẠNG (1.8). Field cũ
  /// `heroDissolve` mang đúng hai thông tin:
  ///     • "màu = surface"      → một BẤT BIẾN, không phải lựa chọn
  ///     • "có bật không"       → một bool
  /// Nó buộc ba preset chép lại `surface` của chính mình, rồi để lộ ra một
  /// bậc tự do KHÔNG AI ĐƯỢC PHÉP DÙNG: lệch một bậc là hiện ra đúng cái đường
  /// kẻ mà 144px hoà tan được bỏ ra để xoá. Một field tự do mang một ràng buộc
  /// không ai canh là một biến đang chờ trôi — nó đã trôi một lần rồi, khi
  /// preset giấy ghi comment "(taupe)" trên một giá trị bằng `surface`.
  ///
  /// Giờ màu lấy thẳng từ [surface] tại call site, và bất biến biến mất cùng
  /// khả năng vi phạm nó. Còn lại đúng một bit.
  ///
  /// ⚠ VÌ SAO KHÔNG DÙNG IDIOM "TRONG SUỐT = TẮT" như [shadowInk] và
  /// [welcomeBandLower]: hai field kia là MÀU THẬT — "bóng đậm bao nhiêu" là
  /// một câu hỏi có nhiều đáp án, và alpha 0 chỉ là một trong số đó. Field này
  /// không có câu hỏi nào: màu đã bị khoá vào `surface`. Một bool đội lốt
  /// Color thì nên là một bool.
  ///
  /// false ở highContrast: hoà tan là PHẢN ĐỀ của tương phản cao — ảnh gặp danh
  /// sách bằng cạnh cứng, và đó là điều preset đó cần.
  final bool heroDissolveEnabled;

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
  /// preset đó phẳng tuyệt đối (cùng triết lý với [shadowInk]).
  final Color welcomeBandLower;

  /// Xem [welcomeBandLower]. Dải trên nhạt hơn dải dưới ở mọi preset — đỉnh
  /// màn chỉ có một dòng kicker, không cần khối nặng.
  final Color welcomeBandUpper;

  /// Màu BÓNG ĐỔ của app. Dùng ở: khung ảnh trên tường chào (Gate), độ nổi của
  /// badge đang phát (màn 3).
  ///
  /// ĐỔI TÊN TỪ `shadowInk` (1.7). Tên cũ thuần Gate — "bóng đổ của KHUNG ảnh
  /// trên tường chào" — nhưng nó đã được `_StopRow` ở màn 3 dùng từ lâu, và màn
  /// 2/4 sẽ dùng tiếp. Một token mang tên của call site đầu tiên là một token
  /// sẽ nói dối kể từ call site thứ hai.
  ///
  /// KHÔNG PHẢI `ink.withValues(alpha: ...)`: ở preset tối `ink` là TRẮNG, nên
  /// "mực mờ" cho ra một QUẦNG SÁNG, không phải bóng. Bóng luôn là đen ám —
  /// nó là thiếu ánh sáng, không phải ít mực.
  ///
  /// highContrast trong suốt: preset đó phẳng tuyệt đối, và bóng chỉ là chiều
  /// sâu giả — mất nó không mất thông tin nào. (Cùng luật với [welcomeBandLower]
  /// và ramp hoà tan của hero.)
  final Color shadowInk;

  // ── hình học ──────────────────────────────────────────────────────────────

  /// 2px — chữ ký thị giác của thiết kế: gần vuông. MỘT giá trị, không phải một
  /// thang đo. Đừng thêm radiusLarge cho tới khi thiết kế thật sự cần.
  final double radiusSharp;

  // ── `gutter` ĐÃ BỊ XOÁ KHỎI ĐÂY — đừng thêm lại ─────────────────────────
  //
  // Nguồn duy nhất giờ là AppSpace.gutter (20). Lý do xoá, để không ai hồi sinh
  // nó vì "cho nhất quán với các token khác":
  //
  //   1. Khoảng cách là HÌNH HỌC, không phải sắc độ. Đổi theme không được làm
  //      bố cục nhảy — nên nó không có việc gì ở trong một ThemeExtension.
  //   2. `t.gutter` không phải const ⇒ `EdgeInsets.fromLTRB(t.gutter, ...)`
  //      giết `const` ở mọi call site.
  //   3. Nó đã sai LẶNG LẼ, đúng như TODO của chính nó tiên tri. Cả ba preset
  //      mang 18 trong khi AppSpace.gutter = 20, và `settings_screen.dart`
  //      là call site duy nhất còn đọc nó ⇒ màn Cài đặt đang lệch 2dp so với
  //      màn 1 và màn 3, NGAY LÚC NÀY. Một token chỉ có một người đọc thì
  //      không ai kiểm nó, và "không ai kiểm" là cách nó sai.
  //
  // Đây là lời cảnh báo cũ của chính file này, đã ứng nghiệm rồi mới được gỡ.

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
    line: Color(0xFF262220), // 1.17:1 — CỐ Ý mờ: vạch trang trí, xem doc
    outline: Color(0xFF736C63), // 3.55/3.22/3.36:1 trên surface/Raised/backdrop
    surfaceRaised: Color(0xFF201D1A),
    badgeWell: Color(0xFF141211), // ΔL* 5.2 dưới surfaceRaised — xem doc
    ctaFill: Color(0xFFFFFFFF),
    ctaLabel: Color(0xFF151312),
    ctaDisabled: Color(0xFF6B655D),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFD6CFC5),
    artistOnImage: Color(0xFFCEC7BD),
    scrimBack: Color(0x66000000), // 40% — chủ đích, xem doc
    lineOnImage: Color(0x59FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeil,
    playerVeil: _playerVeil,
    imageFallback: _imageFallback,
    heroVeil: _heroVeil,

    // 6.63:1 trên surfaceRaised #201D1A, 7.30:1 trên surface — accent tự đủ ở
    // preset tối, nên hai họ tình cờ trùng giá trị. TÌNH CỜ, không phải luật:
    // đó chính là ngộ nhận đã sinh ra bản một-field.
    accent: Color(0xFFC99A5B),
    accentOnImage: Color(0xFFC99A5B),
    accentInk: Color(0xFF201509), // 7.11:1 trên accent ✓
    // Đỏ ĐẤT NUNG hue ~10° — cùng gia đình ấm với accent. 5.66:1 trên surface, 5.13 trên kệ · glyph 5.49:1
    error: Color(0xFFD9705C),
    errorInk: Color(0xFF2A0F09),
    heroDissolveEnabled: true,

    welcomeBackdrop: Color(0xFF181A1F),
    welcomeAmbient: Color(0xB3181A1F), // ~70% — tường tranh tối, ảnh nổi
    welcomeBandLower: Color(0xFF42231B), // nâu đất — cùng giá trị bandUpper (chủ đích)
    welcomeBandUpper: Color(0xFF42231B),
    shadowInk: Color(0x80000000),

    radiusSharp: 2,
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
    inkMuted: Color(0xFF5D554C), // 6.61:1 trên surface ✓
    // #7D7469 cũ = 4.15:1 trên surface — DƯỚI chuẩn AA (4.5) cho chữ 12px, và
    // đó là cỡ của mọi style dùng nó. #6E655A: 5.17:1 trên surface, 4.56:1
    // trên surfaceRaised (ràng buộc chặt hơn).
    //
    // LƯU Ý VỀ THANG: ở preset giấy, "mờ nhất" và "đạt AA" gần như chạm nhau —
    // inkFaint #6E655A giờ chỉ còn cách inkMuted #5D554C một bậc hẹp. Preset
    // tối có headroom (6.70 / 15.1), preset giấy thì không. Nếu sau này thang
    // ba bậc đọc ra hai bậc ở light, đó KHÔNG phải lỗi chọn màu — đó là giấy
    // có ít khoảng chói hơn, và câu trả lời là bớt một bậc, không phải hạ AA.
    inkFaint: Color(0xFF6E655A),
    line: Color(0xFFE5DFD6), // 1.20:1 — CỐ Ý mờ: vạch trang trí, xem doc
    outline: Color(0xFF837E75), // 3.64/3.22/3.39:1 trên surface/Raised/backdrop
    surfaceRaised: Color(0xFFEBE5DB), // TRẦM hơn giấy, không trắng hơn
    // ĐẢO DẤU, KHÔNG ĐÀO SÂU: badge từng tô `surface` #F6F3EE — SÁNG hơn kệ
    // ΔL* 4.7 ⇒ đọc là đĩa NỔI. Giờ TRẦM hơn kệ ΔL* 4.6 — đúng dấu, đúng bằng
    // độ sâu mà preset tối vẫn luôn có.
    badgeWell: Color(0xFFDFD8CC),
    ctaFill: Color(0xFF171412),
    ctaLabel: Color(0xFFF6F3EE),
    ctaDisabled: Color(0xFFC4BDB3),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFD6CFC5),
    artistOnImage: Color(0xFFCEC7BD),
    scrimBack: Color(0x66000000), // đóng băng = dark (họ on-image)
    lineOnImage: Color(0x59FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeil,
    playerVeil: _playerVeil,
    imageFallback: _imageFallback,
    heroVeil: _heroVeil,

    // ĐÂY LÀ CHỖ BẢN MỘT-FIELD VỠ. Cùng hue 34.5° với #C99A5B, hạ độ sáng:
    //   #7E5620 trên surfaceRaised #EBE5DB = 5.17:1 ✓  (ràng buộc chặt nhất)
    //   #7E5620 trên surface       #F6F3EE = 5.86:1 ✓
    //   #7E5620 trên welcomeBackdrop #F0EBE3 = 5.45:1 ✓
    accent: Color(0xFF7E5620),
    // ĐÓNG BĂNG = giá trị của dark. Ảnh hiện vật không sáng lên theo theme,
    // nên kicker/vạch trên ảnh cũng không được tối đi. Xem doc của field.
    accentOnImage: Color(0xFFC99A5B),
    // LẬT SANG MÀU GIẤY, không còn nâu-gần-đen: nền accent của preset này là
    // #7E5620 sẫm, nên #201509 chỉ còn 2.76:1 — rớt chuẩn. Màu giấy: 5.86:1 ✓
    accentInk: Color(0xFFF6F3EE),
    // Đỏ ĐẤT NUNG hue ~10° — cùng gia đình ấm với accent. 6.90:1 trên surface, 6.09 trên kệ · glyph 6.90:1
    error: Color(0xFF8C3A28),
    errorInk: Color(0xFFF6F3EE),
    heroDissolveEnabled: true,

    // Giấy ấm — cùng độ chói với surface #F7F7F5 nhưng ngả đất,
    // để hai khung ảnh nổi như tranh treo tường sáng.
    welcomeBackdrop: Color(0xFFF0EBE3),
    // TỐI trên theme sáng — CHỦ ĐÍCH, xem doc của field: đây là tường tranh,
    // ảnh cần nền tối hơn chúng để nổi. Vùng chữ được band + scrim che.
    welcomeAmbient: Color(0xB3262019),
    welcomeBandLower: Color(0xFFD9D0C3), // taupe ấm — giữa giấy và tường tối
    welcomeBandUpper: Color(0xFFD9D0C3),
    shadowInk: Color(0x4D000000), // ~30% — tường sáng, bóng nhạt hơn dark

    radiusSharp: 2,
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
    outline: Color(0xFF8A8A8A), // 6.08/4.94:1 — preset này ưu tiên tương phản
    surfaceRaised: Color(0xFF1C1C1C), // phân tách hàng — xem doc của field
    badgeWell: Color(0xFF111111), // ΔL* 5.2 dưới surfaceRaised — cùng luật ba preset
    ctaFill: Color(0xFFFFFFFF),
    ctaLabel: Color(0xFF000000),
    ctaDisabled: Color(0xFF4A4A4A),

    inkOnImage: Color(0xFFFFFFFF),
    mutedOnImage: Color(0xFFF0F0F0),
    artistOnImage: Color(0xFFF0F0F0),
    scrimBack: Color(0xCC000000), // ĐẬM hơn — preset này đánh đổi sắc thái lấy tương phản
    lineOnImage: Color(0x99FFFFFF),
    ctaOnImageFill: Color(0xFFFFFFFF),
    ctaOnImageInk: Color(0xFF000000),
    tourCardVeil: _tourCardVeilStrong,
    playerVeil: _playerVeilStrong,
    imageFallback: _imageFallbackFlat,
    heroVeil: _heroVeilStrong,

    // 9.27:1 trên surfaceRaised #1C1C1C — hai họ trùng giá trị, như ở dark.
    accent: Color(0xFFE3B87E),
    accentOnImage: Color(0xFFE3B87E),
    accentInk: Color(0xFF000000), // 11.4:1 trên accent — tương phản trước, sắc thái sau
    // Đỏ ĐẤT NUNG hue ~10° — cùng gia đình ấm với accent. 9.86:1 trên surface, 8.00 trên kệ · glyph 9.86:1
    error: Color(0xFFFF9580),
    errorInk: Color(0xFF000000),
    heroDissolveEnabled: false,

    // Đen tuyệt đối = surface của preset: tương phản trước, sắc thái sau.
    welcomeBackdrop: Color(0xFF000000),
    welcomeAmbient: Color(0xFF000000), // ĐẶC — ambient tắt, xem doc của field
    welcomeBandLower: Color(0x00000000), // phẳng tuyệt đối
    welcomeBandUpper: Color(0x00000000),
    shadowInk: Color(0x00000000), // phẳng tuyệt đối

    radiusSharp: 2,
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
    colors: [Color(0xB3000000), Color(0x26000000)],
    stops: [0.42, 0.74],
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
    colors: [Color(0xD9000000), Color(0x80000000)],
    stops: [0.42, 0.74],
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
    Color? outline,
    Color? surfaceRaised,
    Color? badgeWell,
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
    LinearGradient? imageFallback,
    LinearGradient? heroVeil,
    Color? accent,
    Color? accentOnImage,
    Color? accentInk,
    Color? error,
    Color? errorInk,
    bool? heroDissolveEnabled,
    Color? welcomeBackdrop,
    Color? welcomeAmbient,
    Color? welcomeBandLower,
    Color? welcomeBandUpper,
    Color? shadowInk,
    double? radiusSharp,
  }) {
    return MuseumTokens(
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      outline: outline ?? this.outline,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      badgeWell: badgeWell ?? this.badgeWell,
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
      imageFallback: imageFallback ?? this.imageFallback,
      heroVeil: heroVeil ?? this.heroVeil,
      accent: accent ?? this.accent,
      accentOnImage: accentOnImage ?? this.accentOnImage,
      accentInk: accentInk ?? this.accentInk,
      error: error ?? this.error,
      errorInk: errorInk ?? this.errorInk,
      heroDissolveEnabled: heroDissolveEnabled ?? this.heroDissolveEnabled,
      welcomeBackdrop: welcomeBackdrop ?? this.welcomeBackdrop,
      welcomeAmbient: welcomeAmbient ?? this.welcomeAmbient,
      welcomeBandLower: welcomeBandLower ?? this.welcomeBandLower,
      welcomeBandUpper: welcomeBandUpper ?? this.welcomeBandUpper,
      shadowInk: shadowInk ?? this.shadowInk,
      radiusSharp: radiusSharp ?? this.radiusSharp,
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
      outline: Color.lerp(outline, other.outline, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      badgeWell: Color.lerp(badgeWell, other.badgeWell, t)!,
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
      imageFallback: LinearGradient.lerp(imageFallback, other.imageFallback, t)!,
      heroVeil: LinearGradient.lerp(heroVeil, other.heroVeil, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentOnImage: Color.lerp(accentOnImage, other.accentOnImage, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorInk: Color.lerp(errorInk, other.errorInk, t)!,
      welcomeBackdrop: Color.lerp(welcomeBackdrop, other.welcomeBackdrop, t)!,
      welcomeAmbient: Color.lerp(welcomeAmbient, other.welcomeAmbient, t)!,
      welcomeBandLower:
          Color.lerp(welcomeBandLower, other.welcomeBandLower, t)!,
      welcomeBandUpper:
          Color.lerp(welcomeBandUpper, other.welcomeBandUpper, t)!,
      shadowInk: Color.lerp(shadowInk, other.shadowInk, t)!,
      // bool KHÔNG nội suy được: nhảy ở nửa đường. Ramp hoà tan bật/tắt giữa
      // chừng một animation đổi theme là chớp một cái — chấp nhận được, và
      // highContrast là preset duy nhất tắt nó nên đường đổi đó hiếm.
      heroDissolveEnabled: t < 0.5 ? heroDissolveEnabled : other.heroDissolveEnabled,
      radiusSharp: lerpDouble(radiusSharp, other.radiusSharp, t)!,
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