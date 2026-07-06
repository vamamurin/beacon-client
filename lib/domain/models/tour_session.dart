// Destination: lib/domain/models/tour_session.dart
//
// Session lifecycle value types. The state machine itself lives in
// SessionController (Phase 3 Step 3); these are the vocabulary it speaks.
//
// Four phases (confirmed):
//   atDesk  -> gate     : on UNPLUG (isCharging true->false) — the physical
//                         "lock": no zone signal can start a tour, only lifting
//                         the device off the dock.
//   gate    -> touring  : on userStartedTour() (active intent; a Start button).
//   gate    -> atDesk   : on re-plug (device put back, unused).
//   touring -> ending   : on charging (P1, 0ms) / deskStable after grace (P2) /
//                         radio silence > sessionSilence (P3) / staff manual.
//   ending  -> atDesk   : after cleanup (stop audio, wipe visited, show end).

import 'package:flutter/foundation.dart';

enum SessionPhase {
  /// Resting on the dock between visitors. Charging is normal here. The ONLY
  /// way out is unplugging. Zone signals are ignored.
  atDesk,

  /// The session gate: language choice, headphone prompt, Start button. Zone
  /// events are ignored until the visitor actively starts (rule 1).
  gate,

  /// Active tour. Audio + zone pipeline live.
  touring,

  /// Transient cleanup: stop audio -> wipe visited memory -> show end screen
  /// -> atDesk.
  ending,
}

/// Why a tour session ended — for analytics/logging. When several end signals
/// are simultaneously true, priority charging > desk > silence > manual
/// decides which reason is recorded (the ACTION is identical regardless).
enum SessionEndReason {
  /// Device docked mid-tour (isCharging rose). Priority 1, acts instantly.
  charging,

  /// Desk beacon dominated for deskDwell (deskStable), after the grace window.
  /// Priority 2.
  desk,

  /// No museum beacon heard for sessionSilence (~30 min). Priority 3.
  silence,

  /// Staff pressed the manual "End session" control.
  manual,
}

/// Immutable session snapshot for the UI (gate screen, end screen) and for
/// wiring decisions. Small by design.
@immutable
class SessionState {
  final SessionPhase phase;

  /// Set only while [phase] == ending / just-ended, for the end screen and
  /// analytics. Null otherwise.
  final SessionEndReason? endReason;

  /// True between userStartedTour() and the first EnteredZone — the grace
  /// window during which deskStable is ignored (rule 2: "until the device sees
  /// its first exhibition zone"). Exposed for tests/debug; consumers rarely
  /// need it directly.
  final bool inStartGrace;

  const SessionState({
    required this.phase,
    this.endReason,
    this.inStartGrace = false,
  });

  static const SessionState initial = SessionState(phase: SessionPhase.atDesk);

  bool get isTouring => phase == SessionPhase.touring;
  bool get isAtGate => phase == SessionPhase.gate;

  SessionState copyWith({
    SessionPhase? phase,
    SessionEndReason? endReason,
    bool clearEndReason = false,
    bool? inStartGrace,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      endReason: clearEndReason ? null : (endReason ?? this.endReason),
      inStartGrace: inStartGrace ?? this.inStartGrace,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionState &&
        other.phase == phase &&
        other.endReason == endReason &&
        other.inStartGrace == inStartGrace;
  }

  @override
  int get hashCode => Object.hash(phase, endReason, inStartGrace);

  @override
  String toString() =>
      'SessionState($phase${endReason != null ? ", reason: $endReason" : ""}'
      '${inStartGrace ? ", grace" : ""})';
}
