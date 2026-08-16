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
// ⚠ MỘT ẢNH, KHÔNG PHẢI HAI. `museum.welcomeAccentImage` (khung phụ của collage
// cũ) đã bị gỡ hẳn khỏi model, parser và manifest ngày 16/08/2026, sau khi rà
// lại và thấy không màn nào đọc nó. Bundle cũ ngoài hiện trường vẫn khai báo
// khoá ấy và vẫn parse được — parser bỏ qua khoá lạ, không từ chối chúng.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI HÀNG PHỤ — CÓ, VÀ CHỈ HIỆN KHI BẢO TÀNG ĐÃ VIẾT NỘI DUNG
// ═══════════════════════════════════════════════════════════════════════════
//
// "Giới thiệu bảo tàng" và "Câu hỏi thường gặp" đọc từ hai khối `about` và
// `faq` trong manifest — cùng hình dạng với `guide`, cùng bộ phân tích, cùng
// một màn bài đọc.
//
// KHỐI RỖNG KHÔNG LÀM HÀNG BIẾN MẤT. Hàng vẫn có mặt và dẫn tới màn bài đọc ở
// trạng thái "Sắp có".
//
// Bản trước ẩn hàng khi thiếu nội dung, và đó là một lỗi cùng loại với việc bỏ
// hẳn hai hàng này: nó để một quyết định KỸ THUẬT (bundle chưa có khoá) âm thầm
// sửa một quyết định THIẾT KẾ (poster có ba lối đi). App vẫn không bịa nội dung
// của bảo tàng — nó chỉ không giấu đi cái cửa.
//
// Bản vẽ giữ hai mục này và BỎ hai mục khác của Rijksmuseum (*are you in the
// museum*, *tickets*) vì cả hai vô nghĩa ở đây — khách đang cầm máy của bảo
// tàng, đứng trong bảo tàng, đã có vé. Còn `faq` là thứ khách cần TRƯỚC khi
// bước vào (máy này là gì, có mất tiền không, hỏng thì sao), khác hẳn "Hướng
// dẫn sử dụng" vốn nói về lúc tour đã chạy.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/guide_content.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/article_screen.dart';
import 'package:beacon_client/presentation/widgets/signature_screen.dart';

class GateScreen extends StatelessWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    // ═══════════════════════════════════════════════════════════════════════
    // CÒN CẮM SẠC ⇒ KHOÁ LỐI VÀO TOUR, VÀ KHOÁ Ở ĐÂY
    // ═══════════════════════════════════════════════════════════════════════
    //
    // `atDesk` nghĩa là máy vẫn nằm trên dock — phiên chỉ rời trạng thái đó khi
    // có người RÚT máy ra. Đó là tín hiệu vật lý, không phải một cờ trong app.
    //
    // Trước đây chỗ khoá nằm mãi trong màn Menu: `startTour()` bị bỏ qua ở
    // `atDesk`, nên khách đi Poster → Menu → bấm "Bắt đầu tham quan" và KHÔNG
    // CÓ GÌ XẢY RA. Một nút chết không nói ra là chết, sau hai lần chạm.
    //
    // Nay lối đi bị chặn ngay ở cửa, và chặn một cách nhìn thấy được: hàng
    // "Tham quan" mờ đi. Khách nhấc máy khỏi dock là nó sáng lại — đúng thứ tự
    // mà một chiếc máy mượn ở quầy vốn phải đi qua.
    final onDock = context.select<SessionProvider, bool>(
      (s) => s.phase == SessionPhase.atDesk,
    );

    return SignatureScreen(
      imagePath: content.welcomeImagePath,
      kind: SignatureKind.poster,
      // Cặp chữ ký của app: nhãn "Bảo tàng" 22 mờ, ĐỨNG TRÊN tên riêng 48 trắng
      // đặc. Chỉ dùng lại đúng một lần nữa — ở màn Cảm ơn.
      //
      // ⚠ DÙNG TÊN NGẮN, KHÔNG DÙNG TÊN ĐẦY ĐỦ. Bản vẽ tách tên bảo tàng làm
      // hai: chữ "Bảo tàng" là NHÃN ở dòng nhỏ, phần còn lại là TÊN RIÊNG ở
      // dòng lớn ("Chứng tích Chiến tranh"). Ghép nhãn với tên đầy đủ cho ra
      // "Bảo tàng / Bảo tàng Chứng tích Chiến tranh" — chữ "Bảo tàng" đọc hai
      // lần, và dòng lớn dài thêm một nửa nên vạch 92 bên dưới trông hụt hẳn.
      //
      // Tên ngắn là dữ liệu của bảo tàng nên nó ở manifest (`museum.shortName`),
      // không phải một phép cắt chuỗi trong app: cắt tiền tố "Bảo tàng " chỉ
      // chạy được với tiếng Việt và sẽ sai ngay ở tiếng thứ hai.
      kicker: content.ui(UiKeys.posterKicker),
      title: content.museumShortName,
      poweredBy: true,
      rows: [
        AppRow(
          label: content.ui(UiKeys.posterEnter),
          // `lead` = đường đi tiếp DUY NHẤT của màn. Cao hơn, chữ hoa, tracking
          // giãn — nổi bằng KHÔNG GIAN, không bằng một khối màu.
          lead: true,
          onTap: onDock
              ? null
              : () {
                  // PUSH, không thay thế: poster ở lại dưới đáy ngăn xếp, nên nút lùi
                  // của Android rơi xuống một tấm áp phích thay vì rơi ra khỏi app.
                  // Khi phiên quay về trạng thái nghỉ, `MuseumApp._syncNavigation`
                  // vẫn dựng lại stack về đúng đây.
                  Navigator.of(context).pushNamed(AppRouter.shellRoute);
                },
        ),
        // HAI HÀNG NÀY LUÔN CÓ MẶT. Bundle chưa có nội dung thì màn bài đọc
        // hiện trạng thái "Sắp có" — hàng KHÔNG biến mất. Xem chú giải ở đầu
        // file cho lý do.
        AppRow(
          label: content.ui(UiKeys.posterAbout),
          onTap: () => _openArticle(context, UiKeys.posterAbout, content.about),
        ),
        AppRow(
          label: content.ui(UiKeys.posterFaq),
          onTap: () => _openArticle(context, UiKeys.posterFaq, content.faq),
        ),
      ],
    );
  }

  void _openArticle(BuildContext context, String titleKey, GuideContent body) {
    Navigator.of(context).pushNamed(
      AppRouter.articleRoute,
      arguments: ArticleArgs(titleKey: titleKey, content: body),
    );
  }
}
