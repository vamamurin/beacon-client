// Destination: lib/data/repositories/model_store.dart
//
// Kho mô hình 3D trên máy, ĐÁNH ĐỊA CHỈ BẰNG NỘI DUNG (content-addressed).
//
// ─────────────────────────────────────────────────────────────────────────────
// VÌ SAO KHÔNG NHÉT `.glb` VÀO BUNDLE NỘI DUNG
//
// `ContentSyncService` tải NGUYÊN KHỐI và thay NGUYÊN KHỐI: sửa một dấu phẩy
// trong manifest ⇒ tải lại toàn bộ. Ở 7.5 MB thì không ai để ý. Model 3D đưa
// bundle lên hàng trăm MB, và lúc đó "sửa một chữ = tải lại 300 MB" trở thành
// một lỗi thiết kế, cộng thêm ~3× dung lượng tạm lúc giải nén.
//
// Nên model đi đường riêng, TỪNG FILE MỘT, và bundle chính giữ nguyên nhỏ +
// nguyên tử. Hai cơ chế, hai nhịp cập nhật, đúng với hai loại dữ liệu.
//
// ─────────────────────────────────────────────────────────────────────────────
// VÌ SAO TÊN FILE LÀ SHA256
//
// Tên file = băm của chính nội dung. Bốn thứ có được miễn phí:
//
//   1. KHÔNG BAO GIỜ TẢI LẠI thứ không đổi. CMS xuất lại một model, băm không
//      đổi ⇒ máy đã có ⇒ bỏ qua. Không cần trường "version" cho từng model,
//      không cần so ngày sửa file.
//   2. GỘP TRÙNG. Hai hiện vật dùng chung một model chỉ tốn một bản trên đĩa.
//   3. TÊN KHÔNG THỂ ĐỤNG NHAU, và không mang ký tự lạ từ CMS. Băm là
//      [a-f0-9]{64}, xác thực được bằng một regex.
//   4. TẢI DỞ KHÔNG BAO GIỜ BỊ ĐỌC NHẦM. File chỉ mang tên băm SAU khi đã
//      verify; trước đó nó là `<sha>.part`.
//
// Điểm 4 chính là hợp đồng của `ContentSyncService`, thu nhỏ lại cho một file:
// tại mọi thời điểm, một đường dẫn `<sha>.glb` tồn tại NGHĨA LÀ nội dung ở đó
// đã được kiểm băm. Không có trạng thái lưng chừng nào đọc được.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:beacon_client/data/repositories/bundle_layout.dart';

/// Một mô hình như máy chủ khai báo nó trong `models.json`.
@immutable
class ModelRef {
  /// Khoá ổn định do CMS đặt ("tuong-phat"). Dùng cho log và cho manifest trỏ
  /// tới; KHÔNG dùng làm tên file — tên file là [sha256].
  final String id;

  /// Đường dẫn trên máy chủ, tương đối với base URL ("models/tuong-phat.glb").
  final String file;

  /// Băm của nội dung. Vừa là tên file trên máy, vừa là thứ được verify.
  final String sha256;

  /// Dung lượng khai báo, để hiện tiến trình và để chặn trước khi tải.
  final int bytes;

  /// Nhãn cho người vận hành đọc. Không phải chuỗi giao diện khách.
  final String? label;

  const ModelRef({
    required this.id,
    required this.file,
    required this.sha256,
    required this.bytes,
    this.label,
  });

  /// Đọc một phần tử của `models.json`. Trả null nếu bản ghi không dùng được —
  /// KHÔNG ném. Cùng luật với `exhibit.images` trong ManifestParser: một model
  /// khai sai không được phép làm hỏng cả danh mục, vì các model khác vẫn tải
  /// và xem được.
  static ModelRef? tryParse(Object? raw, List<String> warnings) {
    if (raw is! Map<String, dynamic>) {
      warnings.add('models.json: phần tử không phải object — bỏ');
      return null;
    }
    final id = raw['id'];
    final file = raw['file'];
    final sha = raw['sha256'];
    final bytes = raw['bytes'];

    if (id is! String || id.isEmpty) {
      warnings.add('models.json: thiếu "id" — bỏ');
      return null;
    }
    if (file is! String || !_filePattern.hasMatch(file)) {
      warnings.add('models.json[$id]: "file" không hợp lệ — bỏ');
      return null;
    }
    if (sha is! String || !ModelStore.isValidSha256(sha)) {
      warnings.add('models.json[$id]: "sha256" không hợp lệ — bỏ');
      return null;
    }
    if (bytes is! int || bytes <= 0) {
      warnings.add('models.json[$id]: "bytes" không hợp lệ — bỏ');
      return null;
    }
    return ModelRef(
      id: id,
      file: file,
      sha256: sha.toLowerCase(),
      bytes: bytes,
      label: raw['label'] as String?,
    );
  }

  /// Đường dẫn máy chủ: chỉ `models/…` với đuôi 3D, không `..`, không scheme.
  /// Cùng hình dạng với `ManifestParser._pathRule` — một chuỗi từ mạng đi vào
  /// một URL thì phải được chứng minh vô hại, không phải được tin tưởng.
  static final RegExp _filePattern =
      RegExp(r'^(?!.*\.\.)models/[A-Za-z0-9_./-]+\.(glb|gltf)$');

  @override
  bool operator ==(Object other) =>
      other is ModelRef && other.sha256 == sha256 && other.id == id;

  @override
  int get hashCode => Object.hash(id, sha256);
}

/// Kết quả một lần tải.
enum ModelFetchStatus {
  /// Đã có sẵn trên máy, không chạm mạng.
  cached,

  /// Vừa tải và verify xong.
  downloaded,

  /// Không đủ chỗ trống trên đĩa — CHƯA tải.
  noSpace,

  /// Băm không khớp sau khi tải ⇒ đã vứt. Không bao giờ ghi vào kho.
  checksumMismatch,

  /// Mạng/máy chủ lỗi.
  failed,
}

@immutable
class ModelFetchResult {
  final ModelFetchStatus status;
  final File? file;
  final String? error;

  const ModelFetchResult(this.status, {this.file, this.error});

  bool get ok => file != null;
}

class ModelStore {
  ModelStore(this.rootDir, {HttpClient? client, Duration? idleTimeout})
      : _client = client ?? HttpClient(),
        _idleTimeout = idleTimeout ?? const Duration(seconds: 30);

  /// <appDocuments>/models
  final Directory rootDir;
  final HttpClient _client;
  final Duration _idleTimeout;

  /// Chừa lại chỗ trống trên đĩa sau khi tải xong. Một máy đầy ổ thì không chỉ
  /// hỏng việc tải — nó hỏng cả ghi log, ghi analytics và ghi tiến trình tour.
  /// Thà từ chối một model còn hơn làm chết cả chuyến tham quan.
  static const int _minFreeBytesAfter = 200 * 1024 * 1024;

  static final RegExp _shaPattern = RegExp(r'^[a-f0-9]{64}$');

  /// BIÊN AN TOÀN. Băm đi thẳng vào một đường dẫn hệ thống file, nên nó phải
  /// được chứng minh là 64 ký tự hex trước khi được ghép — y hệt lý do
  /// `BundleLayout.isValidVersion` tồn tại.
  static bool isValidSha256(String? s) =>
      s != null && _shaPattern.hasMatch(s.toLowerCase());

  Future<void> ensureRoot() async {
    if (!await rootDir.exists()) await rootDir.create(recursive: true);
  }

  File fileFor(String sha256) {
    if (!isValidSha256(sha256)) {
      throw ArgumentError.value(sha256, 'sha256', 'không phải băm hợp lệ');
    }
    return File(p.join(rootDir.path, '${sha256.toLowerCase()}.glb'));
  }

  File _partFor(String sha256) =>
      File(p.join(rootDir.path, '${sha256.toLowerCase()}.part'));

  /// Đã có trên máy chưa. Chỉ hỏi hệ thống file — tên file ĐÃ LÀ bằng chứng
  /// nội dung đúng (xem chú giải đầu file), nên không cần băm lại mỗi lần mở.
  Future<bool> has(String sha256) =>
      isValidSha256(sha256) ? fileFor(sha256).exists() : Future.value(false);

  /// Danh mục model từ máy chủ.
  Future<(List<ModelRef>, List<String>)> catalog(String baseUrl) async {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$base/models.json');
    final req = await _client.getUrl(uri);
    final res = await req.close().timeout(_idleTimeout);
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException('models.json HTTP ${res.statusCode}', uri: uri);
    }
    final body = await res.transform(utf8.decoder).join();
    final root = jsonDecode(body);
    final warnings = <String>[];
    final list = <ModelRef>[];

    final items = root is Map<String, dynamic> ? root['models'] : root;
    if (items is! List) {
      warnings.add('models.json: không tìm thấy mảng "models"');
      return (list, warnings);
    }
    for (final item in items) {
      final ref = ModelRef.tryParse(item, warnings);
      if (ref != null) list.add(ref);
    }
    return (list, warnings);
  }

  /// Lấy một model về, verify, rồi đưa vào kho.
  ///
  /// Đã có ⇒ trả về ngay, KHÔNG chạm mạng. Đây là lý do chính của việc đánh
  /// địa chỉ bằng nội dung, và nó có nghĩa là gọi hàm này nhiều lần thì rẻ.
  Future<ModelFetchResult> fetch(
    String baseUrl,
    ModelRef ref, {
    void Function(double progress)? onProgress,
  }) async {
    await ensureRoot();

    final dest = fileFor(ref.sha256);
    if (await dest.exists()) {
      return ModelFetchResult(ModelFetchStatus.cached, file: dest);
    }

    // Kiểm chỗ trống TRƯỚC khi tải. `ContentSyncService` hiện không làm bước
    // này (nợ đã ghi nhận); ở đây làm ngay vì model là thứ nặng nhất bundle
    // từng phải mang, và hỏng vì đầy ổ giữa chừng là hỏng khó hiểu nhất.
    final free = await BundleLayout.freeBytesFor(rootDir.path);
    if (free != null && free - ref.bytes < _minFreeBytesAfter) {
      return ModelFetchResult(
        ModelFetchStatus.noSpace,
        error: 'còn ${_mb(free)} MB, cần ${_mb(ref.bytes)} MB '
            'và phải chừa ${_mb(_minFreeBytesAfter)} MB',
      );
    }

    final part = _partFor(ref.sha256);
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$base/${ref.file}');

    try {
      // Tải vào `.part` — KHÔNG bao giờ vào đường dẫn cuối. Tiến trình bị giết
      // giữa chừng chỉ để lại rác mang tên `.part`, không để lại một file
      // `<sha>.glb` cụt mà lần mở sau tin là đủ.
      int existing = 0;
      if (await part.exists()) existing = await part.length();

      final req = await _client.getUrl(uri);
      if (existing > 0) {
        req.headers.add(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      final res = await req.close().timeout(_idleTimeout);

      IOSink sink;
      int total;
      switch (res.statusCode) {
        case HttpStatus.partialContent:
          sink = part.openWrite(mode: FileMode.append);
          total = existing + res.contentLength;
          break;
        case HttpStatus.ok:
          if (await part.exists()) await part.delete();
          sink = part.openWrite(mode: FileMode.write);
          existing = 0;
          total = res.contentLength;
          break;
        default:
          return ModelFetchResult(ModelFetchStatus.failed,
              error: 'HTTP ${res.statusCode}');
      }

      var got = existing;
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          got += chunk.length;
          if (onProgress != null && total > 0) {
            onProgress((got / total).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // Verify TRƯỚC khi đặt tên cuối. Băm được tính bằng cách đọc dòng
      // (openRead), không nạp cả file vào RAM — một model 20 MB trên máy 1.79 GB
      // thì đọc cả vào bộ nhớ là tự tạo một đỉnh cấp phát không cần thiết.
      final actual = await _sha256OfFile(part);
      if (actual != ref.sha256.toLowerCase()) {
        await part.delete();
        return ModelFetchResult(
          ModelFetchStatus.checksumMismatch,
          error: 'băm lệch: chờ ${ref.sha256}, nhận $actual',
        );
      }

      // Điểm chốt: rename là nguyên tử trên cùng hệ thống file.
      await part.rename(dest.path);
      if (kDebugMode) {
        debugPrint('[ModelStore] đã lấy ${ref.id} (${_mb(ref.bytes)} MB) '
            '-> ${p.basename(dest.path)}');
      }
      return ModelFetchResult(ModelFetchStatus.downloaded, file: dest);
    } on Exception catch (e) {
      return ModelFetchResult(ModelFetchStatus.failed, error: '$e');
    }
  }

  /// Xoá mọi thứ không nằm trong [keep], kể cả rác `.part`.
  ///
  /// Nhận DANH SÁCH GIỮ LẠI chứ không phải danh sách xoá: sau này bộ dọn chạy
  /// từ manifest, và "giữ những gì còn được trỏ tới" là phép toán đúng — một
  /// danh sách xoá sẽ bỏ sót đúng những file mà không ai còn nhớ tới.
  Future<int> sweep(Set<String> keep) async {
    if (!await rootDir.exists()) return 0;
    var removed = 0;
    await for (final e in rootDir.list()) {
      if (e is! File) continue;
      final name = p.basenameWithoutExtension(e.path);
      if (p.extension(e.path) == '.glb' && keep.contains(name)) continue;
      await e.delete();
      removed++;
    }
    return removed;
  }

  Future<int> usedBytes() async {
    if (!await rootDir.exists()) return 0;
    var total = 0;
    await for (final e in rootDir.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<String> _sha256OfFile(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  static String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);

  void close() => _client.close(force: true);
}
