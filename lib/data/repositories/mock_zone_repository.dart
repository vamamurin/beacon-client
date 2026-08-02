// Destination: lib/data/repositories/mock_zone_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/repositories/manifest_parser.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';

/// Dev/test implementation seeded from an EMBEDDED copy of
/// manifest.example.json and pushed through the REAL [ManifestParser].
///
/// Deliberately NOT hand-built Dart objects: the mock must exercise the exact
/// production parse path so schema drift breaks tests immediately instead of
/// surfacing on a device at the museum. One source of truth (the example
/// manifest), two consumers (this mock + the JSON-Schema validator).
class MockZoneRepository implements IZoneRepository {
  MuseumConfig? _config;
  List<ZoneInfo> _zones = const [];
  Map<int, ZoneInfo> _byMajor = const {};
  List<String> _warnings = const [];
  String? _lastError;
  bool _warmed = false;

  /// Simulated bundle-load latency so callers can't accidentally depend on
  /// preWarm being synchronous (the real repository does disk I/O).
  final Duration simulatedLatency;

  MockZoneRepository({this.simulatedLatency = const Duration(milliseconds: 120)});

  @override
  Future<void> preWarm() async {
    if (_warmed) return; // idempotent, same idiom as the artifact repos
    await Future<void>.delayed(simulatedLatency);
    try {
      final parsed = ManifestParser.parse(
          jsonDecode(kMockManifestJson) as Map<String, dynamic>);
      _config = parsed.config;
      _zones = parsed.zones;
      _byMajor = Map.unmodifiable({for (final z in parsed.zones) z.major: z});
      _warnings = parsed.warnings;
      _lastError = null;
      _warmed = true;
      if (kDebugMode && _warnings.isNotEmpty) {
        for (final w in _warnings) {
          debugPrint('[MockZoneRepository] warning: $w');
        }
      }
    } on BundleValidationException catch (e) {
      _lastError = e.message;
      if (kDebugMode) debugPrint('[MockZoneRepository] FAILED: $e');
    }
  }

  @override
  bool get isWarmed => _warmed;

  @override
  String? get lastError => _lastError;

  @override
  List<String> get warnings => _warnings;

  @override
  MuseumConfig? get config => _config;

  @override
  ZoneInfo? zoneByMajor(int major) => _byMajor[major];

  @override
  List<ZoneInfo> get allZones => _zones;
}

/// Verbatim-structure copy of manifest.example.json (transcripts shortened).
/// Có thêm 2 key optional `welcomeImage`/`welcomeAccentImage` để đường parse
/// optional-path được tập luyện; file ảnh không tồn tại trên máy dev ⇒
/// HeroImage tự rơi về gradient fallback (đúng hợp đồng của nó).
/// AK-47 và lựu đạn có thêm key optional `images` (ảnh phụ) để đường parse dải
/// ảnh được tập luyện; Kar98 cố tình KHÔNG có, giữ nguyên hình dạng bundle cũ.
/// Zone 1 "Vũ khí Kháng chiến": minors 1, 2, 5 — grenade is minor 5, matching
/// the original UX scenario. Zone 2 "Kỷ vật Sinh hoạt": minors 1, 2.
/// Desk beacon: major 99.
const String kMockManifestJson = r'''
{
  "schemaVersion": 1,
  "bundleVersion": "mock-2026.07.04-01",
  "generatedAt": "2026-07-04T08:00:00+07:00",
  "languages": ["vi", "en"],
  "fallbackLanguage": "vi",
  "museum": {
    "name": { "vi": "Bảo tàng Tôn Đức Thắng", "en": "Ton Duc Thang Museum" },
    "welcomeImage": "images/welcome.jpg",
    "welcomeAccentImage": "images/welcome_accent.jpg"
  },
  "beacon": {
    "uuid": "4d6fc88b-be75-6698-da48-6866a36ec78e",
    "deskMajor": 99,
    "arbitration": {
      "minDeltaDb": 7,
      "dwellSeconds": 3,
      "lockoutSeconds": 12,
      "zoneSilenceSeconds": 8,
      "deskDwellSeconds": 10,
      "sessionSilenceMinutes": 10
    }
  },
  "policies": {
    "allowLoudspeaker": false,
    "autoplayRequiresHeadphones": true,
    "revisitPlaysWelcome": false
  },
  "zones": [
    {
      "major": 1,
      "id": "vu-khi-khang-chien",
      "name": { "vi": "Vũ khí Kháng chiến", "en": "Resistance-Era Weapons" },
      "welcomeText": {
        "vi": "Nơi lưu giữ những kỷ vật chiến đấu của hai cuộc kháng chiến.",
        "en": "Home to combat relics from the nation's two resistance wars."
      },
      "heroImage": "images/zones/vu-khi-khang-chien/hero.jpg",
      "heroImageBlurred": "images/zones/vu-khi-khang-chien/hero_blur.jpg",
      "introAudio": {
        "tracks": {
          "vi": {
            "file": "audio/vi/zones/vu-khi-khang-chien/intro.mp3",
            "durationSec": 32.4,
            "transcript": "Bạn đang dừng chân tại cụm Vũ khí Kháng chiến..."
          },
          "en": {
            "file": "audio/en/zones/vu-khi-khang-chien/intro.mp3",
            "durationSec": 30.1,
            "transcript": "You are now in the Resistance-Era Weapons gallery..."
          }
        }
      },
      "exhibits": [
        {
          "minor": 1,
          "id": "sung-ak-47",
          "name": { "vi": "Súng AK-47", "en": "AK-47 Rifle" },
          "summary": {
            "vi": "Khẩu súng trường gắn liền với người chiến sĩ giải phóng.",
            "en": "The rifle inseparable from the liberation soldier."
          },
          "meaning": {
            "vi": "Biểu tượng của ý chí chiến đấu...",
            "en": "A symbol of fighting resolve..."
          },
          "specs": [
            { "label": { "vi": "Năm sản xuất", "en": "Year" },
              "value": { "vi": "1965", "en": "1965" } },
            { "label": { "vi": "Xuất xứ", "en": "Origin" },
              "value": { "vi": "Liên Xô", "en": "Soviet Union" } }
          ],
          "image": "images/exhibits/sung-ak-47/main.jpg",
          "thumbnail": "images/exhibits/sung-ak-47/thumb.jpg",
          "images": [
            "images/exhibits/sung-ak-47/detail-bang.jpg",
            "images/exhibits/sung-ak-47/detail-khoa-nong.jpg"
          ],
          "audio": {
            "tracks": {
              "vi": { "file": "audio/vi/exhibits/sung-ak-47.mp3",
                      "durationSec": 47.2,
                      "transcript": "Trước mắt bạn là khẩu AK-47..." },
              "en": { "file": "audio/en/exhibits/sung-ak-47.mp3",
                      "durationSec": 51.0,
                      "transcript": "Before you is an AK-47..." }
            }
          }
        },
        {
          "minor": 2,
          "id": "sung-kar98",
          "name": { "vi": "Súng Kar98", "en": "Kar98 Rifle" },
          "summary": {
            "vi": "Chiến lợi phẩm phổ biến thời kỳ đầu kháng chiến.",
            "en": "A common war trophy of the early resistance years."
          },
          "image": "images/exhibits/sung-kar98/main.jpg",
          "thumbnail": "images/exhibits/sung-kar98/thumb.jpg",
          "audio": {
            "tracks": {
              "vi": { "file": "audio/vi/exhibits/sung-kar98.mp3",
                      "durationSec": 39.8,
                      "transcript": "Khẩu Kar98 này là chiến lợi phẩm..." }
            }
          }
        },
        {
          "minor": 5,
          "id": "luu-dan-mo-vit",
          "name": { "vi": "Lựu đạn mỏ vịt", "en": "Stick Grenade" },
          "summary": {
            "vi": "Lựu đạn tự tạo trong xưởng quân giới Nam Bộ.",
            "en": "A grenade made in southern ordnance workshops."
          },
          "meaning": {
            "vi": "Kết tinh của tinh thần tự lực tự cường...",
            "en": "The spirit of self-reliance embodied..."
          },
          "image": "images/exhibits/luu-dan-mo-vit/main.jpg",
          "thumbnail": "images/exhibits/luu-dan-mo-vit/thumb.jpg",
          "images": ["images/exhibits/luu-dan-mo-vit/detail-ngoi-no.jpg"],
          "audio": {
            "tracks": {
              "vi": { "file": "audio/vi/exhibits/luu-dan-mo-vit.mp3",
                      "durationSec": 43.5,
                      "transcript": "Quả lựu đạn mỏ vịt trước mắt bạn..." },
              "en": { "file": "audio/en/exhibits/luu-dan-mo-vit.mp3",
                      "durationSec": 45.9,
                      "transcript": "The stick grenade before you..." }
            }
          }
        }
      ]
    },
    {
      "major": 2,
      "id": "ky-vat-sinh-hoat",
      "name": { "vi": "Kỷ vật Sinh hoạt", "en": "Everyday-Life Memorabilia" },
      "welcomeText": {
        "vi": "Những vật dụng đời thường của Bác Tôn.",
        "en": "Everyday objects from President Ton's simple life."
      },
      "heroImage": "images/zones/ky-vat-sinh-hoat/hero.jpg",
      "heroImageBlurred": "images/zones/ky-vat-sinh-hoat/hero_blur.jpg",
      "introAudio": {
        "tracks": {
          "vi": {
            "file": "audio/vi/zones/ky-vat-sinh-hoat/intro.mp3",
            "durationSec": 28.7,
            "transcript": "Chào mừng bạn đến với khu Kỷ vật Sinh hoạt..."
          },
          "en": {
            "file": "audio/en/zones/ky-vat-sinh-hoat/intro.mp3",
            "durationSec": 27.3,
            "transcript": "Welcome to the Everyday-Life gallery..."
          }
        }
      },
      "exhibits": [
        {
          "minor": 1,
          "id": "bo-do-nghe-tho-may",
          "name": { "vi": "Bộ đồ nghề thợ máy", "en": "Mechanic's Tool Set" },
          "summary": {
            "vi": "Dụng cụ Bác Tôn dùng tại xưởng Ba Son.",
            "en": "Tools President Ton used at Ba Son shipyard."
          },
          "specs": [
            { "label": { "vi": "Niên đại", "en": "Period" },
              "value": { "vi": "Đầu thế kỷ XX", "en": "Early 20th century" } }
          ],
          "image": "images/exhibits/bo-do-nghe-tho-may/main.jpg",
          "thumbnail": "images/exhibits/bo-do-nghe-tho-may/thumb.jpg",
          "audio": {
            "tracks": {
              "vi": { "file": "audio/vi/exhibits/bo-do-nghe-tho-may.mp3",
                      "durationSec": 52.1,
                      "transcript": "Bộ đồ nghề trước mắt bạn..." },
              "en": { "file": "audio/en/exhibits/bo-do-nghe-tho-may.mp3",
                      "durationSec": 49.4,
                      "transcript": "The tool set before you..." }
            }
          }
        },
        {
          "minor": 2,
          "id": "chiec-xe-dap-thong-nhat",
          "name": { "vi": "Chiếc xe đạp Thống Nhất", "en": "Thong Nhat Bicycle" },
          "summary": {
            "vi": "Phương tiện đi lại giản dị những năm ở Hà Nội.",
            "en": "A humble means of transport in the Hanoi years."
          },
          "image": "images/exhibits/chiec-xe-dap-thong-nhat/main.jpg",
          "thumbnail": "images/exhibits/chiec-xe-dap-thong-nhat/thumb.jpg",
          "audio": {
            "tracks": {
              "vi": { "file": "audio/vi/exhibits/chiec-xe-dap-thong-nhat.mp3",
                      "durationSec": 38.0,
                      "transcript": "Chiếc xe đạp Thống Nhất này..." }
            }
          }
        }
      ]
    }
  ]
}
''';