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
// việc cả hai cùng đọc [AppRatio.gateTop] — một thoả thuận, không phải một cơ
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

import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/widgets/signature_screen.dart';

const Size _phone = Size(390, 844);

Widget _host(Widget child, {MuseumThemeId theme = MuseumThemeId.light}) =>
    MaterialApp(theme: buildMuseumTheme(theme), home: child);

/// Poster: cụm chữ mang các hàng thao tác ngay bên dưới.
Widget _poster() => const SignatureScreen(
      imagePath: null, // ⇒ gradient dự phòng; test không đụng đĩa
      veil: SignatureVeil.poster,
      kicker: 'Bảo tàng',
      title: 'Chứng tích Chiến tranh',
      poweredBy: true,
    );

/// Cảm ơn: cụm chữ mang thêm câu dặn dò, và hàng thao tác ghim ở đáy.
Widget _farewell({String lede = 'Chuyến tham quan đã kết thúc.'}) =>
    SignatureScreen(
      imagePath: null,
      veil: SignatureVeil.backdrop,
      kicker: 'Cảm ơn',
      title: 'quý khách',
      lede: lede,
      bottom: const SizedBox(height: 66),
    );

void main() {
  setUp(() {
    // Khoá cỡ màn để phép so vị trí có nghĩa. 390×844 là khung bản vẽ được đo.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<double> topOf(WidgetTester tester, Widget screen, String text) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(screen));
    return tester.getTopLeft(find.text(text)).dy;
  }

  group('cặp đối xứng Poster ↔ Cảm ơn', () {
    testWidgets('cụm chữ của hai màn rơi đúng cùng một độ cao', (tester) async {
      final poster = await topOf(tester, _poster(), 'Bảo tàng');
      final farewell = await topOf(tester, _farewell(), 'Cảm ơn');

      expect(farewell, moreOrLessEquals(poster, epsilon: 0.5),
          reason: 'Dòng nhỏ của hai màn lệch nhau ${(farewell - poster).abs()}dp. '
              'Cả hai phải neo ở AppRatio.gateTop — nếu một màn vừa được thêm '
              'một khối phía trên cụm chữ, hãy neo nó bằng Positioned thay vì '
              'để nó đẩy cụm chữ xuống.');
    });

    testWidgets('neo đúng AppRatio.gateTop tính từ MÉP TRÊN MÁY', (tester) async {
      final top = await topOf(tester, _poster(), 'Bảo tàng');

      // Đo từ mép trên thiết bị, KHÔNG phải từ vùng an toàn: bản vẽ đo
      // `--gate-top` từ đỉnh khung máy, và ảnh nền cũng chạm mép trên.
      expect(top, moreOrLessEquals(_phone.height * AppRatio.gateTop, epsilon: 1),
          reason: 'Cụm chữ không còn neo ở AppRatio.gateTop. Nếu đây là thay '
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

  group('hai hòn đảo luôn tối', () {
    testWidgets('giữ preset tối kể cả khi app đang ở theme sáng',
        (tester) async {
      await tester.binding.setSurfaceSize(_phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
      await tester.binding.setSurfaceSize(_phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(_poster(), theme: MuseumThemeId.dark));

      final inside = tester.element(find.text('Bảo tàng'));
      expect(inside.tokens.surface, MuseumTokens.dark.surface);
    });
  });
}
