// Destination: test/presentation/exhibits/exhibit_detail_gallery_test.dart
// Run with: flutter test test/presentation/exhibits/exhibit_detail_gallery_test.dart
//
// Dải ảnh của màn 4. Hai hợp đồng được khoá ở đây:
//
//   1. NHIỀU ẢNH ⇒ VUỐT ĐƯỢC ĐÚNG BẤY NHIÊU LẦN. AK-47 trong bundle mock có 3
//      ảnh (1 chính + 2 phụ); vuốt sang trái ba lần phải dừng ở ảnh 3, không
//      vòng về ảnh 1.
//   2. MỘT ẢNH ⇒ KHÔNG CÓ PageView. Đây không phải tối ưu vặt: một viewport
//      cuộn được mà không cuộn đi đâu vẫn khai scrollLeft/scrollRight với
//      screen reader — hứa một thao tác không tồn tại.
//
// Vị trí hiện tại được đọc qua SEMANTICS ("Ảnh 2 trên 3") chứ không qua màu
// chấm: chấm là trang trí, câu nói với khách khiếm thị mới là hợp đồng.
//
// imagePathResolver: (_) => null ⇒ HeroImage rơi về gradient fallback, không
// đụng đĩa. Ảnh thật không cần tồn tại để kiểm tra hành vi vuốt.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/presentation/exhibits/exhibit_detail_screen.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/language_controller.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';

import '../../fakes/fake_audio_engine.dart';

/// Repository đã warm SẴN, dựng trong [setUp].
///
/// ⚠ KHÔNG gọi `preWarm()` bên trong callback của `testWidgets`:
/// `MockZoneRepository` mô phỏng độ trễ đĩa bằng `Future.delayed`, mà trong
/// `testWidgets` đồng hồ là GIẢ — timer chỉ chạy khi có `pump()`. Await nó ở
/// đó là treo vĩnh viễn, không phải fail. `setUp` chạy ở zone thật nên an toàn.
late MockZoneRepository _repo;

/// Cây widget tối thiểu quanh màn 4: repository mock (đi qua ManifestParser
/// thật) + engine/tai nghe giả. Không Bluetooth, không plugin, không Injection.
Widget _app({required int major, required int minor}) {
  final repo = _repo;
  final engine = FakeAudioEngine();
  final controller = TourAudioController(
    repository: repo,
    engine: engine,
    headphones: FakeHeadphoneMonitor(connected: true),
    uriResolver: (p) => Uri.parse('file:///bundle/$p'),
    language: () => 'vi',
    onChime: () {},
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ContentProvider>(
        create: (_) => ContentProvider(
          repository: repo,
          imagePathResolver: (_) => null,
          language: LanguageController(available: const ['vi'], fallback: 'vi'),
        ),
      ),
      ChangeNotifierProvider<AudioProvider>(
        create: (_) => AudioProvider(engine: engine, controller: controller),
      ),
    ],
    child: MaterialApp(
      theme: buildMuseumTheme(MuseumThemeId.dark),
      home: ExhibitDetailScreen(major: major, minor: minor),
    ),
  );
}

/// Tìm widget [Semantics] theo nhãn KHAI BÁO trong cây widget.
///
/// KHÔNG dùng `find.bySemanticsLabel`: finder đó đọc `renderObject
/// .debugSemantics`, chỉ tồn tại ở render object thực sự SỞ HỮU một
/// SemanticsNode — tức phải là một semantics boundary. `Semantics(button: true)`
/// mặc định `container: false` nên không sở hữu node nào (nhãn của nó gộp vào
/// node của tổ tiên gần nhất), và finder trả về rỗng dù TalkBack vẫn đọc đúng.
/// Ở đây thứ cần khoá là HỢP ĐỒNG ta khai báo, nên đọc thẳng `properties`.
Finder _semantics(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
      description: 'Semantics(label: "$label")',
    );

/// Giá trị semantics của thẻ ảnh — "Ảnh 2 trên 3". Null nếu không có dải ảnh.
String? _galleryValue(WidgetTester tester) {
  final finder = _semantics('Dải ảnh hiện vật');
  if (finder.evaluate().isEmpty) return null;
  return (finder.evaluate().single.widget as Semantics).properties.value;
}

void main() {
  setUp(() async {
    _repo = MockZoneRepository(simulatedLatency: Duration.zero);
    await _repo.preWarm();
  });

  testWidgets('AK-47 (3 ảnh): vuốt sang trái lật ảnh, hết ảnh thì dừng',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(major: 1, minor: 1));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(_galleryValue(tester), 'Ảnh 1 trên 3');

    // Quãng vuốt tính theo BỀ NGANG THẬT của trang, không phải hằng số px:
    // thẻ ảnh rộng ~252 trong viewport test 800×600, nên `Offset(-400, 0)`
    // là 1.6 trang và PageView chốt thẳng sang trang 3. 0.6 trang là con số
    // duy nhất đúng ở mọi cỡ màn: quá nửa ⇒ chốt sang trang kế, không hơn.
    Future<void> swipe(double pages) async {
      final w = tester.getSize(find.byType(PageView)).width;
      await tester.drag(find.byType(PageView), Offset(pages * w, 0));
      await tester.pumpAndSettle();
    }

    await swipe(-0.6);
    expect(_galleryValue(tester), 'Ảnh 2 trên 3');

    await swipe(-0.6);
    expect(_galleryValue(tester), 'Ảnh 3 trên 3');

    // Ảnh cuối: vuốt tiếp KHÔNG vòng về đầu.
    await swipe(-0.6);
    expect(_galleryValue(tester), 'Ảnh 3 trên 3');

    // ...và vuốt ngược quay lại được.
    await swipe(0.6);
    expect(_galleryValue(tester), 'Ảnh 2 trên 3');

    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chạm vào ảnh mở màn xem lớn; lật trong đó thì thẻ nhỏ theo kịp',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(major: 1, minor: 1));
    await tester.pumpAndSettle();

    await tester.tap(_semantics('Xem ảnh lớn'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.text('1/3'), findsOneWidget);

    // Lật sang ảnh 2 TRONG màn xem lớn. Cú kéo này cũng khoá luôn hợp đồng
    // `panEnabled: _zoomed`: nếu InteractiveViewer giành mất cú kéo ngang khi
    // chưa phóng to, PageView không lật và bộ đếm đứng yên ở "1/3".
    final viewer = find.byType(InteractiveViewer).first;
    await tester.drag(viewer, Offset(-tester.getSize(viewer).width * 0.6, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(_semantics('Đóng ảnh'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);

    // Hợp đồng: thẻ nhỏ KHÔNG quay về ảnh 1.
    expect(_galleryValue(tester), 'Ảnh 2 trên 3');

    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Kar98 (1 ảnh): không có PageView, không có chỉ báo dải ảnh',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(major: 1, minor: 2));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(_semantics('Dải ảnh hiện vật'), findsNothing);

    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
