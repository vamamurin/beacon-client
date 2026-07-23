// Destination: lib/data/analytics/analytics_uploader.dart
//
// Network boundary for analytics upload, abstracted exactly like SyncTransport
// so the buffering sink can be unit-tested with a fake and so the real endpoint
// can change without touching the sink. The sink hands over already-serialized
// NDJSON lines (one JSON object per line); the uploader just ships them.
//
// Contract: return true ONLY when the batch is durably accepted by the server.
// Any error (offline, 5xx, timeout) returns false so the sink keeps the events
// and retries next drain — analytics must never be lost to a flaky network, and
// must never block a tour.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

abstract interface class AnalyticsUploader {
  /// Upload one batch of NDJSON lines. Returns true if the server accepted them.
  Future<bool> upload(List<String> ndjsonLines);
}

/// Mock/dev uploader: pretends success so buffered events are pruned and don't
/// accumulate on disk during UI development. Use in mock mode.
class NoopAnalyticsUploader implements AnalyticsUploader {
  const NoopAnalyticsUploader();

  @override
  Future<bool> upload(List<String> ndjsonLines) async => true;
}

/// POSTs NDJSON to `<baseUrl>/events`. [baseUrl] is read at call time (same
/// pattern as HttpSyncTransport) so a Settings override / --dart-define takes
/// effect on the next drain without a restart.
///
/// TRANSPORT SECURITY: plain-HTTP upload is allowed in DEBUG builds only, so a
/// LAN dev server (http://192.168.x.x:8000) works out of the box during field
/// testing, while RELEASE builds refuse anything but HTTPS. Analytics carry no
/// visitor identity, but they do describe a real building's traffic patterns
/// and shouldn't travel in the clear off a museum's network. Override
/// [allowInsecure] explicitly if a deployment genuinely needs plain HTTP on a
/// closed network — an explicit flag beats silently weakening the default.
class HttpAnalyticsUploader implements AnalyticsUploader {
  HttpAnalyticsUploader({
    required String Function() baseUrl,
    bool? allowInsecure,
    Duration timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl,
        _allowInsecure = allowInsecure ?? kDebugMode,
        _timeout = timeout;

  final String Function() _baseUrl;
  final bool _allowInsecure;
  final Duration _timeout;

  @override
  Future<bool> upload(List<String> ndjsonLines) async {
    if (ndjsonLines.isEmpty) return true;

    final base = _baseUrl().trim();
    if (base.isEmpty) {
      if (kDebugMode) debugPrint('[Analytics] no baseUrl configured');
      return false;
    }

    final Uri uri;
    try {
      uri = Uri.parse('${base.replaceAll(RegExp(r"/+$"), "")}/events');
    } catch (_) {
      return false;
    }
    if (uri.scheme != 'https' && !_allowInsecure) {
      // Loud on purpose: silently dropping every upload is the kind of bug that
      // only surfaces weeks later as "why is there no data".
      debugPrint('[Analytics] REFUSING non-HTTPS upload to $uri '
          '(release build). Use https, or pass allowInsecure: true.');
      return false;
    }

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.postUrl(uri).timeout(_timeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/x-ndjson');
      req.write(ndjsonLines.join('\n'));
      final resp = await req.close().timeout(_timeout);
      // Drain the body so the socket can be reused/closed cleanly.
      await resp.drain<void>();
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (kDebugMode) {
        debugPrint('[Analytics] POST $uri -> ${resp.statusCode} '
            '(${ndjsonLines.length} events)');
      }
      return ok;
    } on TimeoutException {
      if (kDebugMode) debugPrint('[Analytics] upload timed out to $uri');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] upload failed: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }
}