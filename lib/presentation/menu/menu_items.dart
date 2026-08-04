// Destination: lib/presentation/menu/menu_items.dart
//
// Danh sách các mục Menu — DÙNG CHUNG cho hai chỗ hiện nó:
//   • [MenuScreen]  — màn đầy đủ TRƯỚC tour (phase gate)
//   • [MenuSheet]   — sheet kéo lên GIỮA tour
//
// Một widget cho cả hai vì đó chính là lời hứa với khách: "menu" phải là cùng
// một thứ ở mọi thời điểm. Hai bản sao sẽ lệch nhau ngay lần thêm mục thứ ba.
//
// BA TẦNG LỌC, theo thứ tự — nhầm thứ tự là ra một nút bấm không dẫn đi đâu:
//   1. bundle BẬT mục đó                (MenuEntry.enabled)
//   2. app ĐÃ CÓ màn hình thật cho nó   ([menuActionIsImplemented])
//   3. mục hợp với NGỮ CẢNH hiện tại    ([MenuPlacement])
//
// Tầng 2 là thứ khiến kịch bản "bật khi làm xong" chạy được: CMS khai báo mục
// `map` từ hôm nay, nó tự xuất hiện vào ngày app có màn bản đồ, không ai phải
// sửa manifest lần hai.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/menu_config.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_icons.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Menu đang được hiện ở đâu.
enum MenuPlacement {
  /// Màn Menu — MÀN NGHỈ của máy (xem [AppRouter.restRoute]). Pipeline beacon
  /// chưa chạy ở đây (phase atDesk/gate), nên mọi mục phụ thuộc vị trí đều vô
  /// nghĩa — hiện chưa mục nào như vậy, nhưng đó là lý do enum này tồn tại thay
  /// vì một cờ `bool inTour`.
  beforeTour,

  /// Sheet giữa tour. "Bắt đầu tham quan" biến mất vì tour đang chạy.
  duringTour,
}

/// Màn hình thật đã tồn tại cho đích đến này chưa.
///
/// Cập nhật ĐÚNG MỘT DÒNG ở đây khi thêm một màn mới — và nhớ thêm route trong
/// [AppRouter] cùng lúc, vì hai thứ đó là một quyết định.
bool menuActionIsImplemented(MenuAction action) => switch (action) {
      MenuAction.startTour => true,
      MenuAction.guide => true,
      MenuAction.catalog => false,
      MenuAction.map => false,
      MenuAction.tours => false,
    };

String _labelKey(MenuAction a) => switch (a) {
      MenuAction.startTour => UiKeys.menuItemStart,
      MenuAction.guide => UiKeys.menuItemGuide,
      MenuAction.catalog => UiKeys.menuItemCatalog,
      MenuAction.map => UiKeys.menuItemMap,
      MenuAction.tours => UiKeys.menuItemTours,
    };

String _descKey(MenuAction a) => switch (a) {
      MenuAction.startTour => UiKeys.menuItemStartDesc,
      MenuAction.guide => UiKeys.menuItemGuideDesc,
      MenuAction.catalog => UiKeys.menuItemCatalogDesc,
      MenuAction.map => UiKeys.menuItemMapDesc,
      MenuAction.tours => UiKeys.menuItemToursDesc,
    };

/// Các mục sẽ hiện ra, sau cả ba tầng lọc. Tách khỏi widget để màn hình biết
/// trước danh sách rỗng hay không mà không phải dựng cây.
///
/// [deviceReady] false (Bluetooth chưa bật / máy chưa có nội dung) ⇒ ẩn lối vào
/// tour. Ẩn chứ không làm mờ, vì thẻ trạng thái dành cho nhân viên đứng ngay
/// phía trên đã nói rõ vì sao — một nút xám không bấm được bên cạnh một thẻ đã
/// giải thích là nói hai lần. Các mục khác (hướng dẫn, danh mục) không cần sóng
/// nên vẫn dùng được.
List<MenuAction> visibleMenuActions(
  MenuConfig config,
  MenuPlacement placement, {
  bool deviceReady = true,
}) {
  bool hidden(MenuAction a) {
    if (a == MenuAction.startTour) {
      // Giữa tour thì tour đã chạy rồi; máy chưa sẵn sàng thì chưa chạy được.
      return placement == MenuPlacement.duringTour || !deviceReady;
    }
    return false;
  }

  return [
    for (final e in config.visible)
      if (menuActionIsImplemented(e.action) && !hidden(e.action)) e.action,
  ];
}

/// Danh sách dọc các mục. KHÔNG tự cuộn và KHÔNG tự thêm lề ngang — chỗ gọi
/// quyết định cả hai (màn thì nằm trong CustomScrollView, sheet thì nằm trong
/// một cột ngắn).
class MenuItemList extends StatelessWidget {
  final MenuPlacement placement;
  final void Function(MenuAction action) onSelect;

  /// false ⇒ ẩn lối vào tour (xem [visibleMenuActions]).
  final bool deviceReady;

  const MenuItemList({
    super.key,
    required this.placement,
    required this.onSelect,
    this.deviceReady = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final actions =
        visibleMenuActions(content.menu, placement, deviceReady: deviceReady);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in actions)
          _MenuRow(
            key: ValueKey('menu.item.${a.id}'),
            action: a,
            title: content.ui(_labelKey(a)),
            description: content.ui(_descKey(a)),
            onTap: () => onSelect(a),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final MenuAction action;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _MenuRow({
    super.key,
    required this.action,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      // Đọc cả mô tả: ở màn này mô tả KHÔNG phải trang trí — nó là thứ phân
      // biệt "Bắt đầu tham quan" với "Chọn tuyến tham quan" cho người dùng
      // screen reader, hai nhãn nghe gần như nhau nếu chỉ đọc tiêu đề.
      label: '$title. $description',
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x3),
        child: Material(
          color: t.surfaceRaised,
          borderRadius: t.sharpAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: t.sharpAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Đĩa icon: cùng vật liệu với badge màn khu vực, nên hai màn
                  // đọc ra là cùng một bảo tàng.
                  Container(
                    width: AppSpace.badge,
                    height: AppSpace.badge,
                    decoration: BoxDecoration(
                      color: t.badgeWell,
                      borderRadius: t.sharpAll,
                    ),
                    alignment: Alignment.center,
                    child: Icon(MuseumIcons.forMenu(action),
                        size: 18, color: t.ink),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: AppText.cardTitle.copyWith(color: t.ink)),
                        const SizedBox(height: AppSpace.x1),
                        Text(description,
                            style: AppText.meta.copyWith(color: t.inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  // Mũi tên ngồi trên dòng tiêu đề, không giữa thẻ: thẻ cao
                  // thấp khác nhau tuỳ độ dài mô tả, mũi tên trôi theo thì cả
                  // cột mất đường thẳng.
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.x1),
                    child: Icon(Icons.chevron_right,
                        size: 18, color: t.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
