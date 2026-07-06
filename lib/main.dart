// Destination: lib/main.dart (REPLACES current)
//
// Async bootstrap: build the whole graph in order, showing a minimal splash
// while it warms, then hand the wired services to the app via providers. If the
// bundle is missing (fresh device) the graph still builds — the Gate screen
// reads repository.lastError and shows staff a "needs sync" state.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/presentation/app/app.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

/// Runs Injection.build() once and swaps the splash for the app when ready.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<AppGraph> _future = Injection.build();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppGraph>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _SplashApp();
        }
        if (snap.hasError) {
          return _ErrorApp(message: '${snap.error}');
        }
        final graph = snap.data!;
        return MultiProvider(
          providers: [
            Provider<AppGraph>.value(value: graph),
            ChangeNotifierProvider(
                create: (_) => SessionProvider(graph.session)),
            ChangeNotifierProvider(
                create: (_) => ZoneProvider(graph.presence)),
            ChangeNotifierProvider(
                create: (_) => AudioProvider(
                      engine: graph.audioEngine,
                      controller: graph.audioController,
                    )),
          ],
          child: const MuseumApp(),
        );
      },
    );
  }
}

/// Minimal dark splash shown during bootstrap.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown if bootstrap itself throws (not for a missing bundle — that path still
/// builds the app and surfaces via the Gate).
class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Không khởi động được ứng dụng.\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}