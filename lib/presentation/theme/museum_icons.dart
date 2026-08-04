// Destination: lib/presentation/theme/museum_icons.dart
//
// Ánh xạ TÊN CHUỖI (do bundle gửi) → IconData.
//
// VÌ SAO PHẢI LÀ WHITELIST, KHÔNG PHẢI CODEPOINT ĐỘNG
// ────────────────────────────────────────────────────
// Cách "linh hoạt" hiển nhiên là để CMS gửi thẳng codepoint và app dựng
// `IconData(cp, fontFamily: 'MaterialIcons')`. Cách đó CHẠY TRÊN DEBUG VÀ HỎNG
// TRÊN RELEASE: bản release tree-shake font icon, chỉ giữ các glyph mà trình
// biên dịch NHÌN THẤY được tham chiếu tĩnh trong code. Icon dựng động không có
// tham chiếu nào ⇒ bị cắt khỏi font ⇒ khách thấy ô vuông rỗng. Đây là loại lỗi
// chỉ lộ ra sau khi đã ký bản phát hành.
//
// Nên hợp đồng là: server chọn TRONG danh sách này. Thêm một tên mới là một
// dòng ở đây cộng một lần phát hành app — đổi lại, thứ gì hiện lên cũng chắc
// chắn hiện được.
//
// Tên lạ ⇒ [fallback], KHÔNG BAO GIỜ ném. Một icon sai chỗ không đáng làm hỏng
// cả màn hình.

import 'package:flutter/material.dart';

import 'package:beacon_client/domain/models/menu_config.dart';

abstract final class MuseumIcons {
  /// Dùng khi bundle không khai báo icon, hoặc khai báo một tên không có ở đây.
  static const IconData fallback = Icons.info_outline;

  /// Từ điển icon dùng chung cho bước hướng dẫn (và mọi chỗ sau này cần cho
  /// server chọn icon). Đặt tên theo Ý NGHĨA, không theo hình dạng: bảo tàng
  /// gõ "headphones" chứ không phải "hình cái tai nghe vòng cung".
  static const Map<String, IconData> _byName = <String, IconData>{
    'headphones': Icons.headphones,
    'volume': Icons.volume_up_outlined,
    'walk': Icons.directions_walk,
    'touch': Icons.touch_app_outlined,
    'image': Icons.image_outlined,
    'time': Icons.schedule,
    'map': Icons.map_outlined,
    'help': Icons.support_agent,
    'warning': Icons.warning_amber_outlined,
    'info': Icons.info_outline,
    'battery': Icons.battery_charging_full,
    'language': Icons.translate,
    'star': Icons.star_outline,
    'qr': Icons.qr_code_2,
  };

  static IconData byName(String? name) =>
      name == null ? fallback : (_byName[name] ?? fallback);

  /// Icon của một mục Menu. KHÔNG cho bundle chọn: mục menu là một đích đến do
  /// app sở hữu, nên biểu tượng của nó cũng vậy — để CMS đổi icon "Bắt đầu"
  /// thành hình cái bản đồ chỉ tạo ra một cách làm khách lạc.
  static IconData forMenu(MenuAction action) => switch (action) {
        MenuAction.startTour => Icons.play_arrow_rounded,
        MenuAction.guide => Icons.menu_book_outlined,
        MenuAction.catalog => Icons.grid_view_outlined,
        MenuAction.map => Icons.map_outlined,
        MenuAction.tours => Icons.route_outlined,
      };
}
