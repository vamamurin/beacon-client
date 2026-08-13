// Destination: lib/presentation/menu/menu_items.dart
//
// Danh sách các mục Menu — DÙNG CHUNG cho hai chỗ hiện nó:
//   • [MenuScreen]   — màn gốc của tab Trang chính
//   • [MuseumDrawer] — ngăn kéo trượt từ trái, mở được ở mọi màn
//
// Một widget cho cả hai vì đó chính là lời hứa với khách: "menu" phải là cùng
// một thứ ở mọi thời điểm. Hai bản sao sẽ lệch nhau ngay lần thêm mục thứ ba.
//
// ⚠ HÀNG THAY CHO THẺ. Mỗi mục từng là một thẻ `surfaceRaised` bo góc có đĩa
// icon 36dp; nay là [AppRow] — tràn hết bề ngang, nền trong suốt, không icon,
// chỉ nhãn và dấu ›. Đó là một trong BA hình dáng của cả app (xem doc đầu
// `app_row.dart`): một mục menu là một THAO TÁC, và thao tác thì đeo dấu ›.
//
// Hệ quả về bố cục: [AppRow] TỰ MANG lề ngang [AppSpace.gutter]. Chỗ gọi phải
// đặt widget này NGOÀI vùng đã có padding ngang, nếu không lề sẽ cộng đôi.
//
// `MuseumIcons.forMenu` mất call site cuối cùng ở đây. Chưa xoá: màn Sơ đồ và
// Danh mục sắp dựng có thể cần lại. Nếu tới lúc đó vẫn không ai gọi, xoá nó.
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
import 'package:beacon_client/presentation/theme/app_row.dart';
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
          AppRow(
            key: ValueKey('menu.item.${a.id}'),
            label: content.ui(_labelKey(a)),
            // Câu mô tả rời khỏi MẮT nhưng ở lại với TAI. Xem doc
            // `AppRow.semanticLabel`: hai nhãn "Bắt đầu tham quan" và "Chọn
            // tuyến tham quan" nghe gần như nhau nếu chỉ đọc tiêu đề.
            semanticLabel:
                '${content.ui(_labelKey(a))}. ${content.ui(_descKey(a))}',
            onTap: () => onSelect(a),
          ),
      ],
    );
  }
}
