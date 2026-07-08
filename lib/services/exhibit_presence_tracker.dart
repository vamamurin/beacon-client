// Destination: lib/services/exhibit_presence_tracker.dart (NEW)
//
// Turns the registry's raw per-major signal heartbeat into a STABLE "which
// exhibit minors are broadcasting right now, per zone" — the source screen 3
// consumes to show only exhibits that are physically nearby.
//
// Why this exists (and why not the arbiter): ZoneArbiter answers "which ZONE am
// I in" and deliberately drops per-minor detail from ZonePresence. The exhibit
// list needs the opposite grain — per-minor liveness WITHIN a zone — which the
// registry already computes (ZoneSignal.rssiByMinor). This tracker taps that
// stream (via ZonePresenceService.signals) and adds exactly two things:
//
//   1. ASYMMETRIC HYSTERESIS (fast-on / slow-off). A minor becomes present the
//      instant it's heard, and stays present until it has been UNHEARD for a
//      continuous [hold] window. The registry already applies a ~3 s staleness
//      floor before a minor leaves rssiByMinor, so effective disappear-latency
//      is roughly (registry staleness + hold). This is what stops the list
//      dropping a far/edge beacon on a single missed packet.
//
//   2. SET-EQUALITY CHANGE-GATING. The registry emits a 1 Hz heartbeat even
//      when nothing changed; this tracker forwards a major's set ONLY when the
//      minors actually added/removed. So the UI rebuilds on real membership
//      changes, never per sweep and never per step.
//
// Explicit NON-goals (per product): NO ranking, NO distance thresholding, NO
// sorting by RSSI. Presence is binary ("heard within the window or not"); which
// exhibits are near is decided by the beacons' physical RF range, not software.
// Callers render the present minors in their own stable order (manifest order),
// so rows never reorder as signal strength wobbles.
//
// Clock is injected for deterministic tests (FakeAsync), matching the rest of
// the radio pipeline.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/zone_signal.dart';

class ExhibitPresenceTracker {
  ExhibitPresenceTracker({
    required Stream<List<ZoneSignal>> signals,
    Duration hold = const Duration(seconds: 3),
    DateTime Function()? now,
  })  : _hold = hold,
        _now = now ?? DateTime.now {
    _sub = signals.listen(_onSnapshot);
  }

  /// Extra silence a minor must accumulate — on top of the registry's own
  /// staleness floor — before it drops out of the present set. The slow-off
  /// half of the hysteresis; appearance is always instant.
  final Duration _hold;

  final DateTime Function() _now;
  late final StreamSubscription<List<ZoneSignal>> _sub;

  /// major -> (minor -> wall-clock it was last heard).
  final Map<int, Map<int, DateTime>> _lastHeard = {};

  /// major -> last set we published (for change-gating).
  final Map<int, Set<int>> _emitted = {};

  /// major -> broadcast controller for screens watching that zone.
  final Map<int, StreamController<Set<int>>> _controllers = {};

  /// Present minors for [major] at this instant — for a screen's initial
  /// value before its subscription starts receiving changes. Pure read.
  Set<int> currentPresent(int major) => _presentAt(major, _now());

  /// Change-gated stream of the present-minor set for one zone [major]. Emits
  /// only when the set adds or drops a minor. Seed the first frame with
  /// [currentPresent]; this stream carries subsequent changes.
  Stream<Set<int>> watchMajor(int major) {
    final c = _controllers.putIfAbsent(
      major,
      () => StreamController<Set<int>>.broadcast(),
    );
    return c.stream;
  }

  void _onSnapshot(List<ZoneSignal> snapshot) {
    final now = _now();

    // 1) Refresh "last heard" for every minor in this snapshot.
    for (final z in snapshot) {
      final heard = _lastHeard.putIfAbsent(z.major, () => <int, DateTime>{});
      for (final minor in z.rssiByMinor.keys) {
        heard[minor] = now;
      }
    }

    // 2) Re-evaluate every known major (a minor can time out purely from the
    //    passage of time, even on a snapshot that didn't mention its zone —
    //    the registry's 1 Hz heartbeat guarantees this loop runs ~every second).
    for (final major in _lastHeard.keys.toList(growable: false)) {
      final heard = _lastHeard[major]!;
      heard.removeWhere((_, last) => now.difference(last) > _hold);

      final present = heard.keys.toSet();
      if (heard.isEmpty) _lastHeard.remove(major); // tidy; controller stays open

      final prev = _emitted[major];
      if (prev != null && setEquals(prev, present)) continue; // no real change

      _emitted[major] = present;
      final c = _controllers[major];
      if (c != null && !c.isClosed) c.add(present);
    }
  }

  Set<int> _presentAt(int major, DateTime now) {
    final heard = _lastHeard[major];
    if (heard == null) return const <int>{};
    final out = <int>{};
    heard.forEach((minor, last) {
      if (now.difference(last) <= _hold) out.add(minor);
    });
    return out;
  }

  void dispose() {
    _sub.cancel();
    for (final c in _controllers.values) {
      if (!c.isClosed) c.close();
    }
    _controllers.clear();
    _lastHeard.clear();
    _emitted.clear();
  }
}
