// Destination: lib/data/audio/just_audio_engine.dart
//
// Real IAudioEngine over just_audio. Deliberately uses the ONE-CLIP-AT-A-TIME
// model (setAudioSource + completion event), NOT just_audio's playlist
// (ConcatenatingAudioSource). Sequencing/interrupt/resume-after logic lives in
// TourAudioController; letting the plugin auto-advance a playlist would move
// that logic out of our control. The engine "just plays" one clip and reports.
//
// FIX B8 — CỔNG `_sourceReady` CHO onCompleted (lỗi "đổi khu bị bỏ qua intro"):
// B7 bên dưới bảo vệ ĐƯỜNG EMIT bằng generation token, nhưng KHÔNG bảo vệ
// đường `_completedCtrl.add()`. Hậu quả tái hiện được:
//
//   1. Khách nghe HẾT clip cuối của khu A ⇒ player nằm ở ProcessingState
//      .completed, `_completedSignalled == true`.
//   2. changeZone(B) gọi stop() (không await). stop() đặt
//      `_completedSignalled = false` — LÊN CÒ lại cái bẫy — trong khi player
//      VẪN đang ở `completed`, rồi treo ở `await _player.stop()`.
//   3. Controller chạy tiếp ngay: load(introB) đặt `_currentRef = introB`,
//      `_completedSignalled = false`, rồi treo ở `await setAudioSource`.
//   4. Một PlayerState `completed` còn sót của clip CŨ được giao. Điều kiện
//      `completed && !_completedSignalled` đúng ⇒ bắn onCompleted với ref
//      `introB` — một clip CHƯA HỀ PHÁT.
//   5. TourAudioController thấy ref.zoneMajor == zone hiện hành ⇒ guard cho
//      qua ⇒ _playNextFrom(B, 0) ⇒ nạp hiện vật 0, `_autoIndex = 1`. load()
//      này lại bump generation ⇒ setAudioSource(introB) đang bay bị hủy
//      (PlayerInterruptedException, trước đây bị NUỐT im lặng).
//   6. Event `completed` sót thứ hai lặp lại ⇒ _playNextFrom(B, 1) ⇒ hiện vật
//      thứ HAI của khu B. Đúng triệu chứng đã báo: intro B bị bỏ qua.
//
// Sửa: thêm `_sourceReady` — chỉ TRUE sau khi setAudioSource của thế hệ HIỆN
// HÀNH hoàn tất. Trước mốc đó, mọi `completed` đều là dư âm của clip trước và
// bị nuốt. Cờ được hạ ĐỒNG BỘ ở đầu load()/stop() (trước mọi `await`), nên cửa
// sổ race đóng kín: không có điểm treo nào nằm giữa lúc hạ cờ và lúc bẫy có
// thể nổ. Sau khi setAudioSource xong, player đã mang NGUỒN MỚI nên nó không
// còn có thể ở trạng thái `completed` của clip cũ nữa.
//
// FIX B7 (đợt 1) — GENERATION TOKEN: changeZone gọi stop() (không await) rồi
// load() ngay trên cùng một AudioPlayer. Hai coroutine interleave: phần đuôi
// của stop() (`_emit(idle)` sau khi await _player.stop()) chạy SAU khi load()
// đã emit `loading` với ref mới → UI nhận chuỗi loading(mới) → idle → playing,
// tức một nháy "idle/current=null" giữa hai zone. Sửa: mỗi lệnh load/stop nhận
// một số thế hệ tăng đơn điệu; mọi emit/side-effect nằm SAU một `await` phải
// kiểm tra thế hệ còn hiện hành — lệnh mới nhất luôn thắng, phần đuôi của lệnh
// đã bị vượt mặt bị nuốt trong im lặng. Không đổi gì ở tầng controller.
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

  /// B8 — nguồn của [_currentRef] đã thực sự nạp xong hay chưa.
  ///
  /// Hạ xuống false ĐỒNG BỘ ở đầu mỗi load()/stop() (trước mọi `await`), nâng
  /// lên true CHỈ khi `setAudioSource` của thế hệ hiện hành trả về. Mọi
  /// `ProcessingState.completed` nhận được trong lúc cờ này false đều là dư âm
  /// của clip TRƯỚC — gán nó cho [_currentRef] mới là bịa ra một sự kiện
  /// "nghe hết" chưa từng xảy ra, và đó chính là lỗi B8 ở đầu file.
  ///
  /// KHÔNG dùng cờ này để chặn [_emit]: một clip đang nạp vẫn phải báo
  /// `loading` cho UI. Nó chỉ gác đúng một cửa: [_completedCtrl].
  bool _sourceReady = false;

  /// B7: thế hệ lệnh hiện hành. Mỗi load()/stop() bump nó lên; code chạy sau
  /// một `await` chỉ được emit/side-effect nếu thế hệ nó giữ vẫn là mới nhất.
  int _generation = 0;

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
    var status = switch (ps.processingState) {
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

    // B7: player báo idle trong lúc một clip đang được nạp (đuôi của
    // _player.stop() thuộc lệnh cũ chen giữa) — với ref còn sống, đây là
    // artifact của transition, không phải trạng thái thật. Trình bày là
    // loading để UI không nháy "idle nhưng có current".
    if (status == PlaybackStatus.idle && _currentRef != null) {
      status = PlaybackStatus.loading;
    }

    // Dựng state TƯỜNG MINH thay vì copyWith: copyWith dùng `current ?? this
    // .current`, nên khi _currentRef vừa bị stop() đặt về null nó GIỮ LẠI ref
    // cũ — UI nhận `status: idle` kèm một clip vẫn còn đó. Ở đây _currentRef và
    // _durationHint là nguồn sự thật, kể cả khi chúng null.
    _emit(AudioQueueState(
      status: status,
      current: _currentRef,
      duration: _durationHint,
      position: _state.position,
    ));

    // B8 — CHỈ tin `completed` khi nguồn của clip hiện hành đã nạp xong. Xem
    // ghi chú đầu file: trong cửa sổ stop()→load() player còn mang trạng thái
    // `completed` của clip TRƯỚC, và nếu bắn ra ở đó thì controller sẽ tưởng
    // clip mới vừa nghe hết và nhảy thẳng sang hiện vật kế tiếp.
    if (ps.processingState == ProcessingState.completed &&
        _sourceReady &&
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
    final int gen = ++_generation; // B7: lệnh này là mới nhất kể từ đây
    _currentRef = ref;
    _durationHint = durationHint;
    _completedSignalled = false;
    // B8 — HẠ CỜ ĐỒNG BỘ, trước mọi `await`. Từ đây tới lúc setAudioSource trả
    // về, mọi `completed` là của clip cũ và phải bị nuốt.
    _sourceReady = false;
    _emit(AudioQueueState(
      current: ref,
      status: PlaybackStatus.loading,
      duration: durationHint,
    ));
    try {
      // setAudioSource loads but does NOT play — matches the interface
      // contract that lets a paused visitor keep a queued-but-silent intro.
      await _player.setAudioSource(AudioSource.uri(source));
      // B8 — chỉ mở cổng khi lệnh này VẪN là mới nhất. Nếu đã bị một load()/
      // stop() khác vượt mặt, thế hệ đó tự lo cờ của nó; ta không được nâng cờ
      // hộ một nguồn không còn là nguồn hiện hành.
      if (gen == _generation) _sourceReady = true;
    } on PlayerException catch (e) {
      if (kDebugMode) debugPrint('[JustAudioEngine] load error: $e');
      if (gen == _generation) _emit(AudioQueueState.idle);
    } on PlayerInterruptedException {
      // Một load() mới hơn đã vượt mặt lệnh này — bình thường khi đổi khu.
      // Nhưng KHÔNG im lặng nữa: chính sự im lặng này đã giấu việc intro của
      // khu mới bị hủy giữa chừng trong lỗi B8.
      if (kDebugMode) {
        debugPrint('[JustAudioEngine] load bị vượt mặt (gen $gen): $ref');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[JustAudioEngine] load failed: $e');
      if (gen == _generation) _emit(AudioQueueState.idle);
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
    final int gen = ++_generation; // B7
    _currentRef = null;
    _durationHint = null;
    _completedSignalled = false;
    _sourceReady = false; // B8 — hạ cờ đồng bộ, trước `await`
    await _player.stop();
    // B7: nếu một load() đã vượt mặt trong lúc await, phần đuôi này KHÔNG
    // được phép đè trạng thái loading của clip mới bằng idle.
    if (gen == _generation) _emit(AudioQueueState.idle);
  }

  @override
  Future<void> dispose() async {
    await _playerStateSub.cancel();
    await _player.dispose();
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
    if (!_completedCtrl.isClosed) await _completedCtrl.close();
  }
}