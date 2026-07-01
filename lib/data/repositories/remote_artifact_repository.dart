import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:beacon_client/domain/interfaces/i_artifact_repository.dart';
import 'package:beacon_client/domain/models/artifact_info.dart';

/// Remote catalog (REST/JSON) với cache RAM cho hot path BLE.
///
/// Hardened so với bản cũ ở ba điểm:
///   1. **Per-record safe parse**: một record rác không còn giết cả catalog —
///      record hỏng bị skip, phần còn lại vẫn vào cache (đúng tinh thần "mọi
///      field nullable" của [ArtifactInfo]).
///   2. **Retry + backoff**: blip mạng tạm thời tự phục hồi thay vì để catalog
///      rỗng vĩnh viễn.
///   3. **Không nuốt lỗi**: giữ [lastError] / [isWarmed] để UI biết "tải lỗi"
///      và [refresh] để thử lại sau — trong khi [getCachedArtifact] vẫn O(1),
///      KHÔNG ném trên hot path (graceful degradation giữ nguyên).
class RemoteArtifactRepository implements IArtifactRepository {
  RemoteArtifactRepository({
    required this.apiUrl,
    this.maxAttempts = 3,
    this.requestTimeout = const Duration(seconds: 10),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final int maxAttempts;
  final Duration requestTimeout;
  final http.Client _client;

  final Map<int, ArtifactInfo> _cache = <int, ArtifactInfo>{};
  bool _warmed = false;
  Object? _lastError;
  Future<void>? _inFlight;

  /// True khi cache đã được nạp thành công ít nhất một lần.
  bool get isWarmed => _warmed;

  /// Lỗi gần nhất của lần warm/refresh (null nếu thành công). Cho UI hiển thị.
  Object? get lastError => _lastError;

  static int _key(int major, int minor) => (major << 16) | minor;

  @override
  Future<void> preWarm() {
    if (_warmed) return Future<void>.value();
    return _inFlight ??= _fetchWithRetry();
  }

  /// Ép nạp lại dù đã warmed (UI bấm "Thử lại", refresh định kỳ, hoặc gọi lại
  /// khi cache miss kéo dài). Coalesce lên lần đang chạy nếu có.
  Future<void> refresh() {
    if (_inFlight != null) return _inFlight!;
    return _inFlight ??= _fetchWithRetry();
  }

  Future<void> _fetchWithRetry() async {
    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final fetched = await _fetchOnce();
          _cache
            ..clear()
            ..addAll(fetched);
          _warmed = true;
          _lastError = null;
          if (kDebugMode) {
            debugPrint('[RemoteArtifactRepo] warmed: ${_cache.length} '
                'artifact(s) (attempt $attempt)');
          }
          return;
        } catch (e) {
          _lastError = e;
          if (kDebugMode) {
            debugPrint('[RemoteArtifactRepo] attempt $attempt/$maxAttempts '
                'failed: $e');
          }
          if (attempt < maxAttempts) {
            // Backoff: 0.5s, 1s, 2s ...
            final ms = 500 * (1 << (attempt - 1));
            await Future<void>.delayed(Duration(milliseconds: ms));
          }
        }
      }
      // Hết lượt: giữ _warmed=false + _lastError để UI surface lỗi/thử lại;
      // getCachedArtifact vẫn trả null (degradation), KHÔNG ném trên hot path.
      if (kDebugMode) {
        debugPrint('[RemoteArtifactRepo] bỏ cuộc sau $maxAttempts lần thử');
      }
    } finally {
      _inFlight = null; // cho phép preWarm()/refresh() sau retry lại
    }
  }

  Future<Map<int, ArtifactInfo>> _fetchOnce() async {
    if (kDebugMode) debugPrint('[RemoteArtifactRepo] GET $apiUrl');

    final response =
        await _client.get(Uri.parse(apiUrl)).timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw http.ClientException(
          'HTTP ${response.statusCode}', Uri.parse(apiUrl));
    }

    // UTF-8 để không vỡ font tiếng Việt.
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final items = decoded is Map ? decoded['artifacts'] : null;
    if (items is! List) {
      throw const FormatException('Payload thiếu mảng "artifacts" hợp lệ');
    }

    final out = <int, ArtifactInfo>{};
    var skipped = 0;
    for (final raw in items) {
      final parsed = _tryParseItem(raw);
      if (parsed == null) {
        skipped++;
        continue; // record rác → skip, không giết cả catalog
      }
      out[parsed.$1] = parsed.$2;
    }

    if (kDebugMode && skipped > 0) {
      debugPrint('[RemoteArtifactRepo] skipped $skipped record lỗi định dạng');
    }
    if (out.isEmpty) {
      throw const FormatException('Không parse được record hợp lệ nào');
    }
    return out;
  }

  /// Parse từng record phòng thủ. Trả (packedKey, ArtifactInfo) hoặc null nếu
  /// thiếu các field định danh bắt buộc (id/major/minor/name).
  static (int, ArtifactInfo)? _tryParseItem(dynamic raw) {
    if (raw is! Map) return null;

    final major = _asInt(raw['major']);
    final minor = _asInt(raw['minor']);
    final id = _asInt(raw['id']);
    final name = raw['name'];

    if (major == null || minor == null || id == null || name is! String) {
      return null; // định danh không đủ → không map được
    }

    return (
      _key(major, minor),
      ArtifactInfo(
        id: id,
        name: name,
        summary: raw['summary'] as String? ?? '',
        era: raw['era'] as String?,
        material: raw['material'] as String?,
        meaning: raw['meaning'] as String?,
        imageUrl: raw['imageUrl'] as String?,
        videoUrl: raw['videoUrl'] as String?,
      ),
    );
  }

  /// Ép kiểu số khoan dung: chấp nhận int, num, hoặc String số ("12").
  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  @override
  ArtifactInfo? getCachedArtifact(int major, int minor) =>
      _cache[_key(major, minor)];

  /// Đóng HTTP client. Gọi khi tear down app nếu cần (không bắt buộc với
  /// singleton sống suốt vòng đời app).
  void dispose() => _client.close();
}