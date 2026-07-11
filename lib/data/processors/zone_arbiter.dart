// Destination: lib/data/processors/zone_arbiter.dart
//
// The heart of Phase 1: turns the registry's per-major signal snapshots into a
// single, stable "where is the visitor" answer (ZonePresence).
//
// Design rules (all confirmed with product):
//   (1) ENTRY is instant: first zone seen becomes current with NO dwell —
//       dwell guards TAKEOVERS (contested switches), not first acquisition.
//   (2) TAKEOVER needs BOTH: challenger beats current by >= minDeltaDb AND
//       holds that lead continuously for `dwell`. Losing the lead for even one
//       snapshot resets the dwell timer.
//   (3) After a switch, LOCKOUT: for `lockout` no takeover is considered, and
//       silence does NOT drop us to standby. A calm screen (12 s frozen) beats
//       flicker, and it lets the welcome narration play through.
//   (4) STANDBY applies only AFTER lockout, on EITHER condition: current zone
//       unheard for `zoneSilence` (radio loss), OR — C1 — heard but estimated
//       BEYOND releaseAtMeters continuously for `dwell` (visitor walked away
//       while weak signal still reaches them). Both -> currentMajor = null.
//   (4b) C1 — ENGAGE GATE: a zone may only BECOME current (instant entry or
//       takeover) when its estimated distance <= engageAtMeters. Zones merely
//       heard farther away are DISPLAY-tier only (ranking UI), never audio.
//       engage < release by >= 1 m (enforced) = hysteresis dead band that
//       swallows the ±30–50% indoor error of the RSSI→metres model.
//   (5) DESK (major 99) is arbitrated with the SAME delta rule: it must beat
//       every exhibition zone by minDeltaDb and hold for `deskDwell` to raise
//       deskStable. It NEVER touches currentMajor — ending the session is the
//       Session Controller's job (Phase 3). Layer boundary preserved.
//
// The arbiter is event-driven: it re-evaluates on every snapshot and uses the
// registry's own timestamps as its clock, so it owns no Timer and is fully
// deterministic in tests.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_presence.dart';
import 'package:beacon_client/domain/models/zone_signal.dart';

class ZoneArbiter {
  ZoneArbiter({
    required int deskMajor,
    required ArbitrationParams params,
    DateTime Function()? now,
  })  : _deskMajor = deskMajor,
        _p = params,
        _now = now ?? DateTime.now;

  final int _deskMajor;
  final ArbitrationParams _p;
  final DateTime Function() _now;

  final _controller = StreamController<ZonePresence>.broadcast();

  /// Change-gated stream of presence. Emits only when the presence differs by
  /// value (ZonePresence equality ignores lastBeaconAt on purpose), so the UI
  /// can rebuild on every event without churn.
  Stream<ZonePresence> get presence => _controller.stream;

  // ---- confirmed state ----
  int? _currentMajor;

  /// When the current zone was last confirmed present (for post-lockout
  /// silence). Advances whenever the current zone is heard.
  DateTime? _currentLastHeard;

  /// End of the active lockout window; null when not locked out.
  DateTime? _lockoutUntil;

  /// C1 — when the current zone FIRST measured beyond releaseAtMeters
  /// (sustained-far release measured from here; any dip back inside resets).
  DateTime? _currentFarSince;

  // ---- C1 distance helpers ----
  double _distanceM(ZoneSignal z) =>
      z.estimatedDistanceMeters(_p.pathLossExponent);
  bool _withinEngage(ZoneSignal z) => _distanceM(z) <= _p.engageAtMeters;
  bool _beyondRelease(ZoneSignal z) => _distanceM(z) > _p.releaseAtMeters;

  // ---- takeover candidate (exhibition zones) ----
  int? _candidateMajor;

  /// When the candidate FIRST achieved the delta lead (dwell measured from here).
  DateTime? _candidateSince;

  // ---- desk candidate ----
  DateTime? _deskLeadingSince;
  bool _deskStable = false;

  ZonePresence _last = ZonePresence.none;

  /// Freshness timestamp of the most recent non-empty snapshot. Tracked
  /// outside [_last]'s presence equality so silence detection stays truthful
  /// regardless of how long the visible presence holds steady.
  DateTime? _lastBeaconAt;

  /// Feed one registry snapshot. Pure, synchronous, O(zones-in-range).
  void onSnapshot(List<ZoneSignal> snapshot) {
    if (_controller.isClosed) return;
    final now = _now();

    // Split desk from exhibition zones.
    ZoneSignal? desk;
    final zones = <ZoneSignal>[];
    for (final z in snapshot) {
      if (z.major == _deskMajor) {
        desk = z;
      } else {
        zones.add(z);
      }
    }
    // snapshot is already sorted strongest-first; keep that for zones.
    zones.sort((a, b) => b.rssiDb.compareTo(a.rssiDb));

    _evaluateZone(zones, now);
    _evaluateDesk(desk, zones, now);
    _emit(now, snapshot);
  }

  // ---------------------------------------------------------------- zone path

  void _evaluateZone(List<ZoneSignal> zones, DateTime now) {
    final bool lockedOut =
        _lockoutUntil != null && now.isBefore(_lockoutUntil!);

    // Refresh "last heard" for the current zone whenever it is present.
    final ZoneSignal? currentSignal = _currentMajor == null
        ? null
        : _firstWhereOrNull(zones, (z) => z.major == _currentMajor);
    if (currentSignal != null) _currentLastHeard = now;

    // --- no current zone: instant entry (rule 1) GATED by engage (rule 4b).
    // Strongest-first order stands in for nearest-first; the engage check per
    // candidate corrects the rare case where the loudest zone is calibrated
    // "far" (per-beacon measuredPower) while a quieter one is truly close.
    if (_currentMajor == null) {
      final ZoneSignal? entry = _firstWhereOrNull(zones, _withinEngage);
      if (entry != null) {
        _enterZone(entry.major, now, lockout: false);
      }
      _clearCandidate();
      return;
    }

    // --- inside lockout: freeze. No takeover, no standby (rule 3) ---
    if (lockedOut) {
      _currentFarSince = null; // rule 3: the far clock doesn't run either
      _clearCandidate();
      return;
    }

    // --- C1: track "current zone heard but too far" (release condition) ---
    if (currentSignal == null) {
      _currentFarSince = null; // unheard -> the zoneSilence path owns this
    } else if (_beyondRelease(currentSignal)) {
      _currentFarSince ??= now;
    } else {
      _currentFarSince = null; // dipped back inside -> reset (anti-flicker)
    }

    // --- strongest challenger (not the current zone), engage-gated (4b) ---
    final ZoneSignal? challenger = _firstWhereOrNull(
        zones, (z) => z.major != _currentMajor && _withinEngage(z));

    final double currentRssi = currentSignal?.rssiDb ?? double.negativeInfinity;
    final bool challengerLeads = challenger != null &&
        (challenger.rssiDb - currentRssi) >= _p.minDeltaDb;

    if (challengerLeads) {
      // Same challenger holding the lead? accumulate dwell. New one? restart.
      if (_candidateMajor != challenger.major) {
        _candidateMajor = challenger.major;
        _candidateSince = now;
      }
      final heldFor = now.difference(_candidateSince!);
      if (heldFor >= _p.dwell) {
        _enterZone(challenger.major, now, lockout: true); // rule 2 + open lockout
        _clearCandidate();
        return;
      }
    } else {
      // Lead lost (even for one snapshot) -> reset dwell (rule 2).
      _clearCandidate();
    }

    // --- C1: sustained beyond release -> standby (rule 4, distance arm).
    // Evaluated AFTER takeover so walking from A toward B switches (better)
    // instead of dropping to standby first. Reuses `dwell` as the sustain
    // window — same anti-flicker role, no extra knob.
    if (_currentFarSince != null &&
        now.difference(_currentFarSince!) >= _p.dwell) {
      _currentMajor = null;
      _currentLastHeard = null;
      _currentFarSince = null;
      _clearCandidate();
      return;
    }

    // --- post-lockout silence -> standby (rule 4, radio-loss arm) ---
    if (currentSignal == null &&
        _currentLastHeard != null &&
        now.difference(_currentLastHeard!) > _p.zoneSilence) {
      _currentMajor = null;
      _currentLastHeard = null;
      _clearCandidate();
    }
  }

  void _enterZone(int major, DateTime now, {required bool lockout}) {
    _currentMajor = major;
    _currentLastHeard = now;
    _currentFarSince = null;
    _lockoutUntil = lockout ? now.add(_p.lockout) : null;
  }

  void _clearCandidate() {
    _candidateMajor = null;
    _candidateSince = null;
  }

  // ---------------------------------------------------------------- desk path

  /// Desk raises deskStable only when it beats EVERY exhibition zone by
  /// minDeltaDb and holds for deskDwell (rule 5). Never mutates currentMajor.
  void _evaluateDesk(ZoneSignal? desk, List<ZoneSignal> zones, DateTime now) {
    bool deskLeads = false;
    if (desk != null) {
      // Strongest competing exhibition zone (may be none).
      final double topZoneRssi =
          zones.isEmpty ? double.negativeInfinity : zones.first.rssiDb;
      deskLeads = (desk.rssiDb - topZoneRssi) >= _p.minDeltaDb;
    }

    if (deskLeads) {
      _deskLeadingSince ??= now;
      if (now.difference(_deskLeadingSince!) >= _p.deskDwell) {
        _deskStable = true;
      }
    } else {
      _deskLeadingSince = null;
      _deskStable = false; // left the desk -> presence flag drops
    }
  }

  // ---------------------------------------------------------------- emit

  void _emit(DateTime now, List<ZoneSignal> snapshot) {
    // Advance the freshness timestamp whenever ANY beacon was heard this
    // snapshot; carry the previous one forward on an empty snapshot. This is
    // tracked SEPARATELY from presence equality so the Session Controller
    // (Phase 3) can read a truthful "last beacon at" for silence detection
    // even while the visible presence sits unchanged for minutes.
    _lastBeaconAt = snapshot.isEmpty ? _lastBeaconAt : now;

    final next = ZonePresence(
      currentMajor: _currentMajor,
      candidateMajor: _candidateMajor,
      deskStable: _deskStable,
      lastBeaconAt: _lastBeaconAt,
    );

    // ZonePresence equality ignores lastBeaconAt, so a pure timestamp advance
    // won't emit. Emit only when a consumer-visible field changed.
    if (next == _last) {
      _last = next; // keep the refreshed timestamp available via `current`
      return;
    }
    _last = next;
    _controller.add(next);
    if (kDebugMode) debugPrint('[Arbiter] $next');
  }

  /// Current presence snapshot (for late subscribers / debug).
  ZonePresence get current => _last;

  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }

  static T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }
}