// Destination: test/presentation/theme/design_size_test.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// FILE NÀY CANH MỘT PHÉP QUY ĐỔI, KHÔNG CANH MỘT MÀN
// ═══════════════════════════════════════════════════════════════════════════
//
// [DesignSize.verticalScale] là chỗ duy nhất trong app được phép biến một con
// số của bản vẽ thành một con số của máy. Nó nhỏ, và chính vì nhỏ nên nó dễ bị
// sửa qua đường: nới clamp cho "vừa mắt trên máy A", hoặc đổi mẫu số khi ai đó
// tưởng bản vẽ đo trên 390×844 là 390 chứ không phải 844.
//
// Hai thứ dưới đây là hợp đồng thật:
//
//   1. CON SỐ TRÊN MÁY THỰC ĐỊA (360×800). Đây là cỡ máy app sẽ chạy, nên nó
//      là chỗ duy nhất đáng ghim số cụ thể.
//   2. QUAN HỆ 215 : 580. Bản vẽ nói ra tỉ lệ này và `.zhero.near` mượn lại nó
//      thay vì bịa một tỉ lệ mới. Nó chỉ sống sót nếu hero và lưới thẻ luôn đi
//      qua CÙNG một hệ số — nên phép nhân phải giao hoán được, và test này canh
//      đúng điều đó.
//
// ⚠ CÁI NÓ KHÔNG CANH: rằng `menu_hero.dart` và `menu_topics.dart` có THẬT SỰ gọi
// hàm này hay không. Muốn canh điều đó phải dựng ContentProvider +
// SessionProvider, mà `test/` chưa có harness nào cho màn Menu. Nếu một ngày có
// harness ấy, đó là chỗ đặt phép đo chiều cao hero thật — đừng nhân đôi ở đây.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/presentation/theme/app_space.dart';

/// Máy thực địa: THẤP HƠN khung bản vẽ 390×844.
const Size _shortPhone = Size(360, 800);

/// Máy cao hơn khung bản vẽ — nhánh còn lại của phép quy đổi.
const Size _tallPhone = Size(412, 915);

/// Máy bảng — chỉ để chạm trần clamp.
const Size _tablet = Size(800, 1280);

void main() {
  /// Đặt cỡ màn mà CÂY WIDGET nhìn thấy.
  ///
  /// ⚠ KHÔNG DÙNG `tester.binding.setSurfaceSize` — nó KHÔNG tới được
  /// `MediaQuery`. Đã đo: sau `setSurfaceSize(Size(360, 800))` thì
  /// `MediaQuery.sizeOf` trong cây vẫn trả về `Size(800, 600)` mặc định.
  ///
  /// Cái bẫy nằm ở chỗ nó THẤT BẠI IM LẶNG: một test đặt cỡ màn rồi kiểm một
  /// con số KHÔNG phụ thuộc cỡ màn sẽ xanh, và cả file trông như đang chạy ở
  /// đúng khung bản vẽ trong khi nó chạy ở 800×600. `signature_screen_test.dart`
  /// đã sống như vậy một thời gian, và chỉ lộ ra khi `gateTop` bắt đầu đọc
  /// MediaQuery thật.
  ///
  /// `tester.view.physicalSize` là đường đúng, và nó tính bằng pixel VẬT LÝ nên
  /// phải nhân devicePixelRatio.
  void useScreen(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = size * 3.0;
    addTearDown(tester.view.reset);
  }

  /// Đọc hệ số từ trong một cây widget thật, vì nó phụ thuộc MediaQuery.
  Future<double> scaleAt(WidgetTester tester, Size size) async {
    useScreen(tester, size);

    late double scale;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          scale = DesignSize.verticalScale(context);
          return const SizedBox.shrink();
        }),
      ),
    );
    return scale;
  }

  group('verticalScale', () {
    testWidgets('ở đúng khung bản vẽ thì bằng 1 — không đổi gì cả',
        (tester) async {
      final scale = await scaleAt(tester, const Size(390, 844));

      expect(scale, moreOrLessEquals(1.0, epsilon: 0.0001),
          reason: 'Ở 390×844 mọi con số phải trả về ĐÚNG giá trị bản vẽ. Nếu '
              'test này đỏ thì mẫu số đã bị đổi, và mọi màn dùng hàm này đang '
              'lệch khỏi bản vẽ ngay tại cỡ máy nó được đo.');
    });

    testWidgets('máy thấp hơn ⇒ co lại theo đúng chiều cao', (tester) async {
      final scale = await scaleAt(tester, _shortPhone);

      // 800 / 844
      expect(scale, moreOrLessEquals(0.9479, epsilon: 0.001));
    });

    testWidgets('máy cao hơn ⇒ giãn ra theo đúng chiều cao', (tester) async {
      final scale = await scaleAt(tester, _tallPhone);

      // 915 / 844
      expect(scale, moreOrLessEquals(1.0841, epsilon: 0.001));
    });

    testWidgets('máy bảng chạm trần clamp', (tester) async {
      final scale = await scaleAt(tester, _tablet);

      // 1280 / 844 = 1.517 ⇒ bị chặn ở 1.12. Không có trần thì cụm chữ của
      // Poster rơi xuống quá nửa dưới và thôi đọc ra là một tấm áp phích.
      expect(scale, moreOrLessEquals(1.12, epsilon: 0.0001));
    });
  });

  group('những con số của bản vẽ, quy về máy thực địa 360×800', () {
    testWidgets('hero Menu và lưới thẻ', (tester) async {
      final scale = await scaleAt(tester, _shortPhone);

      // 580 × 0.9479 = 549.8  ·  215 × 0.9479 = 203.8
      expect(DesignSize.menuHero * scale, moreOrLessEquals(549.8, epsilon: 0.5));
      expect(DesignSize.cardGrid * scale, moreOrLessEquals(203.8, epsilon: 0.5));
    });

    testWidgets('hero giữ đúng 68.7% chiều cao màn như bản vẽ', (tester) async {
      final scale = await scaleAt(tester, _shortPhone);

      // Đây là toàn bộ lý do hero được quy đổi: bản vẽ lập luận về nó bằng TỈ
      // LỆ ("~69% màn với đúng một nút"), nên tỉ lệ mới là thứ phải giữ, không
      // phải con số 580. Giữ 580 trên máy 800 cho ra 72.5%.
      final fraction = DesignSize.menuHero * scale / _shortPhone.height;
      expect(fraction, moreOrLessEquals(580 / 844, epsilon: 0.001));
    });

    testWidgets('neo cụm chữ của hai màn khoảnh khắc', (tester) async {
      final scale = await scaleAt(tester, _shortPhone);

      // 200 × 0.9479 = 189.6 — cùng con số mà signature_screen_test ghim từ
      // phía widget. Hai chỗ đo cùng một thứ ở hai tầng khác nhau, cố ý.
      expect(DesignSize.gateTop * scale, moreOrLessEquals(189.6, epsilon: 0.5));
    });
  });

  group('quan hệ 215 : 580 — thứ dễ gãy nhất', () {
    test('tỉ lệ lưới thẻ trên hero đúng bằng tỉ lệ .zhero.near trên .zhero', () {
      // Bản vẽ KHÔNG bịa tỉ lệ mới cho màn Khu vực: 178 : 480 = 215 : 580.
      // Nếu ai đó chỉnh một trong bốn con số này cho "vừa mắt", quan hệ ấy đứt
      // mà không màn nào kêu lên — nên nó được ghim ở đây.
      expect(DesignSize.cardGrid / DesignSize.menuHero,
          moreOrLessEquals(DesignSize.nearZone / DesignSize.zoneHero,
              epsilon: 0.002));
    });

    testWidgets('tỉ lệ đó KHÔNG đổi theo cỡ máy', (tester) async {
      final short = await scaleAt(tester, _shortPhone);
      final tall = await scaleAt(tester, _tallPhone);

      double ratio(double s) =>
          (DesignSize.cardGrid * s) / (DesignSize.menuHero * s);

      expect(ratio(short), moreOrLessEquals(ratio(tall), epsilon: 0.0001),
          reason: 'Hero và lưới thẻ phải đi qua CÙNG một hệ số. Nếu một trong '
              'hai được scale mà cái kia không, tỉ lệ 0.371 đứt và thẻ thôi '
              'đọc ra là "cùng họ với hero, nhỏ hơn một bậc".');
    });
  });
}
