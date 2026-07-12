// Destination: lib/presentation/providers/settings_provider.dart
//
// D — reactive access to staff-facing device settings. Now covers: the
// distance-debug toggle (C3), the content-server URL override, and the manual
// "sync now" action with its in-flight/result state. Same shape as
// ThemeController: seeded from ISettingsStore, writes through on change.
//
// The manual sync reuses the SAME runSync callback the Gate uses (via
// StartupProvider), so there's one sync path, not two. On success it stamps
// lastSuccessfulSyncAt (so the docked auto-sync clock resets too).

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/repositories/content_sync_service.dart';
import 'package:beacon_client/domain/interfaces/i_settings_store.dart';

/// UI-facing outcome of a manual sync, mirroring StartupProvider's SyncStatus
/// but local to Settings so this provider doesn't depend on the gate layer.
enum ManualSyncState { idle, running, updated, upToDate, failed, noServer, mock }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required ISettingsStore store,
    Future<SyncResult?> Function()? runSync,
    DateTime Function()? now,
  })  : _store = store,
        _runSync = runSync,
        _now = now ?? DateTime.now,
        _showDistance = store.showDistanceDebug,
        _baseUrlOverride = store.syncBaseUrlOverride ?? '';

  final ISettingsStore _store;

  /// D — the sync path, (re)bound each time the graph boots (it outlives the
  /// graph across restarts). Null before the first graph is ready / mock mode.
  Future<SyncResult?> Function()? _runSync;
  void bindRunSync(Future<SyncResult?> Function() runSync) =>
      _runSync = runSync;

  final DateTime Function() _now;

  // ── distance debug (C3) ──
  bool _showDistance;
  bool get showDistanceDebug => _showDistance;

  void setShowDistanceDebug(bool value) {
    if (value == _showDistance) return;
    _showDistance = value;
    _store.setShowDistanceDebug(value);
    notifyListeners();
  }

  // ── content-server URL override (D) ──
  String _baseUrlOverride;
  String get baseUrlOverride => _baseUrlOverride;

  /// The last successful sync timestamp, for a "Đã đồng bộ lúc..." line.
  DateTime? get lastSuccessfulSyncAt => _store.lastSuccessfulSyncAt;

  void setBaseUrlOverride(String value) {
    final v = value.trim();
    if (v == _baseUrlOverride) return;
    _baseUrlOverride = v;
    _store.setSyncBaseUrlOverride(v.isEmpty ? null : v);
    notifyListeners();
  }

  // ── manual sync (D) ──
  ManualSyncState _syncState = ManualSyncState.idle;
  ManualSyncState get syncState => _syncState;
  bool get isSyncing => _syncState == ManualSyncState.running;

  Future<void> syncNow() async {
    final run = _runSync;
    if (run == null) {
      _syncState = ManualSyncState.mock;
      notifyListeners();
      return;
    }
    if (_syncState == ManualSyncState.running) return;
    _syncState = ManualSyncState.running;
    notifyListeners();
    try {
      final res = await run();
      if (res == null) {
        _syncState = ManualSyncState.mock;
      } else {
        switch (res.outcome) {
          case SyncOutcome.updated:
            _syncState = ManualSyncState.updated;
            await _store.setLastSuccessfulSyncAt(_now());
            break;
          case SyncOutcome.upToDate:
            _syncState = ManualSyncState.upToDate;
            await _store.setLastSuccessfulSyncAt(_now());
            break;
          case SyncOutcome.noConnectivity:
            _syncState = ManualSyncState.noServer;
            break;
          case SyncOutcome.failed:
            _syncState = ManualSyncState.failed;
            break;
        }
      }
    } catch (_) {
      _syncState = ManualSyncState.failed;
    }
    notifyListeners();
  }
}