// Destination: lib/presentation/debug/model_lab_screen.dart
//
// ⚠ SPIKE M0 — DỤNG CỤ ĐO, KHÔNG PHẢI TÍNH NĂNG. Màn này tồn tại để trả lời một
// câu hỏi và rồi biến mất: *một bộ dựng 3D thời gian thực có sống nổi trên máy
// thực địa, BÊN CẠNH một chuyến tham quan đang chạy hay không?*
//
// Nó KHÔNG phải bản nháp của màn 04c. Màn 04c đã có bố cục đúng theo bản vẽ và
// không được đụng tới cho tới khi 3D thật vào chỗ đó. Xem docs/M0-baseline.md.
//
// ─────────────────────────────────────────────────────────────────────────────
// CHỈ CÒN MỘT BỘ DỰNG
//
// Bản trước của màn này có bộ chọn giữa `model_viewer_plus` và `flutter_scene`.
// `flutter_scene` đã bị loại bằng thực nghiệm ngày 18/08/2026: nó khởi tạo
// được trên máy không Vulkan (32ms) và phân tích glTF nhanh gấp đôi WebView
// (1.96s), nhưng ở khung hình đầu thì backend OpenGL ES của Impeller gặp uniform
// sai kiểu và engine abort — `SIGABRT` trên luồng raster, giết cả tiến trình
// cùng foreground service, BLE và audio.
//
// Đó là khác biệt quyết định giữa hai đường: WebView hỏng thì hệ điều hành hy
// sinh tiến trình khác và chuyến tham quan sống; `flutter_scene` hỏng thì
// chuyến tham quan chết theo. Chi tiết ở docs/M0-baseline.md §8.
//
// ─────────────────────────────────────────────────────────────────────────────
// MODEL ĐẾN TỪ MÁY CHỦ, KHÔNG TỪ ASSETS
//
// Bản đầu của màn này nhúng hai mẫu `.glb` vào `assets/` — nghĩa là mỗi lần đổi
// model phải build lại app. Sai ngay cả với một dụng cụ đo: nó biến một vòng
// thử 30 giây thành một vòng build vài phút, và nó dựng một đường nạp model
// KHÁC với đường sản phẩm thật sẽ dùng, nên số đo nói về sai thứ.
//
// Nay model đi qua [ModelStore] — đúng cơ chế sẽ chạy trong sản phẩm: máy chủ
// khai `models.json`, máy tải từng file, đánh địa chỉ bằng sha256, verify rồi
// mới dùng. Đội CMS thả một `.glb` mới lên máy chủ là thử được ngay, không cần
// ai build hộ. Khi Lab này bị xoá, [ModelStore] Ở LẠI.
//
// ─────────────────────────────────────────────────────────────────────────────
// VÌ SAO MÀN NÀY TRÔNG THÔ NHƯ VẬY
//
// Mọi thứ ở đây phục vụ phép đo, không phục vụ con mắt:
//
//   • Khối 3D chỉ ĐƯỢC DỰNG khi bấm nạp, và bị GỠ KHỎI CÂY khi bấm nhả. Nhờ vậy
//     hiệu số PSS trước/sau đọc bằng `dumpsys meminfo` quy được về đúng một
//     nguyên nhân. Một widget chỉ bị `Visibility` che đi thì WebView vẫn sống và
//     con số sẽ nói dối.
//   • Mốc thời gian được ghi bằng `Stopwatch` chứ không phải DateTime — ta cần
//     KHOẢNG CÁCH giữa hai sự kiện, và đồng hồ tường có thể bị chỉnh giữa chừng.
//   • Nhật ký hiện thẳng trên màn, vì người cầm máy đứng cạnh hiện vật chứ không
//     ngồi cạnh `logcat`.
//
// KHÔNG DÙNG ui() Ở ĐÂY. Mọi chuỗi hiển thị của app phải lấy nguyên văn từ
// bundle nội dung — đó là luật, và luật ấy nói về giao diện KHÁCH nhìn thấy.
// Màn này nhân viên kỹ thuật không bao giờ giao cho khách, và nhét mấy chục
// khoá đo đạc vào manifest sẽ bắt đội CMS dịch một thứ sắp bị xoá.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/data/repositories/model_store.dart';
import 'package:beacon_client/data/repositories/sync_config.dart';
import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

class ModelLabScreen extends StatefulWidget {
  const ModelLabScreen({super.key});

  @override
  State<ModelLabScreen> createState() => _ModelLabScreenState();
}

class _ModelLabScreenState extends State<ModelLabScreen> {
  ModelStore? _store;
  List<ModelRef> _catalog = const [];
  final Set<String> _onDisk = {};
  ModelRef? _picked;

  /// Đường dẫn file của model đang được dựng. Null ⇒ không có khối 3D nào sống.
  String? _mountedPath;
  bool _autoRotate = true;
  bool _busy = false;
  double? _progress;

  final Stopwatch _clock = Stopwatch();
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _store?.close();
    super.dispose();
  }

  void _note(String line) {
    final ms = _clock.elapsedMilliseconds > 0 || _clock.isRunning
        ? '${_clock.elapsedMilliseconds}ms'
        : '·';
    final entry = '[$ms] $line';
    debugPrint('[ModelLab] $entry');
    if (mounted) setState(() => _log.insert(0, entry));
  }

  String get _baseUrl =>
      SyncConfig.baseUrlFrom(context.read<SettingsProvider>().baseUrlOverride);

  Future<void> _open() async {
    final docs = await getApplicationDocumentsDirectory();
    final store = ModelStore(Directory(p.join(docs.path, 'models')));
    if (!mounted) return;
    setState(() => _store = store);
    await _refresh();
  }

  Future<void> _refresh() async {
    final store = _store;
    if (store == null) return;
    setState(() => _busy = true);
    try {
      final (list, warnings) = await store.catalog(_baseUrl);
      for (final w in warnings) {
        _note('⚠ $w');
      }
      final present = <String>{};
      for (final m in list) {
        if (await store.has(m.sha256)) present.add(m.sha256);
      }
      if (!mounted) return;
      setState(() {
        _catalog = list;
        _onDisk
          ..clear()
          ..addAll(present);
        _picked ??= list.isEmpty ? null : list.first;
      });
      _note('danh mục: ${list.length} model, ${present.length} đã có trên máy');
    } on Exception catch (e) {
      _note('⚠ không đọc được models.json từ $_baseUrl — $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Tải model đã chọn về kho. Tách RIÊNG khỏi việc nạp lên màn: thời gian tải
  /// mạng không được lẫn vào "thời gian tới khung hình đầu", nếu không thì con
  /// số ấy nói về tốc độ Wi-Fi chứ không nói về bộ dựng.
  Future<void> _download() async {
    final store = _store;
    final ref = _picked;
    if (store == null || ref == null) return;

    setState(() {
      _busy = true;
      _progress = 0;
    });
    final res = await store.fetch(_baseUrl, ref,
        onProgress: (v) => mounted ? setState(() => _progress = v) : null);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
      if (res.ok) _onDisk.add(ref.sha256);
    });

    _note(switch (res.status) {
      ModelFetchStatus.cached => '${ref.id}: đã có sẵn, không chạm mạng',
      ModelFetchStatus.downloaded => '${ref.id}: tải + verify xong',
      ModelFetchStatus.noSpace => '${ref.id}: KHÔNG ĐỦ CHỖ — ${res.error}',
      ModelFetchStatus.checksumMismatch => '${ref.id}: BĂM LỆCH — ${res.error}',
      ModelFetchStatus.failed => '${ref.id}: LỖI — ${res.error}',
    });
  }

  void _load() {
    final store = _store;
    final ref = _picked;
    if (store == null || ref == null) return;
    _log.clear();
    _clock
      ..reset()
      ..start();
    setState(() => _mountedPath = store.fileFor(ref.sha256).path);
    _note('nạp ${ref.id}');
  }

  /// Nhả khối 3D RA KHỎI CÂY WIDGET, không chỉ ẩn đi.
  ///
  /// Đây là nửa sau của phép đo và nó quan trọng ngang nửa đầu. Đo được:
  /// nhả chỉ thu hồi ~22% tức thời, và `Graphics` có thể còn TĂNG sau đó —
  /// nhưng nạp một model nhẹ hơn thì nó tụt, nên là thu hồi chậm chứ không
  /// phải rò rỉ tích luỹ. Chi tiết ở docs/M0-baseline.md §6.10–6.11.
  void _unload() {
    setState(() => _mountedPath = null);
    _note('đã nhả — đo lại PSS lúc này');
    _clock.stop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ready = _picked != null && _onDisk.contains(_picked!.sha256);

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: t.ink),
        title:
            Text('Model Lab', style: AppText.sheetTitle.copyWith(color: t.ink)),
        actions: [
          IconButton(
            tooltip: 'Đọc lại models.json',
            onPressed: _busy ? null : _refresh,
            icon: Icon(Icons.refresh, color: t.ink),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── SÂN KHẤU ─────────────────────────────────────────────────────
          // Tỉ lệ 50% chiều cao, cùng tỉ lệ với sân khấu thật của màn 04c, để
          // con số fps đo được ở đây nói về đúng diện tích pixel mà bản thật
          // sẽ phải tô. Đo trên một khung nhỏ hơn rồi suy ra là tự lừa mình.
          Expanded(
            child: Container(
              width: double.infinity,
              color: t.surfaceRaised,
              child: _mountedPath == null ? _idlePlate(t) : _viewer(t),
            ),
          ),

          // ── BẢNG ĐIỀU KHIỂN ──────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter, AppSpace.x4, AppSpace.gutter, AppSpace.x6),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MODEL TRÊN MÁY CHỦ',
                        style: AppText.kicker.copyWith(color: t.inkFaint)),
                    if (_busy)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, value: _progress, color: t.accent),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.x2),
                if (_catalog.isEmpty)
                  Text(
                    _busy
                        ? 'đang đọc…'
                        : 'Không có model nào.\n$_baseUrl/models.json',
                    style: AppText.stopMeta.copyWith(color: t.inkFaint),
                  )
                else
                  for (final m in _catalog) _modelRow(t, m),
                const SizedBox(height: AppSpace.x5),

                Text('ĐIỀU KHIỂN',
                    style: AppText.kicker.copyWith(color: t.inkFaint)),
                const SizedBox(height: AppSpace.x2),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _busy || _picked == null || ready ? null : _download,
                        child: const Text('TẢI VỀ'),
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: FilledButton(
                        onPressed: ready && _mountedPath == null ? _load : null,
                        child: const Text('NẠP'),
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _mountedPath == null ? null : _unload,
                        child: const Text('NHẢ'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _autoRotate,
                  // Tự xoay = tải GPU LIÊN TỤC; tắt = tải khi chạm. Hai chế độ
                  // này cho hai đường nhiệt hoàn toàn khác nhau, và bản vẽ 04c
                  // yêu cầu "tự xoay sẵn" nên đường nhiệt xấu mới là đường thật.
                  title: Text('Tự xoay (tải GPU liên tục)',
                      style: AppText.meta.copyWith(color: t.ink)),
                  onChanged: (v) => setState(() {
                    _autoRotate = v;
                    // Đổi cờ này phải dựng lại khối 3D mới có tác dụng, nên nếu
                    // đang nạp thì nhả ra để người đo không đọc nhầm một con số
                    // của chế độ cũ và ghi vào cột của chế độ mới.
                    _mountedPath = null;
                  }),
                ),
                const SizedBox(height: AppSpace.x5),

                Text('NHẬT KÝ',
                    style: AppText.kicker.copyWith(color: t.inkFaint)),
                const SizedBox(height: AppSpace.x2),
                if (_log.isEmpty)
                  Text('(chưa có gì)',
                      style: AppText.stopMeta.copyWith(color: t.inkFaint))
                else
                  for (final line in _log)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(line,
                          style: AppText.stopMeta.copyWith(color: t.inkMuted)),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tấm chờ khi chưa nạp. Ghi rõ mốc nền cần đọc TRƯỚC khi bấm nạp — người đo
  /// quên bước này thì cả phép đo mất nghĩa, và nhắc ở đây rẻ hơn đo lại.
  Widget _idlePlate(MuseumTokens t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: Text(
            'Chưa nạp.\n\n'
            'Đọc mốc nền TRƯỚC khi bấm NẠP:\n'
            'adb shell dumpsys meminfo com.example.beacon_client',
            textAlign: TextAlign.center,
            style: AppText.stopMeta.copyWith(color: t.inkFaint),
          ),
        ),
      );

  Widget _modelRow(MuseumTokens t, ModelRef m) {
    final on = m.sha256 == _picked?.sha256;
    final cached = _onDisk.contains(m.sha256);
    return InkWell(
      // Đổi model khi đang nạp cũng phải dựng lại — cùng lý do với cờ tự xoay.
      onTap: () => setState(() {
        _picked = m;
        _mountedPath = null;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18, color: on ? t.accent : t.inkFaint),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label ?? m.id,
                      style: AppText.meta
                          .copyWith(color: on ? t.ink : t.inkMuted)),
                  Text(
                    '${(m.bytes / 1024 / 1024).toStringAsFixed(2)} MB · '
                    '${cached ? "đã có trên máy" : "chưa tải"}',
                    style: AppText.stopMeta
                        .copyWith(color: cached ? t.inkFaint : t.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khối `<model-viewer>` thật.
  ///
  /// `key` mang đường dẫn + chế độ xoay: đổi một trong hai thì Flutter dựng một
  /// State mới thay vì tái dùng cái cũ, nên WebView cũ được huỷ hẳn. Không có
  /// key này thì hai phép đo liên tiếp có thể dùng chung một WebView đã ấm sẵn,
  /// và thời gian tới khung hình đầu sẽ đẹp một cách giả tạo.
  Widget _viewer(MuseumTokens t) => ModelViewer(
        key: ValueKey('$_mountedPath-$_autoRotate'),
        // `file://` — model nằm trong kho trên máy, KHÔNG trong assets và KHÔNG
        // tải qua mạng lúc này. Mạng đã xong ở bước TẢI VỀ, nên con số đo được
        // dưới đây là chi phí của bộ dựng, không lẫn tốc độ Wi-Fi.
        src: Uri.file(_mountedPath!).toString(),
        id: 'mv',
        alt: _picked?.label ?? _picked?.id ?? 'model',
        autoRotate: _autoRotate,
        cameraControls: true,
        // Nền trùng màu sân khấu để không có một khung xám nhảy ra lúc chuyển.
        backgroundColor: t.surfaceRaised,
        // `loading: eager` — ta ĐANG đo chi phí nạp, nên hoãn nạp là làm hỏng
        // chính thứ cần đo.
        loading: Loading.eager,
        // Bắt sự kiện `load` của chính model-viewer và bắn ngược về Dart. Đây là
        // cách duy nhất lấy được "thời gian tới khung hình đầu" bằng máy thay vì
        // bằng mắt và một chiếc đồng hồ bấm tay.
        relatedJs: '''
          document.addEventListener('DOMContentLoaded', function () {
            const mv = document.querySelector('#mv');
            if (!mv) return;
            mv.addEventListener('load', function () {
              LabProbe.postMessage('model-viewer: load (khung hình đầu)');
            });
            mv.addEventListener('error', function (e) {
              LabProbe.postMessage('model-viewer: LỖI ' + (e.detail || ''));
            });
          });
        ''',
        javascriptChannels: {
          JavascriptChannel('LabProbe',
              onMessageReceived: (msg) => _note(msg.message)),
        },
        onWebViewCreated: (_) => _note('WebView đã tạo (Chromium khởi động)'),
      );
}
