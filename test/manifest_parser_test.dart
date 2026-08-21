// Destination: test/manifest_parser_test.dart
// Run with: flutter test test/manifest_parser_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/repositories/manifest_parser.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';

/// Decode the embedded mock manifest fresh for each test so mutations
/// never leak between cases.
Map<String, dynamic> baseManifest() =>
    jsonDecode(kMockManifestJson) as Map<String, dynamic>;

void main() {
  group('ManifestParser — happy path', () {
    test('parses the embedded example manifest completely', () {
      final parsed = ManifestParser.parse(baseManifest());

      expect(parsed.warnings, isEmpty);
      expect(parsed.config.deskMajor, 99);
      expect(parsed.config.fallbackLanguage, 'vi');
      expect(parsed.zones.length, 2);

      final zone1 = parsed.zones.first;
      expect(zone1.major, 1);
      // Tour order == array order; grenade keeps its scenario minor 5.
      expect(zone1.exhibits.map((e) => e.minor), [1, 2, 5]);
      expect(zone1.tourIndexOf(5), 2);
      expect(zone1.exhibitByMinor(5)!.id, 'luu-dan-mo-vit');

      // meaning is optional: AK-47 has it, Kar98 does not.
      expect(zone1.exhibitByMinor(1)!.meaning, isNotNull);
      expect(zone1.exhibitByMinor(2)!.meaning, isNull);

      // `media` giữ đúng thứ tự CMS xếp. AK-47 có ảnh chính + hai ảnh phụ;
      // Kar98 chỉ có ảnh chính.
      final ak47 = zone1.exhibitByMinor(1)!;
      expect(ak47.media, hasLength(3));
      expect(ak47.media.every((m) => m is ImageMedia), isTrue);
      expect(ak47.hasModel, isFalse);
      // Không có mô hình ⇒ cuộn phim mang cả dải, lưới chỉ mang phần sau.
      expect(ak47.stagePaths, hasLength(3));
      expect(ak47.documentPaths, hasLength(2));
      expect(ak47.gridThumbnailPath, (ak47.media.first as ImageMedia).thumb);

      final kar98 = zone1.exhibitByMinor(2)!;
      expect(kar98.media, hasLength(1));
      expect(kar98.documentPaths, isEmpty);
    });

    test('ảnh trùng đường dẫn bị lọc — cuộn phim không có hai trang y hệt', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      final ak47 = exhibits.first as Map<String, dynamic>;
      const main = 'images/exhibits/sung-ak-47/main.jpg';
      const detail = 'images/exhibits/sung-ak-47/detail-bang.jpg';
      // CMS liệt kê lặp — chuyện thường, và lọc ở parser rẻ hơn bắt họ không nhầm.
      ak47['media'] = [
        {'type': 'image', 'file': main, 'thumb': main},
        {'type': 'image', 'file': detail, 'thumb': detail},
        {'type': 'image', 'file': detail, 'thumb': detail},
      ];

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, isEmpty);
      expect(parsed.zones.first.exhibitByMinor(1)!.stagePaths, [main, detail]);
    });

    test('audio resolve: two-axis fallback (audio vi, transcript still vi)',
        () {
      final parsed = ManifestParser.parse(baseManifest());
      // Kar98 only has a "vi" track. An "en" visitor gets vi AUDIO...
      final kar98 = parsed.zones.first.exhibitByMinor(2)!;
      final resolved = kar98.audio.resolve('en', 'vi')!;
      expect(resolved.audioFellBack, isTrue);
      expect(resolved.track.filePath, contains('/vi/'));
      // ...and since no en transcript exists either, transcript falls back too.
      expect(resolved.transcript, contains('Kar98'));
    });

    test('arbitration params are clamped into sane ranges', () {
      final m = baseManifest();
      (m['beacon'] as Map<String, dynamic>)['arbitration'] = {
        'minDeltaDb': 900, // absurd — clamps to 20
        'dwellSeconds': 0, // clamps to 1
        'lockoutSeconds': 12,
        'zoneSilenceSeconds': 8,
        'deskDwellSeconds': 10,
        'sessionSilenceMinutes': 10,
      };
      final parsed = ManifestParser.parse(m);
      expect(parsed.config.arbitration.minDeltaDb, 20.0);
      expect(parsed.config.arbitration.dwell, const Duration(seconds: 1));
    });
  });

  group('ManifestParser — degradation and fail-fast boundaries', () {
    test('broken exhibit is SKIPPED with a warning, zone survives', () {
      final m = baseManifest();
      final zone1 = (m['zones'] as List).first as Map<String, dynamic>;
      final exhibits = zone1['exhibits'] as List;
      // Corrupt the Kar98 record: kill its only (fallback) audio transcript.
      final kar98 = exhibits[1] as Map<String, dynamic>;
      ((kar98['audio'] as Map)['tracks'] as Map).remove('vi');

      final parsed = ManifestParser.parse(m);
      expect(parsed.zones.first.exhibits.map((e) => e.minor), [1, 5]);
      expect(parsed.warnings, hasLength(1));
      expect(parsed.warnings.single, contains('sung-kar98'));
    });

    test('zone with NO surviving exhibits fails the whole bundle', () {
      final m = baseManifest();
      final zone2 = (m['zones'] as List)[1] as Map<String, dynamic>;
      for (final e in zone2['exhibits'] as List) {
        ((e as Map)['audio'] as Map).remove('tracks');
      }
      expect(() => ManifestParser.parse(m),
          throwsA(isA<BundleValidationException>()));
    });

    test('duplicate zone major fails the bundle', () {
      final m = baseManifest();
      ((m['zones'] as List)[1] as Map<String, dynamic>)['major'] = 1;
      expect(() => ManifestParser.parse(m),
          throwsA(isA<BundleValidationException>()));
    });

    test('zone using deskMajor fails the bundle', () {
      final m = baseManifest();
      ((m['zones'] as List).first as Map<String, dynamic>)['major'] = 99;
      expect(() => ManifestParser.parse(m),
          throwsA(isA<BundleValidationException>()));
    });

    test('duplicate exhibit minor within a zone fails the bundle', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      (exhibits[1] as Map<String, dynamic>)['minor'] = 1; // clash with AK-47
      expect(() => ManifestParser.parse(m),
          throwsA(isA<BundleValidationException>()));
    });

    test('path traversal in any asset path fails its record', () {
      final m = baseManifest();
      final zone1 = (m['zones'] as List).first as Map<String, dynamic>;
      zone1['heroImage'] = 'images/../../../etc/passwd.jpg';
      // Zone-level field ⇒ bundle-fatal.
      expect(() => ManifestParser.parse(m),
          throwsA(isA<BundleValidationException>()));
    });

    test('phần tử media hỏng bị bỏ, hiện vật vẫn sống', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      final ak47 = exhibits.first as Map<String, dynamic>;
      const good = 'images/exhibits/sung-ak-47/detail-bang.jpg';
      ak47['media'] = [
        {'type': 'image', 'file': good, 'thumb': good},
        {'type': 'image', 'file': 'images/../../../etc/passwd.jpg', 'thumb': good},
        {'type': 'image', 'file': 'https://cdn.example.com/x.jpg', 'thumb': good},
        {'type': 'image', 'file': 42, 'thumb': good},
        {'type': 'image', 'file': good}, // thiếu thumb
        {'file': good, 'thumb': good}, // thiếu type
        'không phải object',
      ];

      final parsed = ManifestParser.parse(m);
      final ak = parsed.zones.first.exhibitByMinor(1)!;
      expect(ak.media, hasLength(1));
      expect(ak.stagePaths, [good]);
      expect(parsed.warnings, hasLength(6));
      expect(parsed.warnings.every((w) => w.contains('sung-ak-47')), isTrue);
    });

    test('media rỗng sau khi lọc ⇒ bỏ CẢ hiện vật', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      (exhibits.first as Map<String, dynamic>)['media'] = [
        {'type': 'image', 'file': 'https://evil/x.jpg', 'thumb': 'x'},
      ];

      final parsed = ManifestParser.parse(m);
      // Một hiện vật không có gì để nhìn thì không có gì để bày — nhưng các
      // hiện vật khác của khu KHÔNG được chết theo.
      expect(parsed.zones.first.exhibitByMinor(1), isNull);
      expect(parsed.zones.first.exhibits, isNotEmpty);
      expect(parsed.warnings.any((w) => w.contains('media')), isTrue);
    });

    test('"media" không phải mảng ⇒ bỏ hiện vật kèm warning', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      (exhibits.first as Map<String, dynamic>)['media'] = 'main.jpg';

      final parsed = ManifestParser.parse(m);
      expect(parsed.zones.first.exhibitByMinor(1), isNull);
      expect(parsed.warnings.any((w) => w.contains('"media"')), isTrue);
    });

    test('unsupported schemaVersion is rejected up front', () {
      final m = baseManifest()..['schemaVersion'] = 2;
      expect(() => ManifestParser.parse(m),
          throwsA(isA<BundleValidationException>()));
    });
  });

  // Mô hình 3D là một PHẦN TỬ của `media[]`, không phải một khối riêng — và nó
  // chỉ được đứng ở vị trí 0. Nhóm này giữ hai điều: khối model hỏng không bao
  // giờ giết hiện vật, và ràng buộc vị trí được thi hành thật.
  group('ManifestParser — media type "model"', () {
    Map<String, dynamic> firstExhibit(Map<String, dynamic> m) =>
        (((m['zones'] as List).first as Map)['exhibits'] as List).first
            as Map<String, dynamic>;

    const img = 'images/exhibits/sung-ak-47/main.jpg';
    const thumb = 'images/exhibits/sung-ak-47/thumb.jpg';
    Map<String, dynamic> imageItem() =>
        {'type': 'image', 'file': img, 'thumb': thumb};
    Map<String, dynamic> modelItem({Object? id = 'tuong-phat', Object? poster,
        Object? th = 'images/exhibits/sung-ak-47/model-thumb.jpg'}) =>
        {
          'type': 'model',
          'id': id,
          'poster': poster ?? 'images/exhibits/sung-ak-47/model-poster.jpg',
          'thumb': th,
        };

    test('vắng mặt là hợp lệ — phần lớn hiện vật không có mô hình', () {
      final ex = ManifestParser.parse(baseManifest())
          .zones.first.exhibitByMinor(1)!;
      expect(ex.hasModel, isFalse);
      expect(ex.model, isNull);
    });

    test('đứng đầu media ⇒ đọc đúng, và đổi cả ba quy tắc bố cục', () {
      final m = baseManifest();
      firstExhibit(m)['media'] = [modelItem(), imageItem()];

      final ex = ManifestParser.parse(m).zones.first.exhibitByMinor(1)!;
      expect(ex.hasModel, isTrue);
      expect(ex.model!.id, 'tuong-phat');

      // Cuộn phim còn ĐÚNG một khung: vuốt ngang lúc này là xoay mô hình, nên
      // mọi trang thêm vào đều là trang không ngón tay nào tới được.
      expect(ex.stagePaths, [ex.model!.poster]);
      // Và ảnh KHÔNG biến mất — chúng xuống lưới, kể cả ảnh chính.
      expect(ex.documentPaths, [img]);
      // Ô lưới 04b hứa đúng thứ khách sẽ thấy khi mở ra.
      expect(ex.gridThumbnailPath, 'images/exhibits/sung-ak-47/model-thumb.jpg');
    });

    // Cả bố cục dựa trên "phần tử đầu LÀ sân khấu". Một mô hình ở giữa dải là
    // một trang không lật tới được, nên nó bị bỏ chứ không được nhận.
    test('model KHÔNG đứng đầu thì bị bỏ, hiện vật vẫn sống', () {
      final m = baseManifest();
      firstExhibit(m)['media'] = [imageItem(), modelItem()];

      final parsed = ManifestParser.parse(m);
      final ex = parsed.zones.first.exhibitByMinor(1)!;
      expect(ex.hasModel, isFalse);
      expect(ex.media, hasLength(1));
      expect(parsed.warnings.single, contains('không đứng đầu'));
    });

    test('id chịu bộ ký tự hẹp — nó là khoá tra cứu, không phải đường dẫn', () {
      for (final bad in ['', 'có dấu cách', '../escape', 'a/b', 'a.b', '-gach']) {
        final m = baseManifest();
        firstExhibit(m)['media'] = [modelItem(id: bad), imageItem()];

        final parsed = ManifestParser.parse(m);
        final ex = parsed.zones.first.exhibitByMinor(1)!;
        expect(ex.hasModel, isFalse, reason: 'với "$bad"');
        expect(ex.media, hasLength(1), reason: 'ảnh vẫn còn với "$bad"');
        expect(parsed.warnings.single, contains('model.id'));
      }
    });

    test('poster phải đi qua đúng luật đường dẫn của bundle', () {
      for (final bad in [
        'images/../../../etc/passwd.jpg',
        'https://cdn.example.com/x.jpg',
        '/absolute/x.jpg',
        'models/x.glb', // .glb KHÔNG hợp lệ trong bundle
      ]) {
        final m = baseManifest();
        firstExhibit(m)['media'] = [modelItem(poster: bad), imageItem()];

        final parsed = ManifestParser.parse(m);
        expect(parsed.zones.first.exhibitByMinor(1)!.hasModel, isFalse,
            reason: 'với "$bad"');
        expect(parsed.warnings.single, contains('model.poster'));
      }
    });

    test('thiếu thumb ⇒ bỏ, vì ô lưới sẽ trống mà không giải thích được', () {
      final m = baseManifest();
      firstExhibit(m)['media'] = [modelItem(th: null), imageItem()];

      final parsed = ManifestParser.parse(m);
      expect(parsed.zones.first.exhibitByMinor(1)!.hasModel, isFalse);
      expect(parsed.warnings.single, contains('thumb'));
    });

    // `video` đã có chỗ trong schema nhưng chưa dựng. Bỏ KÈM WARNING chứ không
    // im lặng: một CMS khai video phải thấy ngay rằng app chưa đọc được nó.
    test('type "video" là loại dành sẵn — bỏ kèm warning, không im lặng', () {
      final m = baseManifest();
      firstExhibit(m)['media'] = [
        imageItem(),
        {'type': 'video', 'file': 'images/x.mp4', 'thumb': thumb},
      ];

      final parsed = ManifestParser.parse(m);
      expect(parsed.zones.first.exhibitByMinor(1)!.media, hasLength(1));
      expect(parsed.warnings.single, contains('chưa được hỗ trợ'));
    });
  });

  group('MockZoneRepository', () {
    test('preWarm is idempotent and exposes the parsed catalog', () async {
      final repo = MockZoneRepository(simulatedLatency: Duration.zero);
      expect(repo.isWarmed, isFalse);
      expect(repo.zoneByMajor(1), isNull); // graceful before warm

      await repo.preWarm();
      await repo.preWarm(); // second call must be a no-op

      expect(repo.isWarmed, isTrue);
      expect(repo.lastError, isNull);
      expect(repo.allZones, hasLength(2));
      expect(repo.zoneByMajor(1)!.id, 'vu-khi-khang-chien');
      expect(repo.zoneByMajor(99), isNull); // desk major is not a zone
      expect(repo.config!.beaconUuid, '4d6fc88b-be75-6698-da48-6866a36ec78e');
    });
  });
}
