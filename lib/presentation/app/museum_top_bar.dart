// Destination: lib/presentation/app/museum_top_bar.dart
//
// THANH TRÊN — `.mbar` của bản vẽ. Cùng với tab bar và ngăn kéo, nó là một
// trong ba thứ "không thuộc về màn nào cả, chúng là cái khung mà các màn chạy
// bên trong".
//
// ═══════════════════════════════════════════════════════════════════════════
// NHƯNG NÓ KHÔNG SỐNG TRONG SHELL — và đó là một khác biệt có thật
// ═══════════════════════════════════════════════════════════════════════════
//
// Tab bar nằm NGOÀI vùng cuộn (nó là anh em của màn), nên shell sở hữu nó.
// Thanh trên thì DÍNH Ở MÉP TRÊN CỦA TỪNG MÀN và đổi theo màn: tên khác, nút
// trái khác (☰ hay ‹), nền khác (trong suốt trên ảnh hero, đục khi không có).
// Một thanh do shell vẽ sẽ phải biết mọi màn đang bày gì — tức shell trở thành
// nơi tập trung mọi thứ, đúng cái mà việc tách tab ra đã tránh được.
//
// Nên nó là một WIDGET các màn tự đặt, không phải một tầng của khung.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI BIẾN THỂ, VÀ MÀN CHẮN CHỈ CÓ Ở MỘT
// ═══════════════════════════════════════════════════════════════════════════
//
// [solid] = false dùng khi phía dưới thanh là ẢNH HERO chạm mép trên. Ở đó chữ
// nằm trên ảnh nên nó thuộc họ on-image, và nó được cấp MỘT MÀN CHẮN RIÊNG: một
// dải tối mỏng, 58% ở mép trên, tan hết trong 100dp.
//
// ⚠ ĐỪNG BỎ MÀN CHẮN ĐÓ ĐỂ "DỰA VÀO VEIL CỦA ẢNH". Luật ấy đúng khi app chỉ có
// một preset tối — veil tan vào nền tối nên đầu ảnh bao giờ cũng bị dìm sẵn. Từ
// khi preset giấy thành mặc định thì nó HỎNG: veil nay tan vào GIẤY, tức nó LÀM
// SÁNG đầu ảnh, và chữ trong thanh biến mất trên mọi bức ảnh sáng màu. Màn chắn
// này không phụ thuộc theme và không phụ thuộc bức ảnh — đó chính là lý do nó
// tồn tại.
//
// [solid] = true tô thẳng `surface`. Không blur, không gradient: màn không có
// ảnh hero thì nội dung cuộn lộn thẳng qua thanh nếu nó trong suốt.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/app/museum_drawer.dart';
import 'package:beacon_client/presentation/app/shell_controller.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/language_picker.dart';

/// Nút bên trái của thanh.
enum TopBarLeading {
  /// ☰ — mở ngăn kéo. Dùng ở màn ĐÍCH CẤP MỘT (gốc của một tab).
  menu,

  /// ‹ — lùi một bước trong ngăn xếp của tab. Dùng ở TRANG CON.
  ///
  /// Một màn vừa để tab của chính nó sáng vừa đeo nút lùi thì đang nói hai điều
  /// ngược nhau — nên hai giá trị này loại trừ nhau, và cái nào đúng là do vị
  /// trí của màn trong ngăn xếp quyết định, không phải do khẩu vị.
  back,

  /// Không có nút trái. Ô rỗng vẫn giữ chỗ để tiêu đề nằm đúng giữa.
  none,
}

class MuseumTopBar extends StatelessWidget {
  final String title;
  final TopBarLeading leading;

  /// Tô nền `surface`. Xem khối doc ở đầu file.
  final bool solid;

  /// Hiện chip ngôn ngữ ở mép phải.
  ///
  /// Tắt ở màn chi tiết hiện vật: ở đó có sẵn một DẢI ngôn ngữ đầy đủ, và hai
  /// chỗ đổi tiếng trong cùng một màn là nói một điều hai lần. Ô rỗng vẫn giữ
  /// nguyên bề rộng để tiêu đề không lệch sang phải.
  final bool showLanguage;

  const MuseumTopBar({
    super.key,
    required this.title,
    this.leading = TopBarLeading.menu,
    this.solid = true,
    this.showLanguage = true,
  });

  /// Bề rộng ô hai bên. Bằng nhau ở cả hai mép để tiêu đề nằm ĐÚNG GIỮA màn —
  /// bỏ hẳn ô rỗng bên phải sẽ đẩy tiêu đề lệch đúng bằng bề rộng ô trái.
  static const double _sideWidth = AppSpace.tap;

  /// Chiều cao phần thanh, CHƯA kể vùng an toàn phía trên.
  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    // Chữ trên thanh TRONG SUỐT nằm đè lên vùng ảnh chưa bị lớp phủ chạm tới,
    // nên màu ở đó do BỨC ẢNH quyết định chứ không do theme — ảnh tư liệu thì
    // tối ở cả hai preset. Chỉ khi thanh có nền đục nó mới quay về mực của
    // trang. Đây là một trong những chỗ dễ nối nhầm hai họ token nhất.
    final fg = solid ? t.ink : t.inkOnImage;

    return Stack(
      children: [
        if (!solid)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF12120A).withValues(alpha: 0.58),
                      const Color(0xFF12120A).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Container(
          color: solid ? t.surface : null,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  SizedBox(
                    width: _sideWidth,
                    child: _leading(context, fg),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowLabel.copyWith(
                        color: fg,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _sideWidth,
                    child: showLanguage
                        ? _LanguageChip(
                            code: content.language,
                            color: fg,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _leading(BuildContext context, Color fg) => switch (leading) {
        TopBarLeading.menu => MuseumMenuButton(
            color: fg,
            onTap: () => context.read<ShellController>().openDrawer(),
          ),
        TopBarLeading.back => _BackGlyph(color: fg),
        TopBarLeading.none => null,
      };
}

/// Chip `VI`. Mã hai chữ cái ở đây là ĐỦ và có chủ đích: nó không phải bộ chọn,
/// nó là một cái nhãn nói "đang ở tiếng này, chạm để đổi". Bảng chọn mở ra mới
/// viết tên bằng chính ngôn ngữ đó — khách Nhật tìm 日本語 nhanh hơn tìm "JA".
class _LanguageChip extends StatelessWidget {
  final String code;
  final Color color;

  const _LanguageChip({required this.code, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = context.watch<ContentProvider>().ui(UiKeys.languageLabel);
    return Semantics(
      button: true,
      label: label,
      value: code,
      excludeSemantics: true,
      onTap: () => showLanguageSheet(context),
      child: GestureDetector(
        onTap: () => showLanguageSheet(context),
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpace.gutter),
            child: Text(
              code.toUpperCase(),
              style: AppText.button.copyWith(
                color: color.withValues(alpha: 0.82),
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dấu ‹. Vẽ tay cùng ngữ pháp nét với [AppChevron] — xem doc ở đó cho lý do
/// không dùng ký tự U+2039.
class _BackGlyph extends StatelessWidget {
  final Color color;

  const _BackGlyph({required this.color});

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => Navigator.of(context).maybePop(),
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpace.x2),
          child: Center(
            child: Transform.flip(
              flipX: true,
              child: AppChevron(color: color, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
