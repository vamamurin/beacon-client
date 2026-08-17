// Destination: lib/presentation/app/app_router.dart (REPLACES current)
//
// Route table for the zone-first 4-screen flow. Screens are STUBS in Step 2
// (build-green skeletons); Steps 3-6 replace each with the real UI. The route
// names and argument contract are stable now so later steps only swap widgets.

import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/debug/model_lab_screen.dart';
import 'package:beacon_client/presentation/exhibits/exhibit_detail_screen.dart';
import 'package:beacon_client/presentation/exhibits/exhibit_list_screen.dart';
import 'package:beacon_client/presentation/app/tour_shell.dart';
import 'package:beacon_client/presentation/farewell/farewell_screen.dart';
import 'package:beacon_client/presentation/gate/gate_screen.dart';
import 'package:beacon_client/presentation/summary/summary_screen.dart';
import 'package:beacon_client/presentation/widgets/article_screen.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/settings/settings_screen.dart';

/// Route-argument contract between the exhibit list (screen 3) and the exhibit
/// detail (screen 4). Both identifiers are needed: minor alone is only unique
/// WITHIN a zone.
class ExhibitDetailArgs {
  final int major;
  final int minor;
  const ExhibitDetailArgs({required this.major, required this.minor});
}

abstract final class AppRouter {
  static const String gateRoute = '/'; // Screen 1: welcome / start
  static const String exhibitListRoute = '/exhibits'; // Screen 3
  static const String exhibitDetailRoute = '/exhibit'; // Screen 4
  static const String settingsRoute = '/settings'; // setting screen

  /// ═══════════════════════════════════════════════════════════════════════
  /// KHUNG MÁY — chứa các tab, và gần như mọi màn chạy BÊN TRONG nó
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Đây là route DUY NHẤT mà `MuseumApp._syncNavigation` dựng lại ở mỗi ranh
  /// giới phiên. Bên trong nó, mỗi tab có `Navigator` riêng và các trang con
  /// (danh sách hiện vật, chi tiết hiện vật) sống ở đó — nên chúng KHÔNG phủ
  /// lên tab bar, và tab của chính chúng vẫn sáng.
  ///
  /// ⚠ [exhibitListRoute] và [exhibitDetailRoute] KHÔNG còn được đẩy lên
  /// navigator gốc. Bảng dưới đây vẫn dựng được chúng vì các Navigator lồng
  /// trong shell ỦY QUYỀN cho `onGenerateRoute` này — một bảng, không phải hai
  /// bản sao sẽ lệch nhau ở lần sửa đầu tiên.
  ///
  /// `zoneRoute` ĐÃ BỊ XOÁ cùng lúc: màn khu vực nay là màn GỐC của tab Tham
  /// quan, dựng thẳng trong shell, nên cái tên route ấy không còn ai gọi. Một
  /// hằng số không có call site là một hằng số sẽ nói dối ở lần đọc sau.
  static const String shellRoute = '/shell';

  // ── các màn TOÀN MÀN HÌNH, nằm TRÊN shell ──
  //
  // Ba màn dưới đây phủ cả tab bar, và mỗi màn có một lý do riêng:
  //   [summaryRoute]  màn XÁC NHẬN của cả phiên (vẫn trong `touring`, có đường
  //                   lui). Khách đang đọc bản ghi chuyến đi thì không nên có
  //                   năm lối mời đi tiếp ở dưới chân.
  //   [farewellRoute] sau khi phiên đã dọn; tới được đó là do
  //                   MuseumApp._syncNavigation đưa sang, không phải tự đẩy.
  //   [settingsRoute] màn của NHÂN VIÊN.
  static const String summaryRoute = '/summary'; // tổng kết (VẪN trong phiên)
  /// Bài đọc mở từ màn Poster ("Giới thiệu bảo tàng" / "Câu hỏi thường gặp").
  /// MỘT route cho cả hai: nội dung đi qua [ArticleArgs], nên thêm một bài đọc
  /// thứ ba không sinh thêm route nào.
  static const String articleRoute = '/article';
  static const String farewellRoute = '/farewell'; // cảm ơn / gửi lại máy

  /// ⚠ SPIKE M0 — dụng cụ đo, không phải một màn của sản phẩm.
  ///
  /// Sống cạnh các màn toàn màn hình vì nó cũng phủ tab bar, nhưng khác chúng ở
  /// một điểm: nó phải BIẾN MẤT cùng với `model_viewer_plus` khi M0 có kết luận.
  /// Lối vào duy nhất là mục Chẩn đoán trong Cài đặt (màn của nhân viên).
  static const String modelLabRoute = '/model-lab';

  /// MÀN NGHỈ — nơi máy quay về mỗi khi không có tour nào chạy: lúc nằm trên
  /// dock, lúc vừa được nhấc lên, và sau khi một chuyến đi khép lại.
  ///
  /// Nay là [gateRoute] — MÀN POSTER. Doc trước của hằng này tiên đoán đúng
  /// ngày nó đổi: *"màn poster sẽ được đặt TRƯỚC Menu ở bước sau, và ngày đó
  /// màn nghỉ là poster chứ không phải shell nữa."* Đây là dòng duy nhất phải
  /// sửa, và nó vừa được sửa.
  ///
  /// ⚠ [restRoute] VÀ [shellRoute] NAY LÀ HAI GIÁ TRỊ KHÁC NHAU. Trong một thời
  /// gian chúng trùng nhau, và `tourNavigationTarget` đã cố ý viết hai nhánh
  /// riêng để hôm nay không phải đi tìm chỗ nào nhầm.
  ///
  /// TRÁCH NHIỆM "THẺ TRẠNG THÁI NHÂN VIÊN" KHÔNG ĐI THEO HẰNG NÀY NỮA. Poster
  /// là một cái cổng và không mang gì khác (quyết định sản phẩm) — câu hỏi "máy
  /// đã sẵn sàng chưa" nay sống ở màn Menu dưới dạng hộp thoại. Xem
  /// `widgets/device_status.dart`.
  static const String restRoute = gateRoute;

  static const String initialRoute = restRoute;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case gateRoute:
        return _page(const GateScreen(), settings);
      case exhibitListRoute:
        final args = settings.arguments;
        if (args is! int) {
          return _error(settings,
              'exhibitListRoute cần arguments là int (zone major).');
        }
        return _page(ExhibitListScreen(major: args), settings);
      case exhibitDetailRoute:
        final args = settings.arguments;
        if (args is! ExhibitDetailArgs) {
          return _error(settings,
              'exhibitDetailRoute cần arguments là ExhibitDetailArgs.');
        }
        return _page(
          ExhibitDetailScreen(major: args.major, minor: args.minor),
          settings,
        );
      case shellRoute:
        return _page(const TourShell(), settings);
      case settingsRoute:
        return _page(const SettingsScreen(), settings);
      case articleRoute:
        final args = settings.arguments;
        if (args is! ArticleArgs) {
          return _error(settings, 'articleRoute cần arguments là ArticleArgs.');
        }
        return _page(ArticleScreen(args: args), settings);
      case summaryRoute:
        return _page(const SummaryScreen(), settings);
      case farewellRoute:
        return _page(const FarewellScreen(), settings);
      case modelLabRoute:
        return _page(const ModelLabScreen(), settings);
      default:
        return _error(settings, 'Unknown route: "${settings.name}".');
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) =>
      _error(settings, 'Unknown route: "${settings.name}".');

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings s) =>
      MaterialPageRoute<dynamic>(builder: (_) => child, settings: s);

  static MaterialPageRoute<dynamic> _error(RouteSettings s, String msg) =>
      MaterialPageRoute<dynamic>(
        builder: (_) => _Stub('Routing error\n$msg'),
        settings: s,
      );
}

/// Temporary placeholder so main builds and runs in Step 2.
class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.surface,
      body: Center(
        child: Text(label,
            textAlign: TextAlign.center,
            style: AppText.meta.copyWith(color: t.inkMuted)),
      ),
    );
  }
}

