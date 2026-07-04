import 'package:flutter/foundation.dart';

import 'audio_clip_info.dart';
import 'exhibit_info.dart';
import 'localized_text.dart';

/// Immutable exhibition-zone metadata (successor of FloorInfo).
///
/// Keyed by iBeacon [major] — one zone == one major, regardless of how many
/// physical beacons broadcast it (single ceiling beacon or the existing
/// per-exhibit beacons all sharing the zone's major; arbitration aggregates
/// by major either way).
///
/// [exhibits] order IS the tour order (manifest array order — the single
/// source of truth, no separate "order" field by design).
@immutable
class ZoneInfo {
  final int major;

  /// Slug ("vu-khi-khang-chien") — asset folder name, logs, debugging.
  final String id;

  /// Phase-0 rule: only true for zones whose minor beacons sit >= 3-4 m
  /// apart. When true the UI may softly highlight the nearest exhibit —
  /// a HINT only, never navigation and never an audio interrupt.
  final bool nearestExhibitHint;

  final LocalizedText name;

  /// Shown on the big Zone Card; doubles as the zone description.
  final LocalizedText welcomeText;

  /// Bundle-relative paths. [heroImageBlurredPath] is pre-blurred server-side
  /// — the app must never run a runtime BackdropFilter over the full card.
  final String heroImagePath;
  final String heroImageBlurredPath;

  /// Zone welcome narration ("Bạn đang dừng chân tại cụm Vũ khí...").
  final AudioClipInfo introAudio;

  /// Tour order == list order. Guaranteed non-empty by bundle validation.
  final List<ExhibitInfo> exhibits;

  const ZoneInfo({
    required this.major,
    required this.id,
    this.nearestExhibitHint = false,
    required this.name,
    required this.welcomeText,
    required this.heroImagePath,
    required this.heroImageBlurredPath,
    required this.introAudio,
    required this.exhibits,
  });

  /// Linear lookup by minor. Zones hold ~5-15 exhibits, so O(n) here beats
  /// carrying a parallel map through an otherwise-const constructor. Callers
  /// on hot paths should cache the result, not the lookup.
  ExhibitInfo? exhibitByMinor(int minor) {
    for (final e in exhibits) {
      if (e.minor == minor) return e;
    }
    return null;
  }

  /// Position of [minor] in the tour order, or -1. Used by the audio
  /// controller to implement "continue from AFTER the manually tapped item".
  int tourIndexOf(int minor) =>
      exhibits.indexWhere((e) => e.minor == minor);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZoneInfo &&
        other.major == major &&
        other.id == id &&
        other.nearestExhibitHint == nearestExhibitHint &&
        other.name == name &&
        other.welcomeText == welcomeText &&
        other.heroImagePath == heroImagePath &&
        other.heroImageBlurredPath == heroImageBlurredPath &&
        other.introAudio == introAudio &&
        listEquals(other.exhibits, exhibits);
  }

  @override
  int get hashCode => Object.hash(
        major,
        id,
        nearestExhibitHint,
        name,
        welcomeText,
        heroImagePath,
        heroImageBlurredPath,
        introAudio,
        Object.hashAll(exhibits),
      );
}
