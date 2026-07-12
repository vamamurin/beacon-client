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

  /// C3 — công tắc "hiện khoảng cách ước lượng" trên màn zone (dành cho nhân
  /// viên tinh chỉnh ngưỡng tại hiện trường). Mặc định false: khách không thấy
  /// số mét vì sai số RF trong nhà làm nó nhảy. Bật/tắt tại quầy, không cần
  /// build lại. Null-safe: chưa từng đặt ⇒ false.
  bool get showDistanceDebug;

  Future<void> setShowDistanceDebug(bool value);

  /// D — URL máy chủ nội dung do NHÂN VIÊN đặt tại quầy, GHI ĐÈ giá trị
  /// --dart-define lúc build. Null/rỗng ⇒ dùng giá trị xuất xưởng. Nhờ đây,
  /// đổi IP/link server không cần build lại app.
  String? get syncBaseUrlOverride;

  Future<void> setSyncBaseUrlOverride(String? value);

  /// D — ngưỡng TỰ đồng bộ khi cắm sạc: quá bao nhiêu GIỜ kể từ lần đồng bộ
  /// thành công gần nhất thì máy đang ở dock sẽ tự đồng bộ. Chỉ là LỚP GHI ĐÈ
  /// của staff; nếu null, dùng giá trị từ manifest (rồi mới tới mặc định). Cho
  /// phép chỉnh cả từ server (manifest) lẫn tại máy (Settings).
  double? get autoSyncHoursOverride;

  Future<void> setAutoSyncHoursOverride(double? value);

  /// D — mốc thời gian lần đồng bộ THÀNH CÔNG gần nhất (bất kỳ nguồn nào: tự
  /// động hay thủ công). Dùng để tính "đã quá ngưỡng chưa". Null ⇒ chưa từng.
  DateTime? get lastSuccessfulSyncAt;

  Future<void> setLastSuccessfulSyncAt(DateTime value);
}