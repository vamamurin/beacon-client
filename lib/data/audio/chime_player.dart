// Destination: lib/data/audio/chime_player.dart
//
// The zone-change "ting". Kept SEPARATE from the narration engine (confirmed
// design): the chime plays OVER narration, isn't part of the tour queue, and
// must never be confused with "the current clip". A dedicated tiny AudioPlayer
// owns it. This is the onChime callback TourAudioController fires.
//
// The chime asset is app UX chrome, NOT bundle content (a museum's content
// team shouldn't have to ship it), so it lives in the app's bundled assets.
//
// NOT unit-tested (plugin). Verified via the on-device checklist.

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class ChimePlayer {
  ChimePlayer({this.assetPath = 'assets/audio/chime.mp3'});

  /// App-bundled asset path (declare it under `flutter: assets:` in pubspec).
  final String assetPath;

  AudioPlayer? _player;
  bool _ready = false;

  /// Preload the chime once so the first zone change doesn't stutter. Call at
  /// app start (Phase-4 wiring). Safe to call more than once.
  Future<void> preload() async {
    if (_ready) return;
    try {
      _player = AudioPlayer(handleInterruptions: false);
      await _player!.setAsset(assetPath);
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChimePlayer] preload failed: $e');
      _ready = false;
    }
  }

  /// Fire-and-forget: rewind to start and play over whatever narration is
  /// happening. Deliberately does NOT await completion — the caller (zone
  /// change) must not block on the ting.
  void play() {
    final p = _player;
    if (p == null || !_ready) return;
    p.seek(Duration.zero).then((_) => p.play()).catchError((Object e) {
      if (kDebugMode) debugPrint('[ChimePlayer] play failed: $e');
    });
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _ready = false;
  }
}
