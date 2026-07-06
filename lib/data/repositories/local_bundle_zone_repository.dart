// Destination: lib/data/repositories/local_bundle_zone_repository.dart
//
// Real IZoneRepository: reads the active on-disk bundle instead of an embedded
// string. Same pre-warm/cache-first contract as MockZoneRepository — parse once
// in preWarm, then all reads are synchronous O(1) memory hits.
//
// Uses the SAME ManifestParser as the mock, so on-disk content is validated by
// exactly the code the tests cover. Path resolution goes through the active
// bundle dir and NEVER outside it (the parser already rejects '..'/absolute/
// scheme paths; resolving relative to activeDir is the second guard).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:beacon_client/data/repositories/bundle_layout.dart';
import 'package:beacon_client/data/repositories/manifest_parser.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';

/// Thrown by preWarm when there is NO usable bundle on the device yet (fresh
/// machine). The gate screen catches this (via lastError) and shows staff a
/// "content not synced" instruction rather than a broken tour.
class NoBundleException implements Exception {
  final String message;
  const NoBundleException(this.message);
  @override
  String toString() => 'NoBundleException: $message';
}

class LocalBundleZoneRepository implements IZoneRepository {
  LocalBundleZoneRepository(this._layout);

  final BundleLayout _layout;

  MuseumConfig? _config;
  List<ZoneInfo> _zones = const [];
  Map<int, ZoneInfo> _byMajor = const {};
  List<String> _warnings = const [];
  String? _lastError;
  bool _warmed = false;

  /// Absolute path of the active bundle dir once warmed — used to resolve
  /// asset paths to file URIs for the audio engine.
  Directory? _activeDir;

  @override
  Future<void> preWarm() async {
    if (_warmed) return;
    try {
      final dir = await _layout.activeDir();
      if (dir == null) {
        throw const NoBundleException('No active bundle on device');
      }
      final manifestFile = File(p.join(dir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw const NoBundleException('Active bundle missing manifest.json');
      }

      final raw = await manifestFile.readAsString();
      final parsed = ManifestParser.parse(
          jsonDecode(raw) as Map<String, dynamic>);

      _config = parsed.config;
      _zones = parsed.zones;
      _byMajor = Map.unmodifiable({for (final z in parsed.zones) z.major: z});
      _warnings = parsed.warnings;
      _activeDir = dir;
      _lastError = null;
      _warmed = true;

      if (kDebugMode) {
        debugPrint('[LocalBundleZoneRepository] warmed '
            '${parsed.zones.length} zones from ${dir.path}');
        for (final w in _warnings) {
          debugPrint('[LocalBundleZoneRepository] warning: $w');
        }
      }
    } on NoBundleException catch (e) {
      _lastError = e.message;
      if (kDebugMode) debugPrint('[LocalBundleZoneRepository] $e');
    } on BundleValidationException catch (e) {
      _lastError = e.message;
      if (kDebugMode) debugPrint('[LocalBundleZoneRepository] invalid: $e');
    } catch (e) {
      _lastError = 'Failed to read bundle: $e';
      if (kDebugMode) debugPrint('[LocalBundleZoneRepository] $e');
    }
  }

  @override
  bool get isWarmed => _warmed;

  @override
  String? get lastError => _lastError;

  @override
  List<String> get warnings => _warnings;

  @override
  MuseumConfig? get config => _config;

  @override
  ZoneInfo? zoneByMajor(int major) => _byMajor[major];

  @override
  List<ZoneInfo> get allZones => _zones;

  /// Resolve a bundle-relative asset path (from the manifest) to a file:// URI
  /// inside the active bundle. This is the AudioUriResolver the audio layer
  /// needs. Assumes [bundleRelativePath] already passed the parser's safety
  /// check (no '..', no scheme, no absolute path).
  Uri resolveAsset(String bundleRelativePath) {
    final dir = _activeDir;
    if (dir == null) {
      throw StateError('resolveAsset called before preWarm/without a bundle');
    }
    return Uri.file(p.join(dir.path, bundleRelativePath));
  }
}
