import 'package:shared_preferences/shared_preferences.dart';

import 'package:beacon_client/domain/interfaces/i_settings_store.dart';

class PrefsSettingsStore implements ISettingsStore {
  PrefsSettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kThemeId = 'theme_id';
  static const String _kShowDistance = 'show_distance_debug';
  static const String _kSyncBaseUrl = 'sync_base_url_override';
  static const String _kAutoSyncHours = 'auto_sync_hours_override';
  static const String _kLastSyncAt = 'last_successful_sync_at';

  /// Async vì SharedPreferences phải đọc đĩa. Gọi TRƯỚC runApp() để frame đầu
  /// tiên đã có theme đúng — nếu không sẽ thấy một nháy dark rồi mới sang light.
  static Future<PrefsSettingsStore> create() async =>
      PrefsSettingsStore._(await SharedPreferences.getInstance());

  @override
  String? get themeId => _prefs.getString(_kThemeId);

  @override
  Future<void> setThemeId(String id) => _prefs.setString(_kThemeId, id);

  @override
  bool get showDistanceDebug => _prefs.getBool(_kShowDistance) ?? false;

  @override
  Future<void> setShowDistanceDebug(bool value) =>
      _prefs.setBool(_kShowDistance, value);

  @override
  String? get syncBaseUrlOverride {
    final v = _prefs.getString(_kSyncBaseUrl);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  @override
  Future<void> setSyncBaseUrlOverride(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty
        ? _prefs.remove(_kSyncBaseUrl)
        : _prefs.setString(_kSyncBaseUrl, v);
  }

  @override
  double? get autoSyncHoursOverride {
    if (!_prefs.containsKey(_kAutoSyncHours)) return null;
    return _prefs.getDouble(_kAutoSyncHours);
  }

  @override
  Future<void> setAutoSyncHoursOverride(double? value) => value == null
      ? _prefs.remove(_kAutoSyncHours)
      : _prefs.setDouble(_kAutoSyncHours, value);

  @override
  DateTime? get lastSuccessfulSyncAt {
    final ms = _prefs.getInt(_kLastSyncAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setLastSuccessfulSyncAt(DateTime value) =>
      _prefs.setInt(_kLastSyncAt, value.millisecondsSinceEpoch);
}