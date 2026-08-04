// Destination: lib/data/repositories/manifest_parser.dart

import 'package:beacon_client/domain/models/audio_clip_info.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/feedback_config.dart';
import 'package:beacon_client/domain/models/guide_content.dart';
import 'package:beacon_client/domain/models/localized_text.dart';
import 'package:beacon_client/domain/models/menu_config.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/summary_config.dart';
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

    // ---- màn hình phụ trợ (menu / hướng dẫn / tổng kết / đánh giá) ---------
    // Bốn khối TÙY CHỌN, và không khối nào được phép làm hỏng bundle: mất màn
    // Menu thì cả bảo tàng đứng, còn một câu hỏi đánh giá gõ sai thì chỉ mất
    // câu hỏi đó. Mọi lỗi ở đây đi vào [warnings] rồi rơi về mặc định.
    final menu = _optMenu(root, warnings);
    final guide = _optGuide(root, fallbackLanguage, warnings);
    final summary = _optSummary(root, fallbackLanguage, warnings);
    final feedback = _optFeedback(root, fallbackLanguage, warnings);

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
        menu: menu,
        guide: guide,
        summary: summary,
        feedback: feedback,
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
      final imagePath = _reqPath(e, 'image', ctx);
      return ExhibitInfo(
        minor: _reqInt(e, 'minor', ctx),
        id: e['id'] as String?,
        name: _reqLocalized(e, 'name', ctx, fallbackLang),
        summary: _reqLocalized(e, 'summary', ctx, fallbackLang),
        meaning: meaningRaw is Map<String, dynamic>
            ? _localized(meaningRaw, ctx, fallbackLang)
            : null,
        specs: List.unmodifiable(specs),
        imagePath: imagePath,
        thumbnailPath: _reqPath(e, 'thumbnail', ctx),
        extraImagePaths: _optExtraImages(e, ctx, imagePath, warnings),
        audio: audio,
      );
    } on BundleValidationException catch (err) {
      warnings.add('$ctx: skipped — ${err.message}');
      return null;
    }
  }

  /// `exhibit.images` — dải ảnh phụ, TÙY CHỌN.
  ///
  /// KHÔNG bao giờ làm hỏng hiện vật. Đây là quy tắc khác với `image` (bắt
  /// buộc, sai ⇒ bỏ cả hiện vật): mất một ảnh phụ thì khách vẫn xem được hiện
  /// vật và vẫn nghe được thuyết minh — huỷ cả bản ghi vì một đường dẫn thừa
  /// gõ sai là phản ứng lớn hơn thiệt hại. Mỗi phần tử hỏng ⇒ một warning và
  /// bị bỏ; trường không có / sai kiểu ⇒ rỗng (mọi bundle cũ đi đường này).
  ///
  /// [mainPath] bị LỌC RA: CMS có thể liệt kê cả ảnh chính trong `images` cho
  /// đủ bộ, và nếu không lọc thì màn 4 sẽ có hai trang y hệt nhau ở đầu dải.
  /// Trùng lặp giữa các ảnh phụ cũng bị loại theo cùng lý do.
  static List<String> _optExtraImages(
    Map<String, dynamic> e,
    String ctx,
    String mainPath,
    List<String> warnings,
  ) {
    final raw = e['images'];
    if (raw == null) return const [];
    if (raw is! List) {
      warnings.add('$ctx: "images" is not an array — ignored');
      return const [];
    }

    final out = <String>[];
    final seen = <String>{mainPath};
    for (final item in raw) {
      if (item is! String || !_pathRule.hasMatch(item)) {
        warnings.add('$ctx: dropped invalid entry in "images": $item');
        continue;
      }
      if (!seen.add(item)) continue; // trùng ảnh chính hoặc trùng nhau
      out.add(item);
    }
    return List.unmodifiable(out);
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

  // ---- màn hình phụ trợ ---------------------------------------------------
  //
  // Bốn hàm dưới đây có một quy ước chung KHÁC với phần còn lại của parser:
  // chúng KHÔNG BAO GIỜ ném. Nội dung trưng bày sai thì thà giữ bundle cũ còn
  // hơn nói dối khách (spec §6), nhưng một mục menu gõ sai id không phải lý do
  // để cả bảo tàng mất luôn nội dung mới. Mọi lỗi ⇒ warning + rơi về mặc định.

  /// Khối `menu`. Thứ tự mảng là thứ tự hiển thị.
  ///
  /// BẤT BIẾN ĐƯỢC ÉP: kết quả luôn có một mục [MenuAction.startTour] đang bật.
  /// Cùng học thuyết với [ArbitrationParams.clamped] — server được tin về NỘI
  /// DUNG, không được tin về SỰ ỔN ĐỊNH của app. Một CMS tắt nhầm mục "start"
  /// sẽ khoá toàn bộ đội máy ở màn Menu không có đường vào tour; ở đây nó chỉ
  /// tự nắn lại kèm warning.
  static MenuConfig _optMenu(Map<String, dynamic> root, List<String> warnings) {
    final raw = root['menu'];
    if (raw == null) return MenuConfig.defaults;
    if (raw is! Map<String, dynamic>) {
      warnings.add('menu: không phải object — dùng menu mặc định');
      return MenuConfig.defaults;
    }
    final list = raw['entries'];
    if (list is! List) {
      warnings.add('menu: "entries" không phải mảng — dùng menu mặc định');
      return MenuConfig.defaults;
    }

    final out = <MenuEntry>[];
    final seen = <MenuAction>{};
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        warnings.add('menu: bỏ một mục không phải object');
        continue;
      }
      final id = item['id'];
      if (id is! String) {
        warnings.add('menu: bỏ một mục thiếu "id"');
        continue;
      }
      final action = MenuAction.byId(id);
      if (action == null) {
        warnings.add('menu: id không hỗ trợ "$id" — bỏ qua');
        continue;
      }
      if (!seen.add(action)) {
        warnings.add('menu: id trùng "$id" — chỉ giữ lần khai báo đầu');
        continue;
      }
      final enabled = item['enabled'];
      out.add(MenuEntry(action, enabled: enabled is bool ? enabled : true));
    }

    if (out.isEmpty) {
      warnings.add('menu: không mục nào hợp lệ — dùng menu mặc định');
      return MenuConfig.defaults;
    }
    // Ép bất biến: phải còn đường vào tour.
    if (!out.any((e) => e.action == MenuAction.startTour && e.enabled)) {
      out.removeWhere((e) => e.action == MenuAction.startTour);
      out.insert(0, const MenuEntry(MenuAction.startTour));
      warnings.add(
          'menu: thiếu mục "start" đang bật — đã tự thêm lại ở đầu danh sách');
    }
    return MenuConfig(entries: List.unmodifiable(out));
  }

  /// Khối `guide`. Bước hỏng bị bỏ riêng lẻ (cùng cách xử lý với `exhibit`),
  /// vì mất một bước vẫn còn hướng dẫn để đọc.
  static GuideContent _optGuide(
    Map<String, dynamic> root,
    String fallbackLang,
    List<String> warnings,
  ) {
    final raw = root['guide'];
    if (raw == null) return GuideContent.empty;
    if (raw is! Map<String, dynamic>) {
      warnings.add('guide: không phải object — dùng hướng dẫn mặc định');
      return GuideContent.empty;
    }
    final list = raw['steps'];
    if (list is! List) {
      warnings.add('guide: "steps" không phải mảng — dùng hướng dẫn mặc định');
      return GuideContent.empty;
    }

    final out = <GuideStep>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      final ctx = 'guide.steps[$i]';
      if (item is! Map<String, dynamic>) {
        warnings.add('$ctx: không phải object — bỏ');
        continue;
      }
      // Ảnh minh họa hỏng KHÔNG làm mất bước — cùng lý do với `exhibit.images`:
      // chữ mới là nội dung của bước, ảnh chỉ là trang trí. Tách ra ngoài khối
      // try bên dưới để nó không kéo theo cả bản ghi.
      String? imagePath;
      try {
        imagePath = _optPath(item, 'image', ctx);
      } on BundleValidationException catch (err) {
        warnings.add('$ctx: bỏ ảnh minh họa — ${err.message}');
      }

      try {
        final icon = item['icon'];
        out.add(GuideStep(
          title: _reqLocalized(item, 'title', ctx, fallbackLang),
          body: _reqLocalized(item, 'body', ctx, fallbackLang),
          iconId: icon is String && icon.isNotEmpty ? icon : null,
          imagePath: imagePath,
        ));
      } on BundleValidationException catch (err) {
        warnings.add('$ctx: bỏ — ${err.message}');
      }
    }
    return out.isEmpty
        ? GuideContent.empty
        : GuideContent(steps: List.unmodifiable(out));
  }

  /// Khối `summary` (+ `farewell`, gộp vào cùng một model vì cả hai chỉ mô tả
  /// một việc: chuyến đi kết thúc thế nào).
  static SummaryConfig _optSummary(
    Map<String, dynamic> root,
    String fallbackLang,
    List<String> warnings,
  ) {
    // `farewell` đọc trước và độc lập: bundle có thể khai báo nó mà không khai
    // báo `summary`.
    var farewellAuto = Duration.zero;
    final far = root['farewell'];
    if (far is Map<String, dynamic>) {
      // Trần 300 s: giữ màn cảm ơn quá lâu thì không khác gì giữ vô hạn, mà
      // giữ vô hạn đã có cách diễn đạt riêng (0).
      farewellAuto =
          _optDurationSeconds(far, 'autoReturnSeconds', 0, 300) ?? Duration.zero;
    } else if (far != null) {
      warnings.add('farewell: không phải object — bỏ qua');
    }

    final raw = root['summary'];
    if (raw == null) {
      return SummaryConfig(farewellAutoReturn: farewellAuto);
    }
    if (raw is! Map<String, dynamic>) {
      warnings.add('summary: không phải object — dùng mặc định');
      return SummaryConfig(farewellAutoReturn: farewellAuto);
    }

    LocalizedText? closing;
    final closingRaw = raw['closing'];
    if (closingRaw is Map<String, dynamic>) {
      try {
        closing = _localized(closingRaw, 'summary.closing', fallbackLang);
      } on BundleValidationException catch (err) {
        warnings.add('summary.closing: bỏ — ${err.message}');
      }
    } else if (closingRaw != null) {
      warnings.add('summary: "closing" không phải object đa ngữ — bỏ');
    }

    final fb = raw['showFeedback'];
    var showQr = raw['showQr'] is bool ? raw['showQr'] as bool : false;
    final qrBase = _optHttpUrl(raw, 'qrBaseUrl', 'summary', warnings);
    if (showQr && qrBase == null) {
      // Bật QR mà không có trang đích thì khách quét ra trang trắng — tệ hơn là
      // không có QR nào.
      warnings.add('summary: showQr=true nhưng thiếu qrBaseUrl hợp lệ — tắt QR');
      showQr = false;
    }

    return SummaryConfig(
      closing: closing,
      showFeedback: fb is bool ? fb : true,
      showQr: showQr,
      qrBaseUrl: qrBase,
      farewellAutoReturn: farewellAuto,
    );
  }

  /// Trần số nhãn lý do trên khối đánh giá. CMS đổ 30 nhãn vào một panel nhỏ
  /// thì khách không đọc nhãn nào cả.
  static const int _maxFeedbackTags = 8;

  /// Khối `feedback`.
  static FeedbackConfig _optFeedback(
    Map<String, dynamic> root,
    String fallbackLang,
    List<String> warnings,
  ) {
    final raw = root['feedback'];
    if (raw == null) return FeedbackConfig.defaults;
    if (raw is! Map<String, dynamic>) {
      warnings.add('feedback: không phải object — dùng mặc định');
      return FeedbackConfig.defaults;
    }

    var scale = FeedbackScale.stars5;
    final scaleRaw = raw['scale'];
    if (scaleRaw is String) {
      final parsed = FeedbackScale.byId(scaleRaw);
      if (parsed == null) {
        warnings.add('feedback: thang đo không hỗ trợ "$scaleRaw" — dùng stars5');
      } else {
        scale = parsed;
      }
    }

    LocalizedText? question;
    final qRaw = raw['question'];
    if (qRaw is Map<String, dynamic>) {
      try {
        question = _localized(qRaw, 'feedback.question', fallbackLang);
      } on BundleValidationException catch (err) {
        warnings.add('feedback.question: bỏ — ${err.message}');
      }
    } else if (qRaw != null) {
      warnings.add('feedback: "question" không phải object đa ngữ — bỏ');
    }

    final tags = <FeedbackTag>[];
    final tagsRaw = raw['tags'];
    if (tagsRaw is List) {
      final seen = <String>{};
      for (var i = 0; i < tagsRaw.length; i++) {
        if (tags.length >= _maxFeedbackTags) {
          warnings.add('feedback: quá $_maxFeedbackTags nhãn — cắt phần thừa');
          break;
        }
        final item = tagsRaw[i];
        final ctx = 'feedback.tags[$i]';
        if (item is! Map<String, dynamic>) {
          warnings.add('$ctx: không phải object — bỏ');
          continue;
        }
        final id = item['id'];
        if (id is! String || id.isEmpty) {
          warnings.add('$ctx: thiếu "id" — bỏ');
          continue;
        }
        if (!seen.add(id)) {
          warnings.add('$ctx: id trùng "$id" — bỏ');
          continue;
        }
        try {
          tags.add(FeedbackTag(
            id: id,
            label: _reqLocalized(item, 'label', ctx, fallbackLang),
          ));
        } on BundleValidationException catch (err) {
          warnings.add('$ctx: bỏ — ${err.message}');
        }
      }
    } else if (tagsRaw != null) {
      warnings.add('feedback: "tags" không phải mảng — bỏ');
    }

    return FeedbackConfig(
      scale: scale,
      question: question,
      tags: List.unmodifiable(tags),
    );
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

  /// URL http/https TÙY CHỌN (hiện chỉ `summary.qrBaseUrl`).
  ///
  /// KHÔNG dùng [_pathRule] được: đây là địa chỉ trang web thật, không phải
  /// payload nằm trong bundle — hai loại giá trị khác nhau nên phải có hai luật
  /// khác nhau. Chỉ nhận http/https có host: một QR mang `javascript:` hay
  /// `intent://` là thứ ta không muốn phát ra từ màn hình của bảo tàng, kể cả
  /// khi nó chỉ do CMS gõ nhầm.
  static String? _optHttpUrl(
    Map<String, dynamic> m,
    String key,
    String ctx,
    List<String> warnings,
  ) {
    final v = m[key];
    if (v == null) return null;
    if (v is! String || v.isEmpty) {
      warnings.add('$ctx: "$key" không phải chuỗi — bỏ');
      return null;
    }
    final uri = Uri.tryParse(v);
    if (uri == null ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      warnings.add('$ctx: "$key" không phải URL http/https hợp lệ: $v');
      return null;
    }
    return v;
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