// Destination: lib/presentation/gate/gate_screen.dart
//
// Screen 1 — welcome / session gate. Matches giaodien.html screen 1 1:1:
// full-bleed hero image + veil, wordmark top, welcome block bottom, white
// "Bắt đầu tham quan" button. Wired to SessionProvider.
//
// Beyond the static mockup it handles real state:
//   • fresh device (repository.lastError set) -> staff "needs sync" notice
//     instead of a Start button (a tour with no content would be broken).
//   • pressing Start -> session.startTour() -> phase becomes touring -> navigate
//     to the zone screen.
//   • listens to phase: when touring begins, route forward (covers both the
//     button tap and, later, any programmatic start).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  SessionPhase? _lastPhase;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final graph = context.read<AppGraph>();

    // React to phase transitions: entering touring -> go to the zone screen.
    _handlePhase(session.phase);

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

                // Bottom action area, branches on device readiness:
                //  • BLE not ready  -> status + retry/settings (staff)
                //  • needs sync     -> sync notice + "Đồng bộ" button (staff)
                //  • otherwise      -> Start button (visitor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: _buildAction(context, graph, session, needsSync),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, AppGraph graph,
      SessionProvider session, bool needsSync) {
    // BLE not ready takes precedence — no tour possible without scanning.
    if (graph.startupStatus != StartupStatus.ready) {
      return _BleNotReady(status: graph.startupStatus, graph: graph);
    }
    if (needsSync) {
      return _SyncNotice(
        error: graph.repository.lastError!,
        graph: graph,
      );
    }
    return _StartButton(
      enabled: session.isAtGate,
      onPressed: session.startTour,
    );
  }

  void _handlePhase(SessionPhase phase) {
    if (phase == _lastPhase) return;
    final was = _lastPhase;
    _lastPhase = phase;
    // On the edge into touring, navigate forward once (post-frame to avoid
    // navigating during build).
    if (was != null && phase == SessionPhase.touring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRouter.zoneRoute);
      });
    }
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

/// Fresh-device state: content not yet synced. Shown to museum STAFF, with a
/// working "Đồng bộ nội dung" button that runs the real sync pipeline.
class _SyncNotice extends StatefulWidget {
  final String error;
  final AppGraph graph;
  const _SyncNotice({required this.error, required this.graph});

  @override
  State<_SyncNotice> createState() => _SyncNoticeState();
}

class _SyncNoticeState extends State<_SyncNotice> {
  bool _syncing = false;
  double _progress = 0;
  String? _result;

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _progress = 0;
      _result = null;
    });
    final res = await widget.graph.runSync(
      onProgress: (p) => setState(() => _progress = p),
    );
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _syncing = false;
        _result = 'Chế độ mock — không có server.';
      });
      return;
    }
    // On success, re-warm the repository so the tour has content.
    if (res.outcome.name == 'updated' || res.outcome.name == 'upToDate') {
      await widget.graph.repository.preWarm();
    }
    setState(() {
      _syncing = false;
      _result = switch (res.outcome.name) {
        'updated' => 'Đã cập nhật ${res.version}. Khởi động lại ứng dụng.',
        'upToDate' => 'Đã là bản mới nhất (${res.version}).',
        'noConnectivity' => 'Không kết nối được máy chủ.',
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
          Text('CHƯA SẴN SÀNG'.toUpperCase(),
              style: AppText.kicker.copyWith(color: AppColors.white)),
          const SizedBox(height: 6),
          Text(
            _result ??
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
          else
            _StaffButton(label: 'Đồng bộ nội dung', onPressed: _sync),
        ],
      ),
    );
  }
}

/// BLE not ready: permission denied / bluetooth off / unsupported. Staff-facing
/// with a retry or settings CTA matching the reason.
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
          body: 'Quyền Bluetooth đã bị tắt. Vui lòng bật lại trong Cài đặt.',
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
      await widget.graph.bluetoothGate.openSettings();
    } else {
      // Retry the readiness check; if ready, prompt an app restart so the
      // pipeline (which only starts at boot) comes up cleanly.
      await widget.graph.bluetoothGate.ensureReady();
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