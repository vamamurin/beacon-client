// Destination: lib/data/repositories/manifest_parser.dart

import 'package:beacon_client/domain/models/audio_clip_info.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/localized_text.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';

/// Thrown when the bundle is unusable as a whole. Per content-bundle-spec §6:
/// a broken EXHIBIT is skipped with a warning (graceful degradation), but a
/// broken ZONE fails the entire bundle — shipping a museum with a missing
/// room silently is lying to the visitor; better to keep the previous bundle.
class BundleValidationException implements Exception {
  final String message;
  const BundleValidationException(this.message);

  @override
  String toString() => 'BundleValidationException: $message';
}

/// Result of a successful parse. [warnings] carries every non-fatal skip so
/// callers (repository → debug/ops surface) can report without re-parsing.
class ParsedBundle {
  final MuseumConfig config;
  final List<ZoneInfo> zones;
  final List<String> warnings;

  const ParsedBundle({
    required this.config,
    required this.zones,
    required this.warnings,
  });
}

/// Pure function from decoded manifest JSON to domain models.
///
/// Deliberately has ZERO dependencies on dart:io / http / path resolution —
/// the same parser serves MockZoneRepository (embedded string) and the real
/// LocalBundleZoneRepository (file on disk), and unit tests feed it maps
/// directly. All rules from content-bundle-spec §4 are enforced here as
/// defense-in-depth behind the CMS-side JSON-Schema check.
abstract final class ManifestParser {
  static const int supportedSchemaVersion = 1;

  /// Mirrors the `relativePath` rule in manifest.schema.json: bundle-relative
  /// only — no absolute paths, no URL schemes, no `..` traversal. This is the
  /// last line of defense for "a payload path must never point outside the
  /// bundle directory".
  static final RegExp _pathRule = RegExp(
    r'^(?!.*\.\.)(images|audio)/[A-Za-z0-9_./-]+\.(jpg|jpeg|png|webp|mp3|m4a|ogg)$',
  );

  static ParsedBundle parse(Map<String, dynamic> root) {
    final warnings = <String>[];

    // ---- schema gate -----------------------------------------------------
    final schemaVersion = root['schemaVersion'];
    if (schemaVersion != supportedSchemaVersion) {
      throw BundleValidationException(
          'Unsupported schemaVersion: $schemaVersion '
          '(app supports $supportedSchemaVersion)');
    }

    // ---- root config ------------------------------------------------------
    final bundleVersion = _reqString(root, 'bundleVersion', 'root');
    final languages = _reqStringList(root, 'languages', 'root');
    final fallbackLanguage = _reqString(root, 'fallbackLanguage', 'root');
    if (!languages.contains(fallbackLanguage)) {
      throw BundleValidationException(
          'fallbackLanguage "$fallbackLanguage" not in languages $languages');
    }

    final uiStrings = _optUiStrings(root, 'ui');
    // OPTIONAL: tên hiển thị ngôn ngữ (code → name) cho picker. Thiếu ⇒ rỗng ⇒
    // UI lùi về bảng tên nhúng trong app.
    final languageNames = _optStringMap(root, 'languageNames');
    // C2 OPTIONAL: cửa sổ xác nhận đổi khu (giây). Thiếu/sai kiểu ⇒ null ⇒
    // injection dùng mặc định. Clamp 1..30s để CMS gõ nhầm không tạo UX lạ.
    final zoneChangeConfirmWindow =
        _optDurationSeconds(root, 'zoneChangeConfirmSeconds', 1, 30);

    final museum = _reqMap(root, 'museum', 'root');
    final museumName = _reqLocalized(museum, 'name', 'museum', fallbackLanguage);
    final welcomeImagePath = _optPath(museum, 'welcomeImage', 'museum');
    // Vùng ảnh 2 của màn chào — optional, cùng _pathRule với mọi payload khác.
    final welcomeAccentImagePath =
        _optPath(museum, 'welcomeAccentImage', 'museum');

    final beacon = _reqMap(root, 'beacon', 'root');
    final beaconUuid = _reqString(beacon, 'uuid', 'beacon').toLowerCase();
    final deskMajor = _reqInt(beacon, 'deskMajor', 'beacon');

    final arb = _reqMap(beacon, 'arbitration', 'beacon');
    final arbitration = ArbitrationParams.clamped(
      minDeltaDb: _reqNum(arb, 'minDeltaDb', 'arbitration'),
      dwellSeconds: _reqNum(arb, 'dwellSeconds', 'arbitration'),
      lockoutSeconds: _reqNum(arb, 'lockoutSeconds', 'arbitration'),
      zoneSilenceSeconds: _reqNum(arb, 'zoneSilenceSeconds', 'arbitration'),
      deskDwellSeconds: _reqNum(arb, 'deskDwellSeconds', 'arbitration'),
      sessionSilenceMinutes:
          _reqNum(arb, 'sessionSilenceMinutes', 'arbitration'),
      // C1 — OPTIONAL (bundle cũ chưa có 3 trường này vẫn hợp lệ; default
      // 5/8/2.5 áp tại clamped). Tinh chỉnh tại hiện trường qua CMS.
      engageAtMeters: _optNum(arb, 'engageAtMeters', 4),
      releaseAtMeters: _optNum(arb, 'releaseAtMeters', 7),
      pathLossExponent: _optNum(arb, 'pathLossExponent', 2.5),
      kalmanProcessNoise: _optNum(arb, 'kalmanProcessNoise', 0.008),
      kalmanMeasurementNoise: _optNum(arb, 'kalmanMeasurementNoise', 4.0), 
    );

    final pol = _reqMap(root, 'policies', 'root');
    final policies = AudioPolicies(
      allowLoudspeaker: _reqBool(pol, 'allowLoudspeaker', 'policies'),
      autoplayRequiresHeadphones:
          _reqBool(pol, 'autoplayRequiresHeadphones', 'policies'),
      revisitPlaysWelcome: _reqBool(pol, 'revisitPlaysWelcome', 'policies'),
    );

    // ---- zones (fail-fast) with exhibits (skip-and-warn) -------------------
    final zonesJson = root['zones'];
    if (zonesJson is! List || zonesJson.isEmpty) {
      throw const BundleValidationException('zones must be a non-empty array');
    }

    final zones = <ZoneInfo>[];
    final seenMajors = <int>{};
    for (final z in zonesJson) {
      if (z is! Map<String, dynamic>) {
        throw const BundleValidationException('zone entry is not an object');
      }
      final zone = _parseZone(z, fallbackLanguage, warnings);

      if (!seenMajors.add(zone.major)) {
        throw BundleValidationException('duplicate zone major ${zone.major}');
      }
      if (zone.major == deskMajor) {
        throw BundleValidationException(
            'zone "${zone.id}" uses deskMajor $deskMajor');
      }
      zones.add(zone);
    }

    return ParsedBundle(
      config: MuseumConfig(
        bundleVersion: bundleVersion,
        museumName: museumName,
        welcomeImagePath: welcomeImagePath,
        welcomeAccentImagePath: welcomeAccentImagePath,
        languages: List.unmodifiable(languages),
        fallbackLanguage: fallbackLanguage,
        languageNames: languageNames,
        zoneChangeConfirmWindow: zoneChangeConfirmWindow,
        uiStrings: uiStrings,
        beaconUuid: beaconUuid,
        deskMajor: deskMajor,
        arbitration: arbitration,
        policies: policies,
      ),
      zones: List.unmodifiable(zones),
      warnings: warnings,
    );
  }

  // ---- zone ----------------------------------------------------------------

  static ZoneInfo _parseZone(
    Map<String, dynamic> z,
    String fallbackLang,
    List<String> warnings,
  ) {
    final id = _reqString(z, 'id', 'zone');
    final ctx = 'zone "$id"';
    final major = _reqInt(z, 'major', ctx);

    // Zone-level required pieces fail the WHOLE bundle (spec §6).
    final introAudio = _parseClip(_reqMap(z, 'introAudio', ctx), ctx,
        fallbackLang, warnings, failFast: true)!;

    final exhibitsJson = z['exhibits'];
    if (exhibitsJson is! List || exhibitsJson.isEmpty) {
      throw BundleValidationException('$ctx: exhibits must be non-empty');
    }

    // Exhibits degrade per-record: one broken exhibit is skipped with a
    // warning instead of killing the room...
    final exhibits = <ExhibitInfo>[];
    final seenMinors = <int>{};
    for (final e in exhibitsJson) {
      if (e is! Map<String, dynamic>) {
        warnings.add('$ctx: skipped non-object exhibit entry');
        continue;
      }
      final exhibit = _tryParseExhibit(e, ctx, fallbackLang, warnings);
      if (exhibit == null) continue;
      if (!seenMinors.add(exhibit.minor)) {
        // Duplicate keys are a data conflict, not a partial record —
        // ambiguity about WHICH content belongs to a minor fails the bundle.
        throw BundleValidationException(
            '$ctx: duplicate exhibit minor ${exhibit.minor}');
      }
      exhibits.add(exhibit);
    }
    // ...but a zone that ends up EMPTY is a missing room ⇒ fail (spec §6).
    if (exhibits.isEmpty) {
      throw BundleValidationException('$ctx: no valid exhibits survived');
    }

    return ZoneInfo(
      major: major,
      id: id,
      name: _reqLocalized(z, 'name', ctx, fallbackLang),
      welcomeText: _reqLocalized(z, 'welcomeText', ctx, fallbackLang),
      heroImagePath: _reqPath(z, 'heroImage', ctx),
      heroImageBlurredPath: _reqPath(z, 'heroImageBlurred', ctx),
      introAudio: introAudio,
      exhibits: List.unmodifiable(exhibits),
    );
  }

  // ---- exhibit (skip-and-warn) ----------------------------------------------

  static ExhibitInfo? _tryParseExhibit(
    Map<String, dynamic> e,
    String zoneCtx,
    String fallbackLang,
    List<String> warnings,
  ) {
    final label = e['id'] ?? e['minor'] ?? '?';
    final ctx = '$zoneCtx exhibit "$label"';
    try {
      final specsJson = e['specs'];
      final specs = <SpecEntry>[];
      if (specsJson is List) {
        for (final s in specsJson) {
          if (s is! Map<String, dynamic>) continue;
          specs.add(SpecEntry(
            label: _reqLocalized(s, 'label', ctx, fallbackLang),
            value: _reqLocalized(s, 'value', ctx, fallbackLang),
          ));
        }
      }

      final audio =
          _parseClip(_reqMap(e, 'audio', ctx), ctx, fallbackLang, warnings,
              failFast: false);
      if (audio == null) {
        warnings.add('$ctx: skipped — no usable audio track');
        return null;
      }

      final meaningRaw = e['meaning'];
      return ExhibitInfo(
        minor: _reqInt(e, 'minor', ctx),
        id: e['id'] as String?,
        name: _reqLocalized(e, 'name', ctx, fallbackLang),
        summary: _reqLocalized(e, 'summary', ctx, fallbackLang),
        meaning: meaningRaw is Map<String, dynamic>
            ? _localized(meaningRaw, ctx, fallbackLang)
            : null,
        specs: List.unmodifiable(specs),
        imagePath: _reqPath(e, 'image', ctx),
        thumbnailPath: _reqPath(e, 'thumbnail', ctx),
        audio: audio,
      );
    } on BundleValidationException catch (err) {
      warnings.add('$ctx: skipped — ${err.message}');
      return null;
    }
  }

  // ---- audio clip -------------------------------------------------------------

  /// [failFast]: zone intro throws on an unusable clip (bundle-fatal);
  /// exhibit audio returns null so the exhibit can be skipped instead.
  static AudioClipInfo? _parseClip(
    Map<String, dynamic> clip,
    String ctx,
    String fallbackLang,
    List<String> warnings, {
    required bool failFast,
  }) {
    final tracksJson = clip['tracks'];
    if (tracksJson is! Map<String, dynamic>) {
      if (failFast) {
        throw BundleValidationException('$ctx: audio.tracks missing');
      }
      return null;
    }

    final tracks = <String, AudioTrack>{};
    tracksJson.forEach((lang, t) {
      if (t is! Map<String, dynamic>) {
        warnings.add('$ctx: track "$lang" is not an object — dropped');
        return;
      }
      final file = t['file'];
      final duration = t['durationSec'];
      final transcript = t['transcript'];
      if (file is! String || !_pathRule.hasMatch(file)) {
        warnings.add('$ctx: track "$lang" has invalid path — dropped');
        return;
      }
      // Transcript is REQUIRED (reading mode / accessibility) — a track
      // without one is unusable by policy, not just by taste.
      if (transcript is! String || transcript.isEmpty) {
        warnings.add('$ctx: track "$lang" missing transcript — dropped');
        return;
      }
      if (duration is! num || duration <= 0) {
        warnings.add('$ctx: track "$lang" invalid durationSec — dropped');
        return;
      }
      tracks[lang] = AudioTrack(
        filePath: file,
        durationSec: duration.toDouble(),
        transcript: transcript,
      );
    });

    // A clip is usable only if the fallback-language track survived —
    // otherwise resolve() could return nothing for some visitors.
    if (!tracks.containsKey(fallbackLang)) {
      if (failFast) {
        throw BundleValidationException(
            '$ctx: no valid "$fallbackLang" (fallback) audio track');
      }
      return null;
    }
    return AudioClipInfo(tracks: Map.unmodifiable(tracks));
  }

  // ---- typed-extraction helpers ------------------------------------------------
  // Each throws BundleValidationException with a precise context string —
  // "which field of which object" is the difference between a 5-minute fix
  // and an evening of println debugging for the content team.

  static Map<String, dynamic> _reqMap(
      Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v is Map<String, dynamic>) return v;
    throw BundleValidationException('$ctx: "$key" missing or not an object');
  }

  static String _reqString(Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v is String && v.isNotEmpty) return v;
    throw BundleValidationException('$ctx: "$key" missing or empty');
  }

  static int _reqInt(Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v is int && v >= 1 && v <= 65535) return v;
    throw BundleValidationException('$ctx: "$key" must be int in [1, 65535]');
  }

  static double _reqNum(Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v is num) return v.toDouble();
    throw BundleValidationException('$ctx: "$key" missing or not a number');
  }

  /// C1 — số TÙY CHỌN: thiếu hoặc sai kiểu ⇒ dùng [fallback] (không fail
  /// bundle). Dành cho các trường thêm sau schemaVersion hiện hành để bundle
  /// cũ trên máy vẫn parse được sau khi cập nhật app.
  static double _optNum(Map<String, dynamic> m, String key, double fallback) {
    final v = m[key];
    return v is num ? v.toDouble() : fallback;
  }

  /// Map phẳng lang → chuỗi (vd languageNames). Bỏ qua entry sai kiểu/rỗng.
  static Map<String, String> _optStringMap(
      Map<String, dynamic> root, String key) {
    final raw = root[key];
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (k is String && v is String && v.isNotEmpty) out[k] = v;
    });
    return Map.unmodifiable(out);
  }

  /// Số giây TÙY CHỌN → Duration, clamp [lo, hi]. Thiếu/sai kiểu ⇒ null.
  static Duration? _optDurationSeconds(
      Map<String, dynamic> m, String key, double lo, double hi) {
    final v = m[key];
    if (v is! num) return null;
    return Duration(milliseconds: (v.toDouble().clamp(lo, hi) * 1000).round());
  }

  static Map<String, Map<String, String>> _optUiStrings(
      Map<String, dynamic> root, String key) {
    final raw = root[key];
    if (raw is! Map) return const {};
    final out = <String, Map<String, String>>{};
    raw.forEach((lang, table) {
      if (lang is String && table is Map) {
        final t = <String, String>{};
        table.forEach((k, v) {
          if (k is String && v is String) t[k] = v;
        });
        if (t.isNotEmpty) out[lang] = Map.unmodifiable(t);
      }
    });
    return Map.unmodifiable(out);
  }

  static bool _reqBool(Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v is bool) return v;
    throw BundleValidationException('$ctx: "$key" missing or not a boolean');
  }

  static List<String> _reqStringList(
      Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v is List && v.isNotEmpty && v.every((e) => e is String)) {
      return v.cast<String>();
    }
    throw BundleValidationException(
        '$ctx: "$key" missing or not a string array');
  }

  static String _reqPath(Map<String, dynamic> m, String key, String ctx) {
    final v = _reqString(m, key, ctx);
    if (!_pathRule.hasMatch(v)) {
      throw BundleValidationException(
          '$ctx: "$key" is not a safe bundle-relative path: $v');
    }
    return v;
  }

  static String? _optPath(Map<String, dynamic> m, String key, String ctx) {
    if (!m.containsKey(key) || m[key] == null) return null;
    return _reqPath(m, key, ctx);
  }

  static LocalizedText _localized(
      Map<String, dynamic> m, String ctx, String fallbackLang) {
    final values = <String, String>{};
    m.forEach((lang, text) {
      if (text is String && text.isNotEmpty) values[lang] = text;
    });
    if (!values.containsKey(fallbackLang)) {
      throw BundleValidationException(
          '$ctx: localized text missing fallback "$fallbackLang"');
    }
    return LocalizedText(Map.unmodifiable(values));
  }

  static LocalizedText _reqLocalized(
      Map<String, dynamic> m, String key, String ctx, String fallbackLang) {
    return _localized(_reqMap(m, key, ctx), '$ctx.$key', fallbackLang);
  }
}