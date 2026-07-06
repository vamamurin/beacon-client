// Destination: lib/data/repositories/bundle_layout.dart
//
// Single source of truth for WHERE bundles live on disk and WHICH one is
// active. Shared by LocalBundleZoneRepository (reads active) and
// ContentSyncService (writes the pointer during swap).
//
// Layout under the app documents dir:
//   bundles/
//   ├── <version>/            one directory per fully-validated bundle
//   │   ├── manifest.json
//   │   ├── images/...
//   │   └── audio/...
//   ├── <version>.tmp/        in-progress unpack (never read; GC'd on boot)
//   └── active                text file containing the active <version>
//
// The `active` pointer is a tiny text file. Rewriting it is the near-atomic
// commit point of a swap: it either names the old version or the new one, never
// an in-between. Readers ALWAYS go through the active pointer, so they never
// see a half-written bundle.

import 'dart:io';

import 'package:path/path.dart' as p;

class BundleLayout {
  BundleLayout(this.rootDir);

  /// e.g. <appDocuments>/bundles
  final Directory rootDir;

  Directory get _root => rootDir;
  File get _activePointer => File(p.join(rootDir.path, 'active'));

  /// Directory for a specific version's FINAL (validated) content.
  Directory versionDir(String version) =>
      Directory(p.join(rootDir.path, version));

  /// Scratch dir for an in-progress unpack of [version]. Never read by the app.
  Directory tempDir(String version) =>
      Directory(p.join(rootDir.path, '$version.tmp'));

  /// The downloaded archive's temp path.
  File archiveTempFile(String version) =>
      File(p.join(rootDir.path, '$version.tar.gz.part'));

  Future<void> ensureRoot() async {
    if (!await _root.exists()) {
      await _root.create(recursive: true);
    }
  }

  /// The active version string, or null if none committed yet (fresh device).
  Future<String?> activeVersion() async {
    if (!await _activePointer.exists()) return null;
    final v = (await _activePointer.readAsString()).trim();
    if (v.isEmpty) return null;
    // Defensive: only trust the pointer if that version dir actually exists
    // and holds a manifest — guards against a pointer written but content
    // deleted (should not happen, but a corrupt pointer must not crash boot).
    final manifest = File(p.join(versionDir(v).path, 'manifest.json'));
    if (!await manifest.exists()) return null;
    return v;
  }

  /// Absolute path to the active bundle's directory, or null if none.
  Future<Directory?> activeDir() async {
    final v = await activeVersion();
    return v == null ? null : versionDir(v);
  }

  /// Commit point: point `active` at [version]. Written atomically by writing
  /// a sibling temp file then renaming over the pointer (rename is atomic on
  /// the same filesystem).
  Future<void> setActive(String version) async {
    await ensureRoot();
    final tmp = File(p.join(rootDir.path, 'active.tmp'));
    await tmp.writeAsString(version, flush: true);
    await tmp.rename(_activePointer.path);
  }
}
