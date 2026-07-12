// Destination: lib/main.dart (REPLACES current)
//
// Async bootstrap host: builds the whole graph in order, showing a minimal
// splash while it warms, then hands the wired services to the app via
// providers. If the bundle is missing (fresh device) the graph still builds —
// the Gate reads repository.lastError and shows staff a "needs sync" state.
//
// The host also owns a full in-app RESTART: after a fresh-device content sync,
// the pipeline must be rebuilt to pick up the just-synced config (beacon UUID,
// arbiter params, language) that were absent at first boot. Instead of asking
// the user to kill and reopen the app, the Gate's sync notice calls
// AppRestarter -> _restart(), which disposes the current graph and re-runs
// Injection.build().

import 'package:beacon_client/data/settings/prefs_settings_store.dart';
import 'package:beacon_client/domain/interfaces/i_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/presentation/app/app.dart';
import 'package:beacon_client/presentation/app/app_restarter.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/pending_zone_change_provider.dart';
import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/providers/exhibit_presence_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Đọc preference TRƯỚC runApp: vài mili giây, đổi lại không có cú nháy từ
  // dark sang light ở frame đầu tiên.
  final settings = await PrefsSettingsStore.create();

  runApp(
    MultiProvider(
      providers: [
        // .value ở đây LÀ ĐÚNG: `settings` là object đã tồn tại trước build,
        // không phải thứ provider tự dựng lại mỗi frame.
        Provider<ISettingsStore>.value(value: settings),

        // Nằm NGOÀI _BootstrapHost, nên AppRestarter (remount subtree) không
        // thổi bay lựa chọn theme. Theme là preference của THIẾT BỊ; graph là
        // state của pipeline. Cái trước phải sống lâu hơn cái sau.
        ChangeNotifierProvider(create: (_) => ThemeController(store: settings)),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider(store: settings)),
      ],
      child: const _BootstrapHost(),
    ),
  );
}

/// Owns the graph lifecycle. Runs Injection.build(), swaps the splash for the
/// app when ready, and can rebuild the whole graph on request (restart).
class _BootstrapHost extends StatefulWidget {
  const _BootstrapHost();

  @override
  State<_BootstrapHost> createState() => _BootstrapHostState();
}

class _BootstrapHostState extends State<_BootstrapHost> {
  /// Bumping this remounts the FutureBuilder subtree (fresh MaterialApp +
  /// Navigator), giving a clean UI restart.
  int _generation = 0;

  late Future<AppGraph> _future = _boot();

  /// The graph from the most recent successful build — kept so it can be
  /// disposed when we rebuild (Provider.value doesn't own disposal).
  AppGraph? _built;

  Future<AppGraph> _boot() async {
    final g = await Injection.build();
    _built = g;
    return g;
  }

  /// Full restart: dispose the current graph and rebuild from scratch. The old
  /// subtree is torn down by the generation bump this frame; the old graph is
  /// disposed post-frame, after its providers have already unsubscribed.
  Future<void> _restart() async {
    final old = _built;
    _built = null;
    setState(() {
      _generation++;
      _future = _boot();
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppGraph>(
      key: ValueKey(_generation),
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
            // `create:` chứ không `.value(...)`: FutureBuilder.builder chạy lại
            // mỗi rebuild, và Provider.value không sở hữu giá trị — nó sẽ dựng
            // lại object mỗi frame và đánh dirty mọi widget đang đọc nó.
            // `create` chạy đúng một lần cho vòng đời của element này.
            Provider<AppRestarter>(create: (_) => AppRestarter(_restart)),

            // ── nội dung: "hiển thị chữ nào, ảnh nào?" (màn 2, 3, 4)
            ChangeNotifierProvider<ContentProvider>(
              create: (_) => ContentProvider(
                repository: graph.repository,
                imagePathResolver: graph.imagePathResolver,
              ),
            ),

            // ── hiện diện beacon: "hiện vật nào đang nghe thấy?" (màn 3)
            Provider<ExhibitPresenceProvider>(
              create: (_) => ExhibitPresenceProvider(graph.exhibitPresence),
            ),

            // ── khởi động: "đã sẵn sàng bàn giao máy chưa?" (màn 1)
            Provider<StartupProvider>(
              create: (_) => StartupProvider(
                repository: graph.repository,
                bleStatus: graph.bleStatus,
                retryBluetooth: graph.retryBluetooth,
                refreshBluetoothOnResume: graph.refreshBluetoothOnResume,
                openBluetoothSettings: graph.bluetoothGate.openSettings,
                runSync: graph.runSync,
              ),
            ),

            ChangeNotifierProvider(create: (_) => SessionProvider(graph.session)),
            // C2: pending zone-change (drives the confirm banner over all screens)
            ChangeNotifierProvider(
              create: (_) => PendingZoneChangeProvider(graph.zoneChanges),
            ),
            ChangeNotifierProvider(
              create: (_) => ZoneProvider(
                status: graph.presence.status,
                initial: graph.presence.currentStatus,
                ranking: graph.nearbyZones.ranking,
                initialRanking: graph.nearbyZones.current,
                repository: graph.repository,
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => AudioProvider(
                engine: graph.audioEngine,
                controller: graph.audioController,
              ),
            ),
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: context.watch<ThemeController>().theme,
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: context.watch<ThemeController>().theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Không khởi động được ứng dụng.\n$message',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: context.tokens.inkMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}