// Destination: test/zone_screen_test.dart
// Run with: flutter test test/zone_screen_test.dart
//
// TIÊU CHÍ NGHIỆM THU của Step 4. Không phải "diff trông sạch" mà: màn hình 2
// dựng được từ hai provider giả, KHÔNG Bluetooth, KHÔNG audio engine, KHÔNG
// path_provider, KHÔNG Injection.build().
//
// Nếu bạn thấy mình phải mock thêm bất cứ thứ gì để test này chạy, refactor
// CHƯA xong — và thứ phải mock chính là chỗ còn rò rỉ. Đừng mock nó; hãy hỏi
// "màn hình này đang hỏi loại câu hỏi nào?" rồi cho nó provider tương ứng.

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
import 'package:beacon_client/presentation/zone/zone_screen.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

// ============================================================================
// Fakes. Có thể tách sang test/fakes/ khi màn hình thứ hai cần dùng lại.
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

/// Zone tối thiểu. `exhibits: []` cố ý — màn 2 chỉ đọc `.length`, và giữ
/// fixture khỏi phải dựng ExhibitInfo + AudioTrack là một phần của mục tiêu
/// (test màn 2 không được phụ thuộc vào hình dạng của tầng audio).
ZoneInfo _zone({
  int major = 1,
  String name = 'Khu Thử',
  List<int> exhibitCount = const [],
}) {
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
    child: const MaterialApp(home: ZoneScreen()),
  );
}

void main() {
  testWidgets('renders the current zone card with no pipeline behind it',
      (tester) async {
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

    // Ticker của _RadarStandby không chạy ở đây, nhưng tháo cây cho chắc.
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
    // lặp vô hạn nên nó sẽ treo cho tới timeout.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swaps the card when the arbiter changes zone', (tester) async {
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

    // Arbiter chuyển zone: KHÔNG pop, KHÔNG đẩy route mới — thẻ tự đổi.
    ctrl.add(ZoneStatus(zone: b));
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

    expect(find.text('ĐANG QUÉT KHÔNG GIAN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}