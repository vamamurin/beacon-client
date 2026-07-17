// Destination: test/presentation/gate/gate_layout_test.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// BẤT BIẾN HÌNH HỌC — assert QUAN HỆ, không so ảnh
// ═══════════════════════════════════════════════════════════════════════════
//
// VÌ SAO KHÔNG PHẢI GOLDEN: cả hai bug mà file này canh đều là QUAN HỆ giữa
// hai vật, không phải một bức tranh.
//
//     golden báo:  "khác 4.2% pixel so với gate_667_2x_light.png"
//     file này báo: "lệch đáy hai khung = 12.7dp, kỳ vọng 32.0"
//
// Câu thứ hai dạy được người đọc nó; câu thứ nhất thì không. Và golden đỏ mỗi
// lần có ai đổi MỘT MÀU — nên nó sẽ bị `--update-goldens` cho qua, và tấm lưới
// mục thành nghi lễ. File này chỉ gãy khi một quan hệ HÌNH HỌC gãy.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI BUG ĐƯỢC MÃ HOÁ Ở ĐÂY — cả hai là CÙNG MỘT bug, ở hai đầu màn hình
// ═══════════════════════════════════════════════════════════════════════════
//
// Cả hai đều là "hai hệ toạ độ trượt qua nhau": một bên đo bằng % màn hình,
// bên kia đo bằng dp và co giãn theo textScaler của khách. Không tồn tại giá
// trị % nào đúng trên mọi máy × mọi cỡ chữ — nên chúng chỉ hỏng trên những
// cấu hình mà không ai trong nhóm cầm trên tay.
//
//   1. VẠCH ACCENT BỊ KHUNG ẢNH ĐÈ (đã sửa bằng `Expanded`)
//        khối chữ đo dp TỪ ĐÁY LÊN   ≈ 260dp
//        khung ảnh đo % TỪ ĐỈNH XUỐNG (đáy = h × 0.66)
//        máy 844: đè 9dp · máy 667: đè 69dp
//
//   2. TÊN BẢO TÀNG TRÔI KHỎI BAND (đã sửa bằng `_MuseumNameBar`)
//        band = 0.14 × chiều cao màn      (%, từ y=0)
//        tên  = SafeArea.top + dp × scaler (dp, từ mép an toàn)
//        máy 667 @1.6× tên hai dòng: khối tên 124dp > band 93dp
//
//   3. LỆCH ĐÁY HAI KHUNG SỤP VỀ 0 (đã sửa bằng `_offsetY` dp)
//        lệch = 0.06 × vùng tự do ⇒ chữ to lên thì lệch co về 0
//        h=521 → 31dp · h=212 → 13dp · h=150 → 9dp
//
// Ba con số đó đã được chữa. File này tồn tại để chúng KHÔNG QUAY LẠI, trên
// những cấu hình mà không ai mở ra được bằng tay.
//
// ═══════════════════════════════════════════════════════════════════════════
// GIỚI HẠN
// ═══════════════════════════════════════════════════════════════════════════
// Font: test chạy với font mặc định của môi trường test (Ahem/Roboto), KHÔNG
// phải Cormorant/Inter. Nên mọi con số phụ thuộc CHIỀU CAO CHỮ (band có chứa
// nổi tên không) chỉ đúng về QUAN HỆ, không đúng về giá trị tuyệt đối. Đó là
// lý do file này assert `band.bottom >= text.bottom` chứ không assert
// `band.height == 111`. Quan hệ thì đúng với mọi font; con số thì không —
// và cả dự án này là một chuỗi bài học về đúng chuyện đó.

import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/gate/gate_screen.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Giàn dựng
// ═══════════════════════════════════════════════════════════════════════════

/// Tên bảo tàng DÀI — mặc định của test, không phải trường hợp biên.
///
/// "Bảo tàng" (8 ký tự) là dữ liệu mơ ước. Tên thật của bảo tàng Việt Nam dài,
/// và ở textScaler 1.6× nó xuống hai dòng — đó chính là cấu hình đã làm nó
/// trôi khỏi band. Test với dữ liệu dễ là không test.
const _longName = 'Bảo tàng Lịch sử Quốc gia Việt Nam';

/// Chiều cao khối action. Hai nhánh thật cách nhau gần ba lần, và vùng tự do
/// của khung ảnh = phần CÒN LẠI — nên chúng là hai bố cục khác nhau.
const _ctaHeight = AppSpace.ctaHeight; // 72 — nút "Bắt đầu tham quan"
const _staffCardHeight = 210.0; // ≈ thẻ nhân viên (BLE chưa sẵn / cần sync)

Future<void> _pumpGate(
  WidgetTester tester, {
  required Size logicalSize,
  required MuseumThemeId theme,
  double textScale = 1.0,
  double actionHeight = _ctaHeight,
  String museumName = _longName,
}) async {
  tester.view
    ..devicePixelRatio = 3.0
    ..physicalSize = logicalSize * 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildMuseumTheme(theme),
      // MediaQuery phải nằm TRONG MaterialApp: MaterialApp tự dựng một
      // MediaQuery từ View và sẽ đè lên bất cứ cái nào bọc ngoài nó.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          // Tai thỏ + gesture bar. KHÔNG để 0: cả `_MuseumNameBar` lẫn khối
          // CTA đều đọc SafeArea, và bug band trôi chỉ lộ khi có inset trên.
          padding: const EdgeInsets.only(top: 47, bottom: 34),
          viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: child!,
      ),
      home: GateLayout(
        museumName: museumName,
        // null ⇒ HeroImage trả fallback gradient ĐỒNG BỘ: không I/O, không
        // async, không phụ thuộc bundle. Ta đang đo hình học, không đo ảnh.
        primaryPath: null,
        // KHÔNG null: `_WelcomeFrames` bỏ hẳn khung phụ khi accentPath == null
        // (suy biến có chủ đích cho bundle cũ). Cần một chuỗi để khung được
        // dựng; HeroImage vẫn rơi về fallback vì file không tồn tại.
        accentPath: 'stub',
        action: SizedBox(height: actionHeight),
      ),
    ),
  );
  await tester.pump();
}

/// Ba máy × ba cỡ chữ. 667 là máy nhỏ nhất còn hỗ trợ; 2.0× là trần của
/// Android. Đây đúng là những cấu hình mà nhóm không có trên bàn.
const _devices = <String, Size>{
  '667': Size(375, 667),
  '844': Size(390, 844),
  '932': Size(430, 932),
};
const _scales = <double>[1.0, 1.6, 2.0];

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // BẤT BIẾN 1 — khung ảnh KHÔNG BAO GIỜ chạm vạch accent
  // ═════════════════════════════════════════════════════════════════════════

  group('khung ảnh không chạm khối chữ', () {
    for (final d in _devices.entries) {
      for (final s in _scales) {
        for (final h in <double>[_ctaHeight, _staffCardHeight]) {
          testWidgets('${d.key} @${s}x, action ${h.toInt()}dp', (tester) async {
            await _pumpGate(tester,
                logicalSize: d.value,
                theme: MuseumThemeId.dark,
                textScale: s,
                actionHeight: h);

            final frames = find.byKey(GateKeys.primaryFrame);
            // Collage ẩn khi vùng tự do quá hẹp để nó còn là collage (2.3).
            // Ẩn thì không thể đè lên gì — bất biến thoả một cách tầm thường.
            if (frames.evaluate().isEmpty) return;

            final frame = tester.getRect(frames);
            final rule = tester.getRect(find.byKey(GateKeys.accentRule));

            expect(frame.bottom, lessThanOrEqualTo(rule.top),
                reason: 'Khung ảnh đè lên vạch accent ${(frame.bottom - rule.top).toStringAsFixed(1)}dp. '
                    'Đây là bug GỐC mà `Expanded` đã diệt: khung ảnh sống trong '
                    'phần thừa của Column nên nó VẬT LÝ không thể chạm khối chữ. '
                    'Nếu test này đỏ, ai đó đã đưa khung ảnh ra khỏi Expanded '
                    'hoặc cho nó một chiều cao tuyệt đối.');
          });
        }
      }
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // BẤT BIẾN 2 — band LUÔN bao trọn tên bảo tàng, và luôn chạm y=0
  // ═════════════════════════════════════════════════════════════════════════

  group('band luôn là nền của tên bảo tàng', () {
    for (final d in _devices.entries) {
      for (final s in _scales) {
        testWidgets('${d.key} @${s}x', (tester) async {
          await _pumpGate(tester,
              logicalSize: d.value,
              theme: MuseumThemeId.light, // preset nguy hiểm nhất: xem doc bên dưới
              textScale: s);

          final band = tester.getRect(find.byKey(GateKeys.nameBand));
          final text = tester.getRect(find.byKey(GateKeys.museumNameText));

          expect(band.top, lessThanOrEqualTo(0.0),
              reason: 'Band không chạm y=0 — nó dừng ở mép SafeArea. Một tường '
                  'tranh dừng ở mép tai thỏ là một tai nạn. ColoredBox phải nằm '
                  'NGOÀI SafeArea.');
          expect(text.bottom, lessThanOrEqualTo(band.bottom),
              reason: 'Tên bảo tàng tràn ${(text.bottom - band.bottom).toStringAsFixed(1)}dp '
                  'ra khỏi band — tức khỏi cái nền mà tương phản của nó được đo '
                  'trên. Ở preset giấy đó là tụt từ ~4.8:1 xuống ~1.5:1 (band là '
                  'taupe SÁNG, ambient bên dưới là nâu đen TỐI). '
                  'Nếu test này đỏ, band đã quay về đo bằng % màn hình.');
          expect(text.left, closeTo(AppSpace.gutter, 0.5),
              reason: 'Tên bảo tàng rời khỏi đường dọc trái của màn.');
        });
      }
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // BẤT BIẾN 3 — hai khung ảnh giữ nguyên QUAN HỆ, ở mọi cỡ chữ
  // ═════════════════════════════════════════════════════════════════════════

  group('collage giữ quan hệ đã khai báo', () {
    for (final d in _devices.entries) {
      for (final s in _scales) {
        testWidgets('${d.key} @${s}x', (tester) async {
          await _pumpGate(tester,
              logicalSize: d.value, theme: MuseumThemeId.dark, textScale: s);

          final mainF = find.byKey(GateKeys.primaryFrame);
          if (mainF.evaluate().isEmpty) return; // collage ẩn — xem 2.3

          final main = tester.getRect(mainF);
          final accent = tester.getRect(find.byKey(GateKeys.accentFrame));

          // LỆCH ĐÁY = _offsetY (32dp), BẤT KỂ vùng tự do co bao nhiêu.
          // Trước đây lệch = 0.06 × vùng tự do ⇒ nó sụp về 9dp ở 667 @2.0×, và
          // hai khung đọc thành MỘT đường đáy. Ảnh co lại theo cỡ chữ là đúng
          // kế hoạch; ĐỘ LỆCH co theo thì không — nó là tín hiệu tri giác
          // ("khung nào nằm trước"), và tín hiệu tri giác đo bằng dp.
          expect(main.bottom - accent.bottom, closeTo(AppSpace.x8, 0.5),
              reason: 'Lệch đáy = ${(main.bottom - accent.bottom).toStringAsFixed(1)}dp, '
                  'kỳ vọng ${AppSpace.x8}. Nếu nó nhỏ hơn ở cỡ chữ lớn, độ lệch '
                  'đã quay về tính bằng % của vùng tự do.');

          // CHỒNG NGANG = _overlapX (20dp). Nó KHÔNG phụ thuộc cỡ chữ, nhưng nó
          // từng là kết quả TÌNH CỜ của hiệu hai hằng số (0.66w vs 0.66w−gutter)
          // — nắn 0.66 → 0.60 là nó biến thành KHE HỞ 3.4dp và collage sập thành
          // hai khung suýt chạm nhau. Giờ accentW suy ra từ _overlapX; test này
          // canh việc đó.
          expect(main.right - accent.left, closeTo(AppSpace.x5, 0.5),
              reason: 'Chồng ngang = ${(main.right - accent.left).toStringAsFixed(1)}dp, '
                  'kỳ vọng ${AppSpace.x5}. Số dương nhỏ = hai khung suýt chạm — '
                  'giá trị TỆ NHẤT có thể có: mắt đọc ra tai nạn, không đọc ra '
                  'ý đồ.');

          // Hai đường dọc của màn.
          expect(main.left, closeTo(AppSpace.gutter, 0.5),
              reason: 'Khung chính rời đường dọc trái.');
          expect(accent.right, closeTo(d.value.width - AppSpace.gutter, 0.5),
              reason: 'Khung phụ rời đường dọc phải.');
        });
      }
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // BẤT BIẾN 4 — màn hình KHÔNG ĐƯỢC TRÀN
  // ═════════════════════════════════════════════════════════════════════════

  group('không tràn ở mọi cấu hình', () {
    for (final d in _devices.entries) {
      for (final s in _scales) {
        for (final h in <double>[_ctaHeight, _staffCardHeight]) {
          testWidgets('${d.key} @${s}x, action ${h.toInt()}dp', (tester) async {
            await _pumpGate(tester,
                logicalSize: d.value,
                theme: MuseumThemeId.dark,
                textScale: s,
                actionHeight: h);

            // `Expanded` bảo đảm khung ảnh không ĐÈ lên chữ. Nó KHÔNG bảo đảm
            // mọi thứ vừa màn: nếu các con cố định (band + khối chữ + action)
            // đã vượt chiều cao khả dụng thì Expanded chỉ nhận 0, còn Column
            // vẫn tràn — sọc vàng-đen.
            //
            // Cấu hình nghi ngờ nhất: 667 @2.0× + thẻ nhân viên. Ở đó tên bảo
            // tàng 2 dòng, câu dẫn 4 dòng, tiêu đề 34px×2 — cộng lại vượt xa
            // 667dp. Nếu test này đỏ, đó KHÔNG phải lỗi của test.
            expect(tester.takeException(), isNull,
                reason: 'Gate TRÀN ở ${d.key} @${s}x với action ${h.toInt()}dp. '
                    'Expanded chống được va chạm, không chống được tràn: khi các '
                    'con cố định đã vượt chiều cao khả dụng, Expanded nhận 0 và '
                    'Column vẫn tràn. Lời sửa KHÔNG phải hạ cỡ chữ (khách chọn '
                    'cỡ đó) — mà là cho khối chữ + action cuộn được khi không đủ '
                    'chỗ, và giữ Expanded cho nhánh vừa màn.');
          });
        }
      }
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // BẤT BIẾN 5 — collage KHÔNG BAO GIỜ là một vệt bẹt
  // ═════════════════════════════════════════════════════════════════════════

  group('collage: hoặc đủ hình dạng, hoặc không có', () {
    for (final d in _devices.entries) {
      for (final s in _scales) {
        for (final h in <double>[_ctaHeight, _staffCardHeight]) {
          testWidgets('${d.key} @${s}x, action ${h.toInt()}dp', (tester) async {
            await _pumpGate(tester,
                logicalSize: d.value,
                theme: MuseumThemeId.dark,
                textScale: s,
                actionHeight: h);

            final mainF = find.byKey(GateKeys.primaryFrame);
            if (mainF.evaluate().isEmpty) return; // ẩn — hợp lệ, xem 2.3

            final r = tester.getRect(mainF);
            final aspect = r.width / r.height;

            // ⚠ NGƯỠNG ĐỌC TỪ `GateLayout.maxFrameAspect`, KHÔNG chép 1.6 vào
            // đây. Chép là tạo bản sao thứ hai của cùng một quyết định, và bản
            // sao sẽ trôi — đúng hình dạng bug `decodeWidth 0.56/0.66`. Đổi
            // ngưỡng ở gate_screen thì test này đi theo, không cần sửa.
            expect(aspect, lessThanOrEqualTo(GateLayout.maxFrameAspect + 0.02),
                reason: 'Khung ảnh tỉ lệ ${aspect.toStringAsFixed(2)} — bẹt hơn '
                    'ngưỡng ${GateLayout.maxFrameAspect}. Vùng tự do co theo cỡ '
                    'chữ (Expanded làm đúng việc), nhưng dưới ngưỡng thì collage '
                    'phải ẨN chứ không được BÓP: một collage bị bóp đọc ra là '
                    '"hỏng", không phải "gọn". Nếu test này đỏ, nhánh ẩn ở '
                    '_WelcomeFrames đã bị gỡ hoặc ngưỡng bị tính từ dp thay vì '
                    'từ tỉ lệ.');
          });
        }
      }
    }

    testWidgets('vùng tự do rộng ⇒ collage PHẢI hiện (nhánh ẩn không tham lam)',
        (tester) async {
      // Mặt kia của bất biến. Không có test này, `return SizedBox.shrink()` vô
      // điều kiện cũng cho toàn bộ nhóm trên xanh — một tấm lưới chỉ kiểm một
      // chiều thì cái nó đo được là chính nó.
      await _pumpGate(tester,
          logicalSize: const Size(430, 932),
          theme: MuseumThemeId.dark,
          textScale: 1.0);
      expect(find.byKey(GateKeys.primaryFrame), findsOneWidget,
          reason: 'Máy 932 @1.0× với nút CTA có thừa chỗ cho collage. Nếu nó ẩn '
              'ở đây, ngưỡng đang quá tham.');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Suy biến có chủ đích
  // ═════════════════════════════════════════════════════════════════════════

  group('suy biến', () {
    testWidgets('bundle cũ không có ảnh phụ ⇒ chỉ vẽ khung chính, bố cục vẫn đứng',
        (tester) async {
      tester.view
        ..devicePixelRatio = 3.0
        ..physicalSize = const Size(390, 844) * 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: buildMuseumTheme(MuseumThemeId.dark),
        home: const GateLayout(
          museumName: _longName,
          primaryPath: null,
          accentPath: null, // bundle cũ
          action: SizedBox(height: _ctaHeight),
        ),
      ));
      await tester.pump();

      expect(find.byKey(GateKeys.accentFrame), findsNothing);
      expect(find.byKey(GateKeys.primaryFrame), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tên bảo tàng rỗng không làm sập band', (tester) async {
      await _pumpGate(tester,
          logicalSize: const Size(390, 844),
          theme: MuseumThemeId.light,
          museumName: '');
      final band = tester.getRect(find.byKey(GateKeys.nameBand));
      expect(band.height, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });
}