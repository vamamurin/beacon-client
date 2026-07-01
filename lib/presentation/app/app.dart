import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Global route observer — the load-bearing piece of the freeze-on-obscured
/// design.
///
/// Screen 2 ([DiscoveryScreen]) subscribes to this so it can detect when
/// Screen 3 is pushed over it (`didPushNext`) and popped back (`didPopNext`).
/// It MUST be the same instance registered in [MaterialApp.navigatorObservers],
/// which is why it lives here at the app root and is imported by any
/// `RouteAware` screen rather than constructed locally.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Root application widget: `MaterialApp` + theme + route table, lifted out of
/// `main.dart` so bootstrapping (DI, permissions, provider) stays cleanly
/// separated from app configuration.
class MuseumApp extends StatelessWidget {
  const MuseumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Museum Guide',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      // Same instance the RouteAware screens subscribe to.
      navigatorObservers: [routeObserver],
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.gold,
        secondary: AppColors.goldLight,
        onPrimary: AppColors.background,
        onSurface: AppColors.text,
      ),
      // Screens draw their own SafeArea-aware app bars; stop M3 surface-tinting
      // any default AppBar that slips through.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
