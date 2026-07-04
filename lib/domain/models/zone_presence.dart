import 'package:flutter/foundation.dart';

/// The single output type of the ZoneArbiter — "where is the visitor,
/// according to the radio" (successor of the per-beacon ProximityInfo
/// leaderboard).
///
/// Deliberately SMALL: presentation and session layers consume this and
/// nothing else from the radio pipeline, so every field here is a contract.
/// Debug surfaces that want raw RSSI subscribe to the tracker registry
/// directly instead of widening this type.
///
/// Emission contract (mirrors the existing signature-gating idiom): the
/// arbiter emits a new ZonePresence ONLY when it differs by [==] from the
/// previous one — downstream can rebuild on every event without churn.
@immutable
class ZonePresence {
  /// The CONFIRMED zone major (survived minDeltaDb + dwell + lockout rules).
  /// Null ⇒ standby (radar screen): no zone, or current zone went silent.
  final int? currentMajor;

  /// The zone currently challenging for takeover (winning on delta but not
  /// yet through its dwell window). Never equals [currentMajor]. Exposed for
  /// the debug radar; production UI intentionally ignores it — showing
  /// "maybe zone 3?" to a visitor is noise, not information.
  final int? candidateMajor;

  /// True once the desk beacon (deskMajor) has been heard stably for
  /// deskDwell. The session controller reacts to the rising edge by ending
  /// the tour session; nothing else consumes this.
  final bool deskStable;

  /// Wall-clock of the last packet from ANY tracked major (desk included).
  /// The session controller compares this against sessionSilence to detect
  /// "device left the exhibition area entirely". Null ⇒ nothing heard yet
  /// since the pipeline started.
  final DateTime? lastBeaconAt;

  const ZonePresence({
    this.currentMajor,
    this.candidateMajor,
    this.deskStable = false,
    this.lastBeaconAt,
  });

  /// Initial state before any radio input.
  static const ZonePresence none = ZonePresence();

  bool get inZone => currentMajor != null;

  ZonePresence copyWith({
    int? currentMajor,
    int? candidateMajor,
    bool? deskStable,
    DateTime? lastBeaconAt,
  }) {
    return ZonePresence(
      currentMajor: currentMajor ?? this.currentMajor,
      candidateMajor: candidateMajor ?? this.candidateMajor,
      deskStable: deskStable ?? this.deskStable,
      lastBeaconAt: lastBeaconAt ?? this.lastBeaconAt,
    );
  }

  /// NOTE: [lastBeaconAt] is deliberately EXCLUDED from equality. It advances
  /// on every packet (~3x/second); including it would defeat the emit-on-change
  /// gate and spam the UI thread with identical presences. Consumers that need
  /// silence detection (session controller) poll it on their own 1 Hz sweep.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZonePresence &&
        other.currentMajor == currentMajor &&
        other.candidateMajor == candidateMajor &&
        other.deskStable == deskStable;
  }

  @override
  int get hashCode => Object.hash(currentMajor, candidateMajor, deskStable);

  @override
  String toString() =>
      'ZonePresence(current: $currentMajor, candidate: $candidateMajor, '
      'desk: $deskStable)';
}
