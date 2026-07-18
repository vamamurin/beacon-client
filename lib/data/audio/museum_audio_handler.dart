// Destination: lib/data/audio/museum_audio_handler.dart (NEW)
//
// Feature A — nền tảng CHẠY NGẦM + điều khiển màn hình khóa.
//
// Đây là foreground service DUY NHẤT của app (kiểu mediaPlayback). Nhiệm vụ:
//
//   1. GIỮ PROCESS SỐNG suốt một tour. Foreground service được Android MIỄN
//      Doze/App-Standby, nên khi màn hình tắt: hai Timer 1 Hz (registry sweep +
//      session sweep) tiếp tục chạy và callback BLE tiếp tục được giao. Đây
//      chính là thứ vá lỗi "5 phút rồi mất beacon" — process không còn bị đóng
//      băng. audio_service dựng FGS ngay lần phát đầu tiên; với
//      `androidStopForegroundOnPause: false`, FGS DUY TRÌ cả khi tạm dừng
//      (khách đang đi giữa hai hiện vật, chưa có tiếng) → BLE không chết trong
//      quãng lặng.
//
//   2. MIRROR trạng thái engine → notification/lock-screen (đang phát gì, nút
//      play/pause, thanh tua).
//
//   3. ỦY QUYỀN mọi lệnh từ notification/lock-screen VỀ TourAudioController,
//      KHÔNG gọi thẳng engine. Nhờ vậy play/pause từ màn khóa vẫn đi qua đúng
//      cổng chính sách (rule 6 tai nghe, reading-mode) — không có đường tắt nào
//      phá vỡ luật audio đã dựng ở Phase 2.
//
// RANH GIỚI phá-dựng FGS:
//   • Lệnh "stop" trên notification (người dùng gạt/đóng) ⇒ chỉ PAUSE, KHÔNG
//     kết thúc phiên. Kết thúc tour là việc của SessionController (sạc/về bàn).
//   • engine.stop() giữa lúc đổi zone (flush queue) phát ra `idle` chốc lát —
//     KHÔNG hạ FGS (ta không map idle→super.stop()).
//   • FGS chỉ THỰC SỰ hạ khi PHIÊN kết thúc (rời khỏi `touring`): lúc đó không
//     cần chạy ngầm nữa (ở bàn, thiết bị đã trả), hạ FGS để tiết kiệm pin trên
//     dock. Nghe qua `sessionState` truyền vào [bind].
//
// REBIND: AudioService.init CHỈ được gọi MỘT lần cho cả vòng đời tiến trình
// (main.dart). Nhưng graph có thể được dựng lại (AppRestarter). Vì thế handler
// sống ở tầng app và [bind] lại vào engine/controller/session MỚI mỗi lần graph
// boot — đúng khuôn SettingsProvider.bindRunSync. [bind] hủy subscription cũ
// trước khi gắn cái mới, an toàn qua restart.

import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';

/// Dựng metadata cho notification/lock-screen từ trạng thái audio hiện tại.
/// Inject từ main.dart (nơi biết repository + ngôn ngữ) để handler KHÔNG phải
/// phụ thuộc repository/ngôn ngữ — cùng kiểu inject như uriResolver/presentMinors
/// của controller. Nhận cả [AudioQueueState] để lấy được `duration` cho thanh tua.
typedef MediaMetadataResolver = MediaItem Function(AudioQueueState state);

class MuseumAudioHandler extends BaseAudioHandler with SeekHandler {
  TourAudioController? _controller;
  MediaMetadataResolver? _metadata;

  StreamSubscription<AudioQueueState>? _stateSub;
  StreamSubscription<SessionState>? _sessionSub;

  /// Phase gần nhất đã thấy, để chỉ tác động ở CẠNH rời-touring (không lặp).
  SessionPhase? _lastPhase;

  /// Gắn (hoặc gắn lại sau restart-graph) handler vào một graph cụ thể.
  /// Idempotent về mặt subscription: hủy cái cũ trước khi tạo cái mới.
  void bind({
    required IAudioEngine engine,
    required TourAudioController controller,
    required MediaMetadataResolver metadata,
    required Stream<SessionState> sessionState,
    SessionPhase initialPhase = SessionPhase.atDesk,
  }) {
    _stateSub?.cancel();
    _sessionSub?.cancel();

    _controller = controller;
    _metadata = metadata;
    _lastPhase = initialPhase;

    _stateSub = engine.onStateChanged.listen(_onEngineState);
    _sessionSub = sessionState.listen(_onSessionState);

    _onEngineState(engine.state); // đẩy trạng thái ban đầu lên notification
  }

  /// Gỡ khỏi graph hiện tại (dùng khi dispose graph cũ mà chưa bind cái mới).
  void unbind() {
    _stateSub?.cancel();
    _sessionSub?.cancel();
    _stateSub = null;
    _sessionSub = null;
    _controller = null;
  }

  // ---- engine -> notification ------------------------------------------------

  void _onEngineState(AudioQueueState s) {
    final resolver = _metadata;
    if (resolver != null) {
      mediaItem.add(resolver(s));
    }

    final bool playing = s.status == PlaybackStatus.playing;
    final AudioProcessingState processing = switch (s.status) {
      PlaybackStatus.idle => AudioProcessingState.idle,
      PlaybackStatus.loading => AudioProcessingState.loading,
      PlaybackStatus.playing => AudioProcessingState.ready,
      PlaybackStatus.paused => AudioProcessingState.ready,
    };

    // updatePosition chỉ đặt MỐC neo ở mỗi lần đổi trạng thái. audio_service tự
    // NỘI SUY vị trí thanh tua từ mốc này + updateTime + speed trong lúc phát,
    // nên KHÔNG cần đẩy vị trí mỗi tick (tránh churn notification vô ích).
    playbackState.add(playbackState.value.copyWith(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0],
      processingState: processing,
      playing: playing,
      updatePosition: s.position,
    ));
  }

  // ---- session -> foreground-service lifecycle -------------------------------

  void _onSessionState(SessionState s) {
    final was = _lastPhase;
    _lastPhase = s.phase;
    // CẠNH rời khỏi touring (về ending/atDesk/gate): tour đã xong → hạ FGS.
    // super.stop() mới thực sự gỡ notification + dừng foreground service; các
    // engine.stop() giữa tour KHÔNG đi qua đây nên FGS sống suốt tour.
    if (was == SessionPhase.touring && s.phase != SessionPhase.touring) {
      super.stop();
    }
  }

  // ---- lock-screen / notification commands -> controller (đúng cổng) --------

  @override
  Future<void> play() async => _controller?.userPlay();

  @override
  Future<void> pause() async => _controller?.userPause();

  @override
  Future<void> seek(Duration position) async => _controller?.userSeek(position);

  /// Nút "stop"/gạt notification ⇒ PAUSE, không kết thúc phiên (xem header).
  @override
  Future<void> stop() async => _controller?.userPause();
}