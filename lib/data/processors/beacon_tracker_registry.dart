import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/processors/beacon_tracker.dart';
import 'package:beacon_client/domain/models/active_beacon.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/proximity_info.dart';

/// Owns the live beacon population and the *single* time authority.
///
/// Responsibilities:
///   - O(1) routing of packets to per-beacon [BeaconTracker]s (create-on-sight).
///   - A 1 Hz sweep that demotes stale beacons (→ outOfRange) and evicts dead
///     ones (→ removed from the map) for deterministic, bounded memory.
///   - Projecting the live population into a sorted leaderboard (closest first)
///     and emitting it **only when it meaningfully changes**.
///
/// Concurrency: single isolate, cooperative scheduling. The hot path and the
/// sweep never `await` across a map mutation, so they are mutually atomic — no
/// locks. (Implementation rule: do not introduce such an `await`.)
class BeaconTrackerRegistry {
  BeaconTrackerRegistry({
    Duration stalenessThreshold = const Duration(seconds: 3),
    Duration evictionThreshold = const Duration(seconds: 12),
    Duration sweepInterval = const Duration(seconds: 1),
    int maxTrackers = 64,
  })  : _stalenessThreshold = stalenessThreshold,
        _evictionThreshold = evictionThreshold,
        _sweepInterval = sweepInterval,
        _maxTrackers = maxTrackers;

  /// Silent longer than this → demote zone to outOfRange (drops off leaderboard).
  /// At ~100 ms advertising this is ~30 missed packets — unambiguous loss.
  final Duration _stalenessThreshold;

  /// Silent longer than this → evict from the map (GC). Deliberately ≫ staleness
  /// so a briefly-occluded beacon keeps warm Kalman state (no cold restart).
  final Duration _evictionThreshold;

  final Duration _sweepInterval;

  /// Defensive ceiling against scan-flooding; real N is bounded by museum beacons
  /// in RF range (the UUID filter upstream means only museum packets reach here).
  final int _maxTrackers;

  final Map<int, BeaconTracker> _trackers = {}; // O(1) by packed key
  final _controller = StreamController<List<ActiveBeacon>>.broadcast();
  Timer? _sweepTimer;

  // Signature of the last emitted leaderboard, for flood-gating.
  List<_LbSig> _lastSignature = const [];
  bool _emittedOnce = false;

  /// Sorted leaderboard stream (closest first). Repo-free; service enriches.
  Stream<List<ActiveBeacon>> get leaderboardStream => _controller.stream;

  /// Idempotent. Begins the 1 Hz temporal sweep.
  void start() {
    _sweepTimer ??= Timer.periodic(_sweepInterval, _sweep);
  }

  /// HOT PATH — O(1): packed-key lookup + [BeaconTracker.update] (Kalman+FSM O(1)).
  ///
  /// Projection (O(N) sort) is deliberately **kept off the per-packet path**: it
  /// runs only on (a) a membership addition or (b) a per-beacon zone change —
  /// both rare — while plain distance drift and re-ordering are refreshed by the
  /// 1 Hz sweep. Steady-state cost per packet is therefore O(1).
  void onReading(BeaconReading reading) {
    if (_controller.isClosed) return; // guard clause

    final key = (reading.major << 16) | reading.minor;
    final existing = _trackers[key];

    if (existing == null) {
      if (_trackers.length >= _maxTrackers) {
        if (kDebugMode) {
          debugPrint('[Registry] saturated ($_maxTrackers) — drop new $key');
        }
        return;
      }
      _trackers[key] = BeaconTracker(reading);
      if (kDebugMode) {
        debugPrint('[Registry] + tracker $key (live=${_trackers.length})');
      }
      _projectAndEmit(); // ADDITION → publish immediately (rare event)
      return;
    }

    final zoneBefore = existing.zone;
    existing.update(reading); // O(1)
    if (existing.zone != zoneBefore) {
      _projectAndEmit(); // ZONE CHANGE → publish immediately (rare per beacon)
    }
  }

  /// 1 Hz temporal authority. Replaces the (banned) busy-loop; yields between
  /// ticks. Demotes stale, evicts dead, then refreshes ordering (gated).
  void _sweep(Timer _) {
    if (_controller.isClosed) return;
    final now = DateTime.now();

    // Snapshot keys: must not mutate _trackers while iterating its views.
    for (final key in _trackers.keys.toList(growable: false)) {
      final t = _trackers[key];
      if (t == null) continue;

      if (t.isStaleAt(now, _evictionThreshold)) {
        _trackers.remove(key); // EVICTION → memory reclaimed deterministically
        if (kDebugMode) {
          debugPrint('[Registry] - evict $key '
              '(silent > ${_evictionThreshold.inSeconds}s)');
        }
      } else if (t.isStaleAt(now, _stalenessThreshold)) {
        if (t.markLost() && kDebugMode) {
          debugPrint('[Registry] demote $key → outOfRange '
              '(silent > ${_stalenessThreshold.inSeconds}s)');
        }
      }
    }

    _projectAndEmit(); // refresh order + distance buckets + removals; still gated
  }

  /// Build the leaderboard (live, in-range, closest first) and emit iff its
  /// signature changed: order / zone / distance-bucket / membership.
  void _projectAndEmit() {
    if (_controller.isClosed) return;

    final board = <ActiveBeacon>[];
    for (final t in _trackers.values) {
      if (t.zone == ProximityZone.outOfRange) continue; // demoted/stale excluded
      board.add(ActiveBeacon(
        key: t.key,
        major: t.major,
        minor: t.minor,
        reading: t.lastReading,
        smoothedDistance: t.smoothedDistance,
        zone: t.zone,
      ));
    }
    board.sort((a, b) => a.smoothedDistance.compareTo(b.smoothedDistance));

    final sig = [
      for (final b in board)
        _LbSig(b.key, b.zone, (b.smoothedDistance * 10).round()),
    ];

    // Emission optimization: drop redundant publishes to spare the UI thread.
    if (_emittedOnce && _sameSignature(sig, _lastSignature)) return;
    _lastSignature = sig;
    _emittedOnce = true;
    _controller.add(board);
  }

  /// Ordered, element-wise comparison: any reorder, zone flip, bucket shift, or
  /// add/remove yields inequality → a publish.
  static bool _sameSignature(List<_LbSig> a, List<_LbSig> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Cancel the sweep and drop all state (used on a stop→start cycle).
  void stop() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _trackers.clear();
    _lastSignature = const [];
    _emittedOnce = false;
  }

  void dispose() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _trackers.clear();
    if (!_controller.isClosed) _controller.close();
  }
}

/// Compact, value-equal fingerprint of one leaderboard slot.
/// distBucket = round(distance × 10) → 0.1 m granularity (matches the displayed
/// value), so the metres on screen stay live without per-packet flooding.
class _LbSig {
  final int key;
  final ProximityZone zone;
  final int distBucket;

  const _LbSig(this.key, this.zone, this.distBucket);

  @override
  bool operator ==(Object other) =>
      other is _LbSig &&
      other.key == key &&
      other.zone == zone &&
      other.distBucket == distBucket;

  @override
  int get hashCode => Object.hash(key, zone, distBucket);
}
