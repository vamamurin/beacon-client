// Destination: lib/presentation/gate/gate_screen.dart
//
// Screen 1 — welcome / session gate. Full-bleed hero image + veil, wordmark
// top, welcome block bottom, CTA button. Wired to SessionProvider,
// StartupProvider + ContentProvider.
//
// Navigation is owned by the root (MuseumApp): pressing Start just calls
// session.startTour(); the root moves the stack when touring begins/ends.
//
// Real state it handles (in priority order):
//   • BLE not ready -> staff status + retry/settings. REACTIVE: listens to
//     startup.bleStatus and re-checks readiness on resume (returning from
//     Settings), so granting permission flips to Start WITHOUT a restart.
//   • fresh device (needsSync) -> staff "needs sync" notice. A successful sync
//     requires a rebuild (the pipeline was built with no config), so the notice
//     offers a real in-app "Khởi động lại" button.
//   • otherwise -> Start button, enabled only when the session is at the gate.
//
// ═══════════════════════════════════════════════════════════════════════════
// THIS ENTIRE SCREEN IS ON-IMAGE
// ═══════════════════════════════════════════════════════════════════════════
// The root is a Stack whose first child is HeroImage. Wordmark, welcome copy,
// Start button, sync notice and BLE notice ALL sit on top of it. So every
// colour here comes from the on-image family (inkOnImage, mutedOnImage,
// lineOnImage, ctaOnImage*), which does not follow the theme.
//
// Consequence, and it is correct: the Gate stays dark even in light theme. The
// photograph doesn't brighten, so neither can the text on it. Reaching for
// t.ink here would print #141414 on a dark gradient in light mode — the whole
// welcome screen would disappear.

import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/presentation/app/app_restarter.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

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
      context.read<StartupProvider>().refreshBluetoothOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final session = context.watch<SessionProvider>();
    final startup = context.read<StartupProvider>();
    final content = context.watch<ContentProvider>();

    final museumName = content.textOrNull(content.museumName) ?? 'Bảo tàng';
    final needsSync = startup.needsSync;

    return Scaffold(
      backgroundColor: t.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed hero (bundle image later; gradient fallback for now).
          HeroImage(
            filePath: null, // Screen 1 has no zone image; use fallback tone.
            veil: t.welcomeVeil,
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Wordmark, top-left.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          museumName,
                          style:
                              AppText.wordmark.copyWith(color: t.inkOnImage),
                        ),
                      ),
                      // Nằm trên HeroImage -> họ on-image, không phải t.ink.
                      // mutedOnImage chứ không inkOnImage: đây là chức năng
                      // phụ, không được cạnh tranh thị giác với wordmark.
                      Semantics(
                        button: true,
                        label: 'Cài đặt',
                        child: IconButton(
                          icon: Icon(Icons.settings_outlined,
                              color: t.mutedOnImage, size: 22),
                          // IconButton mặc định đã 48x48 — đủ tap target.
                          tooltip: 'Cài đặt',
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppRouter.settingsRoute),
                        ),
                      ),
                    ],
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
                          style: AppText.kicker.copyWith(color: t.mutedOnImage)),
                      const SizedBox(height: 6),
                      Text('Chào mừng\nquý khách',
                          style:
                              AppText.heroTitle.copyWith(color: t.inkOnImage)),
                      const SizedBox(height: 8),
                      Text(
                        'Ứng dụng tự nhận biết khu trưng bày quanh bạn qua '
                        'sóng beacon — không cần tìm kiếm. Cắm tai nghe để '
                        'nghe thuyết minh.',
                        style: AppText.guidance
                            .copyWith(color: t.mutedOnImage, height: 1.6),
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
                    valueListenable: startup.bleStatus,
                    builder: (context, bleStatus, _) => _buildAction(
                        context, startup, session, bleStatus, needsSync),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, StartupProvider startup,
      SessionProvider session, StartupStatus bleStatus, bool needsSync) {
    // BLE not ready takes precedence — no tour possible without scanning.
    if (bleStatus != StartupStatus.ready) {
      return _BleNotReady(status: bleStatus, startup: startup);
    }
    if (needsSync) {
      return _SyncNotice(startup: startup);
    }
    return _StartButton(
      enabled: session.isAtGate,
      onPressed: session.startTour, // root navigates when phase -> touring
    );
  }
}

/// Visitor CTA, on the image: white fill, dark label, at every theme.
class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _StartButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: 'Bắt đầu tham quan',
      child: Material(
        color: enabled ? t.ctaOnImageFill.withValues(alpha: 0.35) : t.ctaDisabled,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: t.sharpAll,
          child: Container(
            height: 48, // >= 48dp tap target (accessibility)
            alignment: Alignment.center,
            child: Text('Bắt đầu tham quan'.toUpperCase(),
                style: AppText.button.copyWith(color: t.ctaOnImageInk)),
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
  final StartupProvider startup;
  const _SyncNotice({required this.startup});

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

    final report = await widget.startup.runSync(
      // mounted check inside the callback too: sync is the longest-running
      // operation in the app, and progress ticks keep arriving after a pop.
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _readyToRestart = report.readyToRestart;
      _message = switch (report.status) {
        SyncStatus.updated =>
          'Đã tải nội dung ${report.version}. Nhấn để khởi động lại và bắt đầu.',
        SyncStatus.upToDate =>
          'Nội dung đã là bản mới nhất (${report.version}). Nhấn để khởi động lại.',
        SyncStatus.noConnectivity =>
          'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
        SyncStatus.failed => 'Đồng bộ thất bại: ${report.error ?? ""}',
        SyncStatus.mockMode => 'Chế độ mock — không có server.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: t.lineOnImage),
        borderRadius: t.sharpAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text((_readyToRestart ? 'Đã tải xong' : 'Chưa sẵn sàng').toUpperCase(),
              style: AppText.kicker.copyWith(color: t.inkOnImage)),
          const SizedBox(height: 6),
          Text(
            _message ??
                'Thiết bị chưa có nội dung tham quan. Nhấn Đồng bộ để tải '
                    'dữ liệu trước khi bàn giao cho khách.',
            style: AppText.guidance.copyWith(color: t.mutedOnImage),
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
  final StartupProvider startup;
  const _BleNotReady({required this.status, required this.startup});

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
      await widget.startup.openBluetoothSettings();
    } else {
      await widget.startup.retryBluetooth();
    }
    // The widget may be replaced by _StartButton once bleStatus flips.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _copy;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: t.lineOnImage),
        borderRadius: t.sharpAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.title, style: AppText.kicker.copyWith(color: t.inkOnImage)),
          const SizedBox(height: 6),
          Text(c.body, style: AppText.guidance.copyWith(color: t.mutedOnImage)),
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

/// Bordered staff button — visually distinct from the filled visitor CTA, so a
/// visitor never mistakes "Đồng bộ nội dung" for "start my tour".
class _StaffButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _StaffButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: t.sharpAll,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: t.lineOnImage),
              borderRadius: t.sharpAll,
            ),
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: t.inkOnImage)),
          ),
        ),
      ),
    );
  }
}

/// Indeterminate or determinate progress line during sync / retry.
class _ProgressLine extends StatelessWidget {
  final double? progress;
  const _ProgressLine({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: t.sharpAll,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: t.lineOnImage,
              valueColor: AlwaysStoppedAnimation<Color>(t.inkOnImage),
            ),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(width: 10),
          Text('${(progress! * 100).round()}%',
              style: AppText.timeCode.copyWith(color: t.mutedOnImage)),
        ],
      ],
    );
  }
}