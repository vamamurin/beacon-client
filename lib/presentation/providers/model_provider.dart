// Destination: lib/presentation/providers/model_provider.dart
//
// Cầu nối giữa màn hình và [ModelStore]: màn 04c hỏi "hiện vật này có dải ảnh
// xoay chưa?", provider này trả lời và tự lo phần tải về.
//
// ─────────────────────────────────────────────────────────────────────────────
// VÌ SAO TẢI LÚC CẦN, KHÔNG TẢI LÚC ĐỒNG BỘ
//
// Model 3D không đi trong bundle nội dung (xem [ModelStore]), nên chúng không
// tự về theo lần đồng bộ ở quầy. Có hai đường: kéo hết về ngay sau khi đồng bộ,
// hoặc kéo về khi khách mở đúng hiện vật đó.
//
// Chọn đường thứ hai, vì phần lớn khách không mở hết mọi hiện vật: kéo hết là
// bắt mọi máy tải mọi model cho một thiểu số lượt xem. Cái giá phải trả là lần
// mở đầu tiên của một hiện vật có thể chỉ thấy ảnh tĩnh trong vài giây — chấp
// nhận được, vì màn hình KHÔNG BAO GIỜ trống: poster trong bundle luôn có mặt.
//
// ⚠ Đường thứ nhất vẫn nên tồn tại về sau, chạy nền sau khi đồng bộ ở quầy khi
// máy còn cắm sạc. Nó KHÔNG mâu thuẫn với đường này — kho đánh địa chỉ theo nội
// dung nên tải trước chỉ làm cho lần hỏi sau trả lời ngay.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:beacon_client/data/repositories/model_store.dart';

class ModelProvider extends ChangeNotifier {
  ModelProvider({required String Function() baseUrl}) : _baseUrl = baseUrl;

  final String Function() _baseUrl;

  ModelStore? _store;
  Map<String, ModelRef> _catalog = const {};
  bool _catalogLoaded = false;

  /// Kết quả đã giải xong cho từng model id. Giữ chính Future chứ không giữ
  /// kết quả: hai widget hỏi cùng lúc về một hiện vật thì phải dùng chung MỘT
  /// lần tải, không phải hai.
  final Map<String, Future<List<String>>> _inflight = {};

  /// Những model đã thử và hỏng. Không thử lại trong phiên này — một máy chủ
  /// không có model ấy sẽ vẫn không có nó ở lần thứ hai, và thử lại mỗi lần
  /// khách mở hiện vật là gõ cửa máy chủ vô ích trong suốt buổi.
  final Set<String> _failed = {};

  Future<void> _ensureStore() async {
    if (_store != null) return;
    final docs = await getApplicationDocumentsDirectory();
    _store = ModelStore(Directory(p.join(docs.path, 'models')));
  }

  Future<void> _ensureCatalog() async {
    if (_catalogLoaded) return;
    await _ensureStore();
    try {
      final (list, warnings) = await _store!.catalog(_baseUrl());
      _catalog = {for (final m in list) m.id: m};
      if (kDebugMode) {
        for (final w in warnings) {
          debugPrint('[ModelProvider] $w');
        }
      }
    } on Exception catch (e) {
      // Không có danh mục ⇒ không có dải ảnh nào, và màn hình lùi về poster.
      // KHÔNG ném: mất mô hình 3D không được phép làm hỏng màn chi tiết hiện
      // vật, nơi khách còn nghe thuyết minh và xem ảnh.
      if (kDebugMode) debugPrint('[ModelProvider] không đọc được models.json: $e');
      _catalog = const {};
    }
    _catalogLoaded = true;
  }

  /// Dải khung của [modelId] trên máy. Rỗng ⇒ màn hình dùng poster.
  ///
  /// Gọi nhiều lần là rẻ: đã có trên đĩa thì không chạm mạng, và hai lần gọi
  /// đồng thời dùng chung một Future.
  Future<List<String>> turntableFrames(String modelId) {
    if (_failed.contains(modelId)) return Future.value(const []);
    return _inflight.putIfAbsent(modelId, () => _resolve(modelId));
  }

  Future<List<String>> _resolve(String modelId) async {
    await _ensureCatalog();
    final ref = _catalog[modelId];
    if (ref == null || ref.turntable == null) {
      _failed.add(modelId);
      return const [];
    }

    // Đã đủ trên đĩa thì xong ngay — đây là đường đi của mọi lần mở sau lần
    // đầu, và nó không chạm mạng.
    var frames = await _store!.turntableFrames(ref);
    if (frames.isNotEmpty) return frames;

    final res = await _store!.fetchTurntable(_baseUrl(), ref);
    if (!res.ok) {
      if (kDebugMode) {
        debugPrint('[ModelProvider] tải dải ảnh $modelId hỏng: ${res.error}');
      }
      _failed.add(modelId);
      // Bỏ khỏi _inflight để một lần thử sau (ví dụ sau khi nhân viên đồng bộ
      // lại) còn có cơ hội — _failed chặn trong phiên, không chặn vĩnh viễn.
      _inflight.remove(modelId);
      return const [];
    }

    frames = await _store!.turntableFrames(ref);
    if (frames.isNotEmpty) notifyListeners();
    return frames;
  }

  /// File `.glb` trên máy cho lớp 3D thật, hoặc null nếu chưa có.
  /// Chưa dùng ở M3; lớp toàn màn hình (M4) sẽ gọi nó.
  Future<String?> modelFile(String modelId) async {
    await _ensureCatalog();
    final ref = _catalog[modelId];
    if (ref == null) {
      debugPrint('[ModelProvider] "$modelId" không có trong models.json — '
          'kiểm lại exhibit.model.id trong manifest');
      return null;
    }
    if (await _store!.has(ref.sha256)) return _store!.fileFor(ref.sha256).path;

    final res = await _store!.fetch(_baseUrl(), ref);
    if (!res.ok) {
      // GHI LẠI LÝ DO. Người gọi chỉ nhận null và lùi về trình xem ảnh, nên
      // nếu không log ở đây thì triệu chứng duy nhất là "3D không bao giờ mở
      // được" — không có gì chỉ ra vì sao. Đã mất một vòng gỡ lỗi vì đúng
      // chuyện này (ngưỡng dung lượng trống từ chối trong im lặng).
      debugPrint('[ModelProvider] tải model "$modelId" hỏng: '
          '${res.status.name} — ${res.error}');
    }
    return res.file?.path;
  }

  @override
  void dispose() {
    _store?.close();
    super.dispose();
  }
}
