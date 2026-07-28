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

  // ---------------------------------------------------------------- validation

  /// Characters a version may contain. WHITELIST, not a blacklist: the string
  /// arrives from the network (version.json) and is then interpolated into a
  /// filesystem path AND a URL path, so anything not provably inert is refused.
  /// Must start alphanumeric, so `.`/`..`/`-flag` can never be a version.
  static final RegExp _versionPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

  /// Names this layout reserves for its own bookkeeping. A version equal to one
  /// of these would make the pointer file and a bundle dir fight over one path.
  static const Set<String> _reservedNames = {'active', 'active.tmp'};

  /// Suffixes that belong to the SCRATCH namespaces. Without this check,
  /// version "1.0.tmp" resolves `versionDir` to the same path as version "1.0"'s
  /// `tempDir` — boot GC would then delete a live bundle as if it were a
  /// half-finished unpack.
  static const List<String> _reservedSuffixes = ['.tmp', '.part', '.tar.gz'];

  /// Whether [version] is safe to use as a path segment under [rootDir].
  ///
  /// SECURITY BOUNDARY. The server is trusted for CONTENT, never for app
  /// STABILITY or for where bytes land on disk (same contract as
  /// ArbitrationParams.clamped). An unchecked version string is a path-traversal
  /// primitive: `../../databases/x` would make [versionDir] resolve outside the
  /// bundle root, and the swap in ContentSyncService would then rename an
  /// unpacked archive on top of it.
  ///
  /// The archive's INTERNAL entries were already guarded (see
  /// ContentSyncService._unpackTarGzStreaming); this guards the DIRECTORY those
  /// entries land in, which is one level up and was previously unchecked.
  static bool isValidVersion(String? version) {
    if (version == null) return false;
    if (!_versionPattern.hasMatch(version)) return false;
    if (_reservedNames.contains(version)) return false;
    for (final suffix in _reservedSuffixes) {
      if (version.endsWith(suffix)) return false;
    }
    return true;
  }

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
    // Re-validate on READ, not just on write. A pointer persisted by an older
    // build (before isValidVersion existed) must not be trusted just because it
    // is already on disk — treating it as "no bundle" sends the Gate down the
    // needs-sync path, which is the recoverable outcome.
    if (!isValidVersion(v)) return null;
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
    if (!isValidVersion(version)) {
      throw ArgumentError.value(version, 'version', 'unsafe bundle version');
    }
    await ensureRoot();
    final tmp = File(p.join(rootDir.path, 'active.tmp'));
    await tmp.writeAsString(version, flush: true);
    await tmp.rename(_activePointer.path);
  }
}
