// Destination: lib/core/injection.dart (REPLACES current)
//
// Composition root for the zone-first pipeline. Builds the whole dependency
// graph once, in order, and exposes the pieces the app shell needs. Everything
// flows down through constructors — no service-locator singletons leaking out.
//
// Graph (bottom to top):
//   scanner ─┐
//            ├─> registry ─> arbiter ─> ZonePresenceService ─┬─> ZoneEvents
//   (uuid) ──┘                                               │
//   repository(bundle) ─> TourAudioController <── engine,headphones, uriResolver
//   power ─> SessionController <── zoneEvents, presenceTicks, TourAudioSink
//
// Mode switch (mock vs real) mirrors the old injection: mock for desktop/dev,
// real for on-device.

import 'dart:io';

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
import 'package:beacon_client/data/repositories/http_sync_transport.dart';
import 'package:beacon_client/data/repositories/local_bundle_zone_repository.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/data/scanners/mock_beacon_scanner.dart';
import 'package:beacon_client/data/scanners/real_beacon_scanner.dart';
import 'package:beacon_client/data/gateways/mock_bluetooth_gate.dart';
import 'package:beacon_client/data/gateways/real_bluetooth_gate.dart';
import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_bluetooth_gate.dart';
import 'package:beacon_client/domain/interfaces/i_headphone_monitor.dart';
import 'package:beacon_client/domain/interfaces/i_power_monitor.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/services/session_controller.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:beacon_client/services/tour_wiring.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

enum RunMode { mock, real }

/// Holds the fully-wired graph after [Injection.build]. Owns disposal.
class AppGraph {
  final IZoneRepository repository;
  final ZonePresenceService presence;
  final TourAudioController audioController;
  final IAudioEngine audioEngine;
  final SessionController session;
  final ChimePlayer chime;
  final ContentSyncService? sync; // null in mock mode

  /// Bluetooth readiness gate (permission + adapter). The Gate screen shows
  /// its status and lets staff retry / open settings.
  final IBluetoothGate bluetoothGate;

  /// Result of the boot-time BLE readiness check. If not [StartupStatus.ready],
  /// the radio pipeline was NOT started and the UI should surface the reason.
  final StartupStatus startupStatus;

  /// Resolves a bundle-relative asset path (from the manifest) to an absolute
  /// file path for HeroImage, or null when it can't (mock mode / no bundle).
  /// UI uses this instead of guessing the repository's concrete type.
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
    required this.bluetoothGate,
    required this.startupStatus,
    required this.imagePathResolver,
    required ZoneEventRouter router,
    required IPowerMonitor power,
    required IHeadphoneMonitor headphones,
  })  : _router = router,
        _power = power,
        _headphones = headphones;

  /// Runs a content sync if in real mode (no-op in mock). Safe to call from the
  /// Gate (atDesk/gate only — never mid-tour). Returns null in mock mode.
  Future<SyncResult?> runSync({void Function(double)? onProgress}) async {
    final s = sync;
    if (s == null) return null;
    return s.syncIfNeeded(onProgress: onProgress);
  }

  Future<void> dispose() async {
    await _router.dispose();
    await session.dispose();
    await presence.dispose();
    await audioController.dispose();
    await audioEngine.dispose();
    await _power.dispose();
    await _headphones.dispose();
    await chime.dispose();
    bluetoothGate.dispose();
  }
}

abstract final class Injection {
  static const RunMode mode = RunMode.real;

  /// Internal content server base (Phase-0: general protocol; adapt when the
  /// real server lands). TODO(config): move to --dart-define.
  static const String syncBaseUrl = 'http://192.168.1.8:8000';

  /// Builds and wires everything. Async because it warms the bundle and reads
  /// the dock/documents dir. Safe to call once at startup.
  static Future<AppGraph> build() async {
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
          transport: HttpSyncTransport(baseUrl: syncBaseUrl),
        );
        await sync.cleanupOnBoot(); // GC crash leftovers before reading
        repository = LocalBundleZoneRepository(layout);
        break;
    }

    await repository.preWarm(); // may set lastError (fresh device) — Gate shows it
    final cfg = repository.config;

    // ── radio pipeline ──
    final IBeaconScanner scanner = switch (mode) {
      RunMode.mock => MockBeaconScanner(),
      RunMode.real => RealBeaconScanner(),
    };
    final IBluetoothGate bluetoothGate = switch (mode) {
      RunMode.mock => MockBluetoothGate(),
      RunMode.real => RealBluetoothGate(),
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

    // The session needs presence ticks (deskStable + lastBeaconAt). Derive a
    // PresenceTick stream from the arbiter's presence stream.
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

    // BLE readiness gate: request permissions + check adapter BEFORE starting
    // the radio pipeline. If not ready, the pipeline stays stopped and the Gate
    // screen surfaces startupStatus so staff can grant permission / enable BT.
    final startupStatus = await bluetoothGate.ensureReady();

    // Start the radio pipeline last, and ONLY if BLE is ready.
    if (startupStatus == StartupStatus.ready) {
      presence.start();
    }

    // Image path resolver for the UI: real bundle -> absolute file path;
    // mock/no-bundle -> null (HeroImage shows its gradient fallback).
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
      bluetoothGate: bluetoothGate,
      startupStatus: startupStatus,
      imagePathResolver: imagePathResolver,
      router: router,
      power: power,
      headphones: headphones,
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