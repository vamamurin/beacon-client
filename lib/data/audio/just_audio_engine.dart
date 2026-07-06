// Destination: lib/data/audio/just_audio_engine.dart
//
// Real IAudioEngine over just_audio. Deliberately uses the ONE-CLIP-AT-A-TIME
// model (setAudioSource + completion event), NOT just_audio's playlist
// (ConcatenatingAudioSource). Sequencing/interrupt/resume-after logic lives in
// TourAudioController; letting the plugin auto-advance a playlist would move
// that logic out of our control. The engine "just plays" one clip and reports.
//
// Background playback, notification and lock-screen controls come from
// audio_service wiring (see MuseumAudioHandler note at the bottom / Phase-4
// app wiring). audio_session is configured for SPEECH, not music, so a phone
// call pauses narration (audio-book behaviour) rather than ducking it.
//
// NOT unit-tested (plugin/hardware). FakeAudioEngine covers all controller
// logic; this class is verified via the on-device checklist.

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';

class JustAudioEngine implements IAudioEngine {
  JustAudioEngine() {
    _wireStreams();
  }

  final AudioPlayer _player = AudioPlayer(
    // We handle interruptions OURSELVES via audio_session below, because our
    // resume policy (rule 6: never auto-resume) differs from just_audio's
    // default. Setting this false stops the plugin from auto-resuming.
    handleInterruptions: false,
  );

  AudioTrackRef? _currentRef;
  Duration? _durationHint;
  AudioQueueState _state = AudioQueueState.idle;
  bool _completedSignalled = false;

  final _stateCtrl = StreamController<AudioQueueState>.broadcast();
  final _completedCtrl = StreamController<AudioTrackRef>.broadcast();

  late final StreamSubscription<PlayerState> _playerStateSub;

  /// One-time audio-session setup for SPEECH. Call once at app start before
  /// first playback (Phase-4 wiring). Pausing on interruption + not ducking is
  /// the audio-book behaviour we want for narration.
  static Future<void> configureSpeechSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  void _wireStreams() {
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
  }

  void _onPlayerState(PlayerState ps) {
    final status = switch (ps.processingState) {
      ProcessingState.idle => PlaybackStatus.idle,
      ProcessingState.loading ||
      ProcessingState.buffering =>
        PlaybackStatus.loading,
      ProcessingState.ready =>
        ps.playing ? PlaybackStatus.playing : PlaybackStatus.paused,
      // On completion just_audio stays "playing" at the end; we model that as
      // paused and fire onCompleted exactly once so the controller advances.
      ProcessingState.completed => PlaybackStatus.paused,
    };

    _emit(_state.copyWith(
      status: status,
      current: _currentRef,
      duration: _durationHint,
    ));

    if (ps.processingState == ProcessingState.completed &&
        !_completedSignalled) {
      _completedSignalled = true;
      final ref = _currentRef;
      if (ref != null && !_completedCtrl.isClosed) {
        _completedCtrl.add(ref); // controller's cue to advance the queue
      }
    }
  }

  void _emit(AudioQueueState next) {
    if (next == _state) {
      _state = next;
      return;
    }
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  // ---- IAudioEngine ----

  @override
  AudioQueueState get state => _state;

  @override
  Stream<AudioQueueState> get onStateChanged => _stateCtrl.stream;

  @override
  Stream<Duration> get onPosition => _player.positionStream;

  @override
  Stream<AudioTrackRef> get onCompleted => _completedCtrl.stream;

  @override
  Future<void> load(AudioTrackRef ref, Uri source,
      {Duration? durationHint}) async {
    _currentRef = ref;
    _durationHint = durationHint;
    _completedSignalled = false;
    _emit(AudioQueueState(
      current: ref,
      status: PlaybackStatus.loading,
      duration: durationHint,
    ));
    try {
      // setAudioSource loads but does NOT play — matches the interface
      // contract that lets a paused visitor keep a queued-but-silent intro.
      await _player.setAudioSource(AudioSource.uri(source));
    } on PlayerException catch (e) {
      if (kDebugMode) debugPrint('[JustAudioEngine] load error: $e');
      _emit(AudioQueueState.idle);
    } on PlayerInterruptedException {
      // A newer load() superseded this one — expected, ignore.
    } catch (e) {
      if (kDebugMode) debugPrint('[JustAudioEngine] load failed: $e');
      _emit(AudioQueueState.idle);
    }
  }

  @override
  Future<void> play() async {
    if (_currentRef == null) return;
    // If the previous clip completed, rewind before replaying.
    if (_completedSignalled) {
      await _player.seek(Duration.zero);
      _completedSignalled = false;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (_currentRef == null) return;
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    _currentRef = null;
    _durationHint = null;
    _completedSignalled = false;
    await _player.stop();
    _emit(AudioQueueState.idle);
  }

  @override
  Future<void> dispose() async {
    await _playerStateSub.cancel();
    await _player.dispose();
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
    if (!_completedCtrl.isClosed) await _completedCtrl.close();
  }
}
