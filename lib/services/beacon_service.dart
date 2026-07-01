// FILE: /lib/services/beacon_service.dart

  // MARK: - 1. IMPORTS & DEPENDENCIES (Khai báo thư viện)
  // ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/core/constants.dart';
import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/data/repositories/floor_repository.dart';
import 'package:beacon_client/domain/interfaces/i_artifact_repository.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/active_beacon.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/proximity_info.dart';

/// Thin orchestrator for the proximity pipeline (Phase 3 — Leaderboard).
///
/// Delegates everything heavy: per-beacon smoothing/FSM → [BeaconTracker],
/// population lifecycle + temporal sweep + emission-gating → [BeaconTrackerRegistry].
/// This class only: filters by museum UUID, routes packets (O(1)), and enriches
/// the registry's repo-free leaderboard into a [ProximityInfo] list.
///
/// Phase 6 — artifact enrichment now flows through [IArtifactRepository] under a
/// **pre-warm / cache-first** contract: [initialize] warms the catalog ONCE
/// before scanning, and [_onLeaderboard] enriches with synchronous O(1) cache
/// reads only. The hot path never `await`s, preserving the registry's atomicity
/// invariant (no await across a map mutation). Network latency is absorbed up
/// front by the warm-up, not on the per-emission path.
///
/// Emits a **sorted leaderboard (closest first)** of in-range museum beacons.
class BeaconService {
  // MARK: - 2. STATE VARIABLES (Biến trạng thái & Công cụ)
  // ============================================================================
  final IBeaconScanner _scanner;
  final BeaconTrackerRegistry _registry;
  final IArtifactRepository _artifactRepository;

  final _controller = StreamController<List<ProximityInfo>>.broadcast();
  StreamSubscription<BeaconReading>? _readingSub;
  StreamSubscription<List<ActiveBeacon>>? _boardSub;
  bool _running = false;

  // MARK: - 3. CONSTRUCTOR & GETTERS (Khởi tạo & Cổng giao tiếp)
  // ============================================================================
  BeaconService({
    required IBeaconScanner scanner,
    required IArtifactRepository artifactRepository,
    BeaconTrackerRegistry? registry,
  })  : _scanner = scanner,
        _artifactRepository = artifactRepository,
        _registry = registry ?? BeaconTrackerRegistry();

  /// Sorted leaderboard (nearest first). Empty list ⇒ nothing in range.
  Stream<List<ProximityInfo>> get proximityStream => _controller.stream;

  // MARK: - 4. LIFECYCLE (Vòng đời hệ thống)
  // ============================================================================
  /// Async BOOT entry — call this from `ProximityProvider.initialize()` (and
  /// `await` it) IN PLACE OF the old direct `start()` call.
  ///
  /// Cache-first: warms the artifact catalog ([IArtifactRepository.preWarm],
  /// idempotent) BEFORE the BLE pipeline starts, so the first enriched
  /// leaderboard already carries metadata. Until the warm completes,
  /// getCachedArtifact returns null and entries degrade gracefully (name falls
  /// back at the UI). Idempotent across a stop→initialize cycle: preWarm
  /// short-circuits and the pipeline simply re-arms.
  Future<void> initialize() async {
    await _artifactRepository.preWarm();
    if (_controller.isClosed) return; // disposed during warm-up → bail
    start();
  }

  /// Start / RESUME the pipeline. Synchronous and idempotent; safe to call after
  /// [stop] to resume without re-fetching the (already cached) catalog. Boot
  /// goes through [initialize]; this exists for runtime pause/resume.
  void start() {
    if (_running) return;
    _running = true;

    // `??=` để không bao giờ ghi đè (rò rỉ) subscription đang sống.
    _readingSub ??=
        _scanner.readings.listen(_handleRawReading, onError: _onError);
    _boardSub ??= _registry.leaderboardStream.listen(_onLeaderboard);

    _registry.start();
    _scanner.startScan();
  }

  // MARK: - 5. RAW SIGNAL FILTERING (Lọc sóng thô)
  // ============================================================================
  /// UUID guard → route to registry hot path. O(1) per packet.
  void _handleRawReading(BeaconReading r) {
    if (kDebugMode) {
      debugPrint('[BeaconService] uuid=${r.uuid} major=${r.major} '
          'minor=${r.minor} measuredPower=${r.measuredPower} rssi=${r.rssi}');
    }

    // museumUUID vốn đã lowercase → bỏ .toLowerCase() ở vế hằng số (bớt 1 alloc).
    if (r.uuid.toLowerCase() != AppConstants.museumUUID) {
      if (kDebugMode) debugPrint('[BeaconService] UUID không khớp, bỏ qua');
      return; // guard clause
    }

    _registry.onReading(r); // HOT PATH
  }

  // MARK: - 6. ENRICHMENT & PUBLISH (Bồi đắp metadata & phát luồng)
  // ============================================================================
  /// Enrich each repo-free snapshot with floor + artifact, then publish. The
  /// registry already gated this to meaningful changes, so no extra gating.
  ///
  /// CRITICAL: every lookup here is synchronous O(1) — NO `await` is introduced
  /// in this mapping. The registry's atomicity (cooperative scheduling, no await
  /// across a map mutation) depends on this staying synchronous; all network
  /// cost is paid earlier, in [initialize]'s warm-up.
  void _onLeaderboard(List<ActiveBeacon> board) {
    if (_controller.isClosed) return;

    final enriched = [
      for (final b in board)
        ProximityInfo(
          reading: b.reading,
          smoothedDistance: b.smoothedDistance,
          zone: b.zone,
          floor: FloorRepository.getFloor(b.major),
          // Synchronous cache hit — null until preWarm completes, then enriched.
          artifact: _artifactRepository.getCachedArtifact(b.major, b.minor),
        ),
    ];

    _controller.add(List.unmodifiable(enriched));
  }

  // MARK: - 7. UTILITIES & ERROR HANDLING (Hỗ trợ tính toán & Báo lỗi)
  // ============================================================================
  /// FIX: không nuốt lỗi im lặng nữa — log lại để còn debug.
  void _onError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('[BeaconService] stream error: $error\n$stackTrace');
    }
    // TODO(prod): forward sang logging / crash-reporting service.
  }

  void stop() {
    _running = false;
    _readingSub?.cancel();
    _readingSub = null;
    _boardSub?.cancel();
    _boardSub = null;
    _registry.stop();
    _scanner.stopScan();
  }

  void dispose() {
    _running = false;
    _readingSub?.cancel();
    _readingSub = null;
    _boardSub?.cancel();
    _boardSub = null;
    _registry.dispose();
    _scanner.dispose();
    if (!_controller.isClosed) _controller.close();
  }
}