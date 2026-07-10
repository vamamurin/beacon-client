// Destination: test/zone_screen_test.dart
// Run with: flutter test test/zone_screen_test.dart
//
// TIÊU CHÍ NGHIỆM THU của Step 4: màn hình 2 dựng được từ hai provider giả,
// KHÔNG Bluetooth, KHÔNG audio engine, KHÔNG path_provider, KHÔNG
// Injection.build(). Nếu bạn phải mock thêm bất cứ thứ gì, refactor CHƯA xong —
// và thứ phải mock chính là chỗ còn rò rỉ.
//
// TỪ STEP 5, các test này còn khoá một thứ nữa: HAI HỌ TOKEN. Tiêu đề thẻ zone
// nằm TRÊN ẢNH, nên nó phải dùng `inkOnImage`, không phải `ink`. Ở dark theme
// hai giá trị đó trùng nhau (đều trắng), nên chọn nhầm là VÔ HÌNH. Chỉ light
// theme mới lộ ra. Vì vậy phải có một test chạy ở light theme — nếu không, cả
// công việc phân họ token chỉ được bảo vệ bằng trí nhớ của người viết.
//
// MaterialApp BẮT BUỘC phải nhận `theme: buildMuseumTheme(...)`. Không có nó,
// MuseumTokens extension vắng mặt và `context.tokens` sẽ ném. Đó là hành vi cố
// ý: một màn hình không có token là lỗi cấu hình, không phải trạng thái cần xử
// lý duyên dáng.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/audio_clip_info.dart';
import 'package:beacon_client/domain/models/localized_text.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/zone/zone_screen.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

// ============================================================================
// Fakes. Tách sang test/fakes/ khi màn hình thứ hai cần dùng lại.
// ============================================================================

/// Repository trong bộ nhớ. Không I/O, không bundle, không parse.
class FakeZoneRepository implements IZoneRepository {
  FakeZoneRepository({List<ZoneInfo> zones = const [], this.config})
      : _zones = zones;

  final List<ZoneInfo> _zones;

  @override
  final MuseumConfig? config;

  @override
  Future<void> preWarm() async {}

  @override
  bool get isWarmed => true;

  @override
  String? get lastError => null;

  @override
  List<String> get warnings => const [];

  @override
  ZoneInfo? zoneByMajor(int major) {
    for (final z in _zones) {
      if (z.major == major) return z;
    }
    return null;
  }

  @override
  List<ZoneInfo> get allZones => List.unmodifiable(_zones);
}

/// Zone tối thiểu. `exhibits: const []` cố ý — màn 2 chỉ đọc `.length`, và giữ
/// fixture khỏi phải dựng ExhibitInfo + AudioTrack là một phần của mục tiêu:
/// test màn 2 không được phụ thuộc vào hình dạng của tầng audio.
ZoneInfo _zone({int major = 1, String name = 'Khu Thử'}) {
  return ZoneInfo(
    major: major,
    id: 'khu-thu',
    name: LocalizedText({'vi': name}),
    welcomeText: LocalizedText({'vi': 'Chào mừng'}),
    heroImagePath: 'images/zones/khu-thu/hero.jpg',
    heroImageBlurredPath: 'images/zones/khu-thu/hero_blur.jpg',
    introAudio: const AudioClipInfo(tracks: {}),
    exhibits: const [],
  );
}

/// Dựng cây widget tối thiểu quanh ZoneScreen.
Widget _app({
  required FakeZoneRepository repo,
  required Stream<ZoneStatus> status,
  required ZoneStatus initial,
  MuseumThemeId themeId = MuseumThemeId.dark,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ContentProvider>(
        create: (_) => ContentProvider(
          repository: repo,
          // null -> HeroImage tự vẽ gradient fallback, không chạm file system.
          imagePathResolver: (_) => null,
        ),
      ),
      ChangeNotifierProvider<ZoneProvider>(
        create: (_) => ZoneProvider(status: status, initial: initial),
      ),
    ],
    child: MaterialApp(
      // Bắt buộc: cung cấp MuseumTokens extension. Thiếu nó -> context.tokens ném.
      theme: buildMuseumTheme(themeId),
      home: const ZoneScreen(),
    ),
  );
}

void main() {
  group('rendering, with no pipeline behind it', () {
    testWidgets('renders the current zone card', (tester) async {
      final zone = _zone();
      final repo = FakeZoneRepository(zones: [zone]);

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus(zone: zone),
      ));
      await tester.pump();

      expect(find.text('Khu Thử'), findsOneWidget);
      expect(find.text('0 hiện vật · Đang ở đây'), findsOneWidget);
      expect(find.text('ĐANG QUÉT KHÔNG GIAN'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows the radar standby when no zone is confirmed',
        (tester) async {
      final repo = FakeZoneRepository();

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus.standby,
      ));
      await tester.pump();

      expect(find.text('ĐANG QUÉT KHÔNG GIAN'), findsOneWidget);

      // BẮT BUỘC: _RadarStandby giữ một AnimationController.repeat(). Nếu test
      // kết thúc khi widget còn mounted, flutter_test báo "A Ticker was active
      // when the test ended". KHÔNG dùng pumpAndSettle() ở màn này — animation
      // lặp vô hạn nên nó sẽ chờ tới timeout.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the arbiter drives screen 2, and only screen 2', () {
    testWidgets('swaps the card in place when the zone changes', (tester) async {
      final a = _zone(major: 1, name: 'Khu A');
      final b = _zone(major: 2, name: 'Khu B');
      final repo = FakeZoneRepository(zones: [a, b]);
      final ctrl = StreamController<ZoneStatus>();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_app(
        repo: repo,
        status: ctrl.stream,
        initial: ZoneStatus(zone: a),
      ));
      await tester.pump();
      expect(find.text('Khu A'), findsOneWidget);

      // KHÔNG pop, KHÔNG push — thẻ tự đổi tại chỗ.
      ctrl.add(ZoneStatus(zone: b));
      await tester.pump();
      await tester.pump();

      expect(find.text('Khu B'), findsOneWidget);
      expect(find.text('Khu A'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('falls back to standby when the zone is lost', (tester) async {
      final a = _zone();
      final repo = FakeZoneRepository(zones: [a]);
      final ctrl = StreamController<ZoneStatus>();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_app(
        repo: repo,
        status: ctrl.stream,
        initial: ZoneStatus(zone: a),
      ));
      await tester.pump();
      expect(find.text('Khu Thử'), findsOneWidget);

      ctrl.add(ZoneStatus.standby); // walked into a corridor
      await tester.pump();
      await tester.pump();

      expect(find.text('ĐANG QUÉT KHÔNG GIAN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // ==========================================================================
  // Step 5 — token families. This is the only place the split is verifiable
  // without human eyes on a light-theme build.
  // ==========================================================================

  group('token families', () {
    testWidgets('card title uses inkOnImage, not ink, in LIGHT theme',
        (tester) async {
      final zone = _zone();
      final repo = FakeZoneRepository(zones: [zone]);

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus(zone: zone),
        themeId: MuseumThemeId.light,
      ));
      await tester.pump();

      final title = tester.widget<Text>(find.text('Khu Thử'));

      // Tiêu đề nằm TRÊN ẢNH hiện vật, dưới tourCardVeil (đen 82%). Ảnh không
      // sáng lên khi bật light theme. Nếu ai đó "sửa" thành t.ink, chữ sẽ là
      // #141414 trên nền đen — vô hình. Ở dark theme cả hai token đều trắng nên
      // lỗi không lộ ra; chỉ test này bắt được.
      expect(title.style!.color, MuseumTokens.light.inkOnImage);
      expect(title.style!.color, isNot(MuseumTokens.light.ink));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('card meta uses mutedOnImage in LIGHT theme', (tester) async {
      final zone = _zone();
      final repo = FakeZoneRepository(zones: [zone]);

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus(zone: zone),
        themeId: MuseumThemeId.light,
      ));
      await tester.pump();

      final meta = tester.widget<Text>(find.text('0 hiện vật · Đang ở đây'));
      expect(meta.style!.color, MuseumTokens.light.mutedOnImage);
      expect(meta.style!.color, isNot(MuseumTokens.light.inkMuted));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('radar text follows the theme (it sits on surface, not an image)',
        (tester) async {
      final repo = FakeZoneRepository();

      // Dark: kicker trắng.
      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus.standby,
      ));
      await tester.pump();
      var kicker = tester.widget<Text>(find.text('ĐANG QUÉT KHÔNG GIAN'));
      expect(kicker.style!.color, MuseumTokens.dark.ink);
      await tester.pumpWidget(const SizedBox());

      // Light: kicker phải ĐỔI sang mực đen. Đây là mặt đối xứng của hai test
      // trên — chữ trên `surface` PHẢI đi theo theme, đúng như chữ trên ảnh
      // PHẢI KHÔNG đi theo.
      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus.standby,
        themeId: MuseumThemeId.light,
      ));
      await tester.pump();
      kicker = tester.widget<Text>(find.text('ĐANG QUÉT KHÔNG GIAN'));
      expect(kicker.style!.color, MuseumTokens.light.ink);
      expect(kicker.style!.color, isNot(MuseumTokens.light.inkOnImage));

      await tester.pumpWidget(const SizedBox());
    });
  });
}