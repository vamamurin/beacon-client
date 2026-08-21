// Destination: lib/presentation/exhibits/model_route.dart
//
// Mô hình 3D thật, toàn màn hình. Lớp SAU CÙNG của sân khấu màn 04c:
//
//     mở màn      → turntable (tức thì, ~0.8 MB, xem turntable_view.dart)
//     chạm        → màn này  (~200 MB, 2.6–13.6 giây)
//
// ─────────────────────────────────────────────────────────────────────────────
// VÌ SAO NÓ PHẢI NẰM SAU MỘT CÚ CHẠM, KHÔNG PHẢI Ở KHUNG ĐẦU
//
// Đo trên máy thực địa (docs/M0-baseline.md):
//
//     khung hình đầu     3.81 s lần đầu · 2.59 s những lần sau
//     bộ nhớ            +462 MB trên hai tiến trình
//     thu hồi khi nhả   chỉ 22 % tức thì, phần còn lại thu hồi chậm
//     hệ quả            LMK giết Play Store / Play Services để nuôi app này
//
// Phép đối chứng bằng Chrome trên chính máy đó cho thấy ~200 MB là **giá cố
// định của Chromium**, không giảm được bằng ngân sách nội dung. Nên cách duy
// nhất để cái giá ấy không thường trực là để khách CHỦ ĐỘNG yêu cầu nó, trong
// một route có thể đóng.
//
// Bản vẽ 04c yêu cầu vật tự xoay khi màn mở ra — yêu cầu ấy do lớp turntable
// đáp ứng, và nó đáp ứng bằng chính hình ảnh mà màn này sẽ dựng, nên chuyển
// giữa hai lớp không lộ.
//
// ─────────────────────────────────────────────────────────────────────────────
// BA RÀNG BUỘC (docs/M0-baseline.md §7.3), và mỗi cái được ép ở đâu
//
//   1. Chỉ MỘT khối 3D sống tại một thời điểm  → [_alive], chặn ngay ở `open`
//   2. Nghe `didHaveMemoryPressure`             → huỷ scene, đóng route
//   3. ĐỪNG cố giết tiến trình render           → không làm gì cả; để Chromium
//      ở lại làm lần mở sau nhanh gấp 8× (717ms → 85ms)
//
// Thêm một ràng buộc của riêng bối cảnh bảo tàng: **tự đóng khi bị bỏ quên**.
// Máy được chuyền tay và bị đặt xuống; một khối 3D mở suốt là một lỗ thủng pin
// và nhiệt trên máy tản nhiệt thụ động.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/model_provider.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Bao lâu không ai chạm thì tự đóng. Đủ dài để ngắm một hiện vật, đủ ngắn để
/// một chiếc máy bị đặt xuống không nướng pin suốt buổi.
const Duration _kIdleClose = Duration(minutes: 3);

class ExhibitModelRoute extends StatefulWidget {
  final String modelId;

  const ExhibitModelRoute({super.key, required this.modelId});

  /// MỘT KHỐI 3D DUY NHẤT TRONG CẢ TIẾN TRÌNH.
  ///
  /// Trần bộ nhớ được đặt bởi khối nặng nhất; hai khối cùng lúc là hai trần
  /// cộng lại, và trên máy 1.79 GB thì đó là một vụ OOM. Chặn ở đây chứ không
  /// tin vào việc "chắc không ai mở hai lần" — nhấn nhanh hai cái vào cùng một
  /// khung là đủ để đẩy hai route.
  static bool _alive = false;

  /// Mở màn 3D. Trả về `false` nếu không mở được (đã có một khối đang sống,
  /// hoặc máy chưa có file model) — **người gọi phải có đường đi tiếp**, và
  /// đường đó là trình xem ảnh sẵn có.
  static Future<bool> open(BuildContext context, String modelId) async {
    if (_alive) return false;

    final path = await context.read<ModelProvider>().modelFile(modelId);
    if (path == null || !context.mounted) return false;

    _alive = true;
    try {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ExhibitModelRoute(modelId: modelId),
      ));
    } finally {
      _alive = false;
    }
    return true;
  }

  @override
  State<ExhibitModelRoute> createState() => _ExhibitModelRouteState();
}

class _ExhibitModelRouteState extends State<ExhibitModelRoute>
    with WidgetsBindingObserver {
  String? _path;
  bool _failed = false;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolve();
    _touch();
  }

  @override
  void dispose() {
    _idle?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _resolve() async {
    // `open` đã giải xong đường dẫn trước khi đẩy route, nên lần này gần như
    // luôn trả về ngay từ đĩa. Vẫn gọi lại thay vì truyền vào: route có thể
    // được dựng lại (đổi hướng màn), và một tham số đã cũ thì im lặng sai.
    final p = await context.read<ModelProvider>().modelFile(widget.modelId);
    if (!mounted) return;
    setState(() {
      _path = p;
      _failed = p == null;
    });
  }

  void _touch() {
    _idle?.cancel();
    _idle = Timer(_kIdleClose, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  /// Android báo động bộ nhớ TRƯỚC khi giết. Đây là phát súng cảnh báo mà log
  /// LMK cho thấy hệ thống vẫn bắn ra trong lúc đo, và app đang không nghe.
  ///
  /// Nghe được thì đường thoát rẻ nhất là NHẢ KHỐI 3D — nó là thứ nặng nhất
  /// trong tiến trình theo một khoảng cách rất xa, và khách mất một khung hình
  /// 3D còn hơn cả chuyến tham quan bị giết.
  @override
  void didHaveMemoryPressure() {
    if (!mounted) return;
    debugPrint('[ExhibitModelRoute] hệ thống báo thiếu bộ nhớ — nhả khối 3D');
    setState(() {
      _path = null;
      _failed = true;
    });
    // Đóng ở khung hình kế: gỡ khối 3D khỏi cây TRƯỚC rồi mới rời route, để
    // WebView được huỷ hẳn thay vì bị cuốn theo lúc route bị tháo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final t = context.tokens;
    final path = _path;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        // Mỗi lần chạm là một lần gia hạn. Dùng Listener chứ không GestureDetector
        // để không nuốt mất cử chỉ xoay/phóng của chính model-viewer.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _touch(),
        child: Stack(
          children: [
            Positioned.fill(
              child: _failed || path == null
                  ? Center(
                      child: _failed
                          // Không dựng chuỗi mới cho lỗi: route tự đóng và
                          // người gọi mở trình xem ảnh, nên khách thấy một
                          // đường đi tiếp chứ không thấy một câu xin lỗi.
                          ? const SizedBox.shrink()
                          : SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: t.inkOnImage),
                            ),
                    )
                  : ModelViewer(
                      key: ValueKey(path),
                      src: Uri.file(path).toString(),
                      alt: widget.modelId,
                      // Tự xoay để nối tiếp chuyển động của lớp turntable mà
                      // khách vừa rời khỏi — dừng đột ngột ở đây sẽ đọc ra như
                      // màn hình bị treo.
                      autoRotate: true,
                      cameraControls: true,
                      backgroundColor: Colors.black,
                      loading: Loading.eager,
                    ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Semantics(
                    button: true,
                    label: content.ui(UiKeys.exhibitImageClose),
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(Icons.close, color: t.inkOnImage),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
