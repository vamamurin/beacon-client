// Destination: lib/presentation/providers/audio_provider.dart
//
// Thin ChangeNotifier over the audio engine's state stream, plus the user
// intents the UI triggers (tap exhibit, play, pause, replay). Position is
// exposed as a SEPARATE raw stream (not through notifyListeners) so a moving
// progress bar doesn't rebuild the whole tree — same discipline as Phase 2's
// AudioQueueState equality excluding position.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';

class AudioProvider extends ChangeNotifier {
  AudioProvider({
    required IAudioEngine engine,
    required TourAudioController controller,
  })  : _engine = engine,
        _controller = controller {
    _stateSub = _engine.onStateChanged.listen((s) {
      _state = s;
      notifyListeners();
    });
    _state = _engine.state;
  }

  final IAudioEngine _engine;
  final TourAudioController _controller;
  late StreamSubscription<AudioQueueState> _stateSub;

  AudioQueueState _state = AudioQueueState.idle;
  AudioQueueState get state => _state;

  /// High-frequency playhead — subscribe directly in a small widget; do NOT
  /// route through notifyListeners.
  Stream<Duration> get position => _engine.onPosition;

  bool get isPlaying => _state.isPlaying;
  bool get isPaused => _state.isPaused;
  AudioTrackRef? get current => _state.current;

  // ── user intents ──
  void tapExhibit(int minor) => _controller.tapExhibit(minor);
  void play() => _controller.userPlay();
  void pause() => _controller.userPause();

  /// Restart the loaded clip from the beginning ("Về đầu"). Mirrors [play] as
  /// an explicit user action: it seeks to 0 and plays. Only meaningful when a
  /// clip is loaded; on an empty engine it's a harmless no-op.
  void replay() {
    _engine.seek(Duration.zero);
    _engine.play();
  }

  @override
  void dispose() {
    _stateSub.cancel();
    super.dispose();
  }
}