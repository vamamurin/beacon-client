// Destination: lib/presentation/app/app_router.dart (REPLACES current)
//
// Route table for the zone-first 4-screen flow. Screens are STUBS in Step 2
// (build-green skeletons); Steps 3-6 replace each with the real UI. The route
// names and argument contract are stable now so later steps only swap widgets.

import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/exhibits/exhibit_detail_screen.dart';
import 'package:beacon_client/presentation/exhibits/exhibit_list_screen.dart';
import 'package:beacon_client/presentation/gate/gate_screen.dart';
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
  static const String initialRoute = zoneRoute;

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

