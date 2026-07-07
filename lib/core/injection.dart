// Destination: lib/core/injection.dart (REPLACES current)
//
// Composition root for the zone-first pipeline. Builds the whole dependency
// graph once, in order, and exposes the pieces the app shell needs. Everything
// flows down through constructors — no service-locator singletons leaking out.
//
// Mode switch:
//   • mock    — desktop/dev: scanner giả + nội dung mock. Không cần phần cứng.
//   • real    — on-device: scanner BLE thật + nội dung TỪ SERVER. Lúc khởi động
//               gọi syncIfNeeded() để kéo version.json + bundle-<ver>.tar.gz về,
//               verify sha256, giải nén, đổi con trỏ active — RỒI mới preWarm().
//               Offline-tolerant: server chết thì giữ bundle cũ (nếu có), hoặc
//               màn Gate báo "cần đồng bộ" (nếu máy trắng).
//   • bringUp — chạy thử phần cứng: scanner BLE thật + nội dung mock nhúng
//               (không cần server). Đổi lại `.real` khi đã có server.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/audio/audio_session_headphone_monitor.dart';
import 'package:beacon_client/data/audio/chime_player.dart';
import 'package:beacon_client/data/audio/just_audio_engine.dart';
import 'package:beacon_client/data/gateways/real_bluetooth_gate.dart';
import 'package:beacon_client/data/platform/battery_plus_power_monitor.dart';
import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/data/repositories/bundle_layout.dart';
import 'package:beacon_client/data/repositories/content_sync_service.dart';
import 'package:beacon_client/data/repositories/http_sync_transport.dart';
import 'package:beacon_client/data/repositories/local_bundle_zone_repository.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/data/scanners/mock_beacon_scanner.dart';
import 'package:beacon_client/data/scanners/real_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_headphone_monitor.dart';
import 'package:beacon_client/domain/interfaces/i_power_monitor.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/services/session_controller.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:beacon_client/services/tour_wiring.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

enum RunMode { mock, real, bringUp }

/// True khi mode dùng scanner BLE thật (cần quyền runtime + adapter bật).
bool _usesRealRadio(RunMode m) => m == RunMode.real || m == RunMode.bringUp;

/// True khi mode dùng nội dung mock nhúng (không cần server sync).
bool _usesMockContent(RunMode m) => m == RunMode.mock || m == RunMode.bringUp;

/// Holds the fully-wired graph after [Injection.build]. Owns disposal.
class AppGraph {
  final IZoneRepository repository;
  final ZonePresenceService presence;
  final TourAudioController audioController;
  final IAudioEngine audioEngine;
  final SessionController session;
  final ChimePlayer chime;
  final ContentSyncService? sync; // null in mock / bringUp mode

  /// Trạng thái cổng Bluetooth lúc khởi động (chỉ có nghĩa với radio thật).
  final StartupStatus? bluetoothStatus;

  /// Resolves a bundle-relative asset path (from the manifest) to an absolute
  /// file path for HeroImage, or null when it can't (mock/bringUp / no bundle).
  final String? Function(String bundleRelativePath) imagePathResolver;

  final ZoneEventRouter _router;
  final IPowerMonitor _power;
  final IHeadphoneMonitor _headphones;

  AppGraph._({
    required this.repository,
    required this.presence,
    required this.audioController,
    required this.audioEngine,
    required this.session,
    required this.chime,
    required this.sync,
    required this.bluetoothStatus,
    required this.imagePathResolver,
    required ZoneEventRouter router,
    required IPowerMonitor power,
    required IHeadphoneMonitor headphones,
  })  : _router = router,
        _power = power,
        _headphones = headphones;

  Future<void> dispose() async {
    await _router.dispose();
    await session.dispose();
    await presence.dispose();
    await audioController.dispose();
    await audioEngine.dispose();
    await _power.dispose();
    await _headphones.dispose();
    await chime.dispose();
  }
}

abstract final class Injection {
  static const RunMode mode = RunMode.real;

  /// Gốc server nội dung — KHÔNG kèm tên file, KHÔNG dấu '/' cuối.
  /// Client tự ghép "/version.json" và "/bundle-<ver>.tar.gz".
  /// ⚠️ ĐỔI thành IP máy chạy python http.server của bạn.
  static const String syncBaseUrl = 'http://192.168.1.8:8000';

  /// Builds and wires everything. Async because it (optionally) syncs, warms the
  /// bundle, and reads the documents dir. Safe to call once at startup.
  static Future<AppGraph> build() async {
    // ── repository (+ optional sync in real mode) ──
    final IZoneRepository repository;
    ContentSyncService? sync;

    if (_usesMockContent(mode)) {
      repository = MockZoneRepository(simulatedLatency: Duration.zero);
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final layout = BundleLayout(Directory(p.join(docs.path, 'bundles')));
      sync = ContentSyncService(
        layout: layout,
        transport: HttpSyncTransport(baseUrl: syncBaseUrl),
      );
      await sync.cleanupOnBoot(); // GC crash leftovers before reading

      // Kéo nội dung mới TRƯỚC khi đọc. syncIfNeeded không throw cho các lỗi
      // mong đợi (mạng/checksum/validate) — chúng nằm trong result.error.
      final result = await sync.syncIfNeeded(
        onProgress: kDebugMode
            ? (pr) => debugPrint('[Injection] sync ${(pr * 100).round()}%')
            : null,
      );
      if (kDebugMode) {
        debugPrint('[Injection] sync outcome=${result.outcome} '
            'version=${result.version} error=${result.error}');
      }

      repository = LocalBundleZoneRepository(layout);
    }

    await repository.preWarm(); // đọc bundle active; set lastError nếu chưa có
    final cfg = repository.config;

    // ── bluetooth gate (real radio only) ──
    StartupStatus? bluetoothStatus;
    if (_usesRealRadio(mode)) {
      final gate = RealBluetoothGate();
      bluetoothStatus = await gate.ensureReady();
      if (kDebugMode) debugPrint('[Injection] bluetooth gate: $bluetoothStatus');
      gate.dispose();
    }

    // ── radio pipeline ──
    final IBeaconScanner scanner = switch (mode) {
      RunMode.mock => MockBeaconScanner(),
      RunMode.real || RunMode.bringUp => RealBeaconScanner(),
    };
    final registry = BeaconTrackerRegistry();
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
      language: cfg?.fallbackLanguage ?? 'vi',
      onChime: chime.play,
    );

    // ── session ──
    final IPowerMonitor power = BatteryPlusPowerMonitor();
    await power.start();

    final presenceTicks = arbiter.presence.map((pz) => PresenceTick(
          deskStable: pz.deskStable,
          lastBeaconAt: pz.lastBeaconAt,
        ));

    final session = SessionController(
      zoneEvents: presence.events,
      chargingChanges: power.onChargingChanged,
      initialCharging: power.isCharging,
      presenceTicks: presenceTicks,
      audioSink: TourAudioSinkAdapter(audioController),
      sessionSilence:
          cfg?.arbitration.sessionSilence ?? const Duration(minutes: 30),
    );
    session.start();

    // ── wire zone events -> audio (only while touring) ──
    final router = ZoneEventRouter(
      events: presence.events,
      audio: audioController,
      isTouring: () => session.current.isTouring,
    );

    // Start the radio pipeline last, once everything downstream is listening.
    presence.start();

    // Image path resolver for the UI: real bundle -> absolute file path;
    // mock/bringUp/no-bundle -> null (HeroImage shows its gradient fallback).
    String? imagePathResolver(String bundleRelativePath) {
      if (repository is LocalBundleZoneRepository) {
        try {
          return (repository as LocalBundleZoneRepository)
              .resolveAsset(bundleRelativePath)
              .toFilePath();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return AppGraph._(
      repository: repository,
      presence: presence,
      audioController: audioController,
      audioEngine: engine,
      session: session,
      chime: chime,
      sync: sync,
      bluetoothStatus: bluetoothStatus,
      imagePathResolver: imagePathResolver,
      router: router,
      power: power,
      headphones: headphones,
    );
  }

  static AudioUriResolver _uriResolver(IZoneRepository repo) {
    if (repo is LocalBundleZoneRepository) {
      return repo.resolveAsset;
    }
    return (path) => Uri.parse('asset:///$path');
  }
}