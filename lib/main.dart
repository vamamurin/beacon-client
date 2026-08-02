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
//
// ─────────────────────────────────────────────────────────────────────────────
// FEATURE A — CHẠY NGẦM: audio_service được init ĐÚNG MỘT LẦN ở đây (không thể
// init lại) và trả về MuseumAudioHandler — foreground service duy nhất giữ
// process sống khi màn hình tắt. Handler được [bind] lại vào engine/controller/
// session của MỖI graph khi boot (kể cả sau AppRestarter), y khuôn bindRunSync.
// Metadata cho notification/lock-screen được dựng tại ĐÂY (nơi biết repository
// + ngôn ngữ), giữ handler ở data/audio khỏi phụ thuộc repository.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:beacon_client/data/audio/museum_audio_handler.dart';
import 'package:beacon_client/data/settings/prefs_settings_store.dart';
import 'package:beacon_client/domain/interfaces/i_keep_alive.dart';
import 'package:beacon_client/domain/interfaces/i_settings_store.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
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
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/providers/language_controller.dart';
import 'package:beacon_client/presentation/providers/pending_zone_change_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Đọc preference TRƯỚC runApp: vài mili giây, đổi lại không có cú nháy từ
  // dark sang light ở frame đầu tiên.
  final settings = await PrefsSettingsStore.create();

  // FEATURE A — dựng foreground service audio MỘT LẦN cho cả vòng đời tiến
  // trình. Handler chưa có engine/controller lúc này; nó tự báo idle cho tới
  // khi graph boot và gọi bind().
  //
  // MẤU CHỐT chạy ngầm: `androidStopForegroundOnPause: false` — FGS DUY TRÌ khi
  // tạm dừng (khách đi giữa hai hiện vật, chưa có tiếng) nên process không bị
  // Doze đóng băng → BLE + timer 1 Hz sống suốt tour.
  //
  // PHÒNG THỦ QUAN TRỌNG: `AudioService.init` được bọc try/catch + timeout và
  // handler là NULLABLE. Nếu init treo hoặc ném (cấu hình service/máy lạ),
  // app + BLE VẪN chạy bình thường — audio_service KHÔNG được phép chặn hay
  // giết phần lõi.
  //
  MuseumAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => MuseumAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.museum.beacon_client.audio',
        androidNotificationChannelName: 'Thuyết minh tham quan',
        androidStopForegroundOnPause: false, // <-- FGS sống khi pause
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationClickStartsActivity: true,
      ),
    ).timeout(const Duration(seconds: 8));
    debugPrint('[AudioService] init OK');
  } catch (e, st) {
    // Init hỏng/treo → chạy KHÔNG có audio nền + lock-screen (mất tính năng
    // Feature A), nhưng app + BLE + audio foreground VẪN hoạt động.
    audioHandler = null;
    debugPrint('[AudioService] init FAILED (app vẫn chạy, không có FGS): $e\n$st');
  }

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
      child: _BootstrapHost(settings: settings, audioHandler: audioHandler),
    ),
  );
}

/// Dựng metadata cho notification/lock-screen từ trạng thái audio hiện tại.
/// Sống ở main.dart (chứ không trong handler) để giữ handler khỏi phụ thuộc
/// repository/ngôn ngữ.
///
/// FEATURE B (đã nối): `lang` đọc THẲNG từ LanguageController mỗi lần resolve,
/// nên tiêu đề trên màn khóa/notification khớp ngôn ngữ khách đang chọn (không
/// còn khóa cứng về fallback). Đọc trong closure (không cache) để lần phát kế
/// sau khi đổi ngôn ngữ tự dùng mã mới; fallback vẫn là lưới an toàn của resolve.
MediaMetadataResolver _makeMediaResolver(AppGraph graph) {
  final repo = graph.repository;
  return (AudioQueueState s) {
    final cfg = repo.config;
    final fallback = cfg?.fallbackLanguage ?? 'vi';
    final lang = graph.languageController.code; // <-- FEATURE B: live
    final album =
        cfg?.museumName.resolve(lang, fallback) ?? 'Bảo tàng';

    final AudioTrackRef? ref = s.current;
    if (ref == null) {
      return MediaItem(id: 'idle', title: album, album: album);
    }

    final zone = repo.zoneByMajor(ref.zoneMajor);
    String title;
    if (ref.exhibitMinor != null) {
      final ex = zone?.exhibitByMinor(ref.exhibitMinor!);
      title = ex?.name.resolve(lang, fallback) ??
          zone?.name.resolve(lang, fallback) ??
          album;
    } else {
      title = zone?.name.resolve(lang, fallback) ?? album;
    }

    return MediaItem(
      id: '${ref.zoneMajor}-${ref.exhibitMinor}-${ref.clipKind.name}',
      title: title,
      album: album,
      duration: s.duration,
    );
  };
}

/// Owns the graph lifecycle. Runs Injection.build(), swaps the splash for the
/// app when ready, and can rebuild the whole graph on request (restart).
class _BootstrapHost extends StatefulWidget {
  const _BootstrapHost({required this.settings, required this.audioHandler});
  final ISettingsStore settings;
  final MuseumAudioHandler? audioHandler;

  @override
  State<_BootstrapHost> createState() => _BootstrapHostState();
}

class _BootstrapHostState extends State<_BootstrapHost> with WidgetsBindingObserver {
  /// Nguồn sự thật "app đang ở tiền cảnh (màn bật) hay không". Cấp tiến trình —
  /// cùng tầng settings/audioHandler — nên vượt qua AppRestarter: mỗi graph mới
  /// nhận đúng notifier này. Khai báo TRƯỚC _future vì _boot() đọc nó.
  final ValueNotifier<bool> _foreground = ValueNotifier<bool>(true);
  /// Bumping this remounts the FutureBuilder subtree (fresh MaterialApp +
  /// Navigator), giving a clean UI restart.
  int _generation = 0;

  late Future<AppGraph> _future = _boot();

  /// The graph from the most recent successful build — kept so it can be
  /// disposed when we rebuild (Provider.value doesn't own disposal).
  AppGraph? _built;

  /// Graph mà audioHandler đã bind vào — để builder (chạy mỗi rebuild) chỉ
  /// bind LẠI khi graph THỰC SỰ đổi (boot mới), không bind lặp mỗi frame.
  AppGraph? _boundGraph;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foreground.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resumed = màn bật, người dùng bấm được banner. Mọi trạng thái khác coi
    // như nền → ZoneChangeCoordinator chuyển-zone tức thì.
    _foreground.value = state == AppLifecycleState.resumed;

    // Analytics buffer nằm trong RAM cho tới khi flush. Từ `paused` trở đi,
    // Activity có thể bị huỷ bất cứ lúc nào — và khi khách vuốt tắt ở đa nhiệm,
    // MainActivity.onDestroy giết thẳng tiến trình mà KHÔNG kịp gọi xuống Dart
    // (engine đang bị gỡ ở đúng thời điểm đó). Đây là điểm cuối cùng còn chắc
    // chắn chạy được, nên phải persist ở đây thay vì tin vào teardown.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_built?.analytics.flush() ?? Future<void>.value());
    }
  }

  Future<AppGraph> _boot() async {
    final g = await Injection.build(settings: widget.settings, isForeground: _foreground,);
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

  /// Bind audioHandler vào graph nếu đây là graph mới. An toàn gọi trong
  /// builder: guard `_boundGraph` khiến nó là no-op ở các rebuild không đổi
  /// graph. No-op nếu audioHandler null (audio_service bị tắt/hỏng init).
  void _bindAudioIfNeeded(AppGraph graph) {
    final handler = widget.audioHandler;
    if (handler == null) return;
    if (identical(_boundGraph, graph)) return;
    _boundGraph = graph;
    handler.bind(
      engine: graph.audioEngine,
      controller: graph.audioController,
      metadata: _makeMediaResolver(graph),
      sessionState: graph.session.state,
      // Vuốt tắt ở màn đa nhiệm ⇒ tắt HẲN app, không chỉ tắt tiếng. Handler
      // sống ở tầng tiến trình nên phải được trỏ lại vào graph MỚI sau mỗi
      // AppRestarter, y như các subscription bên trên.
      shutdown: graph.shutdownCompletely,
      initialPhase: graph.session.current.phase,
    );
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
        // D — bind the manual "Đồng bộ ngay" action to this graph's sync path.
        // SettingsProvider lives above _BootstrapHost (survives restart), so we
        // rebind on each successful boot. read() is safe here: the provider is
        // an ancestor of this FutureBuilder.
        context.read<SettingsProvider>().bindRunSync(() => graph.runSync());

        // FEATURE A — gắn foreground-audio handler vào graph này (một lần/boot).
        _bindAudioIfNeeded(graph);

        return MultiProvider(
          providers: [
            // `create:` chứ không `.value(...)`: FutureBuilder.builder chạy lại
            // mỗi rebuild, và Provider.value không sở hữu giá trị — nó sẽ dựng
            // lại object mỗi frame và đánh dirty mọi widget đang đọc nó.
            // `create` chạy đúng một lần cho vòng đời của element này.
            Provider<AppRestarter>(create: (_) => AppRestarter(_restart)),

            // Màn Cài đặt (nhân viên) đọc cái này để hiện trạng thái miễn tối
            // ưu hoá pin — bước thiết lập một lần mỗi máy lúc bàn giao.
            Provider<IKeepAlive>.value(value: graph.keepAlive),

            ChangeNotifierProvider<LanguageController>.value(
              value: graph.languageController,
            ),
            ChangeNotifierProvider<ContentProvider>(
              create: (_) => ContentProvider(
                repository: graph.repository,
                imagePathResolver: graph.imagePathResolver,
                language: graph.languageController, // <-- Feature B
              ),
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