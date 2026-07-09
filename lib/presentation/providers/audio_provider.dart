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

  // ── user intents ── (tất cả đi qua controller, không chạm engine)
  AudioIntentResult tapExhibit({required int major, required int minor}) =>
      _controller.tapExhibit(major: major, minor: minor);
  AudioIntentResult play() => _controller.userPlay();
  void pause() => _controller.userPause();

  /// Tua về đầu rồi phát (nếu chính sách cho phép).
  AudioIntentResult replay() => _controller.userReplay();

  void seek(Duration position) => _controller.userSeek(position);

  @override
  void dispose() {
    _stateSub.cancel();
    super.dispose();
  }
}