// Destination: lib/presentation/app/app_router.dart (REPLACES current)
//
// Route table for the zone-first 4-screen flow. Screens are STUBS in Step 2
// (build-green skeletons); Steps 3-6 replace each with the real UI. The route
// names and argument contract are stable now so later steps only swap widgets.

import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/gate/gate_screen.dart';
import 'package:beacon_client/presentation/zone/zone_screen.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

abstract final class AppRouter {
  static const String gateRoute = '/'; // Screen 1: welcome / start
  static const String zoneRoute = '/zone'; // Screen 2: current zone card / radar
  static const String exhibitListRoute = '/exhibits'; // Screen 3
  static const String exhibitDetailRoute = '/exhibit'; // Screen 4
  static const String initialRoute = gateRoute;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case gateRoute:
        return _page(const GateScreen(), settings);
      case zoneRoute:
        return _page(const ZoneScreen(), settings);
      case exhibitListRoute:
        return _page(const _Stub('Exhibit list (Screen 3)'), settings);
      case exhibitDetailRoute:
        return _page(const _Stub('Exhibit detail (Screen 4)'), settings);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(label,
            textAlign: TextAlign.center,
            style: AppText.meta.copyWith(color: AppColors.muted)),
      ),
    );
  }
}