import 'package:beacon_client/domain/models/artifact_info.dart';

/// Contract for artifact-metadata access.
///
/// Designed around the **pre-warm / cache-first** model so the BLE emission
/// hot path can enrich synchronously:
///   • [preWarm] performs the one-off (possibly slow / networked) catalog load
///     and fills an in-memory cache. It is idempotent — repeat calls are
///     no-ops once warmed.
///   • [getCachedArtifact] is a pure O(1) memory read with NO I/O and NO
///     `Future`, safe to call on every leaderboard emission. It returns null
///     for an unknown key OR before [preWarm] has completed (graceful
///     degradation).
///
/// Mirrors the IBeaconScanner HAL idiom: a Mock / Local / Remote implementation
/// can be swapped via DI without touching any call site.
abstract interface class IArtifactRepository {
  /// One-time catalog warm-up. Populates the cache [getCachedArtifact] reads.
  Future<void> preWarm();

  /// Synchronous O(1) lookup by packed (major, minor). Null if unknown/unwarmed.
  ArtifactInfo? getCachedArtifact(int major, int minor);
}