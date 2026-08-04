// Destination: test/zone_screen_test.dart
// Run with: flutter test test/zone_screen_test.dart
//
// TIÊU CHÍ NGHIỆM THU của Step 4: màn hình 2 dựng được từ các provider giả,
// KHÔNG Bluetooth, KHÔNG audio engine, KHÔNG path_provider, KHÔNG
// Injection.build(). Nếu bạn phải mock thêm bất cứ thứ gì, refactor CHƯA xong.
//
// TỪ STEP 5, các test này còn khoá HAI HỌ TOKEN. Tiêu đề thẻ zone nằm TRÊN ẢNH,
// nên nó phải dùng `inkOnImage`, không phải `ink`. Ở dark theme hai giá trị đó
// trùng nhau (đều trắng), nên chọn nhầm là VÔ HÌNH. Chỉ light theme mới lộ ra.
//
// TỪ C3, màn 2 là RANKING: zone kích hoạt ghim đầu ("Đang ở đây"), các zone
// nghe thấy khác xếp dưới đánh số theo khoảng cách (NearbyZonesTracker). Radar
// chỉ hiện khi KHÔNG nghe thấy gì. ZoneProvider giờ nhận thêm ranking stream +
// repository; các test dưới drive nó bằng Stream.value(<NearbyZone>[]) cho danh
// sách gần kề (rỗng = chỉ có zone ghim, đúng hành vi "một thẻ" như trước C3).
//
// MaterialApp BẮT BUỘC nhận `theme: buildMuseumTheme(...)` — thiếu nó
// context.tokens ném (cố ý: màn không token là lỗi cấu hình).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/interfaces/i_settings_store.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/audio_clip_info.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/localized_text.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/language_controller.dart';
import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/providers/tour_progress_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/zone/zone_screen.dart';
import 'package:beacon_client/services/nearby_zones_tracker.dart';
import 'package:beacon_client/services/tour_progress_service.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

// ============================================================================
// Fakes.
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

/// In-memory settings store (distance-debug toggle off by default).
class FakeSettingsStore implements ISettingsStore {
  FakeSettingsStore({this.showDistance = false});
  String? _themeId;
  bool showDistance;
  String? _url;
  double? _hours;
  DateTime? _lastSync;

  @override
  String? get themeId => _themeId;
  @override
  Future<void> setThemeId(String id) async => _themeId = id;
  @override
  bool get showDistanceDebug => showDistance;
  @override
  Future<void> setShowDistanceDebug(bool value) async => showDistance = value;

  // Nhóm D — cấu hình server + auto-sync (màn 2 không dùng, chỉ cần thoả interface).
  @override
  String? get syncBaseUrlOverride => _url;
  @override
  Future<void> setSyncBaseUrlOverride(String? value) async => _url = value;
  @override
  double? get autoSyncHoursOverride => _hours;
  @override
  Future<void> setAutoSyncHoursOverride(double? value) async => _hours = value;
  @override
  DateTime? get lastSuccessfulSyncAt => _lastSync;
  @override
  Future<void> setLastSuccessfulSyncAt(DateTime value) async =>
      _lastSync = value;
}

/// Zone tối thiểu. `exhibits: const []` — màn 2 chỉ đọc `.length`.
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
  Stream<List<NearbyZone>>? ranking,
  List<NearbyZone> initialRanking = const [],
  bool showDistance = false,
  MuseumThemeId themeId = MuseumThemeId.dark,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ContentProvider>(
        create: (_) => ContentProvider(
          repository: repo,
          imagePathResolver: (_) => null,
          language: LanguageController(available: const ['vi'], fallback: 'vi'),
        ),
      ),
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) =>
            SettingsProvider(store: FakeSettingsStore(showDistance: showDistance)),
      ),
      ChangeNotifierProvider<ZoneProvider>(
        create: (_) => ZoneProvider(
          status: status,
          initial: initial,
          ranking: ranking ?? const Stream<List<NearbyZone>>.empty(),
          initialRanking: initialRanking,
          repository: repo,
        ),
      ),
      // Màn khu vực giờ mang thêm hàng chrome (nút menu) và thẻ gợi ý "đã đi
      // hết các khu". Service thật cần bốn stream nguồn; ở đây chỉ cần một
      // TourProgress im lặng — mọi test trong file này nói về xếp hạng khu, và
      // với tiến trình rỗng thì thẻ gợi ý không dựng gì cả.
      ChangeNotifierProvider<TourProgressProvider>(
        create: (_) => TourProgressProvider(TourProgressService(
          sessionState: const Stream<SessionState>.empty(),
          zoneEvents: const Stream<ZoneEvent>.empty(),
          audioState: const Stream<AudioQueueState>.empty(),
          audioCompleted: const Stream<AudioTrackRef>.empty(),
          totalZones: () => 0,
          totalExhibits: () => 0,
        )),
      ),
    ],
    child: MaterialApp(
      theme: buildMuseumTheme(themeId),
      home: const ZoneScreen(),
    ),
  );
}

void main() {
  group('rendering, with no pipeline behind it', () {
    testWidgets('renders the current (pinned) zone card', (tester) async {
      final zone = _zone();
      final repo = FakeZoneRepository(zones: [zone]);

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus(zone: zone),
      ));
      await tester.pump();

      expect(find.text('Khu Thử'), findsOneWidget);
      expect(find.text('ĐANG Ở ĐÂY'), findsOneWidget);
      expect(find.text('0 hiện vật'), findsOneWidget);
      expect(find.text('ĐANG QUÉT KHÔNG GIAN'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows radar standby only when NOTHING is heard', (tester) async {
      final repo = FakeZoneRepository();

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus.standby,
        initialRanking: const [], // nothing audible
      ));
      await tester.pump();

      expect(find.text('ĐANG QUÉT KHÔNG GIAN'), findsOneWidget);

      // _RadarStandby giữ AnimationController.repeat() — KHÔNG pumpAndSettle.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('audible-but-not-engaged zones show the list, not radar',
        (tester) async {
      // No engaged zone (status standby) but one zone is audible -> list, not
      // radar. This is the C3 "heard but beyond engage" case.
      final b = _zone(major: 2, name: 'Khu B');
      final repo = FakeZoneRepository(zones: [b]);

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus.standby,
        initialRanking: const [
          NearbyZone(major: 2, rssiDb: -70, distanceMeters: 6.5),
        ],
      ));
      await tester.pump();

      expect(find.text('ĐANG QUÉT KHÔNG GIAN'), findsNothing);
      expect(find.text('Khu B'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ranking', () {
    testWidgets('pinned current zone first, nearby zones numbered below',
        (tester) async {
      final a = _zone(major: 1, name: 'Khu A');
      final b = _zone(major: 2, name: 'Khu B');
      final repo = FakeZoneRepository(zones: [a, b]);

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus(zone: a), // A engaged
        initialRanking: const [
          NearbyZone(major: 1, rssiDb: -55, distanceMeters: 2.0), // A (pinned)
          NearbyZone(major: 2, rssiDb: -72, distanceMeters: 7.0), // B (nearby)
        ],
      ));
      await tester.pump();

      // A pinned with the "Đang ở đây" badge; B present as a numbered nearby
      // row without that badge. Only the pinned card carries it.
      expect(find.text('ĐANG Ở ĐÂY'), findsOneWidget);
      expect(find.text('Khu A'), findsOneWidget);
      expect(find.text('Khu B'), findsOneWidget);
      // Both cards' meta is just the count (A pinned + B nearby, same text).
      expect(find.text('0 hiện vật'), findsNWidgets(2));
      // Rank badge "2" for the single nearby row.
      expect(find.text('2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('distance shown only when the debug toggle is on',
        (tester) async {
      final a = _zone(major: 1, name: 'Khu A');
      final repo = FakeZoneRepository(zones: [a]);

      // Off -> no metres.
      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus(zone: a),
        initialRanking: const [
          NearbyZone(major: 1, rssiDb: -55, distanceMeters: 2.3),
        ],
        showDistance: false,
      ));
      await tester.pump();
      expect(find.textContaining('m', findRichText: false), findsNothing);
      await tester.pumpWidget(const SizedBox());

      // On -> metres appended.
      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus(zone: a),
        initialRanking: const [
          NearbyZone(major: 1, rssiDb: -55, distanceMeters: 2.3),
        ],
        showDistance: true,
      ));
      await tester.pump();
      expect(find.textContaining('2.3 m'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the arbiter drives screen 2, and only screen 2', () {
    testWidgets('swaps the pinned card in place when the zone changes',
        (tester) async {
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

      ctrl.add(ZoneStatus(zone: b));
      await tester.pump();
      await tester.pump();

      expect(find.text('Khu B'), findsOneWidget);
      expect(find.text('Khu A'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('falls back to standby when the zone AND ranking are lost',
        (tester) async {
      final a = _zone();
      final repo = FakeZoneRepository(zones: [a]);
      final ctrl = StreamController<ZoneStatus>();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_app(
        repo: repo,
        status: ctrl.stream,
        initial: ZoneStatus(zone: a),
        // ranking empty from the start -> once zone lost, nothing audible.
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
  // Step 5 — token families (unchanged by C3: pinned card still on image).
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

      final meta = tester.widget<Text>(find.text('0 hiện vật'));
      expect(meta.style!.color, MuseumTokens.light.mutedOnImage);
      expect(meta.style!.color, isNot(MuseumTokens.light.inkMuted));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('radar text follows the theme (sits on surface, not an image)',
        (tester) async {
      final repo = FakeZoneRepository();

      await tester.pumpWidget(_app(
        repo: repo,
        status: const Stream<ZoneStatus>.empty(),
        initial: ZoneStatus.standby,
      ));
      await tester.pump();
      var kicker = tester.widget<Text>(find.text('ĐANG QUÉT KHÔNG GIAN'));
      expect(kicker.style!.color, MuseumTokens.dark.ink);
      await tester.pumpWidget(const SizedBox());

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