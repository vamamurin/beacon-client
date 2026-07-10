// Destination: lib/presentation/settings/settings_screen.dart (NEW)
//
// Màn Cài đặt. Hôm nay chỉ có chọn giao diện; sau này thêm ngôn ngữ, đồng bộ.
//
// AI DÙNG MÀN NÀY: nhân viên bảo tàng, một lần, lúc bàn giao thiết bị. Khách
// tham quan mượn máy rồi đi 90 phút — họ không vào đây. Vì vậy lối vào là
// long-press lên wordmark ở Gate, không phải một nút hiện rõ.
//
// Lựa chọn được LƯU BỀN VỮNG (ISettingsStore) và KHÔNG tự reset khi hết phiên:
// đây là quyết định sản phẩm đã chốt. Hệ quả cần biết: thiết bị cho mượn sẽ giữ
// nguyên giao diện mà khách trước để lại, cho tới khi nhân viên đổi.
//
// Màn này chỉ biết ThemeController. Không import ContentProvider, ZoneProvider,
// hay HeroImage — nếu bạn thấy mình cần chúng, có lẽ thứ bạn đang thêm không
// thuộc về Cài đặt.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ctrl = context.watch<ThemeController>();

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: t.ink),
        title:
            Text('Cài đặt', style: AppText.sheetTitle.copyWith(color: t.ink)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(t.gutter, 8, t.gutter, 24),
        children: [
          Text('GIAO DIỆN', style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          for (final id in MuseumThemeId.values)
            _ThemeOption(
              id: id,
              selected: id == ctrl.id,
              // Đổi ngay, không cần nút Lưu: thay đổi là khả nghịch, thấy được
              // tức thì, và lerp của MuseumTokens làm nó mượt.
              onTap: () => ctrl.select(id),
            ),
          const SizedBox(height: 24),
          Text(
            'Giao diện được lưu trên thiết bị và giữ nguyên cho khách tiếp theo.',
            style: AppText.stopMeta.copyWith(color: t.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// Một dòng chọn theme. Tự vẽ thay vì dùng RadioListTile: RadioListTile kéo
/// theo màu Material mặc định (không phải token của ta), và trên Flutter mới
/// groupValue/onChanged của nó đã deprecate.
class _ThemeOption extends StatelessWidget {
  final MuseumThemeId id;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  /// Cảnh báo vận hành cho light mode. Sếp yêu cầu tính năng này; người bấm nút
  /// vẫn xứng đáng biết đánh đổi. Đây là thông tin, không phải rào cản.
  String? get _caveat => switch (id) {
        MuseumThemeId.light =>
          'Màn hình sáng gây chói trong phòng trưng bày tối và có thể làm phiền '
              'khách đứng cạnh.',
        MuseumThemeId.highContrast =>
          'Tăng độ tương phản cho khách lớn tuổi hoặc thị lực kém.',
        MuseumThemeId.dark => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final caveat = _caveat;

    return Semantics(
      button: true,
      selected: selected,
      label: id.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vòng tròn chọn — cùng ngôn ngữ thị giác với badge số hiện vật.
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? t.ink : t.inkFaint),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: t.ink),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(id.label,
                          style: AppText.body.copyWith(color: t.ink)),
                      if (caveat != null) ...[
                        const SizedBox(height: 4),
                        Text(caveat,
                            style:
                                AppText.stopMeta.copyWith(color: t.inkFaint)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}