// Destination: test/manifest_parser_test.dart
// Run with: flutter test test/manifest_parser_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/repositories/manifest_parser.dart';
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

      // "images" is optional too: AK-47 carries two extra shots, Kar98 none.
      // imagePaths always leads with the representative image.
      final ak47 = zone1.exhibitByMinor(1)!;
      expect(ak47.extraImagePaths, hasLength(2));
      expect(ak47.imagePaths.first, ak47.imagePath);
      expect(ak47.imagePaths, hasLength(3));
      expect(zone1.exhibitByMinor(2)!.extraImagePaths, isEmpty);
      expect(zone1.exhibitByMinor(2)!.imagePaths,
          [zone1.exhibitByMinor(2)!.imagePath]);
    });

    test('the representative image is never duplicated inside the gallery', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      final ak47 = exhibits.first as Map<String, dynamic>;
      // CMS liệt kê cả ảnh chính, và lặp một ảnh phụ.
      ak47['images'] = [
        ak47['image'],
        'images/exhibits/sung-ak-47/detail-bang.jpg',
        'images/exhibits/sung-ak-47/detail-bang.jpg',
      ];

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, isEmpty);
      expect(parsed.zones.first.exhibitByMinor(1)!.imagePaths, [
        'images/exhibits/sung-ak-47/main.jpg',
        'images/exhibits/sung-ak-47/detail-bang.jpg',
      ]);
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

    test('bad entries in "images" are dropped, the exhibit survives', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      final ak47 = exhibits.first as Map<String, dynamic>;
      ak47['images'] = [
        'images/exhibits/sung-ak-47/detail-bang.jpg', // hợp lệ
        'images/../../../etc/passwd.jpg', // traversal
        'https://cdn.example.com/x.jpg', // URL
        42, // sai kiểu
      ];

      final parsed = ManifestParser.parse(m);
      final parsedAk47 = parsed.zones.first.exhibitByMinor(1)!;
      expect(parsedAk47.extraImagePaths,
          ['images/exhibits/sung-ak-47/detail-bang.jpg']);
      expect(parsed.warnings, hasLength(3));
      expect(parsed.warnings.every((w) => w.contains('sung-ak-47')), isTrue);
    });

    test('"images" that is not an array is ignored with a warning', () {
      final m = baseManifest();
      final exhibits = ((m['zones'] as List).first as Map)['exhibits'] as List;
      (exhibits.first as Map<String, dynamic>)['images'] = 'main.jpg';

      final parsed = ManifestParser.parse(m);
      expect(parsed.zones.first.exhibitByMinor(1)!.extraImagePaths, isEmpty);
      expect(parsed.warnings.single, contains('"images" is not an array'));
    });

    test('unsupported schemaVersion is rejected up front', () {
      final m = baseManifest()..['schemaVersion'] = 2;
      expect(() => ManifestParser.parse(m),
          throwsA(isA<BundleValidationException>()));
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
