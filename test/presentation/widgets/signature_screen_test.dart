// Destination: test/presentation/widgets/signature_screen_test.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// CẶP ĐỐI XỨNG — file này canh MỘT ý đồ thiết kế, không canh một bố cục
// ═══════════════════════════════════════════════════════════════════════════
//
// Màn Poster và màn Cảm ơn là hai đầu của một chuyến đi, và toàn bộ ý nghĩa của
// việc chúng dùng chung khuôn nằm ở một câu: *khách phải nhận ra mình đã quay
// về đúng nơi bắt đầu.* Nhận ra được thì cụm chữ phải rơi ĐÚNG MỘT CHỖ trên cả
// hai màn — không phải "trông na ná".
//
// Đó là một tính chất đo được, và nó là thứ dễ mất nhất: chỉ cần một trong hai
// màn thêm một `SizedBox` phía trên, hoặc đổi `height` của [AppText.posterKicker],
// là sự đối xứng đi mất mà không có gì kêu lên. Trước file này, cái canh nó là
// việc cả hai cùng đọc [DesignSize.gateTop] — một thoả thuận, không phải một cơ
// chế.
//
// FILE NÀY THAY `gate_layout_test.dart` ĐÃ XOÁ. Test cũ đo hình học của collage
// hai khung ảnh ở màn chào — một bố cục không còn tồn tại. Nó chết cùng bố cục
// đó, và đúng ra phải chết: một test kiểm những con số của một thiết kế đã bị
// thay thì nó không bảo vệ gì cả, nó chỉ chặn đường.
//
// KHÔNG CẦN PROVIDER NÀO: [SignatureScreen] nhận chuỗi thuần, mọi thứ phụ thuộc
// bundle đã được hai màn gọi nó giải sẵn. Đó cũng là một tính chất đáng giữ —
// nếu một ngày file test này phải dựng ContentProvider, nghĩa là khuôn đã hút
// dữ liệu vào trong nó.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/widgets/signature_screen.dart';

/// Khung của bản vẽ. Ở đúng cỡ này mọi hệ số quy đổi bằng 1, nên các phép so
/// vị trí bên dưới đọc thẳng ra con số của bản vẽ.
const Size _phone = Size(390, 844);

/// Máy thực địa: THẤP HƠN khung bản vẽ. Đây là cỡ mà các con số tuyệt đối bắt
/// đầu nói dối về bố cục, nên nó có mặt trong file này.
const Size _shortPhone = Size(360, 800);

Widget _host(Widget child, {MuseumThemeId theme = MuseumThemeId.light}) =>
    MaterialApp(theme: buildMuseumTheme(theme), home: child);

/// Poster: cụm chữ mang các hàng thao tác ngay bên dưới.
Widget _poster() => const SignatureScreen(
      imagePath: null, // ⇒ gradient dự phòng; test không đụng đĩa
      kind: SignatureKind.poster,
      kicker: 'Bảo tàng',
      title: 'Chứng tích Chiến tranh',
      poweredBy: true,
      rows: [
        AppRow(label: 'Tham quan', lead: true),
        AppRow(label: 'Giới thiệu bảo tàng'),
        AppRow(label: 'Câu hỏi thường gặp'),
      ],
    );

/// Cảm ơn: cụm chữ mang thêm câu dặn dò, và hàng thao tác ghim ở đáy.
Widget _farewell({String lede = 'Chuyến tham quan đã kết thúc.'}) =>
    SignatureScreen(
      imagePath: null,
      kind: SignatureKind.farewell,
      kicker: 'Cảm ơn',
      title: 'quý khách',
      lede: lede,
      // Hàng THẬT, không phải một `SizedBox` giữ chỗ: hàng "XONG" phải phóng
      // đúng bằng hàng "THAM QUAN" của màn kia, và một ô đệm cứng thì không
      // canh được điều đó.
      bottom: const AppRow(label: 'Xong', lead: true),
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  /// Đặt cỡ màn mà CÂY WIDGET nhìn thấy — xem [pump].
  void useScreen(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = size * 3.0;
    addTearDown(tester.view.reset);
  }

  /// Dựng màn ở một cỡ máy cụ thể.
  ///
  /// ⚠ ĐÃ TỪNG DÙNG `tester.binding.setSurfaceSize`, VÀ NÓ KHÔNG LÀM GÌ CẢ.
  /// Đo được: sau `setSurfaceSize(Size(390, 844))` thì `MediaQuery.sizeOf`
  /// trong cây vẫn trả `Size(800, 600)` mặc định.
  ///
  /// Suốt thời gian đó file này xanh, vì mọi thứ nó kiểm đều là hằng số không
  /// phụ thuộc cỡ màn — dòng chú thích "khoá cỡ màn 390×844" mô tả một điều
  /// không xảy ra. Lỗi chỉ lộ ra khi [DesignSize.gateTop] bắt đầu quy theo
  /// chiều cao máy thật.
  ///
  /// Bài học chung: một lệnh setup thất bại IM LẶNG thì test không bắt được nó
  /// — chỉ có một phép đo mới bắt được.
  Future<void> pump(WidgetTester tester, Widget screen,
      {Size size = _phone}) async {
    useScreen(tester, size);
    await tester.pumpWidget(_host(screen));
  }

  Future<double> topOf(WidgetTester tester, Widget screen, String text,
      {Size size = _phone}) async {
    await pump(tester, screen, size: size);
    return tester.getTopLeft(find.text(text)).dy;
  }

  group('cặp đối xứng Poster ↔ Cảm ơn', () {
    testWidgets('cụm chữ của hai màn rơi đúng cùng một độ cao', (tester) async {
      final poster = await topOf(tester, _poster(), 'Bảo tàng');
      final farewell = await topOf(tester, _farewell(), 'Cảm ơn');

      expect(farewell, moreOrLessEquals(poster, epsilon: 0.5),
          reason: 'Dòng nhỏ của hai màn lệch nhau ${(farewell - poster).abs()}dp. '
              'Cả hai phải neo ở DesignSize.gateTop — nếu một màn vừa được thêm '
              'một khối phía trên cụm chữ, hãy neo nó bằng Positioned thay vì '
              'để nó đẩy cụm chữ xuống.');
    });

    testWidgets('neo đúng DesignSize.gateTop tính từ MÉP TRÊN MÁY', (tester) async {
      final top = await topOf(tester, _poster(), 'Bảo tàng');

      // Đo từ mép trên thiết bị, KHÔNG phải từ vùng an toàn: bản vẽ đo
      // `--gate-top` từ đỉnh khung máy, và ảnh nền cũng chạm mép trên.
      expect(top, moreOrLessEquals(DesignSize.gateTop, epsilon: 1),
          reason: 'Cụm chữ không còn neo ở DesignSize.gateTop. Nếu đây là thay '
              'đổi có chủ đích thì sửa hằng số, đừng sửa con số ở test — hằng '
              'số là thứ hai màn cùng đọc.');
    });

    testWidgets('vị trí cụm chữ KHÔNG phụ thuộc độ dài câu dặn dò',
        (tester) async {
      // Bản trước của màn Cảm ơn căn giữa bằng hai `Spacer()`, nên câu một dòng
      // và câu bốn dòng đẩy cụm chữ lệch nhau ~30dp. Không ai thiết kế như vậy;
      // đó là tác dụng phụ của việc dùng flex để định vị.
      final shortLede = await topOf(tester, _farewell(lede: 'Xong.'), 'Cảm ơn');
      final longLede = await topOf(
        tester,
        _farewell(
          lede: 'Chuyến tham quan đã kết thúc. Xin vui lòng gửi lại thiết bị '
              'tại quầy lễ tân. Chúc quý khách một ngày tốt lành. Hẹn gặp lại '
              'quý khách trong những triển lãm sắp tới của bảo tàng.',
        ),
        'Cảm ơn',
      );

      expect(longLede, moreOrLessEquals(shortLede, epsilon: 0.5),
          reason: 'Cụm chữ trôi ${(longLede - shortLede).abs()}dp khi câu dặn '
              'dò dài ra ⇒ nó đang được định vị bằng flex, không phải bằng neo.');
    });
  });

  group('nhịp dọc quy theo chiều cao máy', () {
    // Bản vẽ đo trên 390×844. Máy thực địa là 360×800 — THẤP HƠN, nên dp tuyệt
    // đối cho ra một cụm chữ đứng im trong khi khoảng thở dưới đáy tóp lại, và
    // ba hàng thao tác chiếm một phần màn khác hẳn bản vẽ. Ở một tấm áp phích
    // thì tỉ lệ LÀ nội dung; những con số dưới đây canh đúng chỗ đó.
    //
    // Số kỳ vọng viết thẳng, KHÔNG tính lại bằng chính công thức của code: một
    // test gọi lại `DesignSize.verticalScale` sẽ xanh kể cả khi công thức sai.

    testWidgets('máy thấp hơn khung vẽ ⇒ neo cụm chữ co theo', (tester) async {
      final top = await topOf(tester, _poster(), 'Bảo tàng',
          size: _shortPhone);

      // 200 × (800 / 844) = 189.6
      expect(top, moreOrLessEquals(189.6, epsilon: 1),
          reason: 'Neo không co theo chiều cao máy. Trên máy 800dp mà vẫn giữ '
              'đúng 200 thì cụm chữ tụt xuống thấp hơn bản vẽ về tỉ lệ, và '
              'khoảng thở dưới đáy — thứ làm poster ra poster — bị ăn mất.');
    });

    testWidgets('ba hàng phóng theo rowBoost', (tester) async {
      await pump(tester, _poster(), size: _shortPhone);

      final rows = find.byType(AppRow);
      expect(rows, findsNWidgets(3));

      // 66 × (800/844) × 1.15 = 71.9  ·  58 × (800/844) × 1.15 = 63.2
      expect(tester.getSize(rows.at(0)).height,
          moreOrLessEquals(71.9, epsilon: 0.5),
          reason: 'Hàng dẫn đường chính không còn phóng theo '
              'DesignSize.rowBoost.');
      expect(tester.getSize(rows.at(1)).height,
          moreOrLessEquals(63.2, epsilon: 0.5));
      expect(tester.getSize(rows.at(2)).height,
          moreOrLessEquals(63.2, epsilon: 0.5));
    });

    testWidgets('hàng dẫn đường của hai màn phóng BẰNG NHAU', (tester) async {
      await pump(tester, _poster(), size: _shortPhone);
      final poster = tester.getSize(find.byType(AppRow).first).height;

      await pump(tester, _farewell(), size: _shortPhone);
      final farewell = tester.getSize(find.byType(AppRow).first).height;

      expect(farewell, moreOrLessEquals(poster, epsilon: 0.1),
          reason: 'Hàng "XONG" và hàng "THAM QUAN" lệch nhau '
              '${(farewell - poster).abs()}dp. Hai màn là một cặp đối xứng — '
              'hệ số phải đến từ RowScale của khuôn chung, không phải từ một '
              'con số gõ lại ở từng màn.');
    });

    testWidgets('ở đúng khung bản vẽ thì neo trở lại tròn 200', (tester) async {
      // Bất biến ngược: hệ số chỉ được phép ĐỔI bố cục khi máy khác 844. Nếu
      // test này đỏ, nghĩa là rowBoost đã rò sang neo — xem doc `_buildBody`.
      final top = await topOf(tester, _poster(), 'Bảo tàng');
      expect(top, moreOrLessEquals(DesignSize.gateTop, epsilon: 0.5));
    });

    testWidgets('hàng NGOÀI hai màn khoảnh khắc giữ đúng số của bản vẽ',
        (tester) async {
      // Ngăn kéo không có RowScale nào phía trên ⇒ 58, y như bản vẽ. Đây là
      // toàn bộ lý do hệ số không được nướng vào AppSpace.row.
      useScreen(tester, _shortPhone);
      await tester.pumpWidget(_host(
        const Scaffold(body: AppRow(label: 'Cài đặt')),
      ));

      expect(tester.getSize(find.byType(AppRow)).height,
          moreOrLessEquals(AppSpace.row, epsilon: 0.1),
          reason: 'Hàng ngoài hai màn khoảnh khắc đã bị phóng theo. Hệ số phải '
              'do RowScale phát tại chỗ, không nằm trong AppSpace.');
    });
  });

  group('hai hòn đảo luôn tối', () {
    testWidgets('giữ preset tối kể cả khi app đang ở theme sáng',
        (tester) async {
      useScreen(tester, _phone);
      await tester.pumpWidget(_host(_poster(), theme: MuseumThemeId.light));

      // Đọc token TỪ BÊN TRONG cây con — đó mới là thứ các widget con thấy.
      final inside = tester.element(find.text('Bảo tàng'));
      expect(inside.tokens.surface, MuseumTokens.dark.surface,
          reason: 'Màn khoảnh khắc đã rơi theo theme sáng. Ở đây bức ảnh CHÍNH '
              'LÀ cái màn và chữ nằm trong ảnh: veil tan vào `surface`, nên '
              'preset sáng sẽ LÀM SÁNG đáy ảnh đúng chỗ cụm tiêu đề ngồi.');
      expect(inside.tokens.ink, MuseumTokens.dark.ink);
    });

    testWidgets('ở theme tối thì không có gì đổi', (tester) async {
      useScreen(tester, _phone);
      await tester.pumpWidget(_host(_poster(), theme: MuseumThemeId.dark));

      final inside = tester.element(find.text('Bảo tàng'));
      expect(inside.tokens.surface, MuseumTokens.dark.surface);
    });
  });
}
