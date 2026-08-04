// Destination: lib/presentation/app/app_router.dart (REPLACES current)
//
// Route table for the zone-first 4-screen flow. Screens are STUBS in Step 2
// (build-green skeletons); Steps 3-6 replace each with the real UI. The route
// names and argument contract are stable now so later steps only swap widgets.

import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/exhibits/exhibit_detail_screen.dart';
import 'package:beacon_client/presentation/exhibits/exhibit_list_screen.dart';
import 'package:beacon_client/presentation/farewell/farewell_screen.dart';
import 'package:beacon_client/presentation/gate/gate_screen.dart';
import 'package:beacon_client/presentation/guide/guide_screen.dart';
import 'package:beacon_client/presentation/menu/menu_screen.dart';
import 'package:beacon_client/presentation/summary/summary_screen.dart';
import 'package:beacon_client/presentation/zone/zone_screen.dart';
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
  static const String zoneRoute = '/zone'; // Screen 2: current zone card / radar
  static const String exhibitListRoute = '/exhibits'; // Screen 3
  static const String exhibitDetailRoute = '/exhibit'; // Screen 4
  static const String settingsRoute = '/settings'; // setting screen

  // ── các màn thêm ở nhánh add-on-screens ──
  //
  // Ba màn dưới đây chia nhau một đặc điểm quan trọng: KHÔNG màn nào tự dựng
  // lại stack theo vòng đời phiên. [menuRoute] và [guideRoute] sống trong phase
  // `gate`; [summaryRoute] sống trong phase `touring` (nó là màn XÁC NHẬN, có
  // đường lui); chỉ [farewellRoute] nằm sau khi phiên đã dọn — và nó tới được
  // đó là do MuseumApp._syncNavigation đưa sang, không phải tự đẩy.
  static const String menuRoute = '/menu'; // trung tâm điều hướng
  static const String guideRoute = '/guide'; // hướng dẫn sử dụng
  static const String summaryRoute = '/summary'; // tổng kết (VẪN trong phiên)
  static const String farewellRoute = '/farewell'; // cảm ơn / gửi lại máy

  /// MÀN NGHỈ — nơi máy quay về mỗi khi không có tour nào chạy: lúc nằm trên
  /// dock, lúc vừa được nhấc lên, và sau khi một chuyến đi khép lại.
  ///
  /// Có tên riêng thay vì viết thẳng [menuRoute] ở các call site, vì thứ tự đầu
  /// luồng còn đổi: màn poster/giới thiệu sẽ được đặt TRƯỚC Menu, và ngày đó
  /// màn nghỉ là poster chứ không phải Menu nữa. Khi ấy đây là DÒNG DUY NHẤT
  /// phải sửa — bộ định tuyến và mọi đường quay về đều đọc qua hằng này.
  ///
  /// Hệ quả trách nhiệm: màn nào đứng ở đây thì màn đó phải mang các thẻ trạng
  /// thái dành cho nhân viên (xem `deviceNotReadyCard`), vì nó là thứ nhân viên
  /// nhìn khi nhấc máy khỏi dock.
  static const String restRoute = menuRoute;

  static const String initialRoute = restRoute;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case gateRoute:
        return _page(const GateScreen(), settings);
      case zoneRoute:
        return _page(const ZoneScreen(), settings);
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
      case settingsRoute:
        return _page(const SettingsScreen(), settings);
      case menuRoute:
        return _page(const MenuScreen(), settings);
      case guideRoute:
        return _page(const GuideScreen(), settings);
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

