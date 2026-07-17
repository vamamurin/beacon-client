// Destination: test/presentation/theme/museum_tokens_contract_test.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// HỢP ĐỒNG CỦA HỆ TOKEN — thuần Dart, không widget, không font, không golden
// ═══════════════════════════════════════════════════════════════════════════
//
// File này KHÔNG cần: font thật, provider giả, ảnh golden, thiết bị, hay một
// dòng `pumpWidget` nào. Nó chỉ đọc ba hằng số `MuseumTokens` và làm số học.
// Chạy trong vài mili giây.
//
// VÌ SAO NÓ TỒN TẠI: mọi lỗi nặng tìm được trong đợt rà soát thị giác đều là
// MỘT CON SỐ TƯƠNG PHẢN, và mọi lỗi đó đều xuất hiện theo cùng một cách —
// preset `light` được thêm vào sau, và không ai chạy lại phép đo:
//
//     accent  trên surfaceRaised  = 2.01:1   ("Đang phát" — tín hiệu quan
//                                             trọng nhất của màn 3, vô hình)
//     inkFaint trên surface       = 4.15:1   (đoạn chỉ dẫn của trạng thái rỗng)
//     line    làm viền ô nhập     = 1.17:1   (ô nhập URL không có viền)
//     ink@.35 làm viền nút        = 2.18:1   (nút mất tư cách nút)
//
// Không cái nào cần mắt để phát hiện. Tất cả đều là số học, và số học thì máy
// làm được — mỗi lần commit, thay vì mỗi lần có người tình cờ mở app ở theme
// sáng trước lúc demo.
//
// ĐÂY LÀ TẤM LƯỚI RẺ NHẤT TRONG CẢ KẾ HOẠCH TEST, và nó KHÔNG GIÒN: đổi bố
// cục, đổi font, đổi cỡ chữ, đổi cả một màn hình — file này không nhúc nhích.
// Nó chỉ gãy khi một quan hệ MÀU bị phá, và đó đúng là lúc ta muốn nó gãy.
//
// ═══════════════════════════════════════════════════════════════════════════
// GIỚI HẠN — đọc trước khi tin nó quá nhiều
// ═══════════════════════════════════════════════════════════════════════════
//
// 1. Nó kiểm CẶP MÀU, không kiểm CALL SITE. Nó chứng minh `accent` đọc được
//    trên `surfaceRaised`; nó KHÔNG chứng minh `_StopRow` thực sự dùng cặp đó.
//    Ai đó viết `t.accent` lên `t.surface` ở một màn mới thì file này im lặng.
//    Chuỗi `why` ở mỗi assertion là chỗ ghi call site — giữ nó đúng.
//
// 2. Nó KHÔNG kiểm được thứ nằm trên ẢNH. `welcomeAmbient`, `heroVeil`,
//    `tourCardVeil` phủ lên ảnh của bảo tàng — ảnh đó do bảo tàng nạp và ta
//    không kiểm soát. Tương phản trên đó phụ thuộc bundle, không phụ thuộc
//    token, nên nó KHÔNG TÍNH ĐƯỢC TĨNH. Đó là lý do họ on-image chọn giá trị
//    an toàn tuyệt đối (trắng) thay vì tối ưu — và là lý do nhóm 4 kiểm rằng
//    họ đó KHÔNG ĐỔI, thay vì kiểm nó đạt bao nhiêu.
//
// 3. Ngưỡng 4.5:1 là AA cho chữ < 18pt. Mọi style chữ của app đều dưới ngưỡng
//    đó (lớn nhất là welcomeTitle 34px ≈ 25.5pt — nhưng nó dùng `ink`, vốn dư
//    xa). Nên áp 4.5 cho tất cả là đúng, không phải bảo thủ.

import 'dart:math' as math;
import 'dart:ui';

import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Số học
// ═══════════════════════════════════════════════════════════════════════════

/// WCAG 2.1 contrast ratio. Dùng `Color.computeLuminance()` của Flutter — nó
/// CHÍNH LÀ công thức relative luminance của WCAG, không cần tự cài lại.
///
/// ⚠ `computeLuminance()` BỎ QUA alpha. Một token bán trong suốt sẽ cho ra con
/// số vô nghĩa ở đây — nên nhóm 4 khoá cứng rằng họ surface phải đục. Đừng gỡ
/// assertion đó đi để "cho qua" một token mới.
double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE L* — độ sáng CẢM NHẬN, thang 0..100.
///
/// KHÔNG PHẢI contrast ratio, và đây là phân biệt quan trọng nhất của file:
/// tỉ lệ tương phản là thước cho CHỮ trên nền. Với hai MẢNG NỀN cạnh nhau
/// (đĩa badge nằm trên kệ), nó vô dụng — #201D1A và #151312 cho 1.10:1, con
/// số nghe như "không thấy gì", trong khi mắt thấy rõ hai tông. ΔL* mới là
/// thước đúng cho câu hỏi "hai mảng này có đọc ra là khác tông không".
double _lstar(Color c) {
  final y = c.computeLuminance();
  return y <= 0.008856 ? 903.3 * y : 116 * math.pow(y, 1 / 3) - 16;
}

/// Chồng một màu BÁN TRONG SUỐT lên một nền ĐỤC (source-over).
///
/// VÌ SAO CẦN: `computeLuminance()` bỏ qua alpha, nên mọi assertion khác trong
/// file này đòi hai đầu phải đục. Nhưng có đúng MỘT cặp không thể đục —
/// `scrimBack` LÀ một lớp phủ, đó là toàn bộ công việc của nó — và nó là chỗ
/// một lỗi thật đã sống: nút back ở 3.13:1 trên preset giấy khi hero thu.
///
/// Chỉ dùng khi nền là một TOKEN đục. Nếu nền là ẢNH thì đừng — xem giới hạn 2
/// ở đầu file: thứ nằm trên ảnh không tính tĩnh được.
Color _over(Color fg, Color opaqueBg) {
  assert(opaqueBg.a == 1.0, 'nền phải đục');
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + opaqueBg.r * (1 - a),
    green: fg.g * a + opaqueBg.g * (1 - a),
    blue: fg.b * a + opaqueBg.b * (1 - a),
  );
}

void main() {
  const presets = <String, MuseumTokens>{
    'dark': MuseumTokens.dark,
    'light': MuseumTokens.light,
    'highContrast': MuseumTokens.highContrast,
  };

  /// Chạy `body` cho cả ba preset. Tên preset đi vào `reason` của mọi
  /// assertion — không có nó thì "expected >= 4.5, actual 2.01" không nói được
  /// preset nào hỏng, và đó luôn là câu hỏi đầu tiên.
  void forEachPreset(void Function(String name, MuseumTokens t) body) {
    presets.forEach((name, t) => body(name, t));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // NHÓM 1 — CHỮ: WCAG AA, 4.5:1
  // ═════════════════════════════════════════════════════════════════════════

  group('chữ đạt WCAG AA (4.5:1)', () {
    void text(String label, Color Function(MuseumTokens) fg,
        Color Function(MuseumTokens) bg, String callSite) {
      test(label, () {
        forEachPreset((name, t) {
          final r = _contrast(fg(t), bg(t));
          expect(r, greaterThanOrEqualTo(4.5),
              reason: 'preset "$name": $label = ${r.toStringAsFixed(2)}:1 — '
                  'dưới AA. Call site: $callSite');
        });
      });
    }

    text('ink / surface', (t) => t.ink, (t) => t.surface, 'tiêu đề mọi màn');
    text('ink / surfaceRaised', (t) => t.ink, (t) => t.surfaceRaised,
        '_StopRow: tên hiện vật trên thẻ');
    text('inkMuted / surface', (t) => t.inkMuted, (t) => t.surface,
        'câu dẫn Gate, mô tả dưới tiêu đề');
    text('inkMuted / surfaceRaised', (t) => t.inkMuted, (t) => t.surfaceRaised,
        '_StopRow: dòng meta');
    text('inkFaint / surface', (t) => t.inkFaint, (t) => t.surface,
        '_NoneNearby: đoạn chỉ dẫn — TỪNG LÀ 4.15:1 ở light');
    text('inkFaint / surfaceRaised', (t) => t.inkFaint, (t) => t.surfaceRaised,
        '_StopRow: chỉ số badge (trang trí, nhưng vẫn phải đọc được nếu nhìn)');
    text('accent / surfaceRaised', (t) => t.accent, (t) => t.surfaceRaised,
        '_StopRow: "Đang phát thuyết minh" — TỪNG LÀ 2.01:1 ở light');
    text('accentInk / accent', (t) => t.accentInk, (t) => t.accent,
        '_StopRow: glyph sóng âm trên badge đang phát');
    text('error / surface', (t) => t.error, (t) => t.surface,
        'chữ lỗi, errorText của TextField ở Cài đặt');
    text('error / surfaceRaised', (t) => t.error, (t) => t.surfaceRaised,
        'chữ lỗi đặt trên thẻ');
    text('errorInk / error', (t) => t.errorInk, (t) => t.error,
        'ColorScheme.onError — chữ trên nền lỗi');
    text('ctaLabel / ctaFill', (t) => t.ctaLabel, (t) => t.ctaFill,
        '_StartButton: nhãn "BẮT ĐẦU THAM QUAN"');
    text('inkMuted / welcomeBackdrop', (t) => t.inkMuted,
        (t) => t.welcomeBackdrop, 'Gate: câu dẫn — đầu mút SÁNG, xem test dưới');

    test('inkMuted / welcomeBandLower — đầu mút TỐI của câu dẫn Gate', () {
      // CẶP NÀY ĐỔI LÝ DO, KHÔNG ĐỔI GIÁ TRỊ. Trước đây `inkMuted /
      // welcomeBackdrop` được biện minh bằng "nhánh _showBand = false — tên bảo
      // tàng rơi xuống backdrop". Cờ đó đã bị xoá (band là bắt buộc: nó tốn 0dp
      // và gánh toàn bộ độ đọc của tên ở preset giấy), nên lý do cũ chết theo.
      //
      // Nhưng assertion sống, vì nó có một call site THẬT và quan trọng hơn:
      // CÂU DẪN ở Gate (`AppText.lede`, màu inkMuted) ngồi ở ~14% từ đáy, nơi
      // scrim pha ~74.5% [welcomeBackdrop] với ~25.5% [welcomeBandLower].
      //
      // Nền thật là một HỖN HỢP, và hỗn hợp thì không assert thẳng được — nó
      // phụ thuộc con số 0.745, thứ sẽ đổi nếu ai chỉnh scrim. Nên assert HAI
      // ĐẦU MÚT: nền thật luôn nằm giữa chúng, nên hai đầu mút đứng thì cả đoạn
      // đứng, ở mọi vị trí scrim.
      //
      //     dark : backdrop 10.95 · band 8.88  → nền thật 10.52
      //     light: backdrop  6.17 · band 4.80  → nền thật  5.79
      //
      // Đây là một cặp assertion mạnh hơn cái nó thay thế — nó canh một đoạn,
      // không canh một điểm.
      forEachPreset((name, t) {
        if (t.welcomeBandLower.a == 0) return; // HC: band tắt ⇒ chỉ còn backdrop
        final r = _contrast(t.inkMuted, t.welcomeBandLower);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: 'preset "$name": câu dẫn Gate trên đầu mút tối = '
                '${r.toStringAsFixed(2)}:1');
      });
    });

    test('inkMuted / welcomeBandUpper — nền của TÊN BẢO TÀNG', () {
      // Cặp này là lý do band tồn tại và là lý do cờ `_showBand` bị xoá.
      //
      // Không có band, tên bảo tàng rơi xuống `welcomeAmbient` — lớp phủ 70%
      // trên ẢNH BUNDLE, tức trên một màu do BẢO TÀNG quyết khi họ chọn ảnh:
      //     light: 2.45:1 (ảnh rất tối) · 1.47 (trung bình) · 1.21 (rất sáng)
      // Fail trên mọi ảnh. Có band: 4.80:1 ở light, 8.88:1 ở dark, và KHÔNG
      // phụ thuộc ảnh nào cả.
      //
      // Đó mới là điều đáng giá, hơn cả bản thân con số: một tương phản ta
      // KIỂM ĐƯỢC, thay vì một tương phản bảo tàng quyết hộ mà không biết.
      // Đây cũng là ranh giới của file này (xem giới hạn 2 ở đầu): thứ nằm
      // trên ảnh thì không tính tĩnh được — nên thiết kế phải sắp sao cho chữ
      // quan trọng KHÔNG nằm trên ảnh.
      forEachPreset((name, t) {
        if (t.welcomeBandUpper.a == 0) return; // HC: band trong suốt ⇒ rơi
        // xuống backdrop, đã có test ở trên.
        final r = _contrast(t.inkMuted, t.welcomeBandUpper);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: 'preset "$name": tên bảo tàng trên band = '
                '${r.toStringAsFixed(2)}:1');
      });
    });

    test('nút back đọc được KHI HERO THU — chevron đổi họ, scrim giữ nguyên',
        () {
      // ĐÂY LÀ ASSERTION LẼ RA ĐÃ BẮT ĐƯỢC LỖI GỐC, và nó vắng mặt ban đầu vì
      // một lý do nghe rất hợp lý: `scrimBack` bán trong suốt, mà
      // `computeLuminance()` bỏ qua alpha ⇒ "không test được" ⇒ bỏ qua. Sai.
      // Nó không test được TRỰC TIẾP; nó test được SAU KHI CHỒNG LỚP — và nền
      // ở đây là `surface`, một token đục ta biết chính xác.
      //
      // LỊCH SỬ NGẮN CỦA CON SỐ NÀY, vì nó đã đổi hai lần trong một phiên:
      //   • gốc: chevron cứng `inkOnImage` (trắng), scrim 40% → light 3.10:1,
      //     dưới AA. Sửa bằng cách NÂNG SCRIM lên 80% (0xCC) → 13:1, nhưng đổi
      //     hẳn diện mạo nút trên hero — bị bác vì lý do THẨM MỸ, không phải
      //     lý do kỹ thuật.
      //   • giờ: scrim TRẢ VỀ 40% (đúng thẩm mỹ gốc). CHEVRON đổi họ theo
      //     `open()` — `ink` khi đứng trên surface thật, `inkOnImage` khi còn
      //     trên ảnh. Cả hai mục tiêu đạt cùng lúc: 40% mờ như cũ VÀ AA.
      //
      // Test giả lập đúng nhánh nguy hiểm nhất: hero đã thu hết (`onSurface`),
      // scrim chồng lên `surface` thật, chevron dùng `ink` — không dùng
      // `inkOnImage` như bản gốc.
      forEachPreset((name, t) {
        final bg = _over(t.scrimBack, t.surface);
        final r = _contrast(t.ink, bg);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: 'preset "$name": chevron (ink) trên đĩa scrimBack chồng lên '
                'surface = ${r.toStringAsFixed(2)}:1. Nhánh onSurface của '
                '_BackGlyph không còn đọc được khi hero thu.');
      });
    });

    test('inkMuted / ctaDisabled — sàn 3:1, không phải 4.5', () {
      // WCAG MIỄN TRỪ control bị vô hiệu hoá khỏi ngưỡng tương phản, nên 4.5
      // là sai luật ở đây. Nhưng "được miễn" không có nghĩa là "được tàng
      // hình": nút "Bắt đầu tham quan" ở trạng thái disabled là thứ khách nhìn
      // trong lúc app đang chờ BLE — nó phải đọc được, chỉ là không mời bấm.
      // 3:1 là sàn tự đặt, có chủ đích, và nó KHÔNG phải một ngưỡng chuẩn.
      forEachPreset((name, t) {
        final r = _contrast(t.inkMuted, t.ctaDisabled);
        expect(r, greaterThanOrEqualTo(3.0),
            reason: 'preset "$name": nhãn CTA disabled = '
                '${r.toStringAsFixed(2)}:1 — khách không đọc được app đang chờ '
                'gì.');
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // NHÓM 2 — PHI-CHỮ: WCAG 1.4.11, 3:1
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Ranh giới của một control cần 3:1 vì nó là thứ nói cho người dùng biết
  // control BẮT ĐẦU Ở ĐÂU. Đây là ngưỡng mà `t.line` (hairline, 1.17:1) đã
  // trượt suốt thời gian nó bị dùng nhầm làm viền.

  group('ranh giới control đạt WCAG 1.4.11 (3:1)', () {
    void nonText(String label, Color Function(MuseumTokens) fg,
        Color Function(MuseumTokens) bg, String callSite) {
      test(label, () {
        forEachPreset((name, t) {
          final r = _contrast(fg(t), bg(t));
          expect(r, greaterThanOrEqualTo(3.0),
              reason: 'preset "$name": $label = ${r.toStringAsFixed(2)}:1 — '
                  'dưới 1.4.11. Call site: $callSite');
        });
      });
    }

    nonText('outline / surface', (t) => t.outline, (t) => t.surface,
        'settings: viền TextField URL máy chủ — TỪNG dùng `line` = 1.17:1');
    nonText('outline / surfaceRaised', (t) => t.outline, (t) => t.surfaceRaised,
        'viền control đặt trên thẻ');
    nonText('outline / welcomeBackdrop', (t) => t.outline,
        (t) => t.welcomeBackdrop,
        '_StaffCard + _StaffButton + _ProgressLine — TỪNG là ink@.35 = 2.18:1');
    nonText('accent / surface', (t) => t.accent, (t) => t.surface,
        'vạch nhấn 48×2 ở _NoneNearby');
    nonText('accent / welcomeBackdrop', (t) => t.accent,
        (t) => t.welcomeBackdrop, 'vạch nhấn 88×2 ở Gate');

    test('badge đang phát tách khỏi kệ', () {
      forEachPreset((name, t) {
        final r = _contrast(t.accent, t.surfaceRaised);
        expect(r, greaterThanOrEqualTo(3.0),
            reason: 'preset "$name": nền badge accent trên surfaceRaised = '
                '${r.toStringAsFixed(2)}:1. Đây là NỀN chứ không phải chữ, '
                'nhưng nó mang trạng thái ("đang phát") nên vẫn là thành phần '
                'giao diện theo 1.4.11.');
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // NHÓM 3 — ΔL*: mã hoá HAI lỗi đã thực sự xảy ra
  // ═════════════════════════════════════════════════════════════════════════

  group('âm lượng của badge (ΔL*, không phải contrast ratio)', () {
    test('đĩa lõm phải LÕM — đúng dấu ở mọi preset', () {
      forEachPreset((name, t) {
        final d = _lstar(t.surfaceRaised) - _lstar(t.badgeWell);
        expect(d, greaterThan(0),
            reason: 'preset "$name": badgeWell SÁNG hơn surfaceRaised '
                '(ΔL* ${d.toStringAsFixed(1)}) ⇒ badge đọc là đĩa NỔI, ngược '
                'hẳn ẩn dụ. Đây là bug THẬT đã ship: badge từng tô `surface`, '
                'và `surface` chỉ tình cờ tối hơn kệ ở preset tối — preset '
                'giấy đảo dấu nó.');
      });
    });

    test('đĩa lõm không được hút mắt — ΔL* ≤ 8', () {
      forEachPreset((name, t) {
        final d = _lstar(t.surfaceRaised) - _lstar(t.badgeWell);
        expect(d, lessThanOrEqualTo(8.0),
            reason: 'preset "$name": badgeWell sâu ΔL* ${d.toStringAsFixed(1)} '
                '⇒ đĩa thành điểm tương phản mạnh nhất trong hàng và cãi lại '
                'tên hiện vật. Đây cũng là bug THẬT, ở chiều ngược lại: bản sửa '
                'lỗi đảo dấu đã đào sâu hố lên 11.4 vì tưởng ẩn dụ cần rõ hơn. '
                'Thứ cần rõ là TÊN hiện vật; badge chỉ cần không cãi nó.');
      });
    });

    test('thứ tự âm lượng trong hàng: tên > meta > số', () {
      forEachPreset((name, t) {
        final ten = (_lstar(t.ink) - _lstar(t.surfaceRaised)).abs();
        final meta = (_lstar(t.inkMuted) - _lstar(t.surfaceRaised)).abs();
        final so = (_lstar(t.inkFaint) - _lstar(t.badgeWell)).abs();
        expect(ten, greaterThan(meta),
            reason: 'preset "$name": tên hiện vật (ΔL* ${ten.toStringAsFixed(1)}) '
                'không nổi hơn meta (${meta.toStringAsFixed(1)})');
        expect(meta, greaterThan(so),
            reason: 'preset "$name": chỉ số badge (ΔL* ${so.toStringAsFixed(1)}) '
                'nổi hơn dòng meta (${meta.toStringAsFixed(1)}). Con số là '
                'TRANG TRÍ — bảo tàng không đánh số hiện vật, giá trị hiển thị '
                'là minor ID của beacon. Nó không được to tiếng hơn nội dung.');
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // NHÓM 4 — BẤT BIẾN KIẾN TRÚC
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Ba luật dưới đây được phát biểu rõ ràng trong doc của museum_tokens.dart,
  // và cho tới file này, KHÔNG CÓ GÌ canh chúng. Cả ba đều đã bị vi phạm ít
  // nhất một lần trong lịch sử dự án. Doc không phải cơ chế thi hành.

  group('bất biến kiến trúc', () {
    test('họ on-image ĐÓNG BĂNG giữa dark và light', () {
      // Doc đầu file: "Ảnh hiện vật không sáng lên khi bật light theme. Nếu
      // `inkOnImage` đi theo `ink`, light mode sẽ cho chữ đen trên ảnh tối —
      // không đọc được. Cái bẫy này chỉ lộ ra khi thực sự có theme sáng."
      //
      // `accent` ĐÃ SẬP CÁI BẪY NÀY: nó khai báo một lần cho cả hai họ với lý
      // do "đủ tương phản trên cả surface tối lẫn ảnh có veil" — câu đó chỉ
      // đúng khi chưa có preset giấy.
      //
      // highContrast ĐƯỢC MIỄN, có chủ đích: doc cho phép nó làm đậm veil và
      // sáng chữ on-image, vì mục tiêu của nó là độ tương phản chứ không phải
      // sắc thái. Nên bất biến là dark == light, KHÔNG phải cả ba.
      const d = MuseumTokens.dark;
      const l = MuseumTokens.light;
      final pairs = <String, List<Object>>{
        'inkOnImage': [d.inkOnImage, l.inkOnImage],
        'mutedOnImage': [d.mutedOnImage, l.mutedOnImage],
        'artistOnImage': [d.artistOnImage, l.artistOnImage],
        'accentOnImage': [d.accentOnImage, l.accentOnImage],
        'scrimBack': [d.scrimBack, l.scrimBack],
        'lineOnImage': [d.lineOnImage, l.lineOnImage],
        'ctaOnImageFill': [d.ctaOnImageFill, l.ctaOnImageFill],
        'ctaOnImageInk': [d.ctaOnImageInk, l.ctaOnImageInk],
        'tourCardVeil': [d.tourCardVeil, l.tourCardVeil],
        'playerVeil': [d.playerVeil, l.playerVeil],
        'heroVeil': [d.heroVeil, l.heroVeil],
        // imageFallback (1.5): 4/5 call site của HeroImage có chữ TRẮNG nằm
        // trên. Nếu nó đi theo theme, preset giấy làm nó sáng lên và chữ trắng
        // biến mất ĐÚNG LÚC ảnh hỏng — đúng lúc màn hình cần nói có gì đó sai.
        'imageFallback': [d.imageFallback, l.imageFallback],
      };
      pairs.forEach((field, v) {
        expect(v[0], equals(v[1]),
            reason: '`$field` lệch giữa dark và light. Ảnh hiện vật KHÔNG sáng '
                'lên theo theme, nên thứ nằm trên nó cũng không được đổi. Nếu '
                'field này thật sự cần đổi theo theme thì nó thuộc họ surface, '
                'và tên nó đang nói dối.');
      });
    });

    test('bất biến `heroDissolve == surface` KHÔNG CÒN TỒN TẠI ĐỂ VI PHẠM', () {
      // Test này từng assert `t.heroDissolve == t.surface`, vì doc của field
      // ghi: "KHÔNG CÓ GÌ trong compiler canh ràng buộc này".
      //
      // 1.8 đã xoá field đó. Nó chỉ mang hai thông tin — một bất biến ("màu =
      // surface") và một bool ("có bật không") — nên nó là một bool đội lốt
      // Color, và nó bắt ba preset chép lại `surface` của chính mình. Màu giờ
      // lấy thẳng `t.surface` tại call site; bất biến biến mất CÙNG khả năng vi
      // phạm nó.
      //
      // ĐÂY LÀ KẾT CỤC TỐT HƠN MỘT TEST XANH: một assertion chỉ chứng minh
      // ràng buộc đang được tuân thủ; xoá bậc tự do thì không còn gì để tuân
      // thủ. Giữ test này làm bia — nếu ai đó thêm lại một `Color heroDissolve`,
      // hãy đọc doc `heroDissolveEnabled` trước.
      forEachPreset((name, t) {
        expect(t.heroDissolveEnabled, isA<bool>(), reason: 'preset "$name"');
      });
      expect(MuseumTokens.highContrast.heroDissolveEnabled, isFalse,
          reason: 'highContrast phải TẮT hoà tan: hoà tan là phản đề của tương '
              'phản cao — ảnh phải gặp danh sách bằng cạnh cứng.');
      expect(MuseumTokens.dark.heroDissolveEnabled, isTrue);
      expect(MuseumTokens.light.heroDissolveEnabled, isTrue);
    });

    test('họ surface phải ĐỤC', () {
      // Toàn bộ số học của file này dùng `computeLuminance()`, vốn BỎ QUA
      // alpha. Một token surface bán trong suốt làm mọi con số ở trên thành
      // vô nghĩa — và test vẫn xanh. Đây là assertion bảo vệ chính các
      // assertion khác.
      forEachPreset((name, t) {
        final opaque = <String, Color>{
          'surface': t.surface,
          'surfaceRaised': t.surfaceRaised,
          'badgeWell': t.badgeWell,
          'ink': t.ink,
          'inkMuted': t.inkMuted,
          'inkFaint': t.inkFaint,
          'outline': t.outline,
          'accent': t.accent,
          'accentInk': t.accentInk,
          'ctaFill': t.ctaFill,
          'ctaLabel': t.ctaLabel,
          'welcomeBackdrop': t.welcomeBackdrop,
        };
        opaque.forEach((field, c) {
          expect(c.a, equals(1.0),
              reason: 'preset "$name": `$field` bán trong suốt. Họ surface phải '
                  'đục — tương phản của một lớp phủ phụ thuộc thứ nằm dưới nó, '
                  'nên nó KHÔNG có ngưỡng, và mọi assertion tương phản ở file '
                  'này sẽ âm thầm sai.');
        });
      });
    });

    test('lerp giữa hai preset không làm rơi field nào', () {
      // Bẫy đã ghi ở đầu museum_tokens.dart: quên một field trong copyWith
      // KHÔNG gây lỗi compile (`x ?? this.x` luôn trả về field của chính
      // object). Cùng loại bẫy nằm ở lerp. Một field bị quên ở lerp sẽ đứng
      // im khi đổi theme — nhìn ra được, nhưng chỉ khi đang nhìn.
      const a = MuseumTokens.dark;
      const b = MuseumTokens.light;
      final mid = a.lerp(b, 1.0);
      expect(mid.accent, equals(b.accent), reason: 'lerp bỏ quên `accent`');
      expect(mid.accentOnImage, equals(b.accentOnImage),
          reason: 'lerp bỏ quên `accentOnImage`');
      expect(mid.outline, equals(b.outline), reason: 'lerp bỏ quên `outline`');
      expect(mid.badgeWell, equals(b.badgeWell),
          reason: 'lerp bỏ quên `badgeWell`');
      expect(mid.surfaceRaised, equals(b.surfaceRaised),
          reason: 'lerp bỏ quên `surfaceRaised`');

      // copyWith: cùng cái bẫy, và nó ĐÃ CẮN hai lần.
      //
      // Lần một: tham số tên là `sectionBand` — rác của lần đổi tên
      // _SectionBand → heroDissolve — nên `copyWith(heroDissolve: ...)` không
      // tồn tại suốt nhiều lần sửa, và KHÔNG AI BIẾT: `copyWith` lúc đó không
      // có call site nào, nên không có gì để vỡ.
      //
      // Lần hai: đổi tên `heroDissolve` → `heroDissolveEnabled` (1.8) để lại
      // đúng loại rác đó NGAY TRONG assertion này. Khác biệt duy nhất là thời
      // gian sống: rác lần một sống nhiều tháng, rác lần hai chết ở lần
      // `flutter test` kế tiếp — vì giờ test LÀ call site.
      //
      // Đó là toàn bộ lý do khối này tồn tại. Nó không canh một lỗi giả định;
      // nó canh một lỗi đã xảy ra hai lần, và lần thứ hai là do chính người
      // viết ra nó.
      expect(a.copyWith(heroDissolveEnabled: false).heroDissolveEnabled,
          isFalse,
          reason: 'copyWith bỏ quên `heroDissolveEnabled`');
      expect(a.copyWith(shadowInk: b.ink).shadowInk, equals(b.ink),
          reason: 'copyWith bỏ quên `shadowInk`');
      expect(a.copyWith(imageFallback: b.heroVeil).imageFallback,
          equals(b.heroVeil),
          reason: 'copyWith bỏ quên `imageFallback`');
      expect(a.copyWith(error: b.error).error, equals(b.error),
          reason: 'copyWith bỏ quên `error`');
      expect(a.copyWith(accentOnImage: b.accent).accentOnImage,
          equals(b.accent),
          reason: 'copyWith bỏ quên `accentOnImage`');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // NHÓM 5 — ColorScheme: KHÔNG vai trò nào được là màu thuật toán
  // ═════════════════════════════════════════════════════════════════════════

  group('ColorScheme không chứa màu ngoài hệ token', () {
    test('mọi vai trò M3 đều truy về một token', () {
      // ĐÂY LÀ TEST BIẾN MỘT LỜI HỨA THÀNH MỘT TÍNH CHẤT.
      //
      // `MuseumTokens` bắt mọi field `required` để không preset nào âm thầm
      // mượn màu của preset khác. Rồi `buildMuseumTheme` từng giao ~20 vai trò
      // cho `ColorScheme.fromSeed` — đúng cái lỗ hổng đó, ở tầng dưới. Nó chưa
      // lộ ra vì chưa widget nào đọc tới `secondary`/`tertiary`/`error`; nhưng
      // màn 2 đã có FilledButton, Cài đặt đã có TextField, và màn 4 sẽ có
      // Slider + BottomSheet.
      //
      // Test này canh việc đó VĨNH VIỄN: mọi vai trò phải là một màu ai đó đã
      // CHỌN, không phải một màu ai đó đã NỘI SUY.
      //
      // ⚠ GIỚI HẠN: Dart không duyệt được thuộc tính lúc chạy (không mirrors),
      // nên danh sách `roles` dưới đây là THỦ CÔNG. Flutter thêm vai trò mới
      // (M3 từng thêm cả họ `*Fixed`) thì test này KHÔNG tự biết. Khi nâng
      // Flutter, soát lại danh sách — hoặc chấp nhận rằng tấm lưới có một mắt
      // rộng đúng bằng chỗ này.
      for (final id in MuseumThemeId.values) {
        final t = id.tokens;
        final cs = buildMuseumTheme(id).colorScheme;

        final allowed = <Color>{
          t.surface, t.surfaceRaised, t.badgeWell,
          t.ink, t.inkMuted, t.inkFaint,
          t.line, t.outline,
          t.accent, t.accentInk,
          t.error, t.errorInk,
          t.shadowInk,
          t.ctaFill, t.ctaLabel, t.ctaDisabled,
          const Color(0xFF000000), // shadow / scrim — đen là đen
          const Color(0x00000000), // surfaceTint tắt: thiết kế PHẲNG
        };

        final roles = <String, Color>{
          'primary': cs.primary,
          'onPrimary': cs.onPrimary,
          'primaryContainer': cs.primaryContainer,
          'onPrimaryContainer': cs.onPrimaryContainer,
          'primaryFixed': cs.primaryFixed,
          'primaryFixedDim': cs.primaryFixedDim,
          'onPrimaryFixed': cs.onPrimaryFixed,
          'onPrimaryFixedVariant': cs.onPrimaryFixedVariant,
          'secondary': cs.secondary,
          'onSecondary': cs.onSecondary,
          'secondaryContainer': cs.secondaryContainer,
          'onSecondaryContainer': cs.onSecondaryContainer,
          'secondaryFixed': cs.secondaryFixed,
          'secondaryFixedDim': cs.secondaryFixedDim,
          'onSecondaryFixed': cs.onSecondaryFixed,
          'onSecondaryFixedVariant': cs.onSecondaryFixedVariant,
          'tertiary': cs.tertiary,
          'onTertiary': cs.onTertiary,
          'tertiaryContainer': cs.tertiaryContainer,
          'onTertiaryContainer': cs.onTertiaryContainer,
          'tertiaryFixed': cs.tertiaryFixed,
          'tertiaryFixedDim': cs.tertiaryFixedDim,
          'onTertiaryFixed': cs.onTertiaryFixed,
          'onTertiaryFixedVariant': cs.onTertiaryFixedVariant,
          'error': cs.error,
          'onError': cs.onError,
          'errorContainer': cs.errorContainer,
          'onErrorContainer': cs.onErrorContainer,
          'surface': cs.surface,
          'onSurface': cs.onSurface,
          'onSurfaceVariant': cs.onSurfaceVariant,
          'surfaceDim': cs.surfaceDim,
          'surfaceBright': cs.surfaceBright,
          'surfaceContainerLowest': cs.surfaceContainerLowest,
          'surfaceContainerLow': cs.surfaceContainerLow,
          'surfaceContainer': cs.surfaceContainer,
          'surfaceContainerHigh': cs.surfaceContainerHigh,
          'surfaceContainerHighest': cs.surfaceContainerHighest,
          'outline': cs.outline,
          'outlineVariant': cs.outlineVariant,
          'shadow': cs.shadow,
          'scrim': cs.scrim,
          'inverseSurface': cs.inverseSurface,
          'onInverseSurface': cs.onInverseSurface,
          'inversePrimary': cs.inversePrimary,
          'surfaceTint': cs.surfaceTint,
        };

        roles.forEach((name, c) {
          expect(allowed.contains(c), isTrue,
              reason: 'preset "${id.id}": `ColorScheme.$name` = $c — KHÔNG có '
                  'trong MuseumTokens. Đây là màu do thuật toán M3 nội suy, '
                  'không phải màu ai đó chọn. Hoặc nối nó vào một token ở '
                  'buildMuseumTheme, hoặc thêm token nếu vai trò đó thật sự là '
                  'một quyết định thiết kế mới.');
        });
      }
    });

    test('surfaceTint TẮT — thiết kế phẳng tuyệt đối', () {
      // M3 nhuộm bề mặt có elevation bằng `surfaceTint`, mặc định = `primary`.
      // Ở preset tối `primary` là ctaFill TRẮNG ⇒ Card/Dialog/BottomSheet bị
      // dội một lớp trắng. Ngôn ngữ này đã bỏ hairline, bỏ bóng, radius 2 —
      // elevation tint là thứ duy nhất còn có thể lén dựng lại chiều sâu, và
      // nó lén qua một mặc định chứ không qua một quyết định.
      for (final id in MuseumThemeId.values) {
        expect(buildMuseumTheme(id).colorScheme.surfaceTint.a, equals(0.0),
            reason: 'preset "${id.id}": surfaceTint không trong suốt ⇒ M3 sẽ '
                'nhuộm mọi bề mặt nâng cao. Màn 4 (BottomSheet) sẽ thấy đầu '
                'tiên.');
      }
    });
  });
}