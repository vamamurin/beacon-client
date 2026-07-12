// Destination: lib/services/auto_sync_scheduler.dart
//
// D — "charging = sync" policy, as a STANDALONE service so SessionController
// stays a pure state machine (it never learns that a sync layer exists).
//
// Rule: when the device is at the desk AND charging AND the last successful
// sync is older than the resolved threshold, trigger ONE sync. The dock is the
// museum's natural "fleet" mechanism — 30 phones cradled overnight all refresh
// themselves; no MDM, no per-device tapping.
//
// Guards, learned from the pipeline:
//   • Only when atDesk (never mid-tour): syncing under a running session could
//     swap the bundle beneath the visitor. The scheduler watches session phase.
//   • Debounced: a single in-flight sync at a time; re-entering atDesk while a
//     sync runs does nothing.
//   • Threshold + lastSyncAt read at DECISION time, so a Settings change to the
//     threshold, or a manual sync that updated lastSyncAt, is respected without
//     restarting anything.
//
// It does NOT own the sync itself — it calls an injected runSync callback (the
// same one StartupProvider uses) and, on success, stamps lastSuccessfulSyncAt.
// Clock injected for deterministic tests.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/repositories/content_sync_service.dart';
import 'package:beacon_client/data/repositories/sync_config.dart';
import 'package:beacon_client/domain/interfaces/i_settings_store.dart';
import 'package:beacon_client/domain/models/tour_session.dart';

class AutoSyncScheduler {
  AutoSyncScheduler({
    required Stream<SessionState> sessionState,
    required Stream<bool> chargingChanges,
    required bool initialCharging,
    required ISettingsStore settings,
    required double? Function() manifestAutoSyncHours,
    required Future<SyncResult?> Function() runSync,
    DateTime Function()? now,
  })  : _settings = settings,
        _manifestHours = manifestAutoSyncHours,
        _runSync = runSync,
        _now = now ?? DateTime.now,
        _charging = initialCharging {
    _sessionSub = sessionState.listen((s) {
      _phase = s.phase;
      _maybeSync();
    });
    _chargeSub = chargingChanges.listen((c) {
      _charging = c;
      _maybeSync();
    });
  }

  final ISettingsStore _settings;
  final double? Function() _manifestHours;
  final Future<SyncResult?> Function() _runSync;
  final DateTime Function() _now;

  late final StreamSubscription<SessionState> _sessionSub;
  late final StreamSubscription<bool> _chargeSub;

  SessionPhase _phase = SessionPhase.atDesk;
  bool _charging;
  bool _syncing = false;

  /// Optional: evaluate once at startup (device may boot already docked). Call
  /// after the graph is built. Safe to call anytime; it just re-checks.
  void kick() => _maybeSync();

  void _maybeSync() {
    if (_syncing) return;
    // Only sync when parked and powered — never under a live session.
    if (_phase != SessionPhase.atDesk) return;
    if (!_charging) return;

    final hours = SyncConfig.autoSyncHours(_settings, _manifestHours());
    final due = SyncConfig.isAutoSyncDue(
      now: _now(),
      lastSyncAt: _settings.lastSuccessfulSyncAt,
      thresholdHours: hours,
    );
    if (!due) return;

    _run();
  }

  Future<void> _run() async {
    _syncing = true;
    try {
      final res = await _runSync();
      // Stamp only on a real success (updated/upToDate). A failure leaves
      // lastSyncAt untouched so we retry next time we're docked.
      if (res != null &&
          (res.outcome == SyncOutcome.updated ||
              res.outcome == SyncOutcome.upToDate)) {
        await _settings.setLastSuccessfulSyncAt(_now());
      }
      if (kDebugMode) {
        debugPrint('[AutoSyncScheduler] docked sync -> ${res?.outcome}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AutoSyncScheduler] sync error: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> dispose() async {
    await _sessionSub.cancel();
    await _chargeSub.cancel();
  }
}