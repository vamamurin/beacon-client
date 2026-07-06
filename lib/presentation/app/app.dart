// Destination: lib/presentation/app/app.dart (REPLACES current)
//
// Root MaterialApp: new palette/fonts + the zone-first route table. Keeps the
// global routeObserver (the load-bearing piece of freeze-on-obscured, reused in
// Step 5/6 so the exhibit list/detail freeze while a zone changes underneath).

import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Global route observer — same instance registered in navigatorObservers and
/// subscribed by RouteAware screens (Steps 5-6).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

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
      navigatorObservers: [routeObserver],
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.sans,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.white,
        onPrimary: AppColors.black,
        onSurface: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}