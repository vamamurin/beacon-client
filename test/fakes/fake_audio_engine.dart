// Destination: test/fakes/fake_audio_engine.dart
// (test support — not shipped in lib/)
//
// In-memory, silent stand-ins for IAudioEngine and IHeadphoneMonitor so the
// TourAudioController's POLICY can be tested exhaustively and deterministically
// with no plugins, no real audio, no timers. Every transition is driven by an
// explicit test call — including clip completion (completeCurrent), which the
// real engine fires from the decoder.

import 'dart:async';

import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/interfaces/i_headphone_monitor.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';

class FakeAudioEngine implements IAudioEngine {
  AudioQueueState _state = AudioQueueState.idle;

  final _stateCtrl = StreamController<AudioQueueState>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _completedCtrl = StreamController<AudioTrackRef>.broadcast();

  /// Log of every clip loaded, in order — the primary assertion surface for
  /// "did the controller queue the right sequence?".
  final List<AudioTrackRef> loadLog = [];

  /// Count of stop() calls — asserts zone-change queue flushing.
  int stopCount = 0;

  @override
  AudioQueueState get state => _state;

  @override
  Stream<AudioQueueState> get onStateChanged => _stateCtrl.stream;

  @override
  Stream<Duration> get onPosition => _posCtrl.stream;

  @override
  Stream<AudioTrackRef> get onCompleted => _completedCtrl.stream;

  void _emit(AudioQueueState next) {
    if (next == _state) {
      _state = next; // keep non-equality fields (position) fresh
      return;
    }
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  @override
  Future<void> load(AudioTrackRef ref, Uri source,
      {Duration? durationHint}) async {
    loadLog.add(ref);
    _emit(AudioQueueState(
      current: ref,
      status: PlaybackStatus.loading,
      duration: durationHint,
    ));
  }

  @override
  Future<void> play() async {
    if (_state.current == null) return;
    _emit(_state.copyWith(status: PlaybackStatus.playing));
  }

  @override
  Future<void> pause() async {
    if (_state.current == null) return;
    _emit(_state.copyWith(status: PlaybackStatus.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    _emit(_state.copyWith(position: position));
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _emit(AudioQueueState.idle);
  }

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
    await _posCtrl.close();
    await _completedCtrl.close();
  }

  // ---- test drivers (simulate what the real decoder/engine would do) ----

  /// Simulate the loaded clip reaching its natural end.
  void completeCurrent() {
    final ref = _state.current;
    if (ref == null) return;
    _emit(AudioQueueState.idle); // engine goes idle between clips
    _completedCtrl.add(ref); // controller reacts by advancing the queue
  }

  /// Simulate a position tick (for progress-bar consumers).
  void tick(Duration position) => _posCtrl.add(position);
}

class FakeHeadphoneMonitor implements IHeadphoneMonitor {
  FakeHeadphoneMonitor({bool connected = true}) : _connected = connected;

  bool _connected;
  final _ctrl = StreamController<bool>.broadcast();

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get onConnectionChanged => _ctrl.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async => _ctrl.close();

  /// Simulate plug/unplug. false edge == "becoming noisy".
  void setConnected(bool value) {
    if (value == _connected) return;
    _connected = value;
    _ctrl.add(value);
  }
}
