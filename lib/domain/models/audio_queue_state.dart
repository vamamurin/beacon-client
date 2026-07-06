// Destination: lib/domain/models/audio_queue_state.dart

import 'package:flutter/foundation.dart';

/// What KIND of clip is loaded — drives UI labelling and the controller's
/// "what plays next" logic. A zone intro advances into the exhibit queue; an
/// exhibit advances to the next exhibit; a manually-tapped exhibit advances
/// to the one AFTER it (rule 2a) — the enum is how the controller tells these
/// apart without re-deriving intent later.
enum AudioClipKind {
  /// Zone welcome narration (plays first on auto-tour entry).
  zoneIntro,

  /// An exhibit clip reached by the auto-tour running in sequence.
  exhibitAuto,

  /// An exhibit clip the visitor tapped explicitly. After it finishes the
  /// queue resumes from the NEXT exhibit in tour order (confirmed rule 2a).
  exhibitManual,
}

/// Playback engine status, mirrored up from IAudioEngine. Deliberately small:
/// the tour controller only ever needs these four to make policy decisions.
enum PlaybackStatus {
  /// Nothing loaded / tour idle.
  idle,

  /// A clip is loaded and actively producing sound.
  playing,

  /// A clip is loaded but held — covers BOTH user-initiated pause and
  /// headphone-unplug pause. The controller reads this at a zone-change moment
  /// to decide autoplay-vs-silence (confirmed: state is judged at the instant
  /// the event arrives, no history).
  paused,

  /// Between clips or fetching — transient, treated like "busy, not paused".
  loading,
}

/// Identifies WHICH narration clip is loaded, by zone + optional exhibit.
///
/// [exhibitMinor] is null for a [AudioClipKind.zoneIntro]. Carries [clipKind]
/// so a single ref fully describes "zone 1's intro" vs "zone 1 exhibit 5,
/// tapped" without a second lookup.
@immutable
class AudioTrackRef {
  final int zoneMajor;
  final int? exhibitMinor;
  final AudioClipKind clipKind;

  const AudioTrackRef({
    required this.zoneMajor,
    required this.exhibitMinor,
    required this.clipKind,
  });

  const AudioTrackRef.zoneIntro(this.zoneMajor)
      : exhibitMinor = null,
        clipKind = AudioClipKind.zoneIntro;

  bool get isIntro => clipKind == AudioClipKind.zoneIntro;
  bool get isManual => clipKind == AudioClipKind.exhibitManual;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioTrackRef &&
        other.zoneMajor == zoneMajor &&
        other.exhibitMinor == exhibitMinor &&
        other.clipKind == clipKind;
  }

  @override
  int get hashCode => Object.hash(zoneMajor, exhibitMinor, clipKind);

  @override
  String toString() =>
      'AudioTrackRef(zone: $zoneMajor, exhibit: $exhibitMinor, $clipKind)';
}

/// Immutable snapshot of "where the audio tour is right now" — the single type
/// the UI (now-playing bar, exhibit highlight) and the session layer read.
///
/// Mirrors the ZonePresence discipline from Phase 1: [position] is EXCLUDED
/// from equality because it advances several times per second during
/// playback; including it would spam every listener on the UI thread. Widgets
/// that render a live progress bar subscribe to the engine's position stream
/// directly instead of widening this type's equality.
@immutable
class AudioQueueState {
  /// Currently loaded clip, or null when the tour is idle/standby.
  final AudioTrackRef? current;

  final PlaybackStatus status;

  /// Total duration of the loaded clip (from the bundle's durationSec), for
  /// showing "0:12 / 0:47" without waiting on the decoder. Null when idle.
  final Duration? duration;

  /// Live playhead. NOT part of equality (see class note).
  final Duration position;

  /// True while a manual tap's clip is playing — the UI uses this to decide
  /// whether the highlighted exhibit follows the auto-tour or the tap.
  bool get isManualClip => current?.isManual ?? false;

  const AudioQueueState({
    this.current,
    this.status = PlaybackStatus.idle,
    this.duration,
    this.position = Duration.zero,
  });

  static const AudioQueueState idle = AudioQueueState();

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isPaused => status == PlaybackStatus.paused;

  AudioQueueState copyWith({
    AudioTrackRef? current,
    bool clearCurrent = false,
    PlaybackStatus? status,
    Duration? duration,
    bool clearDuration = false,
    Duration? position,
  }) {
    return AudioQueueState(
      current: clearCurrent ? null : (current ?? this.current),
      status: status ?? this.status,
      duration: clearDuration ? null : (duration ?? this.duration),
      position: position ?? this.position,
    );
  }

  /// Equality ignores [position] on purpose (see class note) so steady
  /// playback doesn't churn listeners.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioQueueState &&
        other.current == current &&
        other.status == status &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(current, status, duration);

  @override
  String toString() =>
      'AudioQueueState($status, current: $current, '
      'pos: ${position.inSeconds}s/${duration?.inSeconds ?? "?"}s)';
}
