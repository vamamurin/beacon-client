// Destination: lib/presentation/theme/app_theme.dart (NEW)

import 'package:beacon_client/domain/interfaces/i_settings_store.dart';
import 'package:flutter/material.dart';

import 'app_text.dart';
import 'museum_tokens.dart';

/// Định danh bền vững của một theme. Lưu vào settings dưới dạng [id], KHÔNG
/// lưu index — thêm/bớt preset sẽ không làm lệch lựa chọn đã lưu của thiết bị.
enum MuseumThemeId {
  dark('dark', 'Tối'),
  light('light', 'Sáng'),
  highContrast('high_contrast', 'Tương phản cao');

  const MuseumThemeId(this.id, this.label);

  /// Khoá bền vững cho lưu trữ.
  final String id;

  /// Nhãn hiển thị trong màn Cài đặt.
  final String label;

  MuseumTokens get tokens => switch (this) {
        MuseumThemeId.dark => MuseumTokens.dark,
        MuseumThemeId.light => MuseumTokens.light,
        MuseumThemeId.highContrast => MuseumTokens.highContrast,
      };

  /// Light theme cần status bar chữ tối; hai theme kia cần chữ sáng.
  Brightness get brightness =>
      this == MuseumThemeId.light ? Brightness.light : Brightness.dark;

  static MuseumThemeId fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => dark);
}

/// Dựng ThemeData từ tokens.
///
/// Mục tiêu: các widget Material dựng sẵn (SnackBar trong showAudioFeedback,
/// InkWell splash, CircularProgressIndicator ở splash/sync) tự lấy màu đúng
/// thay vì phải override thủ công ở từng call site. Đây là lý do chính chọn
/// ThemeExtension thay vì Provider<MuseumTokens>.
ThemeData buildMuseumTheme(MuseumThemeId id) {
  final t = id.tokens;
  final brightness = id.brightness;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: t.surface,
    canvasColor: t.surface,
    dividerColor: t.line,
    splashColor: t.ink.withValues(alpha: 0.08),
    highlightColor: t.ink.withValues(alpha: 0.04),

    colorScheme: ColorScheme.fromSeed(
      seedColor: t.ink,
      brightness: brightness,
    ).copyWith(
      surface: t.surface,
      onSurface: t.ink,
      primary: t.ctaFill,
      onPrimary: t.ctaLabel,
      outline: t.line,
    ),

    // Màu chữ mặc định của cây. AppText.* không khai báo `color`, nên mọi
    // `Text` KHÔNG copyWith sẽ nhận màu này qua TextStyle.inherit.
    textTheme: Typography.englishLike2021.apply(
      bodyColor: t.ink,
      displayColor: t.ink,
      fontFamily: AppFonts.sans,
    ),

    iconTheme: IconThemeData(color: t.ink),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.ink,
      linearTrackColor: t.line,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.ink,
      contentTextStyle: AppText.meta.copyWith(color: t.surface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: t.sharpAll),
    ),

    extensions: [t],
  );
}

class ThemeController extends ChangeNotifier {
  /// [initial] chỉ để test ép một theme cụ thể. Bình thường bỏ trống: theme
  /// đọc từ store, và MuseumThemeId.fromId(null) trả về dark.
  ThemeController({required ISettingsStore store, MuseumThemeId? initial})
      : _store = store,
        _id = initial ?? MuseumThemeId.fromId(store.themeId);

  final ISettingsStore _store;
  MuseumThemeId _id;

  MuseumThemeId get id => _id;
  ThemeData get theme => buildMuseumTheme(_id);

  void select(MuseumThemeId next) {
    if (next == _id) return;
    _id = next;
    notifyListeners();

    // Fire-and-forget, có chủ đích: UI đã đổi màu, không được chặn frame để chờ
    // đĩa. Nếu ghi hỏng, hậu quả duy nhất là lần mở app sau về mặc định.
    _store.setThemeId(next.id);
  }
}
