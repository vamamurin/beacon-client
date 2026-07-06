// Destination: test/content_sync_service_test.dart
// Run with: flutter test test/content_sync_service_test.dart
//
// Proves the atomic-swap guarantee on a REAL temp filesystem: a crash
// (transport throwing / bad checksum / invalid bundle) at any stage never
// destroys the active bundle. Builds real .tar.gz archives in-memory so the
// unpack path is exercised end to end.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:beacon_client/data/repositories/bundle_layout.dart';
import 'package:beacon_client/data/repositories/content_sync_service.dart';
import 'package:beacon_client/data/repositories/local_bundle_zone_repository.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';

/// Builds a minimal valid bundle tar.gz in memory from a manifest string.
List<int> buildBundleTarGz(String manifestJson) {
  final archive = Archive();
  final bytes = utf8.encode(manifestJson);
  archive.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
  final tar = TarEncoder().encodeBytes(archive);
  return GZipEncoder().encodeBytes(tar)!;
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// A manifest string for [version], structurally valid (reuses the mock's
/// content but swaps the bundleVersion).
String manifestFor(String version) {
  final map = jsonDecode(kMockManifestJson) as Map<String, dynamic>;
  map['bundleVersion'] = version;
  return jsonEncode(map);
}

/// Configurable fake transport: can serve good bytes, corrupt bytes (checksum
/// fail), throw (network loss), or serve an invalid bundle.
class FakeTransport implements SyncTransport {
  FakeTransport({
    required this.version,
    required this.archiveBytes,
    required this.advertisedSha,
    this.throwOnDownload = false,
    this.throwOnVersion = false,
  });

  String version;
  List<int> archiveBytes;
  String advertisedSha;
  bool throwOnDownload;
  bool throwOnVersion;

  @override
  Future<Map<String, dynamic>> fetchVersionInfo() async {
    if (throwOnVersion) throw const SocketExceptionLike();
    return {'bundleVersion': version, 'sha256': advertisedSha};
  }

  @override
  Future<void> downloadArchive(String version, File dest,
      {void Function(double)? onProgress}) async {
    if (throwOnDownload) throw const SocketExceptionLike();
    await dest.writeAsBytes(archiveBytes, flush: true);
    onProgress?.call(1.0);
  }
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}

void main() {
  late Directory tempRoot;
  late BundleLayout layout;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('bundle_test_');
    layout = BundleLayout(Directory(p.join(tempRoot.path, 'bundles')));
    await layout.ensureRoot();
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  /// Installs v1 as the active bundle directly (bypassing sync) so update
  /// tests start from a known-good state.
  Future<void> seedActive(String version) async {
    final dir = layout.versionDir(version);
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'manifest.json'))
        .writeAsString(manifestFor(version));
    await layout.setActive(version);
  }

  ContentSyncService serviceWith(FakeTransport t) =>
      ContentSyncService(layout: layout, transport: t);

  group('happy path', () {
    test('fresh device installs v1 and commits active pointer', () async {
      final bytes = buildBundleTarGz(manifestFor('v1'));
      final t = FakeTransport(
          version: 'v1', archiveBytes: bytes, advertisedSha: sha256Hex(bytes));

      final r = await serviceWith(t).syncIfNeeded();
      expect(r.outcome, SyncOutcome.updated);
      expect(await layout.activeVersion(), 'v1');

      // Repository can now warm from disk.
      final repo = LocalBundleZoneRepository(layout);
      await repo.preWarm();
      expect(repo.isWarmed, isTrue);
      expect(repo.config!.bundleVersion, 'v1');
      expect(repo.allZones, isNotEmpty);
    });

    test('already up-to-date does nothing', () async {
      await seedActive('v1');
      final bytes = buildBundleTarGz(manifestFor('v1'));
      final t = FakeTransport(
          version: 'v1', archiveBytes: bytes, advertisedSha: sha256Hex(bytes));

      final r = await serviceWith(t).syncIfNeeded();
      expect(r.outcome, SyncOutcome.upToDate);
    });

    test('v1 -> v2 update swaps active and deletes v1 (single-copy)', () async {
      await seedActive('v1');
      final bytes = buildBundleTarGz(manifestFor('v2'));
      final t = FakeTransport(
          version: 'v2', archiveBytes: bytes, advertisedSha: sha256Hex(bytes));

      final r = await serviceWith(t).syncIfNeeded();
      expect(r.outcome, SyncOutcome.updated);
      expect(await layout.activeVersion(), 'v2');
      // Single-copy policy: v1 dir removed.
      expect(await layout.versionDir('v1').exists(), isFalse);
    });
  });

  group('crash safety — active bundle survives every failure', () {
    test('network loss during download keeps v1 active', () async {
      await seedActive('v1');
      final t = FakeTransport(
        version: 'v2',
        archiveBytes: const [],
        advertisedSha: 'whatever',
        throwOnDownload: true,
      );
      final r = await serviceWith(t).syncIfNeeded();
      expect(r.outcome, SyncOutcome.failed);
      expect(await layout.activeVersion(), 'v1'); // untouched
    });

    test('checksum mismatch discards download, keeps v1', () async {
      await seedActive('v1');
      final bytes = buildBundleTarGz(manifestFor('v2'));
      final t = FakeTransport(
        version: 'v2',
        archiveBytes: bytes,
        advertisedSha: 'deadbeef', // wrong on purpose
      );
      final r = await serviceWith(t).syncIfNeeded();
      expect(r.outcome, SyncOutcome.failed);
      expect(r.error, contains('sha256'));
      expect(await layout.activeVersion(), 'v1');
      // No half-written v2 dir left behind.
      expect(await layout.versionDir('v2').exists(), isFalse);
    });

    test('invalid bundle (bad manifest) discarded, keeps v1', () async {
      await seedActive('v1');
      final badBytes = buildBundleTarGz('{ this is not valid json }');
      final t = FakeTransport(
        version: 'v2',
        archiveBytes: badBytes,
        advertisedSha: sha256Hex(badBytes),
      );
      final r = await serviceWith(t).syncIfNeeded();
      expect(r.outcome, SyncOutcome.failed);
      expect(await layout.activeVersion(), 'v1');
      expect(await layout.tempDir('v2').exists(), isFalse); // tmp cleaned
    });

    test('version.json unreachable reports noConnectivity, keeps v1', () async {
      await seedActive('v1');
      final t = FakeTransport(
        version: 'v2',
        archiveBytes: const [],
        advertisedSha: 'x',
        throwOnVersion: true,
      );
      final r = await serviceWith(t).syncIfNeeded();
      expect(r.outcome, SyncOutcome.noConnectivity);
      expect(await layout.activeVersion(), 'v1');
    });
  });

  group('boot GC', () {
    test('removes stray .tmp and .part and non-active version dirs', () async {
      await seedActive('v1');
      // Simulate crash leftovers.
      await layout.tempDir('v2').create(recursive: true);
      await layout.archiveTempFile('v3').writeAsString('partial');
      await layout.versionDir('v9').create(recursive: true); // orphan version

      await serviceWith(FakeTransport(
        version: 'v1',
        archiveBytes: const [],
        advertisedSha: 'x',
      )).cleanupOnBoot();

      expect(await layout.tempDir('v2').exists(), isFalse);
      expect(await layout.archiveTempFile('v3').exists(), isFalse);
      expect(await layout.versionDir('v9').exists(), isFalse);
      expect(await layout.activeVersion(), 'v1'); // active preserved
    });
  });

  group('fresh device', () {
    test('repository preWarm throws-to-lastError when no bundle', () async {
      final repo = LocalBundleZoneRepository(layout);
      await repo.preWarm();
      expect(repo.isWarmed, isFalse);
      expect(repo.lastError, isNotNull); // gate screen shows "needs sync"
    });
  });
}
