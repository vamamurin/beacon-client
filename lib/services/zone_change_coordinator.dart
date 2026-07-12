// Destination: lib/services/zone_change_coordinator.dart
//
// C2 — the "opinion delay" between the arbiter confirming a zone change and the
// audio actually switching. Sits in place of the old ZoneEventRouter (which
// forwarded every ZoneEvent straight to audio) and adds ONE behaviour:
//
//   • EnteredZone / LeftToStandby  -> forwarded to audio IMMEDIATELY, as before
//     (arriving from standby needs no confirmation; losing signal must stop).
//   • ChangedZone(A -> B)          -> DEFERRED. Audio keeps playing zone A. A
//     PendingZoneChange(from A, to B, 20 s) is published for the UI banner.
//     The switch to B fires only when:
//        - the visitor taps "Chuyển sang B"      (confirm()), OR
//        - the 20 s deadline elapses AND the arbiter's current major is still
//          NOT A (auto-accept wherever they ended up), OR
//        - the arbiter emits ANOTHER ChangedZone to a third zone C while
//          pending -> the target becomes C and the 20 s restarts (each new
//          target is a fresh decision).
//     Pending is CANCELLED (banner gone, audio A untouched) when:
//        - the arbiter changes back to A (visitor returned), OR
//        - LeftToStandby arrives (signal lost -> stop wins over a pending ask).
//
// Why here and not in the arbiter: the arbiter answers "where is the visitor",
// a pure radio question. "Should we interrupt what they're hearing" is a
// product/UX question with a human in the loop — a different layer. Keeping it
// out of the arbiter also keeps that class fully deterministic and Timer-free.
//
// The coordinator OWNS the deadline Timer (injected-clock-free: a real Timer is
// fine here because this layer isn't part of the FakeAsync-tested radio core;
// it's driven in tests by pumping events + advancing a passed-in Duration hook).
// Audio switching still reads engine state AT THE INSTANT of the real switch,
// so rule 3+4 ("was playing -> autoplay new intro") stays correct: audio A was
// playing right up to confirm(), so B autoplays.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

/// A pending, visitor-confirmable zone switch. Enriched with resolved ZoneInfo
/// (Cách B) so the banner shows names, mirroring how ZoneStatus already carries
/// a resolved ZoneInfo. `from` may be null if its ZoneInfo can't be resolved
/// (defensive; the banner then omits the "rời khỏi X" clause).
@immutable
class PendingZoneChange {
  final ZoneInfo? from;
  final ZoneInfo to;
  final int toMajor;

  /// Wall-clock when this pending window closes (for the countdown UI).
  final DateTime deadline;

  const PendingZoneChange({
    required this.from,
    required this.to,
    required this.toMajor,
    required this.deadline,
  });

  @override
  bool operator ==(Object other) =>
      other is PendingZoneChange &&
      other.from?.major == from?.major &&
      other.toMajor == toMajor &&
      other.deadline == deadline;

  @override
  int get hashCode => Object.hash(from?.major, toMajor, deadline);
}

class ZoneChangeCoordinator {
  ZoneChangeCoordinator({
    required Stream<ZoneEvent> events,
    required TourAudioController audio,
    required IZoneRepository repository,
    required bool Function() isTouring,
    Duration confirmWindow = const Duration(seconds: 20),
    DateTime Function()? now,
  })  : _audio = audio,
        _repo = repository,
        _isTouring = isTouring,
        _confirmWindow = confirmWindow,
        _now = now ?? DateTime.now {
    _sub = events.listen(_route);
  }

  final TourAudioController _audio;
  final IZoneRepository _repo;
  final bool Function() _isTouring;
  final Duration _confirmWindow;
  final DateTime Function() _now;

  late final StreamSubscription<ZoneEvent> _sub;
  final _pendingCtrl = StreamController<PendingZoneChange?>.broadcast();

  /// Current pending change, or null when none is outstanding. Change-gated:
  /// emits null once when cleared, the value once when opened/retargeted.
  Stream<PendingZoneChange?> get pending => _pendingCtrl.stream;
  PendingZoneChange? get current => _pending;

  // ---- pending state ----
  PendingZoneChange? _pending;
  int? _fromMajor; // the zone audio is still playing while pending
  Timer? _deadlineTimer;

  void _route(ZoneEvent e) {
    if (!_isTouring()) {
      // Outside a tour: drop events and clear any stale pending.
      _clearPending();
      return;
    }
    switch (e) {
      case EnteredZone(:final major):
        // Arrival from standby: immediate, and it supersedes any pending ask
        // (we're no longer "in A deciding about B").
        _clearPending();
        _audio.enterZone(major);
      case ChangedZone(:final fromMajor, :final toMajor):
        _onChangedZone(fromMajor, toMajor);
      case LeftToStandby():
        // Signal lost: stopping wins over a pending question.
        _clearPending();
        _audio.leaveToStandby();
    }
  }

  void _onChangedZone(int fromMajor, int toMajor) {
    // Returned to the zone we were still playing? cancel the pending ask.
    if (_pending != null && toMajor == _fromMajor) {
      _clearPending();
      return;
    }

    // Open or RETARGET the pending window (new target = fresh 20 s).
    final ZoneInfo? toZone = _repo.zoneByMajor(toMajor);
    if (toZone == null) {
      // Can't resolve the destination -> fall back to the old immediate switch
      // rather than showing a nameless banner.
      _clearPending();
      _audio.changeZone(toMajor);
      return;
    }

    // Anchor "from" to the zone audio is ACTUALLY playing (the first pending's
    // origin), not the arbiter's transient fromMajor on a retarget.
    _fromMajor ??= fromMajor;
    final deadline = _now().add(_confirmWindow);
    _pending = PendingZoneChange(
      from: _repo.zoneByMajor(_fromMajor!),
      to: toZone,
      toMajor: toMajor,
      deadline: deadline,
    );
    _restartTimer();
    _emitPending();
  }

  /// Visitor tapped "Chuyển sang B". Performs the deferred switch now, reading
  /// engine state at THIS instant so rule 3+4 holds.
  void confirm() {
    final p = _pending;
    if (p == null) return;
    final target = p.toMajor;
    _clearPending();
    _audio.changeZone(target);
  }

  /// Visitor tapped "Ở lại" (optional dismiss). Cancels the ask; audio A stays.
  void dismiss() => _clearPending();

  void _onDeadline() {
    final p = _pending;
    if (p == null) return;
    // Auto-accept only if the visitor did NOT return to the origin. If they
    // wandered further, accept the pending target (the arbiter would already
    // have retargeted us to their newest zone if it changed).
    _clearPending();
    _audio.changeZone(p.toMajor);
  }

  void _restartTimer() {
    _deadlineTimer?.cancel();
    _deadlineTimer = Timer(_confirmWindow, _onDeadline);
  }

  void _clearPending() {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    if (_pending == null && _fromMajor == null) return;
    _pending = null;
    _fromMajor = null;
    _emitPending();
  }

  void _emitPending() {
    if (!_pendingCtrl.isClosed) _pendingCtrl.add(_pending);
    if (kDebugMode) {
      debugPrint('[ZoneChangeCoordinator] pending=${_pending?.toMajor}');
    }
  }

  Future<void> dispose() async {
    _deadlineTimer?.cancel();
    await _sub.cancel();
    if (!_pendingCtrl.isClosed) await _pendingCtrl.close();
  }
}