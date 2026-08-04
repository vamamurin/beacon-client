// Destination: lib/domain/models/menu_config.dart
//
// Cấu hình MÀN MENU — do bundle điều khiển (khối `menu` trong manifest).
//
// Vì sao để server quyết: bảo tàng bật/tắt và sắp xếp lại các lối vào mà không
// cần build app. Cụ thể là kịch bản "bật khi làm xong": CMS có thể khai báo mục
// `map` từ hôm nay, mục đó chỉ hiện lên vào ngày app có màn bản đồ thật (xem
// `MenuActionSupport` ở tầng presentation) — không ai phải sửa manifest lần hai.
//
// Ranh giới trách nhiệm:
//   • server CHỌN mục nào, THỨ TỰ, và bật/tắt;
//   • app SỞ HỮU tập đích đến hợp lệ ([MenuAction]) và nhãn (qua UiKeys).
// Server không tự nghĩ ra được một đích mới, vì mỗi đích phải có một màn hình
// thật đứng sau. Id lạ bị bỏ kèm warning thay vì làm hỏng bundle.

import 'package:flutter/foundation.dart';

/// Đích đến hợp lệ của một mục Menu. [id] là chuỗi xuất hiện trong manifest.
enum MenuAction {
  /// Bắt đầu chuyến tham quan (gọi `userStartedTour()`). Chỉ có nghĩa ở Menu
  /// TRƯỚC tour; trong sheet giữa tour mục này bị ẩn.
  startTour('start'),

  /// Hướng dẫn sử dụng thiết bị.
  guide('guide'),

  /// Danh mục toàn bộ khu + hiện vật (duyệt không phụ thuộc vị trí).
  ///
  /// Id trong manifest là `catalog`, KHÔNG phải `index`: `index` là tên đã bị
  /// `Enum.index` của Dart chiếm, và để tên Dart lệch tên manifest thì người
  /// đọc CMS và người đọc code sẽ nói về hai thứ khác nhau.
  catalog('catalog'),

  /// Sơ đồ tầng.
  map('map'),

  /// Chọn tuyến tham quan (tour 45 phút / tour đầy đủ ...).
  tours('tours');

  const MenuAction(this.id);

  /// Khóa trong manifest. KHÔNG đổi giá trị này sau khi đã phát hành bundle —
  /// nó là một phần hợp đồng với CMS.
  final String id;

  static MenuAction? byId(String id) {
    for (final a in MenuAction.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Một mục trên Menu.
@immutable
class MenuEntry {
  final MenuAction action;

  /// false ⇒ mục biến mất khỏi Menu. Giữ được bản ghi trong manifest (kèm bản
  /// dịch nhãn nếu có) mà không hiện cho khách.
  final bool enabled;

  const MenuEntry(this.action, {this.enabled = true});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuEntry &&
          other.action == action &&
          other.enabled == enabled);

  @override
  int get hashCode => Object.hash(action, enabled);

  @override
  String toString() => 'MenuEntry(${action.id}${enabled ? "" : ", off"})';
}

/// Khối `menu` của manifest.
///
/// THỨ TỰ MẢNG LÀ THỨ TỰ HIỂN THỊ — không có trường `order` riêng, cùng quy ước
/// với `zone.exhibits` (thứ tự mảng là thứ tự tour). Một nguồn sự thật, không
/// có khả năng hai nguồn lệch nhau.
@immutable
class MenuConfig {
  final List<MenuEntry> entries;

  const MenuConfig({required this.entries});

  /// Bundle không khai báo `menu` ⇒ hai lối vào tối thiểu, đúng thứ tự này.
  /// Mọi bundle đang chạy ngoài hiện trường đều đi đường này cho tới khi CMS
  /// bổ sung khối `menu`.
  static const MenuConfig defaults = MenuConfig(entries: <MenuEntry>[
    MenuEntry(MenuAction.startTour),
    MenuEntry(MenuAction.guide),
  ]);

  /// Các mục đang bật, giữ nguyên thứ tự khai báo.
  Iterable<MenuEntry> get visible => entries.where((e) => e.enabled);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuConfig && listEquals(other.entries, entries));

  @override
  int get hashCode => Object.hashAll(entries);
}
