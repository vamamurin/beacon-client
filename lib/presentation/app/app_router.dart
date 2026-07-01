import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/home/home_screen.dart';
import 'package:beacon_client/presentation/detail/artifact_detail_screen.dart';
import 'package:beacon_client/presentation/discovery/discovery_screen.dart';
import 'package:beacon_client/presentation/detail/artifact_detail_args.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Centralised route table for the 3-screen push flow.
///
/// Wire into the app shell (next migration step):
/// ```dart
/// MaterialApp(
///   initialRoute: AppRouter.homeRoute,
///   onGenerateRoute: AppRouter.onGenerateRoute,
///   onUnknownRoute: AppRouter.onUnknownRoute,
/// )
/// ```
///
/// `abstract final` ⇒ a pure namespace; never instantiated.
abstract final class AppRouter {
  // ── Route names ─────────────────────────────────────────────────────
  static const String homeRoute = '/';
  static const String discoveryRoute = '/discovery';
  static const String detailRoute = '/detail';
  static const String initialRoute = homeRoute;

  /// Resolves [RouteSettings] into a typed [MaterialPageRoute].
  ///
  /// The detail route requires an [ArtifactDetailArgs] payload; a missing or
  /// mistyped argument degrades to an error route instead of throwing, so a
  /// bad `pushNamed` can never crash the app.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homeRoute:
        return _page(const HomeScreen(), settings);

      case discoveryRoute:
        return _page(const DiscoveryScreen(), settings);

      case detailRoute:
        final args = settings.arguments;
        if (args is ArtifactDetailArgs) {
          return _page(ArtifactDetailScreen(args: args), settings);
        }
        return _error(
          settings,
          'Route "$detailRoute" requires an ArtifactDetailArgs argument '
          '(received: ${args.runtimeType}).',
        );

      default:
        return _error(settings, 'Unknown route: "${settings.name}".');
    }
  }

  /// Safety net for [MaterialApp.onUnknownRoute].
  static Route<dynamic> onUnknownRoute(RouteSettings settings) =>
      _error(settings, 'Unknown route: "${settings.name}".');

  // ── Builders ────────────────────────────────────────────────────────
  static MaterialPageRoute<dynamic> _page(
    Widget child,
    RouteSettings settings,
  ) =>
      MaterialPageRoute<dynamic>(builder: (_) => child, settings: settings);

  static MaterialPageRoute<dynamic> _error(
    RouteSettings settings,
    String message,
  ) =>
      MaterialPageRoute<dynamic>(
        builder: (_) => _RouteErrorScreen(message: message),
        settings: settings,
      );
}


/// Shown when [AppRouter.onGenerateRoute] receives an unknown name or a
/// malformed argument — visible failure instead of a silent crash.
class _RouteErrorScreen extends StatelessWidget {
  final String message;
  const _RouteErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: const Text('Routing error'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
