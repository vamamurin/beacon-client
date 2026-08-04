// Destination: lib/services/session_controller.dart
//
// The session lifecycle owner. Converges THREE signal sources — zone events
// (ZonePresenceService), charging (IPowerMonitor), and desk/silence presence —
// into the atDesk/gate/touring/ending machine, and orchestrates cleanup (stop
// audio, wipe visited memory) as one atomic step because ending a session is a
// single business action.
//
// FIX P1-1 (đợt 1): lastBeaconAt trước đây đến qua một stream đã CHANGE-GATED
// (arbiter chỉ emit khi presence đổi giá trị) — trong khi bản chất nó là dữ
// liệu POLL. Hậu quả: giá trị đóng băng tại lần đổi presence gần nhất, và
// (a) khách đứng lâu trong một zone có thể bị kết thúc phiên oan sau
//     sessionSilence dù sóng vẫn đầy;
// (b) máy bỏ quên ở biên hai zone không bao giờ timeout vì candidate flicker
//     reset đồng hồ mãi.
// Sửa: sweep 1 Hz sẵn có tự ĐỌC lastBeaconAt qua callback được inject
// (`() => presence.lastBeaconAt` — arbiter luôn giữ giá trị tươi trong
// `current` kể cả khi không emit). deskStable vẫn là tín hiệu dạng CẠNH nên
// giữ nguyên đường stream (đổi sang Stream<bool> gọn hơn PresenceTick cũ).
//
// Mốc im lặng được neo bởi max(lastBeaconAt, _touringSince): một phiên vừa
// bắt đầu không bao giờ bị giết bởi timestamp cũ còn sót từ phiên trước, và
// một tour không nghe được beacon nào vẫn tự đóng sau sessionSilence.
//
// Confirmed rules:
//  (1) atDesk -> gate ONLY on unplug. Zone signals never start a tour.
//  (2) gate -> touring ONLY on userStartedTour() (active intent). Zone events
//      ignored at the gate. gate -> atDesk on re-plug (device returned unused).
//  (3) touring end signals & priority (for the logged reason; action is
//      identical): charging (P1, instant) > deskStable-after-grace (P2) >
//      silence > sessionSilence (P3) > staff manual.
//  (4) Start grace: from userStartedTour() until the FIRST EnteredZone,
//      deskStable is ignored (so standing near the desk at start can't kill the
//      fresh session).
//  (5) ending -> cleanup(stop audio, wipe visited) -> atDesk.
//
// Time is injected; silence is checked on a 1 Hz sweep.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

/// The minimal surface SessionController needs from the audio layer to clean up
/// on session end. TourAudioController implements this (or an adapter does),
/// keeping the session testable without the whole audio stack.
abstract interface class TourAudioSink {
  /// Stop playback and flush any queue.
  void stopAll();

  /// Forget which zones were visited this session (revisit memory).
  void resetSessionMemory();
}

class SessionController {
  SessionController({
    required Stream<ZoneEvent> zoneEvents,
    required Stream<bool> chargingChanges,
    required bool initialCharging,

    /// Rising/falling edges of "desk beacon dominates" — event-shaped, so a
    /// stream is the right transport (derived from ZoneStatus in injection).
    required Stream<bool> deskStableChanges,

    /// POLLED each sweep: wall-clock of the newest beacon packet the arbiter
    /// has seen (any major), or null when nothing was heard yet. Injected as a
    /// callback — NOT a stream — because freshness must be read against real
    /// time, not against "when did presence last change".
    required DateTime? Function() lastBeaconAt,
    required TourAudioSink audioSink,
    required Duration sessionSilence,
    Duration startGraceTimeout = const Duration(seconds: 20),
    DateTime Function()? now,
    Duration sweepInterval = const Duration(seconds: 1),

    /// Giữ [SessionPhase.farewell] bao lâu trước khi tự về [SessionPhase.atDesk].
    ///
    /// [Duration.zero] (mặc định) = GIỮ TỚI KHI CÓ NGƯỜI BẤM. Không giới hạn
    /// thời gian ở đây là an toàn vì [_onChargingChanged] xử lý phase này: máy
    /// lên dock là về atDesk ngay, nên một máy bị bỏ quên vẫn sạch khi về quầy.
    /// Đặt khác 0 (từ manifest `farewell.autoReturnSeconds`) nếu thực địa cho
    /// thấy khách hay bỏ máy trên ghế.
    Duration farewellHold = Duration.zero,
  })  : _audio = audioSink,
        _lastBeaconAt = lastBeaconAt,
        _sessionSilence = sessionSilence,
        _startGraceTimeout = startGraceTimeout,
        _now = now ?? DateTime.now,
        _sweepInterval = sweepInterval,
        _farewellHold = farewellHold {
    _zoneSub = zoneEvents.listen(_onZoneEvent);
    _chargeSub = chargingChanges.listen(_onChargingChanged);
    _deskSub = deskStableChanges.listen(_onDeskStableChanged);

    // Initial phase reflects the dock state at startup: charging => resting on
    // the dock (atDesk); not charging => already in someone's hand, so wake to
    // the gate. Normal boot (technician provisioning on the dock) lands atDesk.
    if (!initialCharging) {
      _state = const SessionState(phase: SessionPhase.gate);
    }
  }

  final TourAudioSink _audio;
  final DateTime? Function() _lastBeaconAt;
  final Duration _sessionSilence;

  /// Safety cap on the start-grace window in case the visitor never reaches a
  /// zone (e.g. wanders a corridor). Grace also ends on the first EnteredZone.
  final Duration _startGraceTimeout;
  final DateTime Function() _now;
  final Duration _sweepInterval;
  final Duration _farewellHold;

  /// Hẹn giờ tự rời `farewell`. Non-null chỉ trong lúc cửa sổ giữ còn mở; huỷ
  /// khi dispose để một controller đã chết không phát trạng thái nữa.
  Timer? _farewellTimer;

  late final StreamSubscription<ZoneEvent> _zoneSub;
  late final StreamSubscription<bool> _chargeSub;
  late final StreamSubscription<bool> _deskSub;
  Timer? _sweepTimer;

  final _stateCtrl = StreamController<SessionState>.broadcast();
  SessionState _state = SessionState.initial;

  /// Latest desk edge (updated by the desk stream).
  bool _deskStable = false;

  // Grace bookkeeping.
  DateTime? _graceStartedAt;

  /// When the current tour started (anchor for silence — see header). Null
  /// outside touring.
  DateTime? _touringSince;

  Stream<SessionState> get state => _stateCtrl.stream;
  SessionState get current => _state;

  /// Start the silence sweep. Idempotent.
  void start() {
    _sweepTimer ??= Timer.periodic(_sweepInterval, (_) => _sweep());
  }

  // ------------------------------------------------------------------ intents

  /// Visitor pressed "Start" at the gate. gate -> touring, opens start grace.
  void userStartedTour() {
    if (_state.phase != SessionPhase.gate) return;
    final now = _now();
    _graceStartedAt = now;
    _touringSince = now;

    // FIX P1 — DỌN TRÍ NHỚ TOUR Ở ĐÂY, KHÔNG PHẢI Ở _endSession.
    //
    // Trước đây reset chạy ở cuối tour trước. Khoảng thời gian máy nằm trên
    // dock giữa hai tour KHÔNG hề yên tĩnh: nhân viên rút/cắm tai nghe, hệ điều
    // hành gỡ audio session khi tour kết thúc và có ROM bắn becomingNoisy giả.
    // Mọi sự kiện đó đều đi thẳng vào TourAudioController (nó nghe tai nghe ở
    // MỌI phase, không có cổng chặn theo phiên) và đầu độc state của tour SAU.
    // Triệu chứng thực địa: tour thứ hai không tự phát, bấm tay thì vẫn phát.
    //
    // Dọn ở ĐẦU tour thì mọi thứ xảy ra trên dock đều bị xoá sạch, bất kể tour
    // trước kết thúc bằng đường nào (sạc / về bàn / im lặng / staff / crash).
    // stopAll() trước reset để chắc chắn không còn tiếng nào sót lại từ những
    // gì đã bị nạp trong lúc chờ ở dock.
    _audio.stopAll();
    _audio.resetSessionMemory();

    _setState(_state.copyWith(
      phase: SessionPhase.touring,
      inStartGrace: true,
      clearEndReason: true,
    ));
  }

  /// Nút "Kết thúc tham quan" trên notification keep-alive (và mọi lối kết thúc
  /// thủ công KHÔNG có người đứng trước máy).
  ///
  /// KHÔNG đi qua [SessionPhase.farewell]: lối này được bấm từ shade thông báo,
  /// thường là nhân viên thu máy về, và màn "Cảm ơn quý khách" lúc đó nói với
  /// một cái ghế trống. Cùng lý do ba nhánh tự động không đi qua đó.
  void staffEndSession() {
    if (_state.phase == SessionPhase.touring) {
      _endSession(SessionEndReason.manual, next: SessionPhase.atDesk);
    }
  }

  /// Khách tự bấm "Kết thúc chuyến đi" ở màn tổng kết.
  ///
  /// Dọn dẹp Y HỆT mọi lối kết thúc khác — điểm khác duy nhất là điểm đến:
  /// [SessionPhase.farewell] thay vì [SessionPhase.atDesk], để màn Cảm ơn có
  /// một trạng thái thật mà sống trong đó.
  void visitorEndedTour() {
    if (_state.phase != SessionPhase.touring) return;
    _endSession(SessionEndReason.manual, next: SessionPhase.farewell);
  }

  /// Khách bấm "Xong" ở màn Cảm ơn. Đóng cửa sổ giữ sớm hơn hạn.
  void dismissFarewell() {
    if (_state.phase != SessionPhase.farewell) return;
    _settleFromFarewell();
  }

  // ------------------------------------------------------------- signal inputs

  void _onChargingChanged(bool charging) {
    switch (_state.phase) {
      case SessionPhase.atDesk:
        // Unplug is the ONLY way out of atDesk -> wake to the gate (rule 1).
        if (!charging) {
          _setState(const SessionState(phase: SessionPhase.gate));
        }
        break;
      case SessionPhase.gate:
        // Re-plugged: device returned unused -> back to rest.
        if (charging) {
          _setState(const SessionState(phase: SessionPhase.atDesk));
        }
        break;
      case SessionPhase.touring:
        // Docked mid-tour -> end immediately (P1, 0 ms).
        if (charging) {
          _endSession(SessionEndReason.charging, next: SessionPhase.atDesk);
        }
        break;
      case SessionPhase.farewell:
        // ĐƯỜNG THOÁT VẬT LÝ của màn Cảm ơn, và là thứ khiến `farewellHold = 0`
        // (giữ vô hạn) an toàn: máy lên dock thì phiên đóng lại ngay, bất kể
        // khách có bấm "Xong" hay không.
        if (charging) _settleFromFarewell();
        break;
      case SessionPhase.ending:
        break;
    }
  }

  void _onZoneEvent(ZoneEvent e) {
    if (_state.phase != SessionPhase.touring) return; // ignored at desk/gate
    // First real zone entry closes the start-grace window (rule 4).
    if (_state.inStartGrace && e is EnteredZone) {
      _graceStartedAt = null;
      _setState(_state.copyWith(inStartGrace: false));
    }
  }

  void _onDeskStableChanged(bool stable) {
    _deskStable = stable;
    // React to the rising edge immediately (don't wait for the sweep) when
    // not in grace.
    if (_state.phase == SessionPhase.touring && _deskStable && !_inGrace()) {
      _endSession(SessionEndReason.desk, next: SessionPhase.atDesk);
    }
  }

  // ------------------------------------------------------------------- sweep

  /// 1 Hz: expire the grace timeout, re-check desk, and check radio silence.
  void _sweep() {
    if (_state.phase != SessionPhase.touring) return;
    final now = _now();

    // Grace safety timeout (grace normally ends on first EnteredZone).
    if (_state.inStartGrace &&
        _graceStartedAt != null &&
        now.difference(_graceStartedAt!) > _startGraceTimeout) {
      _graceStartedAt = null;
      _setState(_state.copyWith(inStartGrace: false));
    }

    // Desk may have been stable SINCE BEFORE grace ended (edge arrived during
    // grace and was ignored; the change-gated stream won't re-emit). Re-check
    // the level here so leaving grace next to the desk still ends the tour.
    if (_deskStable && !_inGrace()) {
      _endSession(SessionEndReason.desk, next: SessionPhase.atDesk);
      return;
    }

    // Silence (P3, lowest priority). POLL the arbiter's freshness — see
    // header. Anchored to _touringSince so a stale timestamp inherited from a
    // previous session can never kill a fresh one, and a tour that never hears
    // a single beacon still times out after sessionSilence.
    final DateTime? heard = _lastBeaconAt();
    final DateTime started = _touringSince ?? now;
    final DateTime anchor =
        (heard != null && heard.isAfter(started)) ? heard : started;
    if (now.difference(anchor) > _sessionSilence) {
      _endSession(SessionEndReason.silence, next: SessionPhase.atDesk);
    }
  }

  bool _inGrace() => _state.inStartGrace;

  // ------------------------------------------------------------- transitions

  /// Dọn dẹp nguyên tử của một tour: dừng tiếng → về trạng thái nghỉ.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// HAI ĐIỂM ĐẾN, MỘT ĐƯỜNG DỌN DẸP
  ///
  /// [next] chỉ quyết định KHÁCH THẤY GÌ sau đó, không đổi bất cứ điều gì về
  /// việc dọn dẹp — đó là lý do cả hai lối kết thúc đi chung hàm này thay vì có
  /// hai bản sao lệch nhau dần theo thời gian:
  ///
  ///   • [SessionPhase.atDesk]   — kết thúc TỰ ĐỘNG (sạc / về bàn / im lặng)
  ///     và nút trên notification. `ending` chỉ là một CẠNH ở giữa: nó mang
  ///     [SessionEndReason] ra khỏi touring cho AnalyticsRecorder rồi bị thay
  ///     thế ngay trong cùng một lần gọi đồng bộ. Không frame nào được bơm, và
  ///     điều đó đúng — ba nhánh đó đều xảy ra khi KHÔNG ai đang nhìn màn hình.
  ///
  ///   • [SessionPhase.farewell] — khách TỰ bấm ở màn tổng kết. Một trạng thái
  ///     thật, giữ theo `farewellHold`, để màn Cảm ơn sống trong đó.
  ///
  /// AnalyticsRecorder phát TourEnded ở trạng thái non-touring ĐẦU TIÊN nó thấy
  /// — `ending` ở lối thứ nhất, `farewell` ở lối thứ hai. Cả hai đều mang
  /// [SessionEndReason], nên số liệu giống nhau ở cả hai đường.
  ///
  /// ⚠ Thứ tự các câu lệnh dưới đây KHÔNG thiết lập thứ tự cho listener.
  /// `_setState` chỉ xếp hàng; [_audio.stopAll] chạy TRƯỚC khi bất kỳ subscriber
  /// nào quan sát được trạng thái mới.
  void _endSession(SessionEndReason reason, {required SessionPhase next}) {
    if (_state.phase != SessionPhase.touring) return;

    // Trạng thái mang reason ra khỏi touring. Ở lối tự động đó là `ending` (một
    // cạnh); ở lối khách bấm thì chính `farewell` giữ vai đó.
    final carrier =
        next == SessionPhase.farewell ? SessionPhase.farewell : SessionPhase.ending;
    _setState(SessionState(phase: carrier, endReason: reason));

    _audio.stopAll();
    // FIX P1 — KHÔNG resetSessionMemory() ở đây nữa.
    //
    // Dọn ở cuối tour tạo cảm giác an toàn giả: bất kỳ thứ gì xảy ra SAU thời
    // điểm này mà vẫn trước tour kế tiếp (rút tai nghe ở quầy, becomingNoisy
    // giả sinh ra bởi chính việc gỡ audio session ngay bên dưới) sẽ đặt lại
    // state và sống sót sang tour sau. Điểm dọn duy nhất giờ là
    // userStartedTour(). stopAll() thì VẪN phải ở đây — tour kết thúc là phải
    // im ngay, không đợi tới lúc ai đó bấm Bắt đầu.
    _graceStartedAt = null;
    _touringSince = null;
    _deskStable = false;

    _farewellTimer?.cancel();
    _farewellTimer = null;

    if (next == SessionPhase.farewell) {
      // Giữ `farewell`. Hạn 0 = giữ tới khi có người bấm — an toàn vì cắm sạc
      // cũng thoát được (xem _onChargingChanged).
      if (_farewellHold > Duration.zero) {
        _farewellTimer = Timer(_farewellHold, () {
          _farewellTimer = null;
          _settleFromFarewell();
        });
      }
    } else {
      // Giữ endReason cho analytics tới khi tour sau bắt đầu (xoá ở
      // userStartedTour).
      _setState(SessionState(phase: SessionPhase.atDesk, endReason: reason));
    }

    if (kDebugMode) {
      debugPrint('[SessionController] ended: $reason -> $next');
    }
  }

  /// Rời `farewell` về `atDesk`. Ba đường vào — hết giờ, khách bấm "Xong", máy
  /// lên dock — nên nó có tên riêng thay vì được viết lặp ở ba chỗ.
  ///
  /// Có canh phase: một chuyển động khác xen vào giữa cửa sổ giữ sẽ thắng, và
  /// không được để một lần hẹn giờ tới muộn giẫm lên.
  void _settleFromFarewell() {
    _farewellTimer?.cancel();
    _farewellTimer = null;
    if (_state.phase != SessionPhase.farewell) return;
    _setState(SessionState(
      phase: SessionPhase.atDesk,
      endReason: _state.endReason,
    ));
  }

  void _setState(SessionState next) {
    if (next == _state) return;
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  Future<void> dispose() async {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _farewellTimer?.cancel();
    _farewellTimer = null;
    await _zoneSub.cancel();
    await _chargeSub.cancel();
    await _deskSub.cancel();
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
  }

  // ---- test visibility ----
  @visibleForTesting
  bool get deskStableSeen => _deskStable;
}