// Destination: lib/domain/interfaces/i_zone_repository.dart

import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';

/// Contract for zone-catalog access (successor of IArtifactRepository +
/// FloorRepository, zone-first model).
///
/// Same **pre-warm / cache-first** idiom the codebase already uses:
///   • [preWarm] performs the one-off (possibly slow) bundle load and fills
///     an in-memory cache. Idempotent — repeat calls are no-ops once warmed.
///   • Every other member is a pure synchronous memory read with NO I/O and
///     no `Future`, safe on every arbiter/UI emission.
///
/// Lesson carried over from the v1 review: [lastError] is part of the
/// CONTRACT this time, not an implementation detail nobody surfaces — the
/// gate screen must be able to show "Chưa sẵn sàng — cần đồng bộ" to staff
/// instead of silently degrading to unknown-artifact cards.
abstract interface class IZoneRepository {
  /// One-time bundle warm-up. Never throws: failures land in [lastError]
  /// and leave the repository un-warmed ([isWarmed] == false).
  Future<void> preWarm();

  /// True once a bundle has been parsed and cached successfully.
  bool get isWarmed;

  /// Parse/validation failure of the most recent [preWarm], null if none.
  /// Human-readable; the gate screen shows it to STAFF (not visitors).
  String? get lastError;

  /// Non-fatal parse warnings (skipped exhibits, clamped params...) from the
  /// most recent successful warm-up. Ops/debug surface only.
  List<String> get warnings;

  /// Bundle-level config. Null before a successful [preWarm].
  MuseumConfig? get config;

  /// O(1) lookup. Null for unknown major OR before warm-up.
  ZoneInfo? zoneByMajor(int major);

  /// All zones in manifest order. Empty before warm-up. Unmodifiable.
  List<ZoneInfo> get allZones;
}
