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
  // `encodeBytes` return type differs across `archive` versions (nullable vs
  // non-nullable). Route through `dynamic` + List<int>.from so this compiles
  // cleanly on either without a version-specific lint (`!` unnecessary, or a
  // null-comparison-always-false).
  final dynamic gz = GZipEncoder().encodeBytes(tar);
  return List<int>.from(gz as List);
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
    // P1-2: GC now PRESERVES a recent .part so an interrupted download can
    // resume across an app restart. Only .tmp dirs and orphan version dirs are
    // always removed; a stale .part (older than the max-age) is still swept.
    test('removes stray .tmp and orphan version dirs, keeps a RECENT .part',
        () async {
      await seedActive('v1');
      await layout.tempDir('v2').create(recursive: true);
      await layout.archiveTempFile('v3').writeAsString('partial'); // fresh .part
      await layout.versionDir('v9').create(recursive: true); // orphan version

      await serviceWith(FakeTransport(
        version: 'v1',
        archiveBytes: const [],
        advertisedSha: 'x',
      )).cleanupOnBoot();

      expect(await layout.tempDir('v2').exists(), isFalse);
      expect(await layout.versionDir('v9').exists(), isFalse);
      expect(await layout.activeVersion(), 'v1'); // active preserved
      // The recent .part survives for resume — this is the P1-2 behaviour.
      expect(await layout.archiveTempFile('v3').exists(), isTrue);
    });

    test('sweeps a STALE .part (older than the max-age)', () async {
      await seedActive('v1');
      final stale = layout.archiveTempFile('v4');
      await stale.writeAsString('old partial');
      // Backdate well beyond the 7-day retention so GC treats it as abandoned.
      await stale.setLastModified(
          DateTime.now().subtract(const Duration(days: 30)));

      await serviceWith(FakeTransport(
        version: 'v1',
        archiveBytes: const [],
        advertisedSha: 'x',
      )).cleanupOnBoot();

      expect(await stale.exists(), isFalse); // abandoned -> removed
      expect(await layout.activeVersion(), 'v1');
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

  // ─────────────────────────────────────────────────────────────────────────
  // The server names the version, and that name becomes a PATH. These prove
  // the name is checked before it can steer where bytes land.
  // ─────────────────────────────────────────────────────────────────────────
  group('bundleVersion is untrusted input', () {
    test('accepts the shapes a real CMS emits', () {
      for (final v in ['v1', '1.0.0', '2026-07-28', 'v1.2.3-rc1', 'A_b-1.0']) {
        expect(BundleLayout.isValidVersion(v), isTrue, reason: v);
      }
    });

    test('rejects traversal, separators and absolute paths', () {
      for (final v in [
        '../evil',
        '..',
        '.',
        'a/../../b',
        'a/b',
        r'a\b',
        '/etc/passwd',
        '.hidden', // leading dot: never a version, always a hint
        '-rf', //     leading dash: never a version, sometimes a flag
        '',
      ]) {
        expect(BundleLayout.isValidVersion(v), isFalse, reason: v);
      }
    });

    test('rejects names that would collide with the layout itself', () {
      // `active` is the pointer file; `<v>.tmp` / `<v>.part` are scratch
      // namespaces that boot GC is allowed to delete on sight.
      for (final v in ['active', 'active.tmp', '1.0.tmp', '1.0.part', 'x.tar.gz']) {
        expect(BundleLayout.isValidVersion(v), isFalse, reason: v);
      }
    });

    test('rejects an over-long name', () {
      expect(BundleLayout.isValidVersion('v${'9' * 100}'), isFalse);
    });

    test('a traversing version is refused BEFORE anything touches the disk',
        () async {
      await seedActive('v1');
      final bytes = buildBundleTarGz(manifestFor('v2'));
      final t = FakeTransport(
        version: '../../../escaped',
        archiveBytes: bytes,
        advertisedSha: sha256Hex(bytes),
      );

      final r = await serviceWith(t).syncIfNeeded();

      expect(r.outcome, SyncOutcome.failed);
      expect(r.error, contains('unsafe bundleVersion'));
      // The active bundle is untouched...
      expect(await layout.activeVersion(), 'v1');
      // ...and nothing was created outside the bundle root.
      final escaped = Directory(p.join(tempRoot.path, 'escaped'));
      expect(await escaped.exists(), isFalse);
      final siblings = await tempRoot.list().toList();
      expect(siblings.map((e) => p.basename(e.path)), ['bundles']);
    });

    test('setActive refuses to persist an unsafe pointer', () async {
      expect(() => layout.setActive('../evil'), throwsArgumentError);
    });

    test('an unsafe pointer already on disk reads back as "no bundle"',
        () async {
      // Simulates a pointer written by a build that predates this validation.
      await File(p.join(layout.rootDir.path, 'active'))
          .writeAsString('../../../etc');
      expect(await layout.activeVersion(), isNull);
    });
  });
}