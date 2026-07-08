// Destination: lib/presentation/gate/gate_screen.dart
//
// Screen 1 — welcome / session gate. Matches giaodien.html screen 1 1:1:
// full-bleed hero image + veil, wordmark top, welcome block bottom, white
// "Bắt đầu tham quan" button. Wired to SessionProvider + AppGraph.
//
// Navigation is owned by the root (MuseumApp): pressing Start just calls
// session.startTour(); the root moves the stack when touring begins/ends.
//
// Real state it handles (in priority order):
//   • BLE not ready -> staff status + retry/settings. REACTIVE: it listens to
//     graph.bleStatus, and re-checks readiness when the app resumes (returning
//     from Settings), so granting permission flips the screen to Start WITHOUT
//     an app restart.
//   • fresh device (repository.lastError set) -> staff "needs sync" notice. A
//     successful sync requires a rebuild (the pipeline was built with no
//     config), so the notice offers a real in-app "Khởi động lại" button.
//   • otherwise -> Start button, enabled only when the session is at the gate.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/presentation/app/app_restarter.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the app (e.g. after granting permission in Settings):
    // re-derive BLE readiness without prompting. Flips to Start if now ready.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppGraph>().refreshBluetoothOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final graph = context.read<AppGraph>();

    final museumName = graph.repository.config?.museumName;
    final lang = graph.repository.config?.fallbackLanguage ?? 'vi';
    final needsSync = graph.repository.lastError != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed hero (bundle image later; gradient fallback for now).
          const HeroImage(
            filePath: null, // Screen 1 has no zone image; use fallback tone.
            veil: _welcomeVeil,
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Wordmark, top-left.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      museumName?.resolve(lang, lang) ?? 'Bảo tàng',
                      style: AppText.wordmark,
                    ),
                  ),
                ),

                const Spacer(),

                // Welcome text block, bottom.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Hướng dẫn tham quan tự động'.toUpperCase(),
                          style: AppText.kicker),
                      const SizedBox(height: 6),
                      const Text('Chào mừng\nquý khách',
                          style: AppText.heroTitle),
                      const SizedBox(height: 8),
                      const Text(
                        'Ứng dụng tự nhận biết khu trưng bày quanh bạn qua '
                        'sóng beacon — không cần tìm kiếm. Cắm tai nghe để '
                        'nghe thuyết minh.',
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontWeight: FontWeight.w300,
                          fontSize: 11,
                          height: 1.6,
                          color: Color(0xFFD0D0D0),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Bottom action area. Rebuilds on BLE-status change (grant /
                // enable BT) via bleStatus, and on session change via the outer
                // watch. Branches: BLE not ready -> needs sync -> Start.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: ValueListenableBuilder<StartupStatus>(
                    valueListenable: graph.bleStatus,
                    builder: (context, bleStatus, _) =>
                        _buildAction(context, graph, session, bleStatus, needsSync),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, AppGraph graph,
      SessionProvider session, StartupStatus bleStatus, bool needsSync) {
    // BLE not ready takes precedence — no tour possible without scanning.
    if (bleStatus != StartupStatus.ready) {
      return _BleNotReady(status: bleStatus, graph: graph);
    }
    if (needsSync) {
      return _SyncNotice(graph: graph);
    }
    return _StartButton(
      enabled: session.isAtGate,
      onPressed: session.startTour, // root navigates when phase -> touring
    );
  }

  static const LinearGradient _welcomeVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF000000), Color(0x59000000), Color(0x8C000000)],
    stops: [0.10, 0.55, 1.0],
  );
}

/// White uppercase CTA, matching .startbtn.
class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _StartButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bắt đầu tham quan',
      child: Material(
        color: enabled ? AppColors.white : const Color(0xFF6E6E6E),
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 48, // >= 48dp tap target (accessibility)
            alignment: Alignment.center,
            child: Text('Bắt đầu tham quan'.toUpperCase(), style: AppText.button),
          ),
        ),
      ),
    );
  }
}

/// Fresh-device state: content not yet synced. Shown to museum STAFF. A
/// successful sync arms an in-app restart (the pipeline was built without a
/// config and must be rebuilt to pick up the just-synced beacon UUID / params).
class _SyncNotice extends StatefulWidget {
  final AppGraph graph;
  const _SyncNotice({required this.graph});

  @override
  State<_SyncNotice> createState() => _SyncNoticeState();
}

class _SyncNoticeState extends State<_SyncNotice> {
  bool _syncing = false;
  double _progress = 0;
  String? _message;
  bool _readyToRestart = false; // sync succeeded -> offer restart

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _progress = 0;
      _message = null;
      _readyToRestart = false;
    });
    final res = await widget.graph.runSync(
      onProgress: (p) => setState(() => _progress = p),
    );
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _syncing = false;
        _message = 'Chế độ mock — không có server.';
      });
      return;
    }
    final ok = res.outcome.name == 'updated' || res.outcome.name == 'upToDate';
    setState(() {
      _syncing = false;
      _readyToRestart = ok;
      _message = switch (res.outcome.name) {
        'updated' =>
          'Đã tải nội dung ${res.version}. Nhấn để khởi động lại và bắt đầu.',
        'upToDate' =>
          'Nội dung đã là bản mới nhất (${res.version}). Nhấn để khởi động lại.',
        'noConnectivity' => 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
        _ => 'Đồng bộ thất bại: ${res.error ?? ""}',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text((_readyToRestart ? 'Đã tải xong' : 'Chưa sẵn sàng').toUpperCase(),
              style: AppText.kicker.copyWith(color: AppColors.white)),
          const SizedBox(height: 6),
          Text(
            _message ??
                'Thiết bị chưa có nội dung tham quan. Nhấn Đồng bộ để tải '
                    'dữ liệu trước khi bàn giao cho khách.',
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontWeight: FontWeight.w300,
              fontSize: 11,
              height: 1.5,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 12),
          if (_syncing)
            _ProgressLine(progress: _progress)
          else if (_readyToRestart)
            _StaffButton(
              label: 'Khởi động lại ứng dụng',
              onPressed: () => context.read<AppRestarter>().call(),
            )
          else
            _StaffButton(label: 'Đồng bộ nội dung', onPressed: _sync),
        ],
      ),
    );
  }
}

/// BLE not ready: permission denied / bluetooth off / unsupported. Staff-facing
/// with a retry or settings CTA matching the reason. The action re-checks
/// readiness and, on success, the Gate's bleStatus flips it to the Start button
/// (no restart) — and returning from Settings auto-rechecks on resume.
class _BleNotReady extends StatefulWidget {
  final StartupStatus status;
  final AppGraph graph;
  const _BleNotReady({required this.status, required this.graph});

  @override
  State<_BleNotReady> createState() => _BleNotReadyState();
}

class _BleNotReadyState extends State<_BleNotReady> {
  bool _busy = false;

  ({String title, String body, String cta, bool opensSettings}) get _copy {
    switch (widget.status) {
      case StartupStatus.permissionDenied:
        return (
          title: 'CẦN QUYỀN BLUETOOTH',
          body: 'Ứng dụng cần quyền Bluetooth để nhận diện khu trưng bày. '
              'Nhấn để cấp quyền.',
          cta: 'Cấp quyền',
          opensSettings: false,
        );
      case StartupStatus.permissionPermanentlyDenied:
        return (
          title: 'QUYỀN BỊ TỪ CHỐI',
          body: 'Quyền Bluetooth đã bị tắt. Mở Cài đặt để bật, rồi quay lại — '
              'ứng dụng sẽ tự nhận.',
          cta: 'Mở cài đặt',
          opensSettings: true,
        );
      case StartupStatus.bluetoothOff:
        return (
          title: 'BLUETOOTH ĐANG TẮT',
          body: 'Vui lòng bật Bluetooth để tiếp tục.',
          cta: 'Thử lại',
          opensSettings: false,
        );
      case StartupStatus.unsupported:
        return (
          title: 'THIẾT BỊ KHÔNG HỖ TRỢ',
          body: 'Thiết bị này không hỗ trợ Bluetooth Low Energy.',
          cta: '',
          opensSettings: false,
        );
      default:
        return (
          title: 'ĐANG KIỂM TRA',
          body: 'Đang kiểm tra Bluetooth…',
          cta: 'Thử lại',
          opensSettings: false,
        );
    }
  }

  Future<void> _act() async {
    final c = _copy;
    setState(() => _busy = true);
    if (c.opensSettings) {
      // Open settings; the Gate's resume handler re-checks when we come back.
      await widget.graph.bluetoothGate.openSettings();
    } else {
      // Request/re-check now. On success, graph.bleStatus flips and this whole
      // widget is replaced by the Start button.
      await widget.graph.retryBluetooth();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.title,
              style: AppText.kicker.copyWith(color: AppColors.white)),
          const SizedBox(height: 6),
          Text(c.body,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontWeight: FontWeight.w300,
                fontSize: 11,
                height: 1.5,
                color: AppColors.grey,
              )),
          if (c.cta.isNotEmpty) ...[
            const SizedBox(height: 12),
            _busy
                ? const _ProgressLine(progress: null)
                : _StaffButton(label: c.cta, onPressed: _act),
          ],
        ],
      ),
    );
  }
}

/// Bordered staff button (distinct from the white visitor CTA).
class _StaffButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _StaffButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grey),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: AppColors.white)),
          ),
        ),
      ),
    );
  }
}

/// Indeterminate or progress line during sync / retry.
class _ProgressLine extends StatelessWidget {
  final double? progress;
  const _ProgressLine({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppColors.line,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(width: 10),
          Text('${(progress! * 100).round()}%',
              style: AppText.timeCode.copyWith(color: AppColors.grey)),
        ],
      ],
    );
  }
}