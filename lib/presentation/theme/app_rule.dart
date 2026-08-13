// Destination: lib/presentation/theme/app_rule.dart
//
// HAI ĐƯỜNG KẺ CỦA CẢ APP. Không có đường thứ ba.
//
// Thiết kế beacon-v6 dùng đúng hai vạch ngang, và chúng KHÔNG phải hai biến thể
// của một thứ — chúng trả lời hai câu hỏi khác nhau:
//
//     [AppDivider]    92×1, mực mờ    "khối chữ này đã hết"
//     [AppHairline]   tràn ngang, 1dp "loại nội dung vừa đổi"
//
// Divider là một DẤU CHẤM CÂU: nó ngắn, nó không chạm mép nào, và nó luôn đứng
// ngay dưới một cụm chữ mà nó đóng lại (cặp 22/48 ở Poster và màn Cảm ơn, tên
// bảo tàng ở đầu ngăn kéo). Hairline là một RANH GIỚI: nó tràn hết bề ngang của
// vùng nó chia, và ở màn Tổng kết thiết kế đếm rõ cả app chỉ còn ba cái —
// dưới ba con số, trên khối "17 khu chưa ghé", trên khối đánh giá. Mỗi cái đánh
// dấu một lần đổi LOẠI nội dung: số sang danh sách, đã làm sang chưa làm, bản
// ghi sang câu hỏi.
//
// ⚠ VÌ SAO HAI MÀU KHÁC NHAU, và đây là chỗ dễ nối nhầm nhất:
//
//     AppDivider  -> `ink` @22%     (mực pha loãng)
//     AppHairline -> `line`          (token vạch trang trí)
//
// Divider KHÔNG dùng `line` được vì nó thường nằm trên ẢNH hoặc trên nền của
// hai màn "hòn đảo luôn tối", nơi `line` (cố ý mờ, ~1.2:1 với surface) biến mất
// hoàn toàn. Nó là mực của chính khối chữ ở trên, nhạt đi — nên nó theo `ink`.
//
// Và cả hai đều KHÔNG dùng `outline`: outline là ranh giới của một CONTROL và
// có sàn 3:1 (WCAG 1.4.11). Hai vạch ở đây là trang trí — mất chúng không mất
// thông tin nào. Xem doc `line` / `outline` trong museum_tokens.dart; việc trộn
// ba vai trò này vào một token là lỗi đã xảy ra và đã được tách ra.

import 'package:flutter/material.dart';

import 'museum_tokens.dart';

/// Vạch 92×1 đóng một cụm chữ. Xem chú giải đầu file.
class AppDivider extends StatelessWidget {
  /// 92 là con số của bản vẽ và nó KHÔNG co theo màn: divider là một dấu câu
  /// đặt cạnh chữ, không phải một đường chia không gian. Cho nó co theo bề
  /// ngang máy là biến nó thành thứ thứ hai.
  static const double width = 92;

  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width,
      height: 1,
      color: t.ink.withValues(alpha: 0.22),
    );
  }
}

/// Vạch tóc tràn ngang, đánh dấu một lần đổi LOẠI nội dung.
///
/// Không tự thêm lề: chỗ gọi quyết định nó tràn hết máy hay tràn trong lề
/// [AppSpace.gutter]. Ở màn Tổng kết nó nằm trong lề (nó chia hai khối nội
/// dung); ở ngăn kéo nó cũng trong lề. Chưa có call site nào cần tràn hết máy —
/// nếu xuất hiện, đó là dấu hiệu nên xem lại, vì một vạch chạm hai mép đọc ra
/// là "hết màn này" chứ không phải "đổi loại".
class AppHairline extends StatelessWidget {
  const AppHairline({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.tokens.line);
}
