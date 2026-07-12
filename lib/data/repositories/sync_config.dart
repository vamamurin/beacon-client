// Destination: lib/data/repositories/sync_config.dart
//
// D — the single place that answers "which server?" and "how stale before we
// auto-sync?". Both questions have a LAYERED answer, and keeping the precedence
// in one tested helper stops it drifting across call sites.
//
// URL precedence (first non-empty wins):
//   1. Staff override   — ISettingsStore.syncBaseUrlOverride (set at the desk)
//   2. Build default    — --dart-define=SYNC_BASE_URL (factory value per build)
//   3. Hard fallback    — kFallbackBaseUrl (keeps dev/mock from breaking)
//
// Auto-sync threshold precedence (first non-null wins):
//   1. Staff override   — ISettingsStore.autoSyncHoursOverride (per device)
//   2. Manifest value   — from the server bundle (fleet-wide, set centrally)
//   3. Default          — kDefaultAutoSyncHours
//
// The threshold being reachable from BOTH the server (manifest) AND the device
// (Settings) is the confirmed requirement: central control for the fleet, local
// override for one-off tuning.

import 'package:beacon_client/domain/interfaces/i_settings_store.dart';

class SyncConfig {
  const SyncConfig._();

  /// Factory default baked in at build time. Override per build with
  ///   flutter build apk --dart-define=SYNC_BASE_URL=http://10.0.0.5:8000
  static const String _buildDefaultBaseUrl = String.fromEnvironment(
    'SYNC_BASE_URL',
    defaultValue: '',
  );

  /// Last-resort fallback if neither Settings nor --dart-define is set. Kept as
  /// the previous hard-coded dev server so local runs still work out of the box.
  static const String kFallbackBaseUrl = 'http://192.168.1.8:8000';

  /// Default staleness before a docked device auto-syncs, when neither Settings
  /// nor the manifest specifies one. Confirmed shorter-than-12h; 6h means a
  /// device docked overnight always refreshes, and a mid-day top-up dock catches
  /// an afternoon content push.
  static const double kDefaultAutoSyncHours = 6;

  /// Clamp so a typo (server or staff) can't disable auto-sync entirely or
  /// hammer the server every few minutes.
  static const double _minAutoSyncHours = 0.5;
  static const double _maxAutoSyncHours = 72;

  /// Resolve the active base URL (see precedence above). Never returns empty.
  static String baseUrl(ISettingsStore settings) {
    final override = settings.syncBaseUrlOverride;
    if (override != null && override.isNotEmpty) return override;
    if (_buildDefaultBaseUrl.isNotEmpty) return _buildDefaultBaseUrl;
    return kFallbackBaseUrl;
  }

  /// Resolve the auto-sync threshold in hours (see precedence above), clamped.
  /// [manifestHours] is the value parsed from the bundle, or null if absent.
  static double autoSyncHours(ISettingsStore settings, double? manifestHours) {
    final chosen = settings.autoSyncHoursOverride ??
        manifestHours ??
        kDefaultAutoSyncHours;
    return chosen.clamp(_minAutoSyncHours, _maxAutoSyncHours);
  }

  /// Whether a docked device is due for an auto-sync right now.
  static bool isAutoSyncDue({
    required DateTime now,
    required DateTime? lastSyncAt,
    required double thresholdHours,
  }) {
    if (lastSyncAt == null) return true; // never synced -> due
    final elapsed = now.difference(lastSyncAt);
    return elapsed >= Duration(milliseconds: (thresholdHours * 3600000).round());
  }
}