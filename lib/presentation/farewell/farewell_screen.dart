// Destination: lib/presentation/farewell/farewell_screen.dart
//
// MÀN 07 · CẢM ƠN — nửa còn lại của cặp đối xứng với màn Poster.
//
// MÀN NÀY KHÔNG TỰ LÀM GÌ CẢ. Nó không hẹn giờ, không tự điều hướng, không dọn
// dẹp. Đồng hồ giữ màn (`farewellHold`) do [SessionController] cầm, và nút
// "Xong" chỉ phát biểu ý định — phiên về `atDesk`, rồi root đưa ngăn xếp về màn
// nghỉ VÌ PHASE ĐỔI. Đó là lý do nó vẫn là một màn thuần trình bày dù nằm ở
// cuối một luồng phức tạp.
//
// ═══════════════════════════════════════════════════════════════════════════
// DÙNG CHUNG KHUÔN VỚI MÀN MỞ — và đó là toàn bộ ý nghĩa của nó
// ═══════════════════════════════════════════════════════════════════════════
//
// Cùng bức ảnh, cùng bộ lọc, cùng cặp chữ 22/48, cùng neo [DesignSize.gateTop].
// Khách phải nhận ra mình đã quay về đúng nơi bắt đầu — và điều đó chỉ xảy ra
// nếu cụm chữ rơi đúng một chỗ trên cả hai màn, chứ không phải "trông na ná".
// Xem [SignatureScreen] cho cách sự đối xứng được biến thành một tính chất.
//
// Khác màn Poster ở đúng ba điểm:
//   • veil ĐẬM hơn — ở đây ảnh chỉ còn làm nền cho chữ, không còn là nội dung;
//   • có câu dặn dò dưới divider (trả máy ở đâu);
//   • hàng thao tác GHIM Ở ĐÁY, không nằm trong cụm chữ: "Xong" là một dấu
//     chấm hết, không phải câu tiếp theo của một lời mời.
//
// ⚠ TAB BAR VẪN CÒN Ở MÀN NÀY — quyết định tạm. Lý lẽ giữ: phiên chưa đóng cho
// tới khi khách chạm "Xong", nên năm lối điều hướng vẫn hợp lệ. Lý lẽ bỏ (chưa
// thắng): cả màn đang nói "xin trả máy tại quầy", mà bên dưới lại mời đi tiếp.
// Nếu thực địa cho thấy khách đi lạc từ đây, đó là chỗ để sửa.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/signature_screen.dart';

class FarewellScreen extends StatelessWidget {
  const FarewellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();

    return SignatureScreen(
      imagePath: content.welcomeImagePath,
      kind: SignatureKind.farewell,
      kicker: content.ui(UiKeys.farewellKicker),
      title: content.ui(UiKeys.farewellTitle),
      lede: content.ui(UiKeys.farewellBody),
      bottom: AppRow(
        label: content.ui(UiKeys.farewellCta),
        lead: true,
        onTap: () => context.read<SessionProvider>().dismissFarewell(),
      ),
    );
  }
}
