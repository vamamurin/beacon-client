// Destination: lib/data/analytics/buffering_analytics_sink.dart
//
// Offline-first analytics sink. Same spirit as ContentSyncService: assume the
// network is absent for most of a tour and NEVER let analytics block or crash
// the app. Events buffer in memory, persist to an append-only NDJSON file at a
// boundary/flush, and upload in batches only when [drain] is called (docked).
//
// Durability & safety:
//   • record() is non-blocking: it appends to an in-memory list and returns.
//   • All file I/O is serialized through a single future chain (_io) so flush
//     and drain never interleave or corrupt the file. Dart's single thread
//     makes the snapshot-and-clear of the pending buffer atomic.
//   • drain() uploads in batches; a failed batch stops the drain and LEAVES the
//     remaining events on disk for next time (at-least-once; the server should
//     dedupe on (sessionId, name, at)).
//   • Bounded disk: if the file exceeds [maxBytes] (weeks offline), the OLDEST
//     lines are dropped — recent behaviour is worth more than stale, and disk
//     is finite on a kiosk device.
//   • Anonymous device id (random, generated once, stored beside the events) is
//     the ONLY identity, and it identifies a DEVICE, never a visitor.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/analytics/analytics_uploader.dart';
import 'package:beacon_client/domain/interfaces/i_analytics_sink.dart';
import 'package:beacon_client/domain/models/analytics_event.dart';

class BufferingFileAnalyticsSink implements IAnalyticsSink {
  BufferingFileAnalyticsSink({
    required Directory dir,
    required AnalyticsUploader uploader,
    int schemaVersion = 1,
    int uploadBatchSize = 200,
    int memFlushThreshold = 32,
    int maxBytes = 2 * 1024 * 1024, // 2 MB of NDJSON ≈ tens of thousands of events
    Duration? flushInterval = const Duration(seconds: 20),
  })  : _dir = dir,
        _uploader = uploader,
        _schema = schemaVersion,
        _batch = uploadBatchSize,
        _memThreshold = memFlushThreshold,
        _maxBytes = maxBytes {
    if (flushInterval != null) {
      _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
    }
  }

  final Directory _dir;
  final AnalyticsUploader _uploader;
  final int _schema;
  final int _batch;
  final int _memThreshold;
  final int _maxBytes;

  final List<String> _pending = <String>[];
  Future<void> _io = Future<void>.value();
  Timer? _timer;
  String? _deviceId;
  bool _disposed = false;

  File get _eventsFile => File('${_dir.path}/events.jsonl');
  File get _deviceFile => File('${_dir.path}/device_id');

  // ------------------------------------------------------------------ record
  @override
  void record(AnalyticsEvent event) {
    if (_disposed) return;
    _pending.add(_encode(event));
    if (_pending.length >= _memThreshold) unawaited(flush());
  }

  String _encode(AnalyticsEvent event) => jsonEncode({
        'schema': _schema,
        'device': _deviceId, // filled in lazily on first flush; may be null here
        'event': event.toJson(),
      });

  // ------------------------------------------------------------------- flush
  @override
  Future<void> flush() => _run(_doFlush);

  Future<void> _doFlush() async {
    if (_pending.isEmpty) return;

    // Atomic snapshot + clear (no await in between).
    final lines = List<String>.of(_pending);
    _pending.clear();

    await _ensureDir();
    await _ensureDeviceId();

    // Backfill the device id into any line encoded before it was known.
    final withDevice = lines
        .map((l) => l.contains('"device":null')
            ? l.replaceFirst('"device":null', '"device":"$_deviceId"')
            : l)
        .toList(growable: false);

    try {
      await _eventsFile.writeAsString(
        '${withDevice.join('\n')}\n',
        mode: FileMode.writeOnlyAppend,
        flush: true,
      );
    } catch (e) {
      // Put them back so we don't lose events on a transient write failure.
      _pending.insertAll(0, lines);
      if (kDebugMode) debugPrint('[Analytics] flush write failed: $e');
      return;
    }

    await _enforceCap();
  }

  // ------------------------------------------------------------------- drain
  @override
  Future<void> drain() => _run(_doDrain);

  Future<void> _doDrain() async {
    // Fold in anything still buffered so the file is the single source of truth.
    if (_pending.isNotEmpty) {
      final lines = List<String>.of(_pending);
      _pending.clear();
      await _ensureDir();
      await _ensureDeviceId();
      final withDevice = lines
          .map((l) => l.replaceFirst('"device":null', '"device":"$_deviceId"'))
          .toList(growable: false);
      try {
        await _eventsFile.writeAsString('${withDevice.join('\n')}\n',
            mode: FileMode.writeOnlyAppend, flush: true);
      } catch (_) {
        _pending.insertAll(0, lines);
      }
    }

    if (!await _eventsFile.exists()) return;
    final all = (await _eventsFile.readAsLines())
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (all.isEmpty) {
      await _safeDelete(_eventsFile);
      return;
    }

    var i = 0;
    while (i < all.length) {
      final end = math.min(i + _batch, all.length);
      final chunk = all.sublist(i, end);
      final ok = await _uploader.upload(chunk);
      if (!ok) break; // keep this chunk and everything after it
      i = end;
    }

    final remaining = all.sublist(i);
    if (remaining.isEmpty) {
      await _safeDelete(_eventsFile);
    } else if (i > 0) {
      // Rewrite only what's left (some batches uploaded).
      await _eventsFile.writeAsString('${remaining.join('\n')}\n', flush: true);
    }
  }

  // ------------------------------------------------------------------ upkeep
  Future<void> _enforceCap() async {
    try {
      if (!await _eventsFile.exists()) return;
      final len = await _eventsFile.length();
      if (len <= _maxBytes) return;
      // Over cap: keep the NEWEST half, drop the oldest.
      final all = (await _eventsFile.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final keep = all.sublist(all.length ~/ 2);
      await _eventsFile.writeAsString('${keep.join('\n')}\n', flush: true);
      if (kDebugMode) {
        debugPrint('[Analytics] cap hit — dropped ${all.length - keep.length} old events');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] cap enforce failed: $e');
    }
  }

  Future<void> _ensureDir() async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
  }

  Future<void> _ensureDeviceId() async {
    if (_deviceId != null) return;
    try {
      if (await _deviceFile.exists()) {
        final id = (await _deviceFile.readAsString()).trim();
        if (id.isNotEmpty) {
          _deviceId = id;
          return;
        }
      }
    } catch (_) {/* fall through to generate */}
    final id = _generateDeviceId();
    _deviceId = id;
    try {
      await _deviceFile.writeAsString(id, flush: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] device id persist failed: $e');
    }
  }

  static String _generateDeviceId() {
    final r = math.Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _safeDelete(FileSystemEntity e) async {
    try {
      if (await e.exists()) await e.delete();
    } catch (err) {
      if (kDebugMode) debugPrint('[Analytics] delete failed ${e.path}: $err');
    }
  }

  /// Serialize an I/O action onto the single chain so file ops never overlap.
  Future<void> _run(Future<void> Function() action) {
    final next = _io.then((_) => action()).catchError((Object e) {
      if (kDebugMode) debugPrint('[Analytics] io error: $e');
    });
    _io = next;
    return next;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await flush(); // best-effort persist of whatever is buffered
    await _io; // let the chain settle
  }
}