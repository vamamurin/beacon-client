// lib/domain/interfaces/i_settings_store.dart
//
// Tầng state THỨ BA của app. Bundle = chỉ đọc, server quyết. RAM = chết theo
// phiên. Đây là: người dùng sở hữu, sống qua restart.
//
// Interface nằm ở domain, impl ở data — cùng khuôn với IZoneRepository. Nhờ vậy
// widget test dựng được FakeSettingsStore trong bộ nhớ, không cần plugin.

abstract interface class ISettingsStore {
  /// Khoá bền vững của theme đang chọn, hoặc null nếu chưa từng chọn.
  String? get themeId;

  Future<void> setThemeId(String id);
}