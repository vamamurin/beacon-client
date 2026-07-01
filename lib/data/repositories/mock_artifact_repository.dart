import 'package:beacon_client/domain/interfaces/i_artifact_repository.dart';
import 'package:beacon_client/domain/models/artifact_info.dart';

/// In-memory mock standing in for the future remote catalog (REST/GraphQL).
///
/// [preWarm] simulates a single networked fetch (1 s) then caches the whole
/// catalog. Concurrent callers are coalesced onto one in-flight request, and a
/// failed attempt resets so it can be retried. [getCachedArtifact] is then a
/// synchronous O(1) map lookup — exactly the shape the BLE service needs on its
/// hot path.
class MockArtifactRepository implements IArtifactRepository {
  // Key format: (major << 16) | minor — packs both ids into one int for O(1)
  // lookup without a composite-key class (matches the BLE registry's packing).
  final Map<int, ArtifactInfo> _cache = <int, ArtifactInfo>{};

  bool _warmed = false;
  Future<void>? _inFlight;

  static int _key(int major, int minor) => (major << 16) | minor;

  @override
  Future<void> preWarm() {
    if (_warmed) return Future<void>.value();
    // Coalesce concurrent warm-ups onto a single simulated request.
    return _inFlight ??= _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    try {
      // Simulated remote round-trip latency.
      await Future<void>.delayed(const Duration(seconds: 1));
      _cache
        ..clear()
        ..addAll(_seed());
      _warmed = true;
    } finally {
      // Allow a fresh attempt if this one failed (real impl may throw).
      _inFlight = null;
    }
  }

  @override
  ArtifactInfo? getCachedArtifact(int major, int minor) =>
      _cache[_key(major, minor)];

  /// Mock dataset. In the live phase, replace with deserialized remote payloads.
  Map<int, ArtifactInfo> _seed() => {
        // ── Major 1 — Tầng 3 ───────────────────────────────────────────────
        _key(1, 1): const ArtifactInfo(
          id: 1,
          name: 'Trống đồng Ngọc Lũ',
          summary:
              'Chiếc trống đồng Đông Sơn tiêu biểu và hoàn mỹ nhất từng được '
              'phát hiện, nay là Bảo vật quốc gia. Mặt trống chạm khắc tinh xảo '
              'hoa văn hình học, đoàn người hóa trang, nhà sàn và chim Lạc '
              'quây quanh ngôi sao nhiều cánh ở trung tâm.',
          era: 'Khoảng thế kỷ I TCN – I SCN',
          material: 'Đồng',
          meaning:
              'Trống đồng không chỉ là nhạc khí mà còn là biểu tượng quyền lực '
              'của các thủ lĩnh Đông Sơn. Hình ảnh ngôi sao nhiều cánh ở giữa '
              'mặt trống tượng trưng cho thần Mặt Trời...',
          imageUrl:
              'https://images.unsplash.com/photo-1518998053901-5348d3961a04?q=80&w=1200&auto=format&fit=crop',
          videoUrl:
              'https://www.w3schools.com/html/mov_bbb.mp4',
        ),
        _key(1, 2): const ArtifactInfo(
          id: 2,
          name: 'Thạp đồng Đào Thịnh',
          summary:
              'Thạp đồng cỡ lớn của văn hóa Đông Sơn, tìm thấy tại Đào Thịnh '
              '(Yên Bái). Trên nắp gắn các khối tượng đôi, phản ánh tín ngưỡng '
              'phồn thực của cư dân nông nghiệp Việt cổ.',
          era: 'Văn hóa Đông Sơn',
          material: 'Đồng',
          meaning:
              'Hoa văn và tượng trên thạp thể hiện ước vọng sinh sôi, cầu mùa '
              'của cư dân lúa nước thời dựng nước.',
          imageUrl:
              'https://images.unsplash.com/photo-1518998053901-5348d3961a04?q=80&w=1200&auto=format&fit=crop',
          videoUrl:
              'https://www.w3schools.com/html/mov_bbb.mp4',
        ),
        // ── Major 2 — Tầng 4 ───────────────────────────────────────────────
        _key(2, 1): const ArtifactInfo(
          id: 3,
          name: 'Ấn vàng "Hoàng đế chi bảo"',
          summary:
              'Kim bảo đúc thời Nguyễn, quai tạo hình rồng cuộn, thân khắc minh '
              'văn chữ Hán. Biểu trưng cho quyền lực tối cao và tính chính danh '
              'của hoàng đế trong nghi thức ban hành chiếu chỉ.',
          era: 'Triều Nguyễn, thế kỷ XIX',
          material: 'Vàng',
          meaning:
              'Ấn vàng là vật biểu trưng cho vương quyền; mỗi lần đóng ấn là '
              'một lần khẳng định hiệu lực và chính danh của mệnh lệnh triều đình.',
          imageUrl:
              'https://images.unsplash.com/photo-1518998053901-5348d3961a04?q=80&w=1200&auto=format&fit=crop',
          videoUrl:
              'https://www.w3schools.com/html/mov_bbb.mp4',
        ),
        _key(2, 2): const ArtifactInfo(
          id: 4,
          name: 'Ấn vàng "Hoàng đế chi bảo"',
          summary:
              'Kim bảo đúc thời Nguyễn, quai tạo hình rồng cuộn, thân khắc minh '
              'văn chữ Hán. Biểu trưng cho quyền lực tối cao và tính chính danh '
              'của hoàng đế trong nghi thức ban hành chiếu chỉ.',
          era: 'Triều Nguyễn, thế kỷ XIX',
          material: 'Vàng',
          meaning:
              'Ấn vàng là vật biểu trưng cho vương quyền; mỗi lần đóng ấn là '
              'một lần khẳng định hiệu lực và chính danh của mệnh lệnh triều đình.',
          imageUrl:
              'https://images.unsplash.com/photo-1518998053901-5348d3961a04?q=80&w=1200&auto=format&fit=crop',
          videoUrl:
              'https://www.w3schools.com/html/mov_bbb.mp4',
        ),
      };
}