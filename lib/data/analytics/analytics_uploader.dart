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
//
// ─────────────────────────────────────────────────────────────────────────────
// TRANSPORT SECURITY — permissive by default, tightened at BUILD time.
//
//   Dev / staging (default):  plain HTTP allowed.
//   Production:               pass --dart-define=REQUIRE_HTTPS=true
//
// Why this shape rather than a clever runtime default: the two previous
// attempts both keyed the decision on something the build couldn't state
// explicitly, and both silently ate every upload in the field.
//   • `allowInsecure: false` blocked the LAN dev server outright.
//   • `allowInsecure: kDebugMode` looked right but kDebugMode is ALSO false in
//     PROFILE builds, so `flutter run --profile` against the same LAN server
//     failed just as silently.
// A dart-define is explicit, greppable, lives in the release command, and
// cannot drift from what was actually compiled.
//
// The trade-off is real and worth naming: the failure mode moves from "dev is
// blocked" to "prod ships cleartext if someone forgets the flag". Two things
// blunt that:
//   1. Put REQUIRE_HTTPS in the release script / CI job, never type it by hand.
//   2. Even when cleartext is ALLOWED, sending it to a non-private host logs a
//      loud unconditional warning (see [isPrivateHost]). A LAN address stays
//      quiet; a public endpoint over http:// complains on every single drain,
//      in every build mode. Forgetting the flag is then noisy, not invisible.
//
// LOGGING: the per-drain result lines are deliberately NOT wrapped in
// `if (kDebugMode)`. They fire at most once per dock, and they are the only
// signal a field tester has that analytics are leaving the device — burying
// them in a debug-only guard is exactly what made the profile-mode bug
// invisible for two test cycles.

import 'dart:io';
import 'dart:async';
import 'dart:convert';


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
class HttpAnalyticsUploader implements AnalyticsUploader {
  /// Compile-time switch. Production builds pass
  /// `--dart-define=REQUIRE_HTTPS=true`; everything else defaults to permissive
  /// so LAN dev servers work in debug, profile AND release without special
  /// cases.
  static const bool requireHttps =
      bool.fromEnvironment('REQUIRE_HTTPS', defaultValue: false);

  HttpAnalyticsUploader({
    required String Function() baseUrl,
    bool? allowInsecure,
    Duration timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl,
        _allowInsecure = allowInsecure ?? !requireHttps,
        _timeout = timeout;

  final String Function() _baseUrl;
  final bool _allowInsecure;
  final Duration _timeout;

  @override
  Future<bool> upload(List<String> ndjsonLines) async {
    if (ndjsonLines.isEmpty) return true;

    final base = _baseUrl().trim();
    if (base.isEmpty) {
      debugPrint('[Analytics] upload skipped — no baseUrl configured');
      return false;
    }

    final Uri uri;
    try {
      uri = Uri.parse('${base.replaceAll(RegExp(r"/+$"), "")}/events');
    } catch (e) {
      debugPrint('[Analytics] upload skipped — bad baseUrl "$base": $e');
      return false;
    }

    if (uri.scheme != 'https') {
      if (!_allowInsecure) {
        // Only reachable in a REQUIRE_HTTPS build. Say exactly which knob to
        // turn, so this is a 10-second fix and not a debugging session.
        debugPrint('[Analytics] REFUSING cleartext upload to $uri — this build '
            'was compiled with REQUIRE_HTTPS=true. Use an https:// endpoint.');
        return false;
      }
      if (!isPrivateHost(uri.host)) {
        // Allowed, but almost certainly a mistake: cleartext to a public host.
        // Loud on every drain so a forgotten REQUIRE_HTTPS flag can't hide.
        debugPrint('[Analytics] WARNING: sending analytics in cleartext to '
            'PUBLIC host ${uri.host}. Production builds should use https:// '
            'and --dart-define=REQUIRE_HTTPS=true.');
      }
    }

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final body = utf8.encode(ndjsonLines.join('\n'));
      final req = await client.postUrl(uri).timeout(_timeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/x-ndjson');
      req.contentLength = body.length;   // ← DÒNG QUYẾT ĐỊNH
      req.add(body);                     // add(bytes) thay vì write(String)
      final resp = await req.close().timeout(_timeout);
      // Drain the body so the socket can be reused/closed cleanly.
      await resp.drain<void>();
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      debugPrint('[Analytics] POST $uri -> ${resp.statusCode} '
          '(${ndjsonLines.length} events)');
      return ok;
    } on TimeoutException {
      debugPrint('[Analytics] upload timed out -> $uri');
      return false;
    } catch (e) {
      debugPrint('[Analytics] upload failed -> $uri: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// True when [host] is provably on the local network. Used only to decide
  /// whether cleartext deserves a warning — a museum LAN server is the intended
  /// deployment and should stay quiet, while http:// to a public host is worth
  /// shouting about.
  ///
  /// A bare hostname (not an IP literal) is NOT provably private and returns
  /// false: DNS is not a security boundary, and `analytics.internal` can
  /// resolve anywhere.
  @visibleForTesting
  static bool isPrivateHost(String host) {
    if (host == 'localhost') return true;

    final ip = InternetAddress.tryParse(host);
    if (ip == null) return false; // a hostname — can't prove it's local

    if (ip.isLoopback) return true;

    final b = ip.rawAddress;
    switch (ip.type) {
      case InternetAddressType.IPv4:
        if (b[0] == 10) return true; //                  10.0.0.0/8
        if (b[0] == 127) return true; //                 127.0.0.0/8
        if (b[0] == 192 && b[1] == 168) return true; //  192.168.0.0/16
        if (b[0] == 169 && b[1] == 254) return true; //  169.254.0.0/16 link-local
        if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true; // 172.16.0.0/12
        return false;
      case InternetAddressType.IPv6:
        if ((b[0] & 0xFE) == 0xFC) return true; //       fc00::/7 unique local
        if (b[0] == 0xFE && (b[1] & 0xC0) == 0x80) return true; // fe80::/10
        return false;
      default:
        return false;
    }
  }
}