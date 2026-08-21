// Destination: lib/presentation/exhibits/turntable_view.dart
//
// Dải ảnh xoay 360° của một hiện vật — LỚP MẶT của sân khấu màn 04c.
//
// ─────────────────────────────────────────────────────────────────────────────
// VÌ SAO KHÔNG PHẢI BỘ DỰNG 3D THẬT
//
// Bản vẽ 04c yêu cầu hiện vật *"tự xoay sẵn khi màn mở ra"*. Đo trên máy thực
// địa (docs/M0-baseline.md) cho thấy bộ dựng 3D thật cần **2.6–13.6 giây** tới
// khung hình đầu và **~200 MB** bộ nhớ cố định của Chromium — một cái giá không
// trả nổi mỗi lần khách mở một hiện vật, và đo bằng phép đối chứng trên Chrome
// thì đó là giá của chính Chromium, không giảm được bằng ngân sách nội dung.
//
// Dải ảnh này hiện TỨC THÌ, tốn ~0.8 MB, và được render bằng CHÍNH
// `<model-viewer>` ở khâu đóng gói — nên khi khách chạm để mở 3D thật thì hai
// lớp trông giống hệt nhau, không có cú nhảy thị giác nào.
//
// ─────────────────────────────────────────────────────────────────────────────
// ⚠ CÁI BẪY BỘ NHỚ, VÀ VÌ SAO FILE NÀY DÀI HƠN VẺ NGOÀI CỦA NÓ
//
// "Chỉ là hiện vài tấm ảnh" là cách đọc sai. 24 khung 720×720 giải nén ra RGBA
// là **24 × 720 × 720 × 4 ≈ 149 MB** — trên máy 1.79 GB thì tự nó là một vụ
// OOM, và nó sẽ xảy ra ở đúng cái lớp ta chọn VÌ nó rẻ.
//
// Nên widget này giữ một CỬA SỔ TRƯỢT: chỉ những khung quanh khung đang xem
// được nạp, phần còn lại bị đẩy khỏi bộ đệm ảnh của Flutter một cách CHỦ ĐỘNG.
// `ImageCache` mặc định cho phép tới 100 MB và sẽ vui vẻ giữ cả dải — nên
// không thể trông chờ vào nó, phải tự gọi `evict`.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// Số khung giữ trong bộ đệm mỗi bên khung đang xem.
///
/// 2 là đủ để vuốt tay không thấy khựng (ở 30°/s thì một khung sống ~83ms, và
/// giải nén một WebP 720px mất vài ms), mà đỉnh bộ nhớ vẫn chỉ khoảng
/// 5 khung × 2 MB = 10 MB thay vì 149 MB.
const int _kWindow = 2;

class TurntableView extends StatefulWidget {
  /// Đường dẫn tuyệt đối từng khung, theo đúng thứ tự vòng xoay.
  final List<String> frames;

  /// Cạnh hiển thị tính bằng pixel vật lý — dùng làm `cacheWidth`.
  ///
  /// BẮT BUỘC, không có mặc định: giải nén ở kích thước gốc thay vì kích thước
  /// hiển thị là đúng cái sai làm nên con số 149 MB ở trên.
  final int decodeWidth;

  /// Có tự xoay khi vừa hiện ra không. Chạm/kéo luôn giành lại quyền điều khiển.
  final bool autoRotate;

  /// Chạm (không kéo) — dùng để mở 3D thật ở lớp trên.
  final VoidCallback? onTap;

  final String? semanticLabel;

  const TurntableView({
    super.key,
    required this.frames,
    required this.decodeWidth,
    this.autoRotate = true,
    this.onTap,
    this.semanticLabel,
  });

  @override
  State<TurntableView> createState() => _TurntableViewState();
}

class _TurntableViewState extends State<TurntableView>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// Vị trí trong dải, tính bằng KHUNG và có phần thập phân. Giữ số thực thay
  /// vì số nguyên để tốc độ tự xoay không bị lượng tử hoá theo số khung —
  /// 24 khung ở 30°/s là 2 khung/giây, và làm tròn mỗi nhịp ticker sẽ cho ra
  /// một chuyển động giật.
  double _pos = 0;

  /// Khách đã chạm vào chưa. Một lần chạm là tắt tự xoay VĨNH VIỄN cho lần
  /// hiện này: sau khi khách đã tự xoay tới góc họ muốn, việc vật lại tiếp tục
  /// quay đi là giành lại quyền điều khiển từ tay họ.
  bool _touched = false;

  int get _index => _pos.floor() % widget.frames.length;

  @override
  void initState() {
    super.initState();
    if (widget.autoRotate) _startTicker();
    // Nạp sẵn cửa sổ đầu tiên sau khi có context.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWindow());
  }

  @override
  void didUpdateWidget(TurntableView old) {
    super.didUpdateWidget(old);
    if (old.frames != widget.frames) {
      _pos = 0;
      _touched = false;
      _syncWindow();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    // Trả lại TOÀN BỘ dải, không chỉ cửa sổ. Khách đi qua vài chục hiện vật
    // trong một buổi, và mỗi lần rời màn mà để lại 10 MB thì tổng lại thành
    // đúng vụ OOM mà cả kiến trúc này sinh ra để tránh.
    for (final f in widget.frames) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(f)));
    }
    super.dispose();
  }

  void _startTicker() {
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      // 30°/s — khớp `auto-rotate` mặc định của model-viewer, nên lớp mặt và
      // lớp 3D thật quay cùng tốc độ và việc chuyển giữa chúng không lộ.
      final framesPerSecond = widget.frames.length * (30 / 360);
      _advance(dt * framesPerSecond);
    })
      ..start();
  }

  void _advance(double delta) {
    final before = _index;
    _pos = (_pos + delta) % widget.frames.length;
    if (_pos < 0) _pos += widget.frames.length;
    if (_index != before) {
      setState(_syncWindow);
    }
  }

  /// Nạp cửa sổ quanh khung hiện tại và ĐẨY RA phần ngoài cửa sổ.
  ///
  /// Gọi `evict` chủ động chứ không tin `ImageCache` tự lo: trần mặc định của
  /// nó là 100 MB, thừa sức ôm cả dải 24 khung, nên nếu không đẩy thì đỉnh bộ
  /// nhớ vẫn là toàn bộ dải — chỉ chậm hơn một chút.
  void _syncWindow() {
    if (!mounted) return;
    final n = widget.frames.length;
    final keep = <int>{
      for (var d = -_kWindow; d <= _kWindow; d++) (_index + d + n * 2) % n,
    };

    final cache = PaintingBinding.instance.imageCache;
    for (var i = 0; i < n; i++) {
      final provider = FileImage(File(widget.frames[i]));
      if (keep.contains(i)) {
        // Nạp trước để khung kế đã sẵn sàng khi tới lượt — không có bước này
        // thì mỗi lần đổi khung là một lần chờ giải nén, và vòng xoay giật đều.
        unawaited(precacheImage(provider, context).catchError((_) {}));
      } else {
        cache.evict(provider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) return const SizedBox.shrink();

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      button: widget.onTap != null,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onHorizontalDragStart: (_) => _grab(),
        onHorizontalDragUpdate: (d) {
          // Một chiều rộng màn hình kéo ngang = một vòng trọn vẹn. Tỉ lệ này
          // là thứ quyết định cảm giác: nhạy hơn thì vật giật khỏi tay, chậm
          // hơn thì khách phải vuốt nhiều lần mới xem hết một vòng.
          final w = context.size?.width ?? 1;
          _advance(-d.delta.dx / w * widget.frames.length);
          setState(_syncWindow);
        },
        // ⚠ PHẢI ÉP CHIẾM TRỌN KHUNG, KHÔNG ĐỂ ẢNH TỰ ĐỊNH CỠ.
        //
        // Sân khấu đưa xuống ràng buộc LỎNG (Stack mặc định `StackFit.loose`,
        // căn `topStart`). Dưới ràng buộc lỏng, `Image` tự lấy kích thước NỘI
        // TẠI của ảnh đã giải nén — mà ta giải nén ở `decodeWidth` tính bằng
        // pixel VẬT LÝ (720 trên máy thực địa), trong khi Flutter đọc con số ấy
        // như pixel LOGIC. Trên màn 360 logic thì ảnh đòi rộng 720, tràn ra
        // ngoài, và Stack neo nó ở mép trái.
        //
        // Triệu chứng đúng như đã gặp: "hình nằm bị lệch về trái". Nó không
        // lệch — nó to gấp đôi và bị cắt mất nửa phải.
        //
        // `SizedBox.expand` biến ràng buộc lỏng thành chặt theo đúng khung cha,
        // rồi `BoxFit.contain` mới có cái để căn giữa.
        child: SizedBox.expand(
          child: Image.file(
            File(widget.frames[_index]),
            fit: BoxFit.contain,
            cacheWidth: widget.decodeWidth,
            // Giữ khung CŨ trên màn cho tới khi khung mới giải nén xong. Không
            // có cờ này thì mỗi lần đổi khung có một nhịp trống, và cả vòng
            // xoay nhấp nháy.
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  void _grab() {
    if (_touched) return;
    _touched = true;
    _ticker?.stop();
  }
}

/// Chọn ra dải khung để hiện, hoặc null nếu hiện vật này không có dải nào.
///
/// Tách khỏi widget để màn 04c hỏi được câu "có dải ảnh không" TRƯỚC khi dựng
/// bố cục — sân khấu cần biết khung đầu là một vòng xoay hay một tấm ảnh tĩnh
/// ngay từ lúc tính khung, không phải sau khi một Future trả về.
typedef TurntableLoader = Future<List<String>> Function(String modelId);

/// Bọc [TurntableView] trong một Future: hiện [placeholder] cho tới khi dải ảnh
/// sẵn sàng, rồi đổi sang vòng xoay.
///
/// Placeholder ở đây LUÔN là ảnh poster từ bundle, nên khung đầu của sân khấu
/// không bao giờ trống — kể cả khi model chưa tải, tải hỏng, hay máy chủ chưa
/// dựng dải ảnh nào.
class TurntableOrPoster extends StatelessWidget {
  final Future<List<String>> frames;
  final Widget placeholder;
  final int decodeWidth;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const TurntableOrPoster({
    super.key,
    required this.frames,
    required this.placeholder,
    required this.decodeWidth,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
        future: frames,
        builder: (context, snap) {
          final list = snap.data;
          if (list == null || list.isEmpty) return placeholder;
          return TurntableView(
            frames: list,
            decodeWidth: decodeWidth,
            onTap: onTap,
            semanticLabel: semanticLabel,
          );
        },
      );
}
