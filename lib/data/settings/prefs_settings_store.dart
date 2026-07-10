import 'package:shared_preferences/shared_preferences.dart';

import 'package:beacon_client/domain/interfaces/i_settings_store.dart';

class PrefsSettingsStore implements ISettingsStore {
  PrefsSettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kThemeId = 'theme_id';

  /// Async vì SharedPreferences phải đọc đĩa. Gọi TRƯỚC runApp() để frame đầu
  /// tiên đã có theme đúng — nếu không sẽ thấy một nháy dark rồi mới sang light.
  static Future<PrefsSettingsStore> create() async =>
      PrefsSettingsStore._(await SharedPreferences.getInstance());

  @override
  String? get themeId => _prefs.getString(_kThemeId);

  @override
  Future<void> setThemeId(String id) => _prefs.setString(_kThemeId, id);
}