// Destination: lib/domain/interfaces/i_audio_engine.dart

import 'package:beacon_client/domain/models/audio_queue_state.dart';

/// Low-level narration playback contract — deliberately POLICY-FREE.
///
/// The engine knows how to load one file, play/pause/seek/stop it, and report
/// what it's doing. It knows NOTHING about zones, queues, tour order, "what
/// plays next", chimes, or headphone rules — all of that lives in
/// TourAudioController (Phase 2 Step 3). This boundary is what lets us swap
/// just_audio for anything else without touching a line of policy.
///
/// One clip at a time: loading a new clip replaces the current one. The
/// controller sequences clips by listening to [onCompleted] and calling
/// [load] again — the engine never auto-advances on its own.
abstract interface class IAudioEngine {
  /// Load a clip and identify it with [ref] so state/events echo back WHICH
  /// clip they refer to. [durationHint] comes from the bundle so the UI can
  /// show total time before the decoder resolves it. Does NOT auto-play;
  /// caller decides via [play] (this is what makes "load queued, wait for
  /// play" — the paused-visitor zone-change case — expressible).
  Future<void> load(
    AudioTrackRef ref,
    Uri source, {
    Duration? durationHint,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Stop and UNLOAD — clears [current], returns to idle. Used on zone change
  /// (flush the old queue) and session end.
  Future<void> stop();

  /// Current playback snapshot (synchronous read for late subscribers).
  AudioQueueState get state;

  /// Change-gated state stream (position excluded from equality — see
  /// AudioQueueState). UI and controller both subscribe.
  Stream<AudioQueueState> get onStateChanged;

  /// Live playhead, high-frequency. Subscribe here for a smooth progress bar;
  /// do NOT route it through [onStateChanged].
  Stream<Duration> get onPosition;

  /// Fires once when the loaded clip reaches its natural end. This is the
  /// controller's cue to advance the queue (intro → exhibits, exhibit → next,
  /// manual → the one after). Does NOT fire on [stop] or [pause].
  Stream<AudioTrackRef> get onCompleted;

  Future<void> dispose();
}
