// Destination: lib/services/tour_progress_service.dart
//
// Theo dõi tiến trình chuyến đi cho MÀN HÌNH (tổng kết, và sau này là thanh
// tiến trình trên màn khu vực).
//
// Là một LISTENER THUẦN, đúng khuôn mẫu đã dùng ba lần trong dự án
// (NearbyZonesTracker, AutoSyncScheduler, AnalyticsRecorder): nghe các stream
// đã có sẵn, không gọi ngược vào thứ nó quan sát. Nhờ vậy SessionController,
// ZoneArbiter và TourAudioController không phải đổi một dòng nào.
//
// Nguồn (đều đã lộ ra trên AppGraph):
//   • session.state          -> mốc bắt đầu tour + thời điểm dọn
//   • presence.events        -> khu đã ghé
//   • engine.onStateChanged  -> hiện vật đã BẮT ĐẦU nghe
//   • engine.onCompleted     -> hiện vật đã nghe HẾT
//
// DỌN Ở ĐẦU TOUR, KHÔNG PHẢI Ở CUỐI — cùng lý do đã chốt trong
// SessionController.userStartedTour (xem "FIX P1" ở đó): khoảng thời gian máy
// nằm trên dock giữa hai tour không hề yên tĩnh, và một sự kiện audio muộn tới
// sau khi tour kết thúc sẽ vấy bẩn số liệu của tour sau nếu ta dọn ở cuối.
// Thêm một lý do riêng của màn hình: màn tổng kết nằm TRONG phiên và gọi
// endTour() từ chính nó — nếu rời touring mà xoá ngay thì các con số sẽ biến
// mất ngay dưới tay khách trước khi kịp chuyển màn.

import 'dart:async';

import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/tour_progress.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

class TourProgressService {
  TourProgressService({
    required Stream<SessionState> sessionState,
    required Stream<ZoneEvent> zoneEvents,
    required Stream<AudioQueueState> audioState,
    required Stream<AudioTrackRef> audioCompleted,

    /// Tổng số khu / hiện vật trong bundle, đọc dạng CALLBACK chứ không phải
    /// giá trị: kho nội dung nạp bất đồng bộ (và đổi sau mỗi lần đồng bộ), nên
    /// một con số chụp lúc dựng graph sẽ là 0 mãi mãi trên máy vừa khởi động.
    required int Function() totalZones,
    required int Function() totalExhibits,
    DateTime Function()? now,
  }) : _totalZones = totalZones,
       _totalExhibits = totalExhibits,
       _now = now ?? DateTime.now {
    _sessionSub = sessionState.listen(_onSession);
    _zoneSub = zoneEvents.listen(_onZone);
    _audioSub = audioState.listen(_onAudioState);
    _completedSub = audioCompleted.listen(_onCompleted);
  }

  final int Function() _totalZones;
  final int Function() _totalExhibits;
  final DateTime Function() _now;

  late final StreamSubscription<SessionState> _sessionSub;
  late final StreamSubscription<ZoneEvent> _zoneSub;
  late final StreamSubscription<AudioQueueState> _audioSub;
  late final StreamSubscription<AudioTrackRef> _completedSub;

  final _ctrl = StreamController<TourProgress>.broadcast();

  // Trạng thái tích luỹ (nguồn của mọi snapshot).
  final Set<int> _visited = <int>{};
  final Set<ExhibitKey> _heard = <ExhibitKey>{};
  final Set<ExhibitKey> _started = <ExhibitKey>{};
  DateTime? _startedAt;
  bool _inTour = false;

  /// Ref của clip đang phát, để chỉ ghi nhận "bắt đầu nghe" MỘT lần cho mỗi
  /// lần nạp clip (onStateChanged bắn nhiều lần khi vị trí/đệm thay đổi).
  AudioTrackRef? _playing;

  TourProgress _snapshot = TourProgress.empty;

  Stream<TourProgress> get updates => _ctrl.stream;
  TourProgress get current => _snapshot;

  // ------------------------------------------------------------------ phiên

  void _onSession(SessionState s) {
    final touring = s.phase == SessionPhase.touring;
    if (touring && !_inTour) {
      _inTour = true;
      _visited.clear();
      _heard.clear();
      _started.clear();
      _playing = null;
      _startedAt = _now();
      _publish();
      return;
    }
    if (!touring && _inTour) {
      // Đóng sổ: ngừng ghi nhận, nhưng GIỮ số liệu (xem doc đầu file).
      _inTour = false;
      _playing = null;
      _publish();
    }
  }

  // ------------------------------------------------------------------- khu

  void _onZone(ZoneEvent e) {
    if (!_inTour) return;
    switch (e) {
      case EnteredZone(:final major):
        _add(() => _visited.add(major));
      case ChangedZone(:final toMajor):
        _add(() => _visited.add(toMajor));
      case LeftToStandby():
        break; // rời về standby không xoá dấu chân đã đi
    }
  }

  // -------------------------------------------------------------- hiện vật

  void _onAudioState(AudioQueueState s) {
    if (!_inTour) return;
    final ref = s.current;
    if (ref == null) {
      _playing = null;
      return;
    }
    if (s.status != PlaybackStatus.playing || ref == _playing) return;
    _playing = ref;
    final key = _keyOf(ref);
    if (key != null) _add(() => _started.add(key));
  }

  void _onCompleted(AudioTrackRef ref) {
    if (!_inTour) return;
    final key = _keyOf(ref);
    if (key == null) return;
    // Nghe hết thì đương nhiên đã bắt đầu — giữ bất biến started ⊇ heard kể cả
    // khi sự kiện "bắt đầu" bị mất (clip ngắn, engine gộp trạng thái).
    _add(() {
      _started.add(key);
      _heard.add(key);
    });
  }

  /// Lời chào khu (`exhibitMinor == null`) không phải một hiện vật — nó không
  /// có mặt trong mẫu số "x/y hiện vật" nên cũng không được vào tử số.
  ExhibitKey? _keyOf(AudioTrackRef ref) {
    final minor = ref.exhibitMinor;
    return minor == null ? null : ExhibitKey(ref.zoneMajor, minor);
  }

  // ------------------------------------------------------------------ phát

  /// Chạy [mutate] rồi chỉ phát khi snapshot thực sự đổi. Các stream nguồn bắn
  /// dày (mỗi gói beacon, mỗi lần đổi trạng thái phát) trong khi tiến trình chỉ
  /// nhích vài chục lần một tour.
  void _add(void Function() mutate) {
    mutate();
    _publish();
  }

  void _publish() {
    final next = TourProgress(
      visitedMajors: Set.unmodifiable(_visited),
      heardExhibits: Set.unmodifiable(_heard),
      startedExhibits: Set.unmodifiable(_started),
      startedAt: _startedAt,
      totalZones: _totalZones(),
      totalExhibits: _totalExhibits(),
    );
    if (next == _snapshot) return;
    _snapshot = next;
    if (!_ctrl.isClosed) _ctrl.add(next);
  }

  Future<void> dispose() async {
    await _sessionSub.cancel();
    await _zoneSub.cancel();
    await _audioSub.cancel();
    await _completedSub.cancel();
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
