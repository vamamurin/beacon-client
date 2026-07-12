// Destination: lib/data/repositories/http_sync_transport.dart
//
// HTTP implementation of SyncTransport with RESUMABLE downloads (byte-range).
// Skeleton for the museum's internal server — endpoints/paths are configurable
// so it can be adapted when the real server lands (per Phase-0: general
// protocol now, server wiring later). NOT unit-tested (network); the sync
// pipeline that consumes it IS fully tested via FakeTransport.
//
// Resume mechanics (from the HTTP Range spec):
//   • If a .part file already exists, send `Range: bytes=<existing>-`.
//   • 206 Partial Content -> append to the .part file.
//   • 200 OK -> server ignored the range (or file changed) -> restart from 0.
//   • Guard against the archive changing mid-resume with If-Range: <ETag>.
//
// The service verifies sha256 AFTER download regardless, so a botched resume
// simply fails the checksum and is retried — the atomic swap keeps the active
// bundle safe throughout.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/repositories/content_sync_service.dart';

class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({
    required String Function() baseUrl,
    HttpClient? client,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration idleTimeout = const Duration(seconds: 30),
  })  : _baseUrl = baseUrl,
        _connectTimeout = connectTimeout,
        _idleTimeout = idleTimeout,
        _client = client ?? HttpClient() {
    // Timeout khi mạng nội bộ treo: không để nút Đồng bộ quay vô hạn. Áp cho
    // giai đoạn thiết lập kết nối; đọc dữ liệu dùng idle timeout riêng bên dưới.
    _client.connectionTimeout = _connectTimeout;
  }

  /// D — đọc URL TẠI THỜI ĐIỂM GỌI (không chốt cứng lúc khởi tạo), nên đổi URL
  /// trong Settings có hiệu lực ngay lần Đồng bộ kế tiếp, không cần restart.
  /// Trailing slash được cắt để ghép path an toàn.
  final String Function() _baseUrl;
  final Duration _connectTimeout;
  final Duration _idleTimeout;
  final HttpClient _client;

  String get _base {
    final u = _baseUrl().trim();
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  /// ETag of the archive from the last version.json, used with If-Range so a
  /// resume aborts cleanly if the server's file changed.
  String? _lastEtag;

  @override
  Future<Map<String, dynamic>> fetchVersionInfo() async {
    final uri = Uri.parse('$_base/version.json');
    final req = await _client.getUrl(uri);
    final res = await req.close().timeout(_idleTimeout);
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException('version.json HTTP ${res.statusCode}', uri: uri);
    }
    final body = await res.transform(utf8.decoder).join();
    final map = jsonDecode(body) as Map<String, dynamic>;
    _lastEtag = map['etag'] as String?; // optional, if server provides it
    return map;
  }

  @override
  Future<void> downloadArchive(
    String version,
    File dest, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse('$_base/bundle-$version.tar.gz');

    // How much do we already have on disk?
    int existing = 0;
    if (await dest.exists()) {
      existing = await dest.length();
    }

    final req = await _client.getUrl(uri);
    if (existing > 0) {
      req.headers.add(HttpHeaders.rangeHeader, 'bytes=$existing-');
      if (_lastEtag != null) {
        req.headers.add(HttpHeaders.ifRangeHeader, _lastEtag!);
      }
    }

    final res = await req.close().timeout(_idleTimeout);

    IOSink sink;
    int totalExpected;
    switch (res.statusCode) {
      case HttpStatus.partialContent: // 206: resume accepted
        sink = dest.openWrite(mode: FileMode.append);
        // Content-Range: bytes start-end/total
        final cr = res.headers.value(HttpHeaders.contentRangeHeader);
        totalExpected = _parseTotalFromContentRange(cr) ??
            (existing + res.contentLength);
        break;
      case HttpStatus.ok: // 200: server sent the whole file (range ignored)
        // Restart cleanly: truncate whatever partial we had.
        if (await dest.exists()) await dest.delete();
        sink = dest.openWrite(mode: FileMode.write);
        existing = 0;
        totalExpected = res.contentLength;
        break;
      default:
        throw HttpException('download HTTP ${res.statusCode}', uri: uri);
    }

    var received = existing;
    try {
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && totalExpected > 0) {
          onProgress((received / totalExpected).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (kDebugMode) {
      debugPrint('[HttpSyncTransport] downloaded $version '
          '($received/$totalExpected bytes)');
    }
  }

  int? _parseTotalFromContentRange(String? header) {
    // Format: "bytes 200-1000/67589"
    if (header == null) return null;
    final slash = header.lastIndexOf('/');
    if (slash < 0) return null;
    return int.tryParse(header.substring(slash + 1).trim());
  }

  void close() => _client.close(force: true);
}