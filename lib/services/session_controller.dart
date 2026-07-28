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

    /// How long [SessionPhase.ending] is HELD before settling to atDesk.
    ///
    /// Zero (default) = the historical behaviour: `ending` is published and
    /// superseded in the same synchronous call, so it is an EDGE only. Set it
    /// non-zero to give the phase a real window an end screen can render in —
    /// see the note on [_endSession] for what else that requires.
    Duration endingHold = Duration.zero,
  })  : _audio = audioSink,
        _lastBeaconAt = lastBeaconAt,
        _sessionSilence = sessionSilence,
        _startGraceTimeout = startGraceTimeout,
        _now = now ?? DateTime.now,
        _sweepInterval = sweepInterval,
        _endingHold = endingHold {
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
  final Duration _endingHold;

  /// Pending settle from `ending` to `atDesk`. Non-null only while the hold
  /// window is open; cancelled on dispose so a torn-down controller can't
  /// publish afterwards.
  Timer? _endingTimer;

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

  /// Staff pressed "End session".
  void staffEndSession() {
    if (_state.phase == SessionPhase.touring) {
      _endSession(SessionEndReason.manual);
    }
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
        if (charging) _endSession(SessionEndReason.charging);
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
      _endSession(SessionEndReason.desk);
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
      _endSession(SessionEndReason.desk);
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
      _endSession(SessionEndReason.silence);
    }
  }

  bool _inGrace() => _state.inStartGrace;

  // ------------------------------------------------------------- transitions

  /// The single atomic cleanup: stop audio -> wipe visited -> rest.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// ABOUT [SessionPhase.ending] AND `endingHold`
  ///
  /// `ending` always carries [SessionEndReason] out of the touring phase, and
  /// AnalyticsRecorder emits TourEnded on the first non-touring state it sees —
  /// which is this one. That role is unconditional.
  ///
  /// Whether it is also RENDERABLE depends on `endingHold`:
  ///
  ///   • hold == zero (default): `ending` is published and superseded inside
  ///     this one synchronous call. The state stream is a broadcast controller,
  ///     so both values are queued before any listener runs — subscribers see
  ///     `ending` then `atDesk` in back-to-back microtasks with no frame pumped
  ///     between them. A widget keyed on `ending` would be replaced before it
  ///     could paint. Treat it as an EDGE.
  ///
  ///   • hold > zero: the settle to `atDesk` is deferred, so the phase is a
  ///     real state with a real window and an end screen CAN render in it.
  ///
  /// TO ADD AN END SCREEN, three things are needed together:
  ///   1. pass `endingHold:` (a few seconds) where this is constructed
  ///      (Injection.build),
  ///   2. a route for it, and
  ///   3. a branch in MuseumApp._syncNavigation — which today treats every
  ///      non-touring phase as "go to the gate", so `ending` would flash past
  ///      to the Gate even with a hold in place.
  /// Doing only (1) buys nothing visible; that is the trap this note exists to
  /// prevent.
  ///
  /// ⚠ The order of statements below does NOT establish an order for listeners.
  /// `_setState` only enqueues; [_audio.stopAll] runs before ANY subscriber
  /// observes `ending`, at any hold value.
  void _endSession(SessionEndReason reason) {
    if (_state.phase != SessionPhase.touring) return;

    _setState(SessionState(phase: SessionPhase.ending, endReason: reason));

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

    // Settle to atDesk. Keep endReason for analytics until the next tour starts
    // (cleared in userStartedTour).
    void settle() =>
        _setState(SessionState(phase: SessionPhase.atDesk, endReason: reason));

    _endingTimer?.cancel();
    if (_endingHold <= Duration.zero) {
      settle();
    } else {
      // Hold `ending` so an end screen has a window to live in. Guarded on
      // phase: a re-plug (or any other transition) during the hold wins, and
      // must not be stomped by a late settle.
      _endingTimer = Timer(_endingHold, () {
        _endingTimer = null;
        if (_state.phase == SessionPhase.ending) settle();
      });
    }

    if (kDebugMode) debugPrint('[SessionController] ended: $reason');
  }

  void _setState(SessionState next) {
    if (next == _state) return;
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  Future<void> dispose() async {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _endingTimer?.cancel();
    _endingTimer = null;
    await _zoneSub.cancel();
    await _chargeSub.cancel();
    await _deskSub.cancel();
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
  }

  // ---- test visibility ----
  @visibleForTesting
  bool get deskStableSeen => _deskStable;
}