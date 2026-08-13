// Destination: lib/presentation/app/app_router.dart (REPLACES current)
//
// Route table for the zone-first 4-screen flow. Screens are STUBS in Step 2
// (build-green skeletons); Steps 3-6 replace each with the real UI. The route
// names and argument contract are stable now so later steps only swap widgets.

import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/exhibits/exhibit_detail_screen.dart';
import 'package:beacon_client/presentation/exhibits/exhibit_list_screen.dart';
import 'package:beacon_client/presentation/app/tour_shell.dart';
import 'package:beacon_client/presentation/farewell/farewell_screen.dart';
import 'package:beacon_client/presentation/gate/gate_screen.dart';
import 'package:beacon_client/presentation/summary/summary_screen.dart';
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
  static const String farewellRoute = '/farewell'; // cảm ơn / gửi lại máy

  /// MÀN NGHỈ — nơi máy quay về mỗi khi không có tour nào chạy: lúc nằm trên
  /// dock, lúc vừa được nhấc lên, và sau khi một chuyến đi khép lại.
  ///
  /// Nay là [shellRoute]: shell tự chọn tab mở đầu theo phase (chưa tour ⇒ tab
  /// Trang chính). Hằng này vẫn tồn tại riêng vì thứ tự đầu luồng CÒN ĐỔI —
  /// màn poster sẽ được đặt TRƯỚC Menu ở bước sau, và ngày đó màn nghỉ là
  /// poster chứ không phải shell nữa. Khi ấy đây là DÒNG DUY NHẤT phải sửa.
  ///
  /// Hệ quả trách nhiệm: màn nào đứng ở đây thì màn đó phải mang các thẻ trạng
  /// thái dành cho nhân viên (xem `deviceNotReadyCard`), vì nó là thứ nhân viên
  /// nhìn khi nhấc máy khỏi dock. Hiện trách nhiệm đó nằm ở màn gốc của tab
  /// Trang chính.
  static const String restRoute = shellRoute;

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
      case summaryRoute:
        return _page(const SummaryScreen(), settings);
      case farewellRoute:
        return _page(const FarewellScreen(), settings);
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

