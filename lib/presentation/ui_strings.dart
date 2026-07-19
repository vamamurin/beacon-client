// Destination: lib/presentation/ui_strings.dart (NEW)
//
// Feature B — chuỗi GIAO DIỆN (chrome) đi cùng bundle thay vì Flutter .arb, để
// thêm ngôn ngữ = sửa manifest + sync, KHÔNG build lại app / không codegen.
//
// BA lớp:
//   1. [UiKeys] — hằng khóa. Widget gọi `content.ui(UiKeys.gateStart)`, KHÔNG
//      gõ chuỗi thô; gõ sai khóa là lỗi biên dịch.
//   2. [kUiDefaults] — bản tiếng Việt NHÚNG trong app cho mọi khóa. Dùng khi
//      bundle chưa có object `ui` (máy mới chưa sync) hoặc thiếu khóa. App luôn
//      hiển thị được ngay cả với bundle rỗng — không bao giờ lộ khóa thô.
//   3. Resolve (trong ContentProvider.ui): ui[lang][key] → ui[fallback][key]
//      → kUiDefaults[key] → (cùng lắm) chính key.
//
// STAGE 1 chỉ khai các khóa cho picker + nhãn liên quan ngôn ngữ. STAGE 2 sẽ
// bổ sung dần ~93 khóa còn lại (gate/settings/zone/exhibit/banner) — chỉ việc
// thêm hằng vào [UiKeys], thêm default vào [kUiDefaults], và đổi call site.
//
// Muốn tạo template cho người dịch: xuất khóa + default tiếng Việt từ
// [kUiDefaults] thành JSON, đưa họ điền cột ngôn ngữ mới.

abstract final class UiKeys {
  // ── ngôn ngữ / picker ──
  static const languageLabel = 'language.label';
  static const languagePickerTitle = 'language.picker.title';

  // ── gate ──
  static const gateStart = 'gate.start';

  // ── settings ──
  static const settingsLanguage = 'settings.language';

  // STAGE 2: thêm các khóa còn lại ở đây.
}

/// Bản tiếng Việt nhúng — mạng an toàn cuối cùng. Mỗi khóa trong [UiKeys] PHẢI
/// có một dòng ở đây.
const Map<String, String> kUiDefaults = <String, String>{
  UiKeys.languageLabel: 'Ngôn ngữ',
  UiKeys.languagePickerTitle: 'Chọn ngôn ngữ',
  UiKeys.gateStart: 'Bắt đầu tham quan',
  UiKeys.settingsLanguage: 'Ngôn ngữ',
};