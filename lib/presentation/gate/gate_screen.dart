// Destination: lib/presentation/gate/gate_screen.dart
//
// MÀN 01 · POSTER — máy nằm chờ trên quầy, chưa ai chạm vào.
//
// ═══════════════════════════════════════════════════════════════════════════
// MÀN NÀY LÀM ĐÚNG MỘT VIỆC: KHIẾN NGƯỜI ĐI NGANG MUỐN CẦM NÓ LÊN
// ═══════════════════════════════════════════════════════════════════════════
//
// Nó là một CÁI CỔNG, không phải một bảng điều khiển. Quyết định sản phẩm, và
// nó xoá gần hết những gì file này từng chứa:
//
//   KHÔNG thẻ trạng thái máy      → chuyển sang màn Menu, dạng hộp thoại
//   KHÔNG xin quyền Bluetooth     → xin ở màn Menu
//   KHÔNG theo dõi vòng đời app   → `refreshBluetoothOnResume` theo sang Menu
//   KHÔNG lối vào Cài đặt         → nay là một hàng công khai trong ngăn kéo
//   KHÔNG bộ chọn ngôn ngữ        → chip `VI` trên thanh trên của các màn khác
//   KHÔNG nút "Bắt đầu tham quan" → tour bắt đầu từ màn Menu
//
// Bản trước là một collage hai khung ảnh trên nền phẳng, cộng ~900 dòng dây nối
// trạng thái khởi động. Cả hai đều biến mất: collage vì bản vẽ thay nó bằng một
// tấm ảnh tràn màn, dây nối vì trách nhiệm đã đổi chủ.
//
// ⚠ MỘT ẢNH, KHÔNG PHẢI HAI. `content.welcomeAccentImagePath` (khung phụ của
// collage) không còn call site nào. Chưa xoá khỏi manifest/model: bundle đang
// chạy ngoài hiện trường vẫn khai báo nó, và một khoá thừa thì vô hại còn một
// parser đột ngột từ chối nó thì không.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI HÀNG PHỤ CỦA BẢN VẼ CHƯA CÓ MẶT
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ có thêm "Giới thiệu bảo tàng" và "Câu hỏi thường gặp" dưới hàng chính.
// Cả hai đều chưa có: manifest không có khoá nội dung cho chúng, và không có
// màn hình nào để dẫn tới.
//
// Chúng bị BỎ chứ không dựng thành hàng chờ sẵn — một hàng bấm vào không đi đâu
// tệ hơn hẳn một hàng vắng mặt, và ở đây nó còn cạnh tranh với lối vào duy nhất
// được nhấn. Khi CMS có nội dung, thêm chúng vào `rows` là xong.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/signature_screen.dart';

class GateScreen extends StatelessWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();

    return SignatureScreen(
      imagePath: content.welcomeImagePath,
      veil: SignatureVeil.poster,
      // Cặp chữ ký của app: nhãn "Bảo tàng" 22 mờ, ĐỨNG TRÊN tên thật 48 trắng
      // đặc. Chỉ dùng lại đúng một lần nữa — ở màn Cảm ơn.
      kicker: content.ui(UiKeys.posterKicker),
      title: content.textOrNull(content.museumName) ??
          content.ui(UiKeys.gateMuseumFallback),
      poweredBy: true,
      rows: [
        AppRow(
          label: content.ui(UiKeys.posterEnter),
          // `lead` = đường đi tiếp DUY NHẤT của màn. Cao hơn, chữ hoa, tracking
          // giãn — nổi bằng KHÔNG GIAN, không bằng một khối màu.
          lead: true,
          onTap: () {
            // PUSH, không thay thế: poster ở lại dưới đáy ngăn xếp, nên nút lùi
            // của Android rơi xuống một tấm áp phích thay vì rơi ra khỏi app.
            // Khi phiên quay về trạng thái nghỉ, `MuseumApp._syncNavigation`
            // vẫn dựng lại stack về đúng đây.
            Navigator.of(context).pushNamed(AppRouter.shellRoute);
          },
        ),
      ],
    );
  }
}
