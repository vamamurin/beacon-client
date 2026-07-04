import 'package:flutter/foundation.dart';

/// One recorded narration file for one language.
///
/// [transcript] is REQUIRED by the bundle schema — it is not decoration: it
/// backs the reading mode (guest without headphones) and accessibility.
/// [filePath] is bundle-relative; the repository layer resolves it inside the
/// active bundle directory and never outside it.
@immutable
class AudioTrack {
  final String filePath;
  final double durationSec;
  final String transcript;

  const AudioTrack({
    required this.filePath,
    required this.durationSec,
    required this.transcript,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioTrack &&
        other.filePath == filePath &&
        other.durationSec == durationSec &&
        other.transcript == transcript;
  }

  @override
  int get hashCode => Object.hash(filePath, durationSec, transcript);
}

/// Result of resolving an [AudioClipInfo] for a chosen language.
///
/// [track] and [transcript] are resolved INDEPENDENTLY on purpose (spec §3.6):
/// if the chosen language has no recorded audio yet, the audio falls back to
/// the museum's fallback language, but the transcript still prefers the chosen
/// language when available — hearing Vietnamese while reading English beats
/// reading nothing.
@immutable
class ResolvedAudio {
  final AudioTrack track;
  final String transcript;

  /// True when [track] is not in the language the visitor chose — the UI may
  /// surface a small "audio available in Vietnamese only" note.
  final bool audioFellBack;

  const ResolvedAudio({
    required this.track,
    required this.transcript,
    required this.audioFellBack,
  });
}

/// Narration clip with one [AudioTrack] per language.
///
/// The bundle validator guarantees a track exists for the fallback language,
/// so [resolve] can only return null on a malformed bundle that slipped past
/// validation — callers treat null as "no narration" and degrade gracefully.
@immutable
class AudioClipInfo {
  /// Keyed by language code ("vi", "en", ...).
  final Map<String, AudioTrack> tracks;

  const AudioClipInfo({required this.tracks});

  /// Applies the two-axis fallback rule described on [ResolvedAudio].
  ResolvedAudio? resolve(String lang, String fallbackLang) {
    final AudioTrack? track = tracks[lang] ?? tracks[fallbackLang];
    if (track == null) return null;

    final bool fellBack = !tracks.containsKey(lang);
    // Transcript prefers the CHOSEN language even when audio fell back.
    final String transcript =
        (tracks[lang]?.transcript) ?? track.transcript;

    return ResolvedAudio(
      track: track,
      transcript: transcript,
      audioFellBack: fellBack,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioClipInfo && mapEquals(other.tracks, tracks);
  }

  @override
  int get hashCode => Object.hashAllUnordered(
        tracks.entries.map((e) => Object.hash(e.key, e.value)),
      );
}
