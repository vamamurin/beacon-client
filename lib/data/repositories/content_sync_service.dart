// Destination: lib/data/repositories/content_sync_service.dart (REPLACES current)
//
// Downloads and installs content bundles with an ATOMIC-SWAP pipeline that
// makes "power lost mid-update leaves both versions broken" IMPOSSIBLE.
//
// Core principle: NEVER write over the bundle in use. Each version lives in its
// own dir; the `active` pointer (see BundleLayout) is the single commit point.
// At every instant `active` names a fully-validated bundle, or names nothing
// (fresh device). There is no in-between.
//
// Safe sequence (crash at ANY step leaves the active bundle untouched):
//   1. GET version.json. Same version as active? -> nothing to do.
//   2. Download <ver>.tar.gz.part with HTTP Range RESUME (interrupted download
//      continues, never restarts).
//   3. Verify sha256 BEFORE unpacking. Mismatch -> discard, keep old.
//   4. Unpack into <ver>.tmp/ (NOT the final dir), rejecting any '..' entry
//      (archive path-traversal guard). On a background isolate (heavy I/O).
//   5. Validate manifest.json with ManifestParser. Invalid -> discard, keep old.
//   6. Rename <ver>.tmp -> <ver>, THEN write `active` = <ver>. (Commit.)
//   7. ONLY NOW delete the previous version dir (single-copy policy) — order
//      matters: active already points at the new, validated bundle, so a crash
//      between commit and cleanup just leaves stale bytes for boot GC.
//
// ─────────────────────────────────────────────────────────────────────────────
// STREAMING UNPACK — constant memory regardless of bundle size (step 4).
//
// History of this hot spot:
//   v1  readAsBytes() + compute(bytes)  -> peak ≈ 4× bundle size in RAM:
//         (a) whole archive on the UI isolate heap,
//         (b) compute() COPIES the argument across the isolate port (2nd copy),
//         (c) gunzip output buffer, (d) TarDecoder's in-memory entry contents.
//       A 100 MB bundle peaked near 400 MB — well past Android's PER-APP heap
//       cap (typically 128–512 MB), so it OOM-killed long before physical RAM
//       ran out.
//   v2  compute(path) instead of bytes  -> removed (a) and (b); still ~2×.
//   v3  (this)  fully streaming: never materializes the archive at all.
//
// How v3 achieves O(1) memory, verified against archive 4.0.9 source:
//   • GZipDecoder().decodeStream(InputFileStream, OutputFileStream) inflates
//     FILE -> FILE through a small rolling buffer.
//   • TarDecoder().decodeStream(InputFileStream) builds the entry TABLE only:
//     InputFileStream.readBytes(n) returns a LAZY FILE-BACKED VIEW (an
//     InputFileStream subset), not a Uint8List. So each ArchiveFile's
//     rawContent is a file offset+length, not bytes on the heap.
//   • ArchiveFile.writeContent(OutputFileStream) then streams that view
//     FILE -> FILE.
//   Peak RAM is therefore the stream buffers (tens of KB) plus the entry
//   metadata list — independent of whether the bundle is 40 MB or 4 GB.
//
// TRADE-OFF (deliberate): gunzip needs an intermediate .tar on DISK, because
// archive's gzip decoder writes into an OutputStream sink rather than exposing
// a readable stream. So transient DISK use during unpack is roughly
//   archive(.part) + intermediate .tar + extracted files  ≈ 3× bundle size.
// Disk is plentiful compared to heap, and the intermediate tar is deleted in a
// finally block (and swept by boot GC if we're killed mid-unpack). Trading
// scarce RAM for abundant disk is the whole point.
//
// The isolate is KEPT even though memory is no longer the reason: decode is
// CPU- and IO-heavy and fully synchronous, so running it on the UI isolate
// would freeze the frame pump. compute() now ships only two short strings.
//
// RESUME IS UNAFFECTED: download resume lives entirely in
// HttpSyncTransport.downloadArchive (HTTP Range against the .part file) and
// runs to completion BEFORE unpack begins. Nothing in this rewrite touches the
// .part file, its retention policy, or the Range logic.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:beacon_client/data/repositories/bundle_layout.dart';
import 'package:beacon_client/data/repositories/manifest_parser.dart';

/// Abstracts network so tests can feed bytes without a real server.
abstract interface class SyncTransport {
  /// Fetch and decode version.json.
  Future<Map<String, dynamic>> fetchVersionInfo();

  /// Download the archive for [version] to [dest], resuming if a partial file
  /// already exists (HTTP Range). Reports progress 0..1 via [onProgress].
  Future<void> downloadArchive(
    String version,
    File dest, {
    void Function(double progress)? onProgress,
  });
}

enum SyncOutcome { upToDate, updated, failed, noConnectivity }

class SyncResult {
  final SyncOutcome outcome;
  final String? version;
  final String? error;
  const SyncResult(this.outcome, {this.version, this.error});
}

class ContentSyncService {
  ContentSyncService({
    required BundleLayout layout,
    required SyncTransport transport,
  })  : _layout = layout,
        _transport = transport;

  final BundleLayout _layout;
  final SyncTransport _transport;

  /// P1-2: file .part được GIỮ qua các lần khởi động — kịch bản cần resume
  /// nhất chính là "đang tải bundle lớn thì app bị kill / mất điện"; xóa .part
  /// lúc boot là vô hiệu hóa toàn bộ cơ chế HTTP Range của transport. Chỉ dọn
  /// .part đã quá cũ (server nhiều khả năng đã đổi version; sha256 sau download
  /// vẫn là chốt chặn cuối nếu resume nhầm file).
  static const Duration _partMaxAge = Duration(days: 7);

  /// Boot-time housekeeping: delete every stray dir/file that isn't the active
  /// bundle — leftover .tmp unpacks, intermediate .tar files from an unpack we
  /// were killed during, and (single-copy policy) any non-active version dir.
  /// In-progress downloads (.part) are preserved for resume unless older than
  /// [_partMaxAge]. Call once at startup.
  Future<void> cleanupOnBoot() async {
    await _layout.ensureRoot();
    final active = await _layout.activeVersion();
    final now = DateTime.now();
    await for (final entity in _layout.rootDir.list()) {
      final name = p.basename(entity.path);
      if (name == 'active') continue;
      if (active != null && name == active) continue; // keep the live bundle

      // Keep resumable downloads (see _partMaxAge note above).
      if (name.endsWith('.part')) {
        try {
          final stat = await entity.stat();
          if (now.difference(stat.modified) <= _partMaxAge) {
            if (kDebugMode) debugPrint('[Sync] GC kept resumable $name');
            continue;
          }
        } catch (_) {
          // stat failed — fall through and delete the unreadable leftover.
        }
      }

      try {
        await entity.delete(recursive: true);
        if (kDebugMode) debugPrint('[Sync] GC removed $name');
      } catch (e) {
        if (kDebugMode) debugPrint('[Sync] GC failed for $name: $e');
      }
    }
  }

  /// The full safe pipeline. Returns what happened; never throws for expected
  /// failures (network/checksum/validation) — those land in [SyncResult.error].
  Future<SyncResult> syncIfNeeded({
    void Function(double progress)? onProgress,
  }) async {
    await _layout.ensureRoot();

    Map<String, dynamic> info;
    try {
      info = await _transport.fetchVersionInfo();
    } catch (e) {
      return SyncResult(SyncOutcome.noConnectivity, error: '$e');
    }

    final version = info['bundleVersion'] as String?;
    final expectedSha = (info['sha256'] as String?)?.toLowerCase();
    if (version == null || expectedSha == null) {
      return const SyncResult(SyncOutcome.failed,
          error: 'version.json missing bundleVersion/sha256');
    }

    // 1. Already current?
    if (await _layout.activeVersion() == version) {
      return SyncResult(SyncOutcome.upToDate, version: version);
    }

    final archiveFile = _layout.archiveTempFile(version);
    final tmpDir = _layout.tempDir(version);
    final finalDir = _layout.versionDir(version);
    // Intermediate gunzip target. Lives beside the archive so boot GC sweeps it
    // if we're killed mid-unpack.
    final tarFile = File('${archiveFile.path}.tar');

    try {
      // Clear any stale tmp unpack / intermediate tar for this version (but NOT
      // the .part, which we may resume).
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      await _safeDelete(tarFile);

      // 2. Download (resumable — untouched by the streaming rewrite).
      await _transport.downloadArchive(version, archiveFile,
          onProgress: onProgress);

      // 3. Verify checksum BEFORE unpacking. Streams the file (openRead) — no
      // whole-archive allocation here either.
      final actualSha = await _sha256OfFile(archiveFile);
      if (actualSha != expectedSha) {
        await _safeDelete(archiveFile);
        return SyncResult(SyncOutcome.failed,
            version: version, error: 'sha256 mismatch (got $actualSha)');
      }

      // 4. Streaming unpack on a background isolate. Only three short strings
      // cross the isolate port; all bulk data moves file -> file.
      await compute(
        _unpackTarGzStreaming,
        _UnpackArgs(archiveFile.path, tarFile.path, tmpDir.path),
      );

      // 5. Validate the manifest with the SAME parser the app uses.
      final manifestFile = File(p.join(tmpDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw const BundleValidationException('unpacked bundle has no manifest');
      }
      final parsed = ManifestParser.parse(
          jsonDecode(await manifestFile.readAsString())
              as Map<String, dynamic>);
      // Sanity: manifest's own version should match the archive version.
      if (parsed.config.bundleVersion != version && kDebugMode) {
        debugPrint('[Sync] warning: manifest version '
            '${parsed.config.bundleVersion} != archive $version');
      }

      // 6. Commit: promote tmp -> final, then flip the pointer. This ordering
      // is the crux: after setActive, the new bundle IS the source of truth.
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
      await tmpDir.rename(finalDir.path);
      final previous = await _layout.activeVersion();
      await _layout.setActive(version); // <-- atomic commit point

      // 7. ONLY NOW remove the previous version (single-copy policy). A crash
      // before this leaves stale bytes that boot GC will remove; active already
      // points at the new bundle either way.
      await _safeDelete(archiveFile);
      if (previous != null && previous != version) {
        await _safeDelete(_layout.versionDir(previous));
      }

      return SyncResult(SyncOutcome.updated, version: version);
    } on BundleValidationException catch (e) {
      await _discard(tmpDir, archiveFile);
      return SyncResult(SyncOutcome.failed,
          version: version, error: 'invalid bundle: ${e.message}');
    } catch (e) {
      await _discard(tmpDir, archiveFile);
      return SyncResult(SyncOutcome.failed, version: version, error: '$e');
    } finally {
      // The intermediate tar is never needed after unpack, success or not.
      await _safeDelete(tarFile);
    }
  }

  Future<void> _discard(Directory tmpDir, File archiveFile) async {
    await _safeDelete(tmpDir);
    await _safeDelete(archiveFile);
  }

  Future<void> _safeDelete(FileSystemEntity e) async {
    try {
      if (await e.exists()) await e.delete(recursive: true);
    } catch (err) {
      if (kDebugMode) debugPrint('[Sync] delete failed ${e.path}: $err');
    }
  }

  Future<String> _sha256OfFile(File f) async {
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString().toLowerCase();
  }
}

/// Isolate payload — three short paths. Nothing bulky crosses the port.
class _UnpackArgs {
  final String archivePath;
  final String tarPath;
  final String destPath;
  const _UnpackArgs(this.archivePath, this.tarPath, this.destPath);
}

/// Runs on a background isolate (via compute). Two streaming passes, both
/// file -> file, so peak heap is bounded by stream buffers rather than by
/// bundle size. Rejects any entry whose resolved path escapes destPath
/// (path-traversal guard for malicious archives).
void _unpackTarGzStreaming(_UnpackArgs args) {
  final destRoot = Directory(args.destPath);
  destRoot.createSync(recursive: true);
  final rootAbs = p.normalize(destRoot.absolute.path);

  // ---- pass 1: .tar.gz -> .tar (inflate through a rolling buffer) ----
  final gzIn = InputFileStream(args.archivePath);
  final tarOut = OutputFileStream(args.tarPath);
  try {
    const GZipDecoder().decodeStream(gzIn, tarOut);
  } finally {
    gzIn.closeSync();
    tarOut.closeSync();
  }

  // ---- pass 2: .tar -> individual files ----
  // decodeStream over a file stream yields entries whose content is a LAZY
  // file-backed view (see header note), so this table costs metadata only.
  final tarIn = InputFileStream(args.tarPath);
  try {
    final archive = TarDecoder().decodeStream(tarIn);
    for (final entry in archive) {
      final outPath = p.normalize(p.join(args.destPath, entry.name));

      // Traversal guard: the normalized path MUST stay inside destRoot.
      final absOut = p.normalize(File(outPath).absolute.path);
      if (absOut != rootAbs && !p.isWithin(rootAbs, absOut)) {
        throw StateError('archive entry escapes bundle dir: ${entry.name}');
      }
      // Symlinks could point outside the sandbox after extraction; bundles are
      // plain files + dirs by spec, so refuse rather than follow.
      if (entry.isSymbolicLink) {
        throw StateError('archive contains a symlink: ${entry.name}');
      }

      if (!entry.isFile) {
        Directory(outPath).createSync(recursive: true);
        continue;
      }

      Directory(p.dirname(outPath)).createSync(recursive: true);
      final fileOut = OutputFileStream(outPath);
      try {
        entry.writeContent(fileOut); // streams file -> file
      } finally {
        fileOut.closeSync();
      }
    }
  } finally {
    tarIn.closeSync();
  }
}