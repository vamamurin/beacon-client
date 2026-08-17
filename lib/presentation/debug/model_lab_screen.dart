// Destination: lib/presentation/debug/model_lab_screen.dart
//
// ⚠ SPIKE M0 — DỤNG CỤ ĐO, KHÔNG PHẢI TÍNH NĂNG. Màn này tồn tại để trả lời một
// câu hỏi và rồi biến mất: *một bộ dựng 3D thời gian thực có sống nổi trên máy
// thực địa, BÊN CẠNH một chuyến tham quan đang chạy hay không?*
//
// Nó KHÔNG phải bản nháp của màn 04c. Màn 04c đã có bố cục đúng theo bản vẽ và
// không được đụng tới cho tới khi M0 có kết luận. Xem docs/M0-baseline.md.
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

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

/// Một mẫu để đo. Hai mẫu Khronos ở đây được chọn vì chúng hỏng theo HAI KIỂU
/// KHÁC NHAU, và một phép đo chỉ chạm một kiểu là một phép đo nói nửa sự thật.
enum LabModel {
  /// 3.60 MB trên đĩa nhưng 5 texture 2048² ⇒ cận trên ~106 MB VRAM.
  /// Đây là ca "chết vì texture" — dung lượng file không hề báo trước.
  helmet(
    label: 'DamagedHelmet — 15k tam giác, 5×2048² texture',
    asset: 'assets/models_spike/DamagedHelmet.glb',
    note: '3.60 MB đĩa · cận trên ~106 MB VRAM',
  ),

  /// Không một texture nào, nhưng 34 material trên 82 node ⇒ hàng chục lần đổi
  /// trạng thái shader mỗi khung hình. Đây là ca "chết vì draw call".
  engine(
    label: '2CylinderEngine — 121k tam giác, 34 material',
    asset: 'assets/models_spike/2CylinderEngine.glb',
    note: '1.75 MB đĩa · 0 texture · 82 node',
  );

  const LabModel({
    required this.label,
    required this.asset,
    required this.note,
  });

  final String label;
  final String asset;
  final String note;
}

class ModelLabScreen extends StatefulWidget {
  const ModelLabScreen({super.key});

  @override
  State<ModelLabScreen> createState() => _ModelLabScreenState();
}

class _ModelLabScreenState extends State<ModelLabScreen> {
  LabModel _model = LabModel.helmet;
  bool _mounted3d = false;
  bool _autoRotate = true;

  /// Bắt đầu chạy đúng lúc bấm nạp. Mọi mốc dưới đây đo từ mốc đó.
  final Stopwatch _clock = Stopwatch();
  final List<String> _log = [];

  void _note(String line) {
    final ms = _clock.isRunning || _clock.elapsedMilliseconds > 0
        ? '${_clock.elapsedMilliseconds}ms'
        : '—';
    final entry = '[$ms] $line';
    debugPrint('[ModelLab] $entry');
    if (mounted) setState(() => _log.insert(0, entry));
  }

  void _load() {
    _log.clear();
    _clock
      ..reset()
      ..start();
    setState(() => _mounted3d = true);
    _note('nạp ${_model.name} — bắt đầu dựng widget');
  }

  /// Nhả khối 3D RA KHỎI CÂY WIDGET, không chỉ ẩn đi.
  ///
  /// Đây là nửa sau của phép đo và nó quan trọng ngang nửa đầu: nếu PSS không
  /// tụt về gần mốc nền sau khi nhả, nghĩa là bộ dựng RÒ RỈ — và một rò rỉ trên
  /// máy khách đi qua vài chục hiện vật trong một buổi thì tích lại thành một
  /// vụ OOM, dù mỗi lần mở đơn lẻ đều trông vô hại.
  void _unload() {
    setState(() => _mounted3d = false);
    _note('đã nhả — đo lại PSS lúc này, nó PHẢI tụt về gần mốc nền');
    _clock.stop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: t.ink),
        title: Text('Model Lab · spike M0',
            style: AppText.sheetTitle.copyWith(color: t.ink)),
      ),
      body: Column(
        children: [
          // ── SÂN KHẤU ─────────────────────────────────────────────────────
          // Tỉ lệ 50% chiều cao, cùng tỉ lệ với sân khấu thật của màn 04c, để
          // con số fps đo được ở đây nói về đúng diện tích pixel mà bản thật
          // sẽ phải tô. Đo trên một khung nhỏ hơn rồi suy ra là tự lừa mình.
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: t.surfaceRaised,
              child: _mounted3d ? _viewer(t) : _idlePlate(t),
            ),
          ),

          // ── BẢNG ĐIỀU KHIỂN ──────────────────────────────────────────────
          Expanded(
            flex: 1,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter, AppSpace.x4, AppSpace.gutter, AppSpace.x6),
              children: [
                Text('MẪU ĐO',
                    style: AppText.kicker.copyWith(color: t.inkFaint)),
                const SizedBox(height: AppSpace.x2),
                for (final m in LabModel.values) _modelRow(t, m),
                const SizedBox(height: AppSpace.x5),

                Text('ĐIỀU KHIỂN',
                    style: AppText.kicker.copyWith(color: t.inkFaint)),
                const SizedBox(height: AppSpace.x2),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _mounted3d ? null : _load,
                        child: const Text('NẠP'),
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _mounted3d ? _unload : null,
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
                    if (_mounted3d) _mounted3d = false;
                  }),
                ),
                const SizedBox(height: AppSpace.x5),

                Text('NHẬT KÝ',
                    style: AppText.kicker.copyWith(color: t.inkFaint)),
                const SizedBox(height: AppSpace.x2),
                if (_log.isEmpty)
                  Text('(chưa nạp lần nào)',
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

  Widget _modelRow(MuseumTokens t, LabModel m) {
    final on = m == _model;
    return InkWell(
      // Đổi mẫu khi đang nạp cũng phải dựng lại — cùng lý do với cờ tự xoay.
      onTap: () => setState(() {
        _model = m;
        if (_mounted3d) _mounted3d = false;
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
                  Text(m.label,
                      style: AppText.meta
                          .copyWith(color: on ? t.ink : t.inkMuted)),
                  Text(m.note,
                      style: AppText.stopMeta.copyWith(color: t.inkFaint)),
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
  /// `key` mang tên mẫu + chế độ xoay: đổi một trong hai thì Flutter dựng một
  /// State mới thay vì tái dùng cái cũ, nên WebView cũ được huỷ hẳn. Không có
  /// key này thì hai phép đo liên tiếp có thể dùng chung một WebView đã ấm sẵn,
  /// và thời gian tới khung hình đầu sẽ đẹp một cách giả tạo.
  Widget _viewer(MuseumTokens t) => ModelViewer(
        key: ValueKey('${_model.name}-$_autoRotate'),
        src: _model.asset,
        id: 'mv',
        alt: _model.label,
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
