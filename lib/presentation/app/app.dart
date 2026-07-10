// Destination: lib/presentation/app/app.dart (REPLACES current)
//
// Root MaterialApp: new palette/fonts + the zone-first route table, PLUS the
// single owner of session→route mapping.
//
// Why the navigation lives here (Phase-4 Step 7 wiring): a tour session can end
// at any moment from deep in the stack (charging / desk / silence / staff).
// When it does, the visitor may be on screen 2/3/4 — none of which can see the
// Gate anymore (Gate was removed from the stack when the tour began). So the
// ONE place that reshapes the stack on a lifecycle boundary is here, at the
// root, watching SessionProvider through a navigatorKey. Screens never reset
// the stack themselves; they only push forward within a live tour.
//
// Two transitions, nothing else:
//   • enters touring  -> stack becomes [Zone]      (tour begins)
//   • leaves touring  -> stack becomes [Gate]      (tour ended / cleaned up)
// atDesk<->gate need no navigation: both are the Gate screen, which enables or
// disables its Start button from SessionProvider.isAtGate.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';

/// Global route observer, available for any RouteAware screen that wants to
/// pause work while obscured. Registered on the Navigator so it's ready; the
/// current 4 screens don't subscribe (their freeze is structural — they read
/// their route args once), but new screens can opt in without re-plumbing.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

class MuseumApp extends StatefulWidget {
  const MuseumApp({super.key});

  @override
  State<MuseumApp> createState() => _MuseumAppState();
}

class _MuseumAppState extends State<MuseumApp> {
  /// Lets the root drive the Navigator that lives inside MaterialApp. Stable
  /// across rebuilds, so route state survives a MaterialApp reconfigure.
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  /// Last session phase we acted on, so a rebuild that didn't change phase is
  /// a no-op. Null until the first observation (initialRoute is already right).
  SessionPhase? _lastPhase;

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the session state changes (rare: phase transitions).
    final phase = context.watch<SessionProvider>().phase;
    final themeCtrl = context.watch<ThemeController>();
    _syncNavigation(phase);

    return MaterialApp(
      title: 'Museum Guide',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: themeCtrl.theme,
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      navigatorObservers: [routeObserver],
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.6,
        child: child!,
      ),
    );
  }

  /// React to the two tour-boundary transitions. Post-frame so we never push
  /// during build; guarded so only genuine boundary crossings navigate.
  void _syncNavigation(SessionPhase phase) {
    final prev = _lastPhase;
    if (phase == prev) return;
    _lastPhase = phase;
    if (prev == null) return; // first observation: initialRoute handles it

    final enteringTour =
        prev != SessionPhase.touring && phase == SessionPhase.touring;
    final leavingTour =
        prev == SessionPhase.touring && phase != SessionPhase.touring;
    if (!enteringTour && !leavingTour) return;

    final target = enteringTour ? AppRouter.zoneRoute : AppRouter.gateRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navKey.currentState?.pushNamedAndRemoveUntil(target, (_) => false);
    });
  }
}