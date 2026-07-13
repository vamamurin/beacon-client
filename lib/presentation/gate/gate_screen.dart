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
// MÀN NÀY ĐÃ QUAY VỀ HỌ SURFACE (đi theo theme)
// ═══════════════════════════════════════════════════════════════════════════
// Lịch sử: bản đầu là ảnh full màn ⇒ mọi chữ nằm TRÊN ẢNH ⇒ bắt buộc dùng họ
// on-image cố định (ảnh không sáng lên theo theme). Từ khi chuyển sang
// collage — HAI khung ảnh tự chứa đặt trên nền phẳng `welcomeBackdrop` — chữ
// không còn nằm trên ảnh nữa, tiền đề của on-image biến mất.
//
// Quy tắc màu hiện tại của màn này:
//   • Nền: t.welcomeBackdrop (theo theme; ấm hơn surface, cùng độ chói).
//   • Chữ: t.ink / t.inkMuted — như mọi màn surface khác.
//   • CTA: t.ctaFill / t.ctaLabel / t.ctaDisabled.
//   • Đường kẻ/khung: KHÔNG dùng t.line (nó tinh chỉnh cho `surface`, gần như
//     tàng hình trên backdrop ấm) — dùng t.ink với alpha, tự đúng ở mọi theme.
//   • Họ on-image KHÔNG xuất hiện ở đây nữa; nó vẫn là quy tắc cho chữ nằm
//     trên ảnh ở các màn 2/3/player.

import 'dart:ui' as ui show ImageFilter;

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
      backgroundColor: t.welcomeBackdrop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Nền ambient + collage HAI vùng ảnh + scrim đáy. Thay cho
          // HeroImage full-bleed trước đây — xem doc của _WelcomeCollage.
          _WelcomeCollage(
            primaryPath: content.welcomeImagePath,
            accentPath: content.welcomeAccentImagePath,
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tên bảo tàng, top-left — HẠ CẤP từ wordmark 30px xuống
                // kicker: màn hình chỉ được có MỘT tiêu đề, và tiêu đề đó là
                // khối "Chào mừng" phía dưới. Tên bảo tàng vẫn hiện diện,
                // nhưng nhường vai chính.
                //
                // Lối vào Cài đặt là LONG-PRESS lên tên bảo tàng — khớp thiết
                // kế đã ghi trong settings_screen.dart. Nút icon hiện rõ trước
                // đây để khách bấm được vào màn có URL máy chủ; chức năng
                // (route + điều kiện) giữ nguyên, chỉ đổi cách kích hoạt.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      label: museumName,
                      onLongPressHint: 'Mở cài đặt (dành cho nhân viên)',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => Navigator.of(context)
                            .pushNamed(AppRouter.settingsRoute),
                        child: Padding(
                          // Nới vùng chạm của long-press mà không xê chữ.
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            museumName.toUpperCase(),
                            style: AppText.kicker
                                .copyWith(color: t.inkMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),

                // Welcome text block, bottom. Kicker "HƯỚNG DẪN THAM QUAN TỰ
                // ĐỘNG" đã bỏ: chữ hoa tiếng Việt có dấu + tracking rộng đọc
                // lởm chởm, và nội dung của nó đã nằm trong câu dẫn bên dưới.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Điểm nhấn màu duy nhất của màn hình — phá thế đơn sắc
                      // trắng/xám/đen. Trang trí thuần tuý nên không Semantics.
                      Container(width: 28, height: 2, color: t.accent),
                      const SizedBox(height: 12),
                      Text('Chào mừng\nquý khách',
                          style: AppText.welcomeTitle
                              .copyWith(color: t.ink)),
                      const SizedBox(height: 30),
                      Text(
                        // Rút từ 3 ý còn 2: "không cần tìm kiếm" là hệ quả
                        // của "tự nhận biết", không cần nói riêng.
                        'Ứng dụng tự nhận biết khu trưng bày quanh bạn. '
                        'Đeo tai nghe để bắt đầu nghe thuyết minh.',
                        style: AppText.lede.copyWith(color: t.inkMuted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Bottom action area. Rebuilds on BLE-status change (grant /
                // enable BT) via bleStatus, and on session change via the outer
                // watch. Branches: BLE not ready -> needs sync -> Start.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
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

/// Lớp nền của màn chào, từ dưới lên:
///   1. Backdrop đặc [MuseumTokens.welcomeBackdrop] — lưới an toàn khi chưa
///      có ảnh và là "màu danh nghĩa" mà chữ họ surface đứng trên.
///   2. Ambient: ẢNH CHÀO CHÍNH phóng mờ mạnh + lớp phủ
///      [MuseumTokens.welcomeAmbient] (= backdrop kèm alpha theo preset).
///      Nền nhuốm hơi màu của chính tấm ảnh nên tự hoà sắc với mọi bundle,
///      nhưng nhờ lớp phủ đặc, chữ vẫn thuộc họ surface — KHÔNG quay lại
///      on-image. highContrast có alpha 100% ⇒ ambient tự tắt.
///   3. HAI KHỐI MÀU bố cục [MuseumTokens.welcomeBandLower]/[welcomeBandUpper]
///      — mảng dưới ~42%, mảng trên ~14%, cạnh cứng có chủ đích (color-block),
///      chia tường thành các tông để nền không đơn điệu.
///   4. HAI vùng ảnh đóng khung, chồng lệch (kiểu tường trưng bày), có bóng
///      đổ [MuseumTokens.frameShadow] — offset (-6, 8) hắt bóng khung 2 đè
///      lên mép khung 1, tạo chiều sâu lớp lang.
///   5. Scrim đáy màu-của-backdrop, cho MÀN NGẮN khi khối chữ neo đáy dâng
///      lên chạm mép dưới khung 2 — chữ luôn tách khỏi ảnh, đúng ở mọi theme.
///
/// Vị trí hai khung tính theo TỶ LỆ màn hình (khớp mockup thiết kế):
///   • Vùng ảnh 1 (chính): left 12%, top 20%, rộng 56%, cao 34%.
///   • Vùng ảnh 2 (phụ):  right 8%, top 30%, rộng 26%, cao 30% — vẽ SAU nên
///     nằm ĐÈ lên góc phải của vùng 1.
///
/// Suy biến có chủ đích, không nhánh lỗi nào ra broken box:
///   • [accentPath] null (bundle cũ) ⇒ chỉ vẽ vùng 1 — bố cục vẫn đứng được.
///   • [primaryPath] null ⇒ bỏ luôn lớp ambient (không tốn blur cho gradient
///     fallback); khung 1 tự vẽ fallback BÊN TRONG — giữ nhịp bố cục.
class _WelcomeCollage extends StatelessWidget {
  final String? primaryPath;
  final String? accentPath;
  const _WelcomeCollage({required this.primaryPath, required this.accentPath});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: t.welcomeBackdrop),

          // ── 2. Ambient ──
          // Decode rất nhỏ (≈1/5 bề ngang vật lý): vừa rẻ RAM vừa là một nửa
          // của chính hiệu ứng mờ (upscale ảnh nhỏ đã tự mềm). Scale 1.1 nuốt
          // viền mờ dần ở mép do blur lấy mẫu ra ngoài ảnh. RepaintBoundary
          // cô lập lớp tĩnh đắt tiền này khỏi các repaint phía trên.
          if (primaryPath != null) ...[
            RepaintBoundary(
              child: Transform.scale(
                scale: 1.1,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: HeroImage(
                    filePath: primaryPath,
                    cacheWidth: (w * 0.2 * dpr).round(),
                  ),
                ),
              ),
            ),
            ColoredBox(color: t.welcomeAmbient),
          ],

          // ── 3. Hai khối màu bố cục ──
          // Mảng dưới (~42%) và mảng trên (~14%), cạnh cứng CÓ CHỦ ĐÍCH —
          // ngôn ngữ color-block chia tường thành các tông, tránh nền đơn
          // điệu. Màu theo theme qua token (xem doc welcomeBandLower); ở
          // highContrast chúng trong suốt nên tự biến mất.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: h * 0.42,
            child: ColoredBox(color: t.welcomeBandLower),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.14,
            child: ColoredBox(color: t.welcomeBandUpper),
          ),

          // ── 4. Hai vùng ảnh ──
          Positioned(
            left: w * 0.12,
            top: h * 0.20,
            width: w * 0.56,
            height: h * 0.34,
            child: _framed(t, path: primaryPath,
                decodeWidth: (w * 0.56 * dpr).round()),
          ),
          if (accentPath != null)
            Positioned(
              right: w * 0.08,
              top: h * 0.30,
              width: w * 0.26,
              height: h * 0.30,
              child: _framed(t, path: accentPath,
                  decodeWidth: (w * 0.26 * dpr).round()),
            ),

          // ── 5. Scrim đáy — xem doc của class ──
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  t.welcomeBackdrop,
                  t.welcomeBackdrop.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Khung ảnh có bóng — dùng chung cho cả hai vùng để hai khung không bao
  /// giờ lệch nhau về bóng/bo góc khi chỉnh về sau. Màu bóng là token
  /// (theo theme); blur/offset là hình học nên sống ở đây.
  Widget _framed(MuseumTokens t,
      {required String? path, required int decodeWidth}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: t.sharpAll,
        boxShadow: [
          BoxShadow(
            color: t.frameShadow,
            blurRadius: 12,
            offset: const Offset(-6, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: t.sharpAll,
        child: HeroImage(filePath: path, cacheWidth: decodeWidth),
      ),
    );
  }
}

/// Visitor CTA — filled, dùng cặp CTA của họ surface nên tự đảo theo theme:
/// dark = nút trắng chữ đen, light = nút mực chữ giấy, HC = trắng/đen.
///
/// Disabled: nền [ctaDisabled] + chữ [inkMuted] (KHÔNG dùng [ctaLabel] — ở
/// light theme ctaLabel là màu giấy, đặt lên ctaDisabled xám nhạt sẽ chìm).
/// Contrast của cặp disabled đã soát trên cả ba preset.
class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _StartButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = enabled ? t.ctaLabel : t.inkMuted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Bắt đầu tham quan',
      child: Material(
        color: enabled ? t.ctaFill : t.ctaDisabled,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: t.sharpAll,
          child: Container(
            height: 70, // >= 48dp tap target (accessibility)
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon nhắc lại lời dẫn "đeo tai nghe" — trang trí, đã có
                // label ở Semantics bên ngoài.
                Icon(Icons.headphones, size: 16, color: fg),
                const SizedBox(width: 8),
                Text('Bắt đầu tham quan'.toUpperCase(),
                    style: AppText.button.copyWith(color: fg)),
              ],
            ),
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
        border: Border.all(color: t.ink.withValues(alpha: 0.35)),
        borderRadius: t.sharpAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text((_readyToRestart ? 'Đã tải xong' : 'Chưa sẵn sàng').toUpperCase(),
              style: AppText.kicker.copyWith(color: t.ink)),
          const SizedBox(height: 6),
          Text(
            _message ??
                'Thiết bị chưa có nội dung tham quan. Nhấn Đồng bộ để tải '
                    'dữ liệu trước khi bàn giao cho khách.',
            style: AppText.guidance.copyWith(color: t.inkMuted),
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
        border: Border.all(color: t.ink.withValues(alpha: 0.35)),
        borderRadius: t.sharpAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.title, style: AppText.kicker.copyWith(color: t.ink)),
          const SizedBox(height: 6),
          Text(c.body, style: AppText.guidance.copyWith(color: t.inkMuted)),
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
              border: Border.all(color: t.ink.withValues(alpha: 0.35)),
              borderRadius: t.sharpAll,
            ),
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: t.ink)),
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
              backgroundColor: t.ink.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(t.ink),
            ),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(width: 10),
          Text('${(progress! * 100).round()}%',
              style: AppText.timeCode.copyWith(color: t.inkMuted)),
        ],
      ],
    );
  }
}