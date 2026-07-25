// Destination: lib/core/injection.dart (REPLACES current)
//
// Composition root for the zone-first pipeline. Builds the whole dependency
// graph once, in order, and exposes the pieces the app shell needs. Everything
// flows down through constructors — no service-locator singletons leaking out.
//
// Graph (bottom to top):
//   scanner ─┐
//            ├─> registry ─> arbiter ─> ZonePresenceService ─┬─> ZoneEvents
//   (uuid) ──┘                                               ├─> ZoneStatus
//   repository(bundle) ─> TourAudioController <── engine,headphones, uriResolver│
//   power ─> SessionController <── zoneEvents, deskStable(stream),              │
//                                   lastBeaconAt(poll), TourAudioSink           │
//
// Mode switch (mock vs real) mirrors the old injection: mock for desktop/dev,
// real for on-device.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:beacon_client/data/audio/audio_session_headphone_monitor.dart';
import 'package:beacon_client/data/audio/chime_player.dart';
import 'package:beacon_client/data/audio/just_audio_engine.dart';
import 'package:beacon_client/data/platform/battery_plus_power_monitor.dart';
import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/data/repositories/bundle_layout.dart';
import 'package:beacon_client/data/repositories/content_sync_service.dart';
import 'package:beacon_client/data/repositories/sync_config.dart';
import 'package:beacon_client/domain/interfaces/i_settings_store.dart';
import 'package:beacon_client/services/auto_sync_scheduler.dart';
import 'package:beacon_client/data/repositories/http_sync_transport.dart';
import 'package:beacon_client/data/repositories/local_bundle_zone_repository.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/data/scanners/mock_beacon_scanner.dart';
import 'package:beacon_client/data/scanners/real_beacon_scanner.dart';
import 'package:beacon_client/data/gateways/mock_bluetooth_gate.dart';
import 'package:beacon_client/data/gateways/real_bluetooth_gate.dart';
import 'package:beacon_client/data/platform/foreground_task_keep_alive.dart';
import 'package:beacon_client/domain/interfaces/i_keep_alive.dart';
import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_bluetooth_gate.dart';
import 'package:beacon_client/domain/interfaces/i_headphone_monitor.dart';
import 'package:beacon_client/domain/interfaces/i_power_monitor.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/nearby_zones_tracker.dart';
import 'package:beacon_client/services/session_controller.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:beacon_client/services/tour_wiring.dart';
import 'package:beacon_client/services/zone_change_coordinator.dart';
import 'package:beacon_client/services/zone_presence_service.dart';
import 'package:beacon_client/presentation/providers/language_controller.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/domain/interfaces/i_analytics_sink.dart';
import 'package:beacon_client/data/analytics/analytics_uploader.dart';
import 'package:beacon_client/data/analytics/buffering_analytics_sink.dart';
import 'package:beacon_client/data/analytics/noop_analytics_sink.dart';
import 'package:beacon_client/services/analytics_recorder.dart';

enum RunMode { mock, real }

/// Holds the fully-wired graph after [Injection.build]. Owns disposal.
class AppGraph {
  final IZoneRepository repository;
  final ZonePresenceService presence;
  final TourAudioController audioController;
  final IAudioEngine audioEngine;
  final SessionController session;
  final ChimePlayer chime;
  final LanguageController languageController;
  final ContentSyncService? sync; // null in mock mode

   /// Keep-alive foreground service — giữ tiến trình sống suốt tour để BLE +
  /// audio chạy được khi màn tắt, kể cả lúc standby chưa phát gì. No-op ở mock.
  final IKeepAlive keepAlive;

  /// C2 — deferred zone-change coordinator (owns the confirm banner state).
  final ZoneChangeCoordinator zoneChanges;

  /// Live "which exhibit minors are broadcasting right now, per zone", with
  /// anti-flicker hysteresis. Screen 3 reads this to show only nearby exhibits.

  /// C3 — display-tier zone ranking for screen 2 (nearest-first, hysteresis).
  final NearbyZonesTracker nearbyZones;

  /// D — docked auto-sync scheduler ("charging = sync"). Null in mock mode.
  final AutoSyncScheduler? autoSync;

  /// Bluetooth readiness gate (permission + adapter). The Gate screen shows
  /// its status and lets staff retry / open settings.
  final IBluetoothGate bluetoothGate;
  
  final IAnalyticsSink analytics;
  final AnalyticsRecorder analyticsRecorder;

  final StreamSubscription<SessionState>? _analyticsDockSub;
  
  /// Resolves a bundle-relative asset path (from the manifest) to an absolute
  /// file path for HeroImage, or null when it can't (mock mode / no bundle).
  /// UI uses this instead of guessing the repository's concrete type.
  final String? Function(String bundleRelativePath) imagePathResolver;

  /// Reactive BLE readiness. Unlike the old one-shot snapshot, this updates
  /// when the user grants permission / enables Bluetooth (via [retryBluetooth]
  /// or [refreshBluetoothOnResume]), so the Gate flips to the Start button
  /// WITHOUT an app restart. The Gate listens to this.
  final ValueNotifier<StartupStatus> _ble;

  ValueListenable<StartupStatus> get bleStatus => _ble;

  /// Current BLE readiness value (convenience; prefer listening to [bleStatus]).
  StartupStatus get startupStatus => _ble.value;

  final IPowerMonitor _power;
  final IHeadphoneMonitor _headphones;

  /// Re-announces the current zone to the audio layer on the gate->touring
  /// edge (see build()). Held only so it can be cancelled on dispose.
  final StreamSubscription<SessionState> _tourStartSub;

  AppGraph._({
    required this.repository,
    required this.presence,
    required this.audioController,
    required this.audioEngine,
    required this.session,
    required this.chime,
    required this.languageController,
    required this.sync,
    required this.keepAlive,
    required this.zoneChanges,
    required this.nearbyZones,
    required this.autoSync,
    required this.bluetoothGate,
    required this.analytics,
    required this.analyticsRecorder,
    required StartupStatus startupStatus,
    required this.imagePathResolver,
    required IPowerMonitor power,
    required IHeadphoneMonitor headphones,
    required StreamSubscription<SessionState> tourStartSub,
    required StreamSubscription<SessionState>? analyticsDockSub,
  })  : _ble = ValueNotifier<StartupStatus>(startupStatus),
        _power = power,
        _headphones = headphones,
        _tourStartSub = tourStartSub,
        _analyticsDockSub = analyticsDockSub;

  /// Runs a content sync if in real mode (no-op in mock). Safe to call from the
  /// Gate (atDesk/gate only — never mid-tour). Returns null in mock mode.
  Future<SyncResult?> runSync({void Function(double)? onProgress}) async {
    unawaited(analytics.drain());
    final s = sync;
    if (s == null) return null;
    return s.syncIfNeeded(onProgress: onProgress);
  }

  /// Explicit user retry ("Cấp quyền" / "Thử lại"): re-run the readiness check
  /// (this MAY prompt for permission), publish the new status, and start
  /// scanning if we just became ready. No app restart needed — the pipeline
  /// was built at boot; it only needed permission/adapter to start.
  Future<void> retryBluetooth() async {
    final status = await bluetoothGate.ensureReady();
    if (status == StartupStatus.ready) presence.start(); // idempotent
    _ble.value = status; // notifies the Gate
  }

  /// Called when the app returns to the foreground (e.g. back from Settings).
  /// PROMPT-SAFE: only re-derives readiness once permission is already granted,
  /// so we never re-pop the permission dialog on every resume. This is what
  /// makes "grant in Settings -> return to app" flip the Gate to ready.
  Future<void> refreshBluetoothOnResume() async {
    if (_ble.value == StartupStatus.ready) return; // already good
    final granted = await bluetoothGate.hasPermissions(); // no dialog
    if (!granted) return; // leave the current status/button; don't prompt
    final status = await bluetoothGate.ensureReady(); // won't prompt now
    if (status == StartupStatus.ready) presence.start();
    _ble.value = status;
  }

  Future<void> dispose() async {
    await keepAlive.stop();
    await _tourStartSub.cancel();
    await _analyticsDockSub?.cancel();
    await zoneChanges.dispose();
    await session.dispose();
    await presence.dispose();
    nearbyZones.dispose();
    languageController.dispose();
    await autoSync?.dispose();
    await audioController.dispose();
    await audioEngine.dispose();
    await _power.dispose();
    await _headphones.dispose();
    await chime.dispose();
    bluetoothGate.dispose();
    await analyticsRecorder.dispose();
    await analytics.dispose();
    _ble.dispose();
  }
}

abstract final class Injection {
  static const RunMode mode = RunMode.real;

  /// Internal content server base (Phase-0: general protocol; adapt when the
  /// real server lands). TODO(config): move to --dart-define.
  /// D — the hard-coded dev server is gone. URL now resolves at call time via
  /// SyncConfig (Settings override -> --dart-define=SYNC_BASE_URL -> fallback).

  /// Builds and wires everything. Async because it warms the bundle and reads
  /// the dock/documents dir. Safe to call once at startup (and again on a
  /// full restart — a fresh graph is returned each time).
  static Future<AppGraph> build({ISettingsStore? settings, required ValueListenable<bool> isForeground,}) async {
    // D — settings store may be null in mock mode / tests; fall back so URL
    // resolution still works off --dart-define + hard fallback.
    final ISettingsStore settingsStore = settings ?? _EphemeralSettings();

    // ── repository (+ optional sync in real mode) ──
    final IZoneRepository repository;
    ContentSyncService? sync;

    switch (mode) {
      case RunMode.mock:
        repository = MockZoneRepository(simulatedLatency: Duration.zero);
        break;
      case RunMode.real:
        final docs = await getApplicationDocumentsDirectory();
        final layout =
            BundleLayout(Directory(p.join(docs.path, 'bundles')));
        sync = ContentSyncService(
          layout: layout,
          // D — URL read at CALL TIME via SyncConfig (Settings override ->
          // --dart-define -> hard fallback). Changing it in Settings takes
          // effect next sync, no restart.
          transport: HttpSyncTransport(
            baseUrl: () => SyncConfig.baseUrl(settingsStore),
          ),
        );
        await sync.cleanupOnBoot(); // GC crash leftovers before reading
        repository = LocalBundleZoneRepository(layout);
        break;
    }

    await repository.preWarm(); // may set lastError (fresh device) — Gate shows it
    final cfg = repository.config;
    final languageController = LanguageController(
      available: cfg?.languages ?? const ['vi'],
      fallback: cfg?.fallbackLanguage ?? 'vi',
    );

    // ── radio pipeline ──
    final IBeaconScanner scanner = switch (mode) {
      RunMode.mock => MockBeaconScanner(),
      RunMode.real => RealBeaconScanner(),
    };
    final IBluetoothGate bluetoothGate = switch (mode) {
      RunMode.mock => MockBluetoothGate(),
      RunMode.real => RealBluetoothGate(),
    };
    final IKeepAlive keepAlive = switch (mode) {
      RunMode.mock => const NoopKeepAlive(),
      RunMode.real => ForegroundTaskKeepAlive(),
    };
    final registry = BeaconTrackerRegistry(
      kalmanProcessNoise: cfg?.arbitration.kalmanProcessNoise ?? 0.008,
      kalmanMeasurementNoise: cfg?.arbitration.kalmanMeasurementNoise ?? 4.0,
    );
    final arbiter = ZoneArbiter(
      deskMajor: cfg?.deskMajor ?? 99,
      params: cfg?.arbitration ?? ArbitrationParams.defaults(),
    );
    final presence = ZonePresenceService(
      scanner: scanner,
      repository: repository,
      museumUuidLower: (cfg?.beaconUuid ?? '').toLowerCase(),
      registry: registry,
      arbiter: arbiter,
    );

    // C3 — display-tier zone ranking. Same heartbeat source as the exhibit
    // tracker, but per-ZONE with distance ordering (C1). Uses the tuned
    // path-loss exponent so metres match the arbiter's engage/release gate.
    final nearbyZones = NearbyZonesTracker(
      signals: presence.signals,
      pathLossExponent: cfg?.arbitration.pathLossExponent ?? 2.5,
    );

    // ── audio ──
    final IAudioEngine engine = JustAudioEngine();
    final IHeadphoneMonitor headphones = AudioSessionHeadphoneMonitor();
    final chime = ChimePlayer();
    await JustAudioEngine.configureSpeechSession();
    await headphones.start();
    await chime.preload();

    final audioController = TourAudioController(
      repository: repository,
      engine: engine,
      headphones: headphones,
      uriResolver: _uriResolver(repository),
      language: () => languageController.code,

      onChime: chime.play,
    );

    // ── session ──
    final IPowerMonitor power = BatteryPlusPowerMonitor();
    await power.start();

    // P1-1: hai tín hiệu presence đi hai đường ĐÚNG BẢN CHẤT của chúng —
    //   • deskStable là tín hiệu dạng CẠNH → stream (derive từ status, distinct
    //     vì ZoneStatus change-gate trên cặp (zone, deskStable) nên deskStable
    //     đơn lẻ vẫn có thể lặp giá trị khi zone đổi).
    //   • lastBeaconAt là dữ liệu dạng POLL → callback; sweep 1 Hz của session
    //     tự đọc, không phụ thuộc việc presence có đổi giá trị hay không.
    final session = SessionController(
      zoneEvents: presence.events,
      chargingChanges: power.onChargingChanged,
      initialCharging: power.isCharging,
      deskStableChanges:
          presence.status.map((s) => s.deskStable).distinct(),
      lastBeaconAt: () => presence.lastBeaconAt,
      audioSink: TourAudioSinkAdapter(audioController),
      sessionSilence:
          cfg?.arbitration.sessionSilence ?? const Duration(minutes: 30),
    );
    session.start();

    // ── wire zone events -> audio via the deferred coordinator (C2) ──
    // Coordinator forwards EnteredZone/LeftToStandby immediately but DEFERS a
    // ChangedZone behind the confirm banner. Only active while touring.
    final zoneChanges = ZoneChangeCoordinator(
      events: presence.events,
      audio: audioController,
      repository: repository,
      isTouring: () => session.current.isTouring,
      isForeground: isForeground,
      // C2 — từ manifest (zoneChangeConfirmSeconds, clamp 1..30s ở parser),
      // lùi về 5s nếu bundle không khai báo.
      confirmWindow:
          cfg?.zoneChangeConfirmWindow ?? const Duration(seconds: 5),
    );

    // On the gate->touring edge, re-announce the current zone so a visitor who
    // is ALREADY inside a zone at Start still gets EnteredZone (intro + grace
    // close). The arbiter won't re-emit an unchanged presence on its own, so
    // without this the audio layer would stay dormant. At the desk the current
    // zone is null (desk major is arbitrated separately), so it's a no-op there
    // and the dock-linger grace is preserved. The coordinator (built above) is
    // already listening, and treats a replayed EnteredZone as an immediate
    // arrival (no banner), so the intro reaches the audio.
    SessionPhase lastPhase = session.current.phase;
    // Feature B — nhãn thông báo keep-alive resolve theo ngôn ngữ ĐANG chọn tại
    // thời điểm vào tour (composition root resolve, service ở data/platform vẫn
    // "mù" ngôn ngữ). Đọc languageController.code trong closure nên khách đổi
    // ngôn ngữ ở Gate là notification của tour này đã đúng.
    String kaText(String key) => resolveUi(cfg?.uiStrings,
        languageController.code, cfg?.fallbackLanguage ?? 'vi', key);
    final tourStartSub = session.state.listen((s) {
      final was = lastPhase;
      lastPhase = s.phase;
      if (was != SessionPhase.touring && s.phase == SessionPhase.touring) {
        // FIX P1 — đường radio về trắng TRƯỚC, rồi mới resync. Arbiter sống
        // suốt vòng đời app nên nếu không reset, "khu hiện tại" mà máy chốt
        // được trong lúc nằm ở dock sẽ trôi sang tour mới: khách bước vào khu
        // đầu tiên thì arbiter coi là TAKEOVER (ChangedZone → banner 5 giây)
        // thay vì ACQUISITION (EnteredZone → phát intro ngay).
        presence.resetForNewSession();
        presence.resyncCurrentZone();
        keepAlive.start(
          channelName: kaText(UiKeys.keepAliveChannelName),
          channelDescription: kaText(UiKeys.keepAliveChannelDesc),
          notificationTitle: kaText(UiKeys.keepAliveTitle),
          notificationText: kaText(UiKeys.keepAliveText),
        );
      } else if (was == SessionPhase.touring && s.phase != SessionPhase.touring) {
        keepAlive.stop(); // <-- THÊM: hết tour → hạ keep-alive (tiết kiệm pin ở dock)
        languageController.resetToFallback();
      }

      // FIX P1 — đọc lại tuyến nghe THẬT mỗi khi về màn Gate.
      //
      // `headphones.isConnected` là cờ chốt chỉ đổi theo sự kiện cạnh, và
      // becomingNoisy là tín hiệu một chiều không có sự kiện ngược. Một lần
      // bắn nhầm (hay gặp khi audio session bị gỡ lúc tour kết thúc) là cờ kẹt
      // false vĩnh viễn ⇒ _autoplayAllowed luôn false ⇒ autoplay chết mà bấm
      // tay vẫn phát. Ở Gate máy đang chờ khách bấm Bắt đầu nên có thừa thời
      // gian cho một lần đọc bất đồng bộ; đây là chỗ rẻ nhất để tự sửa.
      if (s.phase == SessionPhase.gate) {
        unawaited(headphones.refresh());
      }
    });

    // BLE readiness gate: request permissions + check adapter BEFORE starting
    // the radio pipeline. If not ready, the pipeline stays stopped and the Gate
    // screen surfaces the status so staff can grant permission / enable BT.
    final startupStatus = await bluetoothGate.ensureReady();

    // Start the radio pipeline last, and ONLY if BLE is ready. If it isn't, the
    // Gate can start it later via retryBluetooth/refreshBluetoothOnResume.
    if (startupStatus == StartupStatus.ready) {
      presence.start();
    }

    // Image path resolver for the UI: real bundle -> absolute file path;
    // mock/no-bundle -> null (HeroImage shows its gradient fallback).
    String? imagePathResolver(String bundleRelativePath) {
      if (repository is LocalBundleZoneRepository) {
        try {
          return repository.resolveAsset(bundleRelativePath).toFilePath();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // ── analytics sink (dựng sớm: cả autoSync lẫn runSync đều cần) ──
    final IAnalyticsSink analytics;
    switch (mode) {
      case RunMode.mock:
        analytics = const NoopAnalyticsSink();
        break;
      case RunMode.real:
        final docs = await getApplicationDocumentsDirectory();
        analytics = BufferingFileAnalyticsSink(
          dir: Directory(p.join(docs.path, 'analytics')),
          uploader: HttpAnalyticsUploader(
            baseUrl: () => SyncConfig.baseUrl(settingsStore),
          ),
        );
        break;
    }
    

    // D — docked auto-sync ("charging = sync"). Only when a real sync exists.
    // Reads threshold at decision time (Settings override -> manifest -> default)
    // and only fires while atDesk + charging, never mid-tour.
    AutoSyncScheduler? autoSync;
    if (sync != null) {
      final syncRef = sync;
      autoSync = AutoSyncScheduler(
        sessionState: session.state,
        chargingChanges: power.onChargingChanged,
        initialCharging: power.isCharging,
        settings: settingsStore,
        manifestAutoSyncHours: () => repository.config?.autoSyncHours,
        runSync: () async {
          // Chỉ lo content. Analytics drain nay đi đường riêng (xem analyticsDockSub)
          // vì nó KHÔNG được phụ thuộc vào isAutoSyncDue.
          return syncRef.syncIfNeeded();
        },
      );
      autoSync.kick(); // device may boot already docked
    }

    final analyticsRecorder = AnalyticsRecorder(
      sessionState: session.state,
      zoneEvents: presence.events,
      audioState: engine.onStateChanged,
      audioCompleted: engine.onCompleted,
      sink: analytics,
      languageCode: () => languageController.code,
      headphonesConnected: () => headphones.isConnected,
    );

    // Về dock = cửa sổ an toàn để đẩy analytics. LUÔN chạy, độc lập content sync.
    //
    // Nghe session.state (KHÔNG phải onChargingChanged): recorder subscribe trước
    // sub này nên nó đã emit TourEnded vào _pending khi ta chạy tới đây. Nghe
    // charging trực tiếp sẽ drain SỚM HƠN lúc TourEnded ra đời -> lỡ một chuyến.
    StreamSubscription<SessionState>? analyticsDockSub;
    if (mode == RunMode.real) {
      var lastAnalyticsPhase = session.current.phase;
      analyticsDockSub = session.state.listen((s) {
        final was = lastAnalyticsPhase;
        lastAnalyticsPhase = s.phase;
        if (was != SessionPhase.atDesk && s.phase == SessionPhase.atDesk) {
          unawaited(analytics.drain());
        }
      });
      // Boot khi đã cắm sẵn / còn tồn đọng từ phiên trước.
      if (session.current.phase == SessionPhase.atDesk && power.isCharging) {
        unawaited(analytics.drain());
      }
    }

    return AppGraph._(
      repository: repository,
      presence: presence,
      audioController: audioController,
      audioEngine: engine,
      session: session,
      chime: chime,
      languageController: languageController,
      sync: sync,
      keepAlive: keepAlive,
      zoneChanges: zoneChanges,
      nearbyZones: nearbyZones,
      autoSync: autoSync,
      bluetoothGate: bluetoothGate,
      analytics: analytics,
      analyticsRecorder: analyticsRecorder,
      startupStatus: startupStatus,
      imagePathResolver: imagePathResolver,
      power: power,
      headphones: headphones,
      tourStartSub: tourStartSub,
      analyticsDockSub: analyticsDockSub,
    );
  }

  /// Resolves bundle-relative asset paths to file URIs. For the real repo this
  /// goes through the active bundle dir; for mock it returns a dummy file URI
  /// (mock has no real audio files — dev uses placeholder assets).
  static AudioUriResolver _uriResolver(IZoneRepository repo) {
    if (repo is LocalBundleZoneRepository) {
      return repo.resolveAsset;
    }
    // Mock mode: paths won't resolve to real files; audio won't actually play
    // on desktop, which is fine for UI dev. Return a stable dummy URI.
    return (path) => Uri.parse('asset:///$path');
  }
}
/// D — in-memory ISettingsStore used only when build() is called without one
/// (mock mode / tests). Persists nothing; URL resolution then relies on
/// --dart-define + hard fallback, and auto-sync uses defaults.
class _EphemeralSettings implements ISettingsStore {
  String? _theme;
  bool _dist = false;
  String? _url;
  double? _hours;
  DateTime? _lastSync;

  @override
  String? get themeId => _theme;
  @override
  Future<void> setThemeId(String id) async => _theme = id;
  @override
  bool get showDistanceDebug => _dist;
  @override
  Future<void> setShowDistanceDebug(bool value) async => _dist = value;
  @override
  String? get syncBaseUrlOverride => _url;
  @override
  Future<void> setSyncBaseUrlOverride(String? value) async => _url = value;
  @override
  double? get autoSyncHoursOverride => _hours;
  @override
  Future<void> setAutoSyncHoursOverride(double? value) async => _hours = value;
  @override
  DateTime? get lastSuccessfulSyncAt => _lastSync;
  @override
  Future<void> setLastSuccessfulSyncAt(DateTime value) async =>
      _lastSync = value;
}