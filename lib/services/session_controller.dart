// Destination: lib/services/session_controller.dart
//
// The session lifecycle owner. Converges THREE signal sources — zone events
// (ZonePresenceService), charging (IPowerMonitor), and deskStable/lastBeaconAt
// (via the presence status) — into the atDesk/gate/touring/ending machine, and
// orchestrates cleanup (stop audio, wipe visited memory) as one atomic step
// because ending a session is a single business action.
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
// Time is injected; silence is checked on a 1 Hz sweep against lastBeaconAt.

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

/// Signals the controller needs from the presence layer each tick. Fed from
/// ZonePresenceService: [deskStable] from ZoneStatus, [lastBeaconAt] tracked by
/// the arbiter and surfaced for silence detection.
class PresenceTick {
  final bool deskStable;
  final DateTime? lastBeaconAt;
  const PresenceTick({required this.deskStable, required this.lastBeaconAt});
}

class SessionController {
  SessionController({
    required Stream<ZoneEvent> zoneEvents,
    required Stream<bool> chargingChanges,
    required bool initialCharging,
    required Stream<PresenceTick> presenceTicks,
    required TourAudioSink audioSink,
    required Duration sessionSilence,
    Duration startGraceTimeout = const Duration(seconds: 20),
    DateTime Function()? now,
    Duration sweepInterval = const Duration(seconds: 1),
  })  : _audio = audioSink,
        _sessionSilence = sessionSilence,
        _startGraceTimeout = startGraceTimeout,
        _now = now ?? DateTime.now,
        _sweepInterval = sweepInterval {
    _zoneSub = zoneEvents.listen(_onZoneEvent);
    _chargeSub = chargingChanges.listen(_onChargingChanged);
    _presenceSub = presenceTicks.listen(_onPresenceTick);

    // Initial phase reflects the dock state at startup: charging => resting on
    // the dock (atDesk); not charging => already in someone's hand, so wake to
    // the gate. Normal boot (technician provisioning on the dock) lands atDesk.
    if (!initialCharging) {
      _state = const SessionState(phase: SessionPhase.gate);
    }
  }

  final TourAudioSink _audio;
  final Duration _sessionSilence;

  /// Safety cap on the start-grace window in case the visitor never reaches a
  /// zone (e.g. wanders a corridor). Grace also ends on the first EnteredZone.
  final Duration _startGraceTimeout;
  final DateTime Function() _now;
  final Duration _sweepInterval;

  late final StreamSubscription<ZoneEvent> _zoneSub;
  late final StreamSubscription<bool> _chargeSub;
  late final StreamSubscription<PresenceTick> _presenceSub;
  Timer? _sweepTimer;

  final _stateCtrl = StreamController<SessionState>.broadcast();
  SessionState _state = SessionState.initial;

  // Latest presence signals (updated each tick).
  bool _deskStable = false;
  DateTime? _lastBeaconAt;

  // Grace bookkeeping.
  DateTime? _graceStartedAt;

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
    _graceStartedAt = _now();
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

  void _onPresenceTick(PresenceTick t) {
    _deskStable = t.deskStable;
    _lastBeaconAt = t.lastBeaconAt;
    // React to desk immediately (don't wait for the sweep) when not in grace.
    if (_state.phase == SessionPhase.touring &&
        _deskStable &&
        !_inGrace()) {
      _endSession(SessionEndReason.desk);
    }
  }

  // ------------------------------------------------------------------- sweep

  /// 1 Hz: expire the grace timeout and check radio silence.
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

    // Priority: charging is handled in its own event (instant). Desk handled in
    // presence tick. Here we handle silence (P3), lowest priority.
    if (_lastBeaconAt != null &&
        now.difference(_lastBeaconAt!) > _sessionSilence) {
      _endSession(SessionEndReason.silence);
    }
  }

  bool _inGrace() => _state.inStartGrace;

  // ------------------------------------------------------------- transitions

  /// The single atomic cleanup: stop audio -> wipe visited -> show end -> rest.
  void _endSession(SessionEndReason reason) {
    if (_state.phase != SessionPhase.touring) return;

    // ending phase (transient) so the UI can show an end screen if it wants.
    _setState(SessionState(phase: SessionPhase.ending, endReason: reason));

    _audio.stopAll();
    _audio.resetSessionMemory();
    _graceStartedAt = null;
    _deskStable = false;
    _lastBeaconAt = null;

    // Settle to atDesk. Keep endReason for the end screen / analytics until the
    // next tour starts (cleared in userStartedTour).
    _setState(SessionState(phase: SessionPhase.atDesk, endReason: reason));

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
    await _zoneSub.cancel();
    await _chargeSub.cancel();
    await _presenceSub.cancel();
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
  }

  // ---- test visibility ----
  @visibleForTesting
  bool get deskStableSeen => _deskStable;
}
