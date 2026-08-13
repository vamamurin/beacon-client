// Destination: lib/presentation/app/museum_drawer.dart
//
// NGĂN KÉO — thay cho bottom sheet của `menu_sheet.dart`.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO ĐỔI TỪ SHEET SANG NGĂN KÉO
// ═══════════════════════════════════════════════════════════════════════════
//
// Lý lẽ cũ của sheet vẫn đúng và ngăn kéo giữ nguyên nó: *"màn phía sau là ngữ
// cảnh của khách; để ngữ cảnh đó lộ ra ở rìa và đóng lại là về đúng chỗ cũ."*
// Sheet làm điều đó bằng cách chừa phần TRÊN; ngăn kéo làm bằng cách chừa 78dp
// bên PHẢI. Cùng một ý, khác trục.
//
// Cái ngăn kéo làm được mà sheet không: nó là một mặt phẳng CAO — nó phủ luôn
// tab bar. Lúc ngăn kéo mở thì không có gì khác bấm được, và điều đó phải nhìn
// thấy được. Một sheet trượt lên trong khi năm tab vẫn sáng ở dưới là đang nói
// hai điều ngược nhau.
//
// Vì vậy nó KHÔNG dùng `Scaffold.drawer`: drawer của Scaffold nằm trong body,
// mà tab bar của app này nằm NGOÀI vùng cuộn (nó là anh em của màn, không phải
// con). Ngăn kéo được dựng bằng `Stack` ở tầng shell, trên cùng.
//
// ═══════════════════════════════════════════════════════════════════════════
// NỘI DUNG ĐỔI THEO NGỮ CẢNH, VỎ GIỮ NGUYÊN
// ═══════════════════════════════════════════════════════════════════════════
//
// Hairline chia hai nhóm, và ranh giới đó là ranh giới về LOẠI VIỆC:
//   trên  — nơi để ĐI TỚI (danh mục, sơ đồ, hướng dẫn)
//   dưới  — thứ tác động lên CẢ PHIÊN (ngôn ngữ, kết thúc chuyến đi)
//
// "Kết thúc chuyến đi" chỉ có mặt giữa tour, và nó KHÔNG kết thúc phiên — nó mở
// màn tổng kết. Phiên chỉ đóng khi khách xác nhận ở đó. Lý lẽ giữ nguyên từ
// sheet cũ: với một thao tác không hoàn tác được, hai bước là tính năng chứ
// không phải phiền phức.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/menu_config.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/menu/menu_items.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/theme/app_rule.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/language_picker.dart';

/// Bề rộng ngăn kéo. 312 là con số của bản vẽ; dải lộ ra ở mép phải là phần
/// còn lại của bề ngang máy (78dp trên khung 390).
const double kDrawerWidth = 312;

/// Điều ngăn kéo yêu cầu chỗ gọi làm sau khi nó đóng.
///
/// Cố ý KHÔNG phải [MenuAction]: "kết thúc chuyến đi" không phải một mục menu
/// do bundle điều khiển, và "bắt đầu tham quan" không tồn tại ở đây.
///
/// ĐỔI NGÔN NGỮ KHÔNG CÓ MẶT Ở ĐÂY, và đó là chủ đích: nó không rời khỏi ngăn
/// kéo. Đổi tiếng là một thao tác khách làm rồi ở lại đúng chỗ cũ — đẩy họ sang
/// một màn khác để làm một việc dài hai giây là bắt họ tìm đường quay về.
///
/// CÀI ĐẶT cũng không có mặt ở đây, nhưng vì lý do ngược lại: nó là một hàng
/// THẬT trong ngăn kéo và tự mở lấy màn của nó. Enum này chỉ liệt kê những gì
/// ngăn kéo phải NHỜ chỗ gọi làm — mà chỗ gọi là shell, và shell không cần biết
/// về màn Cài đặt.
enum DrawerResult { guide, summary }

class MuseumDrawer extends StatelessWidget {
  /// Giữa tour ⇒ có "Kết thúc chuyến đi", không có "Bắt đầu tham quan".
  final bool inTour;
  final VoidCallback onClose;
  final void Function(DrawerResult) onResult;

  const MuseumDrawer({
    super.key,
    required this.inTour,
    required this.onClose,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final museum = content.textOrNull(content.museumName) ??
        content.ui(UiKeys.gateMuseumFallback);

    return Material(
      color: t.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(museum: museum, onClose: onClose),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // NHÓM TRÊN — nơi để đi tới. Dùng chung `MenuItemList`
                      // với màn Menu: "menu" phải là cùng một thứ ở mọi thời
                      // điểm, và hai bản sao sẽ lệch nhau ngay lần thêm mục thứ
                      // ba.
                      MenuItemList(
                        placement: inTour
                            ? MenuPlacement.duringTour
                            : MenuPlacement.beforeTour,
                        onSelect: (a) => _onMenuAction(context, a),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpace.gutter,
                          vertical: AppSpace.x4,
                        ),
                        child: AppHairline(),
                      ),

                      // NHÓM DƯỚI — tác động lên cả phiên.
                      AppRow(
                        label: content.ui(UiKeys.languageLabel),
                        status: content.languageName(content.language),
                        onTap: () => showLanguageSheet(context),
                      ),
                      // LỐI VÀO CÀI ĐẶT LÀ MỘT HÀNG CÔNG KHAI, không còn là
                      // cử chỉ nhấn giữ tên bảo tàng.
                      //
                      // Nhấn giữ là một cửa sau: nhân viên phải được DẠY nó, và
                      // ai không được dạy thì không tìm ra. Một hàng nhìn thấy
                      // được thì không phải dạy ai cả.
                      //
                      // ⚠ CÒN NỢ: nó công khai nghĩa là khách cũng vào được.
                      // Chấp nhận trong lúc dựng; khoá bằng mật khẩu sau khi
                      // mọi màn đã xong, và khi ấy chỗ đặt khoá là ĐÂY chứ
                      // không phải là làm cho hàng này khó tìm lại.
                      AppRow(
                        label: content.ui(UiKeys.settingsTitle),
                        onTap: () => _openSettings(context),
                      ),
                      if (inTour)
                        AppRow(
                          label: content.ui(UiKeys.tourEndCta),
                          onTap: () {
                            onClose();
                            onResult(DrawerResult.summary);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const _PoweredBy(),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    // `rootNavigator` chứ không phải Navigator của tab: Cài đặt là màn toàn
    // màn hình của NHÂN VIÊN — nó phủ cả tab bar, không sống trong một tab.
    final nav = Navigator.of(context, rootNavigator: true);
    onClose();
    nav.pushNamed(AppRouter.settingsRoute);
  }

  void _onMenuAction(BuildContext context, MenuAction a) {
    switch (a) {
      case MenuAction.guide:
        onClose();
        onResult(DrawerResult.guide);
      case MenuAction.startTour:
      case MenuAction.catalog:
      case MenuAction.map:
      case MenuAction.tours:
        // `startTour` bị [MenuPlacement.duringTour] lọc, và ở ngăn kéo TRƯỚC
        // tour nó cũng không thuộc về đây — lối vào tour là nút trên hero của
        // màn Menu, không phải một hàng trong ngăn kéo. Ba mục còn lại chưa có
        // màn hình nên `menuActionIsImplemented` đã lọc từ trước.
        break;
    }
  }
}

/// Nút ☰ mở ngăn kéo. Một vật thể duy nhất, cỡ [AppSpace.tap].
///
/// Ba vạch VẼ TAY chứ không phải `Icons.menu`: cùng ngữ pháp nét với `AppChevron`
/// và bộ icon tab bar (nét 1.6, bo tròn hai đầu), và cùng bề rộng 22 với bản vẽ.
/// Trộn một glyph Material vào giữa bốn vật thể vẽ tay là để một cái nói giọng
/// khác.
class MuseumMenuButton extends StatelessWidget {
  /// Màu nét. Trên thanh trong suốt (nằm trên ảnh) là họ on-image; trên thanh
  /// đục là `ink`. Call site chọn — xem doc hai họ ở `museum_tokens.dart`.
  final Color color;
  final VoidCallback onTap;

  const MuseumMenuButton({super.key, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = context.watch<ContentProvider>().ui(UiKeys.menuOpen);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppSpace.tap,
          height: AppSpace.tap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: 5),
                  Container(width: 22, height: 2, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Đầu ngăn kéo: TÊN BẢO TÀNG, không phải chữ "Menu".
///
/// Giữa lúc tour chạy, đây là chỗ duy nhất còn nhắc khách đang ở đâu. Một cái
/// nhãn ghi "Menu" thì nói lại đúng điều mà việc ngăn kéo vừa trượt ra đã nói.
class _Header extends StatelessWidget {
  final String museum;
  final VoidCallback onClose;

  const _Header({required this.museum, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.x5,
        AppSpace.x3,
        AppSpace.x5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content.ui(UiKeys.gateMuseumFallback).toUpperCase(),
                  style: AppText.kicker.copyWith(color: t.inkFaint),
                ),
                const SizedBox(height: AppSpace.x2),
                Text(museum,
                    style: AppText.museumName.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.x4),
                const AppDivider(),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: content.ui(UiKeys.menuOpen),
            excludeSemantics: true,
            onTap: onClose,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: AppSpace.tap,
                height: AppSpace.tap,
                child: Icon(Icons.close, size: 22, color: t.inkFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng chân. CĂN TRÁI ở đây, khác với bản căn giữa ở chân màn Poster: trong
/// ngăn kéo mọi thứ dóng về lề trái, kể cả dòng cuối.
class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.x6,
        AppSpace.gutter,
        AppSpace.x8,
      ),
      child: Text(
        'Powered by Tapama'.toUpperCase(),
        style: AppText.kicker.copyWith(
          color: t.ink.withValues(alpha: 0.36),
          fontSize: 10,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
