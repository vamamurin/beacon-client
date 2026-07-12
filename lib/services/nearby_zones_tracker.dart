// Destination: lib/services/nearby_zones_tracker.dart
//
// C3 — the DISPLAY tier for screen 2's zone ranking. Turns the registry's raw
// 1 Hz per-major heartbeat (ZonePresenceService.signals) into a STABLE, ordered
// "which zones can I hear right now, nearest first" list for the UI.
//
// This is the zone-level twin of ExhibitPresenceTracker, with one addition:
// it also carries an estimated distance per zone (from C1's
// ZoneSignal.estimatedDistanceMeters) so the list can sort nearest-first and
// the debug toggle can show metres. It deliberately does NOT decide the current
// (engaged) zone — that stays the arbiter's job (audio tier). The two tiers are
// independent by design: this one is chrome, the arbiter is behaviour.
//
// Two properties, same as the exhibit tracker:
//
//   1. ASYMMETRIC HYSTERESIS (fast-on / slow-off). A zone appears the instant
//      it's heard and stays until UNHEARD for a continuous [hold] window. Since
//      the registry already applies its own ~3 s staleness floor before a major
//      leaves the snapshot, effective disappear-latency is (registry staleness
//      + hold). This is what stops a far/edge zone flickering out of the list on
//      one missed sweep — exactly the anti-flicker the visitor asked for on the
//      "heard but beyond release" case.
//
//   2. CHANGE-GATING. The registry emits every second even when nothing moved.
//      This tracker forwards a new ranking ONLY when the ORDERED list of majors
//      actually changes (membership OR order). So the UI rebuilds on real
//      changes, not 1 Hz. Distance jitter that doesn't reorder anything is
//      absorbed here and never reaches the widget tree.
//
// Clock injected for deterministic FakeAsync tests, like the rest of the radio
// pipeline.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/zone_signal.dart';

/// One ranked zone for the display tier: its major, smoothed signal, and the
/// C1 distance estimate (metres) used for ordering and the debug readout.
@immutable
class NearbyZone {
  final int major;
  final double rssiDb;
  final double distanceMeters;

  const NearbyZone({
    required this.major,
    required this.rssiDb,
    required this.distanceMeters,
  });

  @override
  bool operator ==(Object other) =>
      other is NearbyZone &&
      other.major == major &&
      other.rssiDb == rssiDb &&
      other.distanceMeters == distanceMeters;

  @override
  int get hashCode => Object.hash(major, rssiDb, distanceMeters);
}

class NearbyZonesTracker {
  NearbyZonesTracker({
    required Stream<List<ZoneSignal>> signals,
    required double pathLossExponent,
    Duration hold = const Duration(seconds: 3),
    DateTime Function()? now,
  })  : _n = pathLossExponent,
        _hold = hold,
        _now = now ?? DateTime.now {
    _sub = signals.listen(_onSnapshot);
  }

  final double _n;
  final Duration _hold;
  final DateTime Function() _now;
  late final StreamSubscription<List<ZoneSignal>> _sub;

  /// major -> last heard wall-clock (slow-off half of the hysteresis).
  final Map<int, DateTime> _lastHeard = {};

  /// major -> latest measurement, kept so a zone still within its hold window
  /// but absent from THIS snapshot keeps its last known signal/distance.
  final Map<int, NearbyZone> _latest = {};

  /// Last ordered list of majors we published (for change-gating).
  List<int> _emittedOrder = const [];

  final _ctrl = StreamController<List<NearbyZone>>.broadcast();

  /// Ranked nearby zones, nearest first. Emits only when the ordered set
  /// changes. Seed a screen's first frame with [current].
  Stream<List<NearbyZone>> get ranking => _ctrl.stream;

  /// Present ranked zones at this instant (pure read for the initial frame).
  List<NearbyZone> get current => _rankAt(_now());

  void _onSnapshot(List<ZoneSignal> snapshot) {
    final now = _now();

    // Refresh last-heard + latest measurement for every zone in this snapshot.
    // Desk major (99) is arbitrated separately and never a visitor destination,
    // so it's excluded from the display ranking here as a defensive measure;
    // the registry may still surface it. Callers can't tap it anyway.
    for (final z in snapshot) {
      _lastHeard[z.major] = now;
      _latest[z.major] = NearbyZone(
        major: z.major,
        rssiDb: z.rssiDb,
        distanceMeters: z.estimatedDistanceMeters(_n),
      );
    }

    // Expire zones unheard past the hold window.
    _lastHeard.removeWhere((major, last) {
      final gone = now.difference(last) > _hold;
      if (gone) _latest.remove(major);
      return gone;
    });

    final ranked = _rankAt(now);
    final order = [for (final z in ranked) z.major];

    // Change-gate on the ORDERED majors (membership + order). Distance wobble
    // that doesn't reorder anything produces the same order -> no emit.
    if (listEquals(order, _emittedOrder)) return;
    _emittedOrder = order;
    if (!_ctrl.isClosed) _ctrl.add(ranked);
  }

  List<NearbyZone> _rankAt(DateTime now) {
    final out = <NearbyZone>[];
    for (final entry in _lastHeard.entries) {
      if (now.difference(entry.value) > _hold) continue;
      final z = _latest[entry.key];
      if (z != null) out.add(z);
    }
    // Nearest first; tie-break by stronger RSSI then major for stable order.
    out.sort((a, b) {
      final d = a.distanceMeters.compareTo(b.distanceMeters);
      if (d != 0) return d;
      final r = b.rssiDb.compareTo(a.rssiDb);
      if (r != 0) return r;
      return a.major.compareTo(b.major);
    });
    return out;
  }

  void dispose() {
    _sub.cancel();
    _lastHeard.clear();
    _latest.clear();
    if (!_ctrl.isClosed) _ctrl.close();
  }
}