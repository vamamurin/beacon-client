// Destination: lib/presentation/theme/app_theme.dart (NEW)

import 'package:beacon_client/domain/interfaces/i_settings_store.dart';
import 'package:flutter/material.dart';

import 'app_text.dart';
import 'museum_tokens.dart';

/// Định danh bền vững của một theme. Lưu vào settings dưới dạng [id], KHÔNG
/// lưu index — thêm/bớt preset sẽ không làm lệch lựa chọn đã lưu của thiết bị.
enum MuseumThemeId {
  dark('dark'),
  light('light'),
  highContrast('high_contrast');

  const MuseumThemeId(this.id);

  /// Khoá bền vững cho lưu trữ. Nhãn hiển thị KHÔNG còn ở đây: màn Cài đặt lấy
  /// tên theme từ ContentProvider.ui() (UiKeys.settingsTheme*) để đa ngôn ngữ,
  /// nên field `label` cũ (chỉ VI, không nơi nào đọc) đã được gỡ.
  final String id;

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
    dividerColor: t.line, // vạch trang trí — đúng vai
    splashColor: t.ink.withValues(alpha: 0.08),
    highlightColor: t.ink.withValues(alpha: 0.04),

    // ═══════════════════════════════════════════════════════════════════
    // KHÔNG DÙNG ColorScheme.fromSeed — ĐỌC TRƯỚC KHI "ĐƠN GIẢN HOÁ" LẠI
    // ═══════════════════════════════════════════════════════════════════
    //
    // `MuseumTokens` bắt MỌI field `required` — không preset nào được âm thầm
    // mượn màu của preset khác. Bản trước rồi giao ~20 vai trò màu (`secondary`,
    // `tertiary`, `error`, `surfaceContainer*`, `onSurfaceVariant`,
    // `surfaceTint`…) cho thuật toán tông màu M3 sinh từ hạt `t.ink`. Đó là
    // ĐÚNG cái lỗ hổng mà cả class được dựng để bịt, chỉ đứng ở tầng dưới.
    //
    // Khác biệt then chốt, và nó gọn hơn "phải khai báo 40 vai trò":
    //
    //     ColorScheme.fromSeed()  → vai trò bỏ trống lấp bằng THUẬT TOÁN
    //     ColorScheme()           → vai trò bỏ trống lấp bằng GIÁ TRỊ ANH EM
    //                               (primaryContainer ?? primary, v.v.)
    //
    // Nên bản sửa không phải liệt kê cho hết — mà là THÔI GIEO HẠT. Sau đó mọi
    // fallback đều rơi về một token, không rơi về một phép nội suy.
    //
    // ⚠ VÌ SAO NÓ CẤP BÁCH BÂY GIỜ: màn 2 đã có `FilledButton`
    // (zone_change_banner), Cài đặt đã có `TextField` (đọc `error` ngay khi có
    // validation), và màn 4 sẽ có `Slider` + `BottomSheet` — chúng đọc THẲNG
    // các vai trò này. Dựng màn 4 rồi mới phát hiện màu lạ thì phải quay lại.
    //
    // ── Vì sao `secondary` và `tertiary` đều là accent ──────────────────
    // App có ĐÚNG hai màu: mực và đồng. Không có màu thứ ba. Đưa accent vào cả
    // hai vai trò là nói thật — không phải đủ ba màu. Nếu một ngày bạn thấy một
    // widget dùng `tertiary` và trông sai, vấn đề không nằm ở đây: widget đó
    // đang đòi một sắc thái mà ngôn ngữ này không có.
    //
    // ── surfaceTint: TRONG SUỐT, và đây là dòng quan trọng nhất khối này ──
    // M3 nhuộm bề mặt nâng cao bằng `surfaceTint`, mặc định = `primary`. Ở
    // preset tối `primary` là ctaFill TRẮNG ⇒ mọi Card/Dialog/BottomSheet có
    // elevation sẽ bị dội một lớp trắng. Thiết kế này PHẲNG TUYỆT ĐỐI (bỏ
    // hairline, bỏ bóng, radius 2). Trong suốt = tắt hẳn cơ chế đó.
    colorScheme: ColorScheme(
      brightness: brightness,

      // Hành động chính — nút Bắt đầu, FilledButton của banner màn 2.
      primary: t.ctaFill,
      onPrimary: t.ctaLabel,
      primaryContainer: t.ctaFill,
      onPrimaryContainer: t.ctaLabel,

      // Màu thứ hai của app = đồng. Không có màu thứ ba.
      secondary: t.accent,
      onSecondary: t.accentInk,
      secondaryContainer: t.accent,
      onSecondaryContainer: t.accentInk,
      tertiary: t.accent,
      onTertiary: t.accentInk,
      tertiaryContainer: t.accent,
      onTertiaryContainer: t.accentInk,

      // Đỏ đất nung, hue ~10° — xem doc MuseumTokens.error.
      error: t.error,
      onError: t.errorInk,
      errorContainer: t.error,
      onErrorContainer: t.errorInk,

      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted, // chữ phụ trong widget dựng sẵn
      surfaceDim: t.surface,
      surfaceBright: t.surface,

      // Thang `surfaceContainer*` của M3 là thang ĐỘ NÂNG. App này chỉ có HAI
      // mặt phẳng: nền và kệ. Ép năm nấc vào hai là nói đúng những gì đang có —
      // dựng ra nấc thứ ba chỉ để lấp chỗ trống là dựng ra một thiết kế không
      // ai vẽ.
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surfaceRaised,
      surfaceContainerHigh: t.surfaceRaised,
      surfaceContainerHighest: t.surfaceRaised,

      outline: t.outline, // ranh giới CONTROL — ≥3:1, xem doc token
      outlineVariant: t.line, // vạch TRANG TRÍ — cố ý mờ

      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),

      // Đảo màu — SnackBar mặc định đọc cặp này. snackBarTheme bên dưới đã ghi
      // đè, nhưng để đúng ở đây thì widget nào chưa được ghi đè vẫn đúng.
      inverseSurface: t.ink,
      onInverseSurface: t.surface,
      inversePrimary: t.surface,

      surfaceTint: const Color(0x00000000), // PHẲNG — xem khối doc ở trên
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
      // outline, không phải line: track là một phần của CONTROL — nó nói cho
      // người dùng biết còn bao xa nữa. Ở 1.17:1 nó không nói được gì.
      linearTrackColor: t.outline,
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