import 'package:flutter/foundation.dart';

import 'localized_text.dart';

/// Zone-arbitration tuning knobs, loaded FROM THE BUNDLE so they can be
/// re-tuned after every site survey without an app rebuild.
///
/// Security/robustness contract (spec §3.2): the server is trusted for
/// CONTENT but not for app STABILITY — every value is clamped into a sane
/// range at construction time via [ArbitrationParams.clamped]. A typo in the
/// CMS (dwell = 0, delta = 900) degrades to the nearest sane bound instead of
/// making every device in the fleet ping-pong between zones.
@immutable
class ArbitrationParams {
  /// A challenger zone must beat the current zone by at least this many dB.
  final double minDeltaDb;

  /// ...and hold that advantage continuously for this long before we switch.
  final Duration dwell;

  /// After a switch, no further switches for this long (border ping-pong guard).
  final Duration lockout;

  /// Current zone unheard for this long ⇒ presence drops back to standby.
  final Duration zoneSilence;

  /// Desk beacon (major 99) stable for this long ⇒ device is back at the
  /// desk ⇒ session controller ends the tour session.
  final Duration deskDwell;

  /// No beacon of ANY major heard for this long ⇒ session-level silence
  /// (device left the exhibition area entirely).
  final Duration sessionSilence;

  /// C1 — TẦNG KÍCH HOẠT: một zone chỉ được trở thành "khu vực hiện tại"
  /// (intro phát, hiện vật vào hàng chờ) khi khoảng cách ước lượng ≤ ngưỡng
  /// này. Zone nghe thấy nhưng xa hơn chỉ nằm ở TẦNG HIỂN THỊ (ranking UI).
  final double engageAtMeters;

  /// C1 — NGƯỠNG NHẢ (hysteresis): zone hiện tại chỉ bị nhả về standby khi
  /// đi ra XA HƠN ngưỡng này (duy trì đủ `dwell`). Khoảng đệm
  /// release − engage nuốt sai số ±30–50% của ước lượng RSSI→mét trong nhà,
  /// chống nhấp nháy ở biên. Bất biến: release ≥ engage + 1 m (ép ở clamped).
  final double releaseAtMeters;

  /// C1 — hệ số suy hao môi trường n của mô hình log-distance (2.0 thoáng,
  /// 2.5–3.5 trong nhà nhiều vật cản). Tinh chỉnh tại hiện trường qua CMS.
  final double pathLossExponent;

  const ArbitrationParams({
    required this.minDeltaDb,
    required this.dwell,
    required this.lockout,
    required this.zoneSilence,
    required this.deskDwell,
    required this.sessionSilence,
    required this.engageAtMeters,
    required this.releaseAtMeters,
    required this.pathLossExponent,
  });

  /// Clamp ranges mirror manifest.schema.json (single source documented in
  /// content-bundle-spec.md §3.2). The schema WARNS at CMS time; this factory
  /// ENFORCES at runtime — defense in depth.
  factory ArbitrationParams.clamped({
    required double minDeltaDb,
    required double dwellSeconds,
    required double lockoutSeconds,
    required double zoneSilenceSeconds,
    required double deskDwellSeconds,
    required double sessionSilenceMinutes,
    double engageAtMeters = 5,
    double releaseAtMeters = 8,
    double pathLossExponent = 2.5,
  }) {
    Duration secs(double v, double lo, double hi) =>
        Duration(milliseconds: (v.clamp(lo, hi) * 1000).round());

    // C1: clamp từng ngưỡng, rồi ÉP bất biến hysteresis release ≥ engage + 1m.
    // CMS gõ nhầm release < engage sẽ tự nắn thành dải hợp lệ thay vì tạo ra
    // một máy trạng thái vào-ra cùng một điểm (nhấp nháy vô hạn).
    final double engage = engageAtMeters.clamp(1.0, 30.0);
    final double release =
        releaseAtMeters.clamp(2.0, 50.0).clamp(engage + 1.0, 50.0);

    return ArbitrationParams(
      minDeltaDb: minDeltaDb.clamp(3.0, 20.0),
      dwell: secs(dwellSeconds, 1, 30),
      lockout: secs(lockoutSeconds, 0, 120),
      zoneSilence: secs(zoneSilenceSeconds, 3, 60),
      deskDwell: secs(deskDwellSeconds, 5, 120),
      sessionSilence: Duration(
        milliseconds: (sessionSilenceMinutes.clamp(2.0, 60.0) * 60000).round(),
      ),
      engageAtMeters: engage,
      releaseAtMeters: release,
      pathLossExponent: pathLossExponent.clamp(1.5, 4.5),
    );
  }

  /// Sensible defaults (== manifest.example.json) for tests and for the
  /// unlikely case a bundle predates the arbitration block.
  factory ArbitrationParams.defaults() => ArbitrationParams.clamped(
        minDeltaDb: 7,
        dwellSeconds: 3,
        lockoutSeconds: 12,
        zoneSilenceSeconds: 8,
        deskDwellSeconds: 10,
        sessionSilenceMinutes: 10,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArbitrationParams &&
        other.minDeltaDb == minDeltaDb &&
        other.dwell == dwell &&
        other.lockout == lockout &&
        other.zoneSilence == zoneSilence &&
        other.deskDwell == deskDwell &&
        other.sessionSilence == sessionSilence &&
        other.engageAtMeters == engageAtMeters &&
        other.releaseAtMeters == releaseAtMeters &&
        other.pathLossExponent == pathLossExponent;
  }

  @override
  int get hashCode => Object.hash(minDeltaDb, dwell, lockout, zoneSilence,
      deskDwell, sessionSilence, engageAtMeters, releaseAtMeters,
      pathLossExponent);
}

/// Museum-wide audio policies — signed off by the museum, shipped in the
/// bundle (spec §3.3), read-only for the app.
@immutable
class AudioPolicies {
  /// false ⇒ the loudspeaker option is hidden entirely at the session gate.
  final bool allowLoudspeaker;

  /// true ⇒ no headphones detected = reading mode (transcript), never
  /// auto-playing narration out loud.
  final bool autoplayRequiresHeadphones;

  /// false ⇒ revisiting a zone within a session plays only the soft chime,
  /// never the 30-second welcome again.
  final bool revisitPlaysWelcome;

  const AudioPolicies({
    required this.allowLoudspeaker,
    required this.autoplayRequiresHeadphones,
    required this.revisitPlaysWelcome,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioPolicies &&
        other.allowLoudspeaker == allowLoudspeaker &&
        other.autoplayRequiresHeadphones == autoplayRequiresHeadphones &&
        other.revisitPlaysWelcome == revisitPlaysWelcome;
  }

  @override
  int get hashCode => Object.hash(
      allowLoudspeaker, autoplayRequiresHeadphones, revisitPlaysWelcome);
}

/// Root configuration parsed from manifest.json (everything except zones).
/// Successor of the config half of AppConstants — beacon UUID and thresholds
/// now travel WITH the content instead of being compiled into the app.
@immutable
class MuseumConfig {
  final String bundleVersion;
  final LocalizedText museumName;

  final String? welcomeImagePath;

  /// Ảnh thứ hai của màn chào (vùng ảnh 2 — khung nhỏ chồng lệch bên phải).
  /// OPTIONAL theo đúng hợp đồng tương thích: bundle cũ không có key
  /// `welcomeAccentImage` ⇒ null ⇒ Gate chỉ vẽ một khung ảnh. Không bao giờ
  /// là điều kiện bắt buộc của bundle.
  final String? welcomeAccentImagePath;

  /// Available narration languages, e.g. ["vi", "en"]. Gate screen options.
  final List<String> languages;
  final String fallbackLanguage;

  /// Museum-wide iBeacon UUID (lowercase).
  final String beaconUuid;

  /// Major reserved for the front-desk beacon. NEVER a zone major (validated
  /// at bundle build AND at repository parse). Seeing it stable for
  /// [ArbitrationParams.deskDwell] means the device has been returned.
  final int deskMajor;

  final ArbitrationParams arbitration;
  final AudioPolicies policies;

  /// D — ngưỡng tự-đồng-bộ (giờ) do SERVER đề xuất cho cả đội máy. Optional:
  /// bundle cũ không có ⇒ null ⇒ SyncConfig lùi về mặc định. Staff vẫn có thể
  /// ghi đè từng máy qua Settings (ưu tiên cao hơn giá trị này).
  final double? autoSyncHours;

  const MuseumConfig({
    required this.bundleVersion,
    required this.museumName,
    this.welcomeImagePath,
    this.welcomeAccentImagePath,
    required this.languages,
    required this.fallbackLanguage,
    required this.beaconUuid,
    required this.deskMajor,
    required this.arbitration,
    required this.policies,
    this.autoSyncHours,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MuseumConfig &&
        other.bundleVersion == bundleVersion &&
        other.museumName == museumName &&
        other.welcomeImagePath == welcomeImagePath &&
        other.welcomeAccentImagePath == welcomeAccentImagePath &&
        listEquals(other.languages, languages) &&
        other.fallbackLanguage == fallbackLanguage &&
        other.beaconUuid == beaconUuid &&
        other.deskMajor == deskMajor &&
        other.arbitration == arbitration &&
        other.policies == policies &&
        other.autoSyncHours == autoSyncHours;
  }

  @override
  int get hashCode => Object.hash(
        bundleVersion,
        museumName,
        welcomeImagePath,
        welcomeAccentImagePath,
        Object.hashAll(languages),
        fallbackLanguage,
        beaconUuid,
        deskMajor,
        arbitration,
        policies,
        autoSyncHours,
      );
}