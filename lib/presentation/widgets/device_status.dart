// Destination: lib/presentation/widgets/device_status.dart
//
// TRẠNG THÁI CỦA CÁI MÁY — dành cho NHÂN VIÊN, không dành cho khách.
//
// ═══════════════════════════════════════════════════════════════════════════
// NÓ VỪA RỜI KHỎI MÀN CHÀO, VÀ ĐÓ LÀ MỘT QUYẾT ĐỊNH SẢN PHẨM
// ═══════════════════════════════════════════════════════════════════════════
//
// Khối này từng sống trong `gate_screen.dart`, ngồi đúng chỗ nút "Bắt đầu" sẽ
// chiếm. Nó ở đó vì màn chào từng là màn nghỉ — thứ nhân viên nhìn khi nhấc máy
// khỏi dock.
//
// Màn chào nay là một tấm ÁP PHÍCH và không mang trách nhiệm nào khác: không
// thẻ trạng thái, không xin quyền, không lối vào cài đặt. Nó là một cái cổng.
// Vì vậy mọi câu hỏi "máy đã sẵn sàng chưa" chuyển sang màn Menu — nơi khách
// (và nhân viên) thật sự bắt đầu làm gì đó — và chuyển luôn HÌNH DẠNG: từ một
// thẻ nội dòng thành một HỘP THOẠI tự bật.
//
// Doc cũ của `deviceNotReadyCard` biện minh việc nó ở lại `gate_screen.dart`
// bằng câu "nó là mặt tiền công khai cho ba widget private phía dưới —
// chuyển đi sẽ phải công khai cả ba". Lý lẽ đó SAI ngay lúc viết: chuyển cả
// nhóm sang một file riêng thì ba widget kia vẫn private, chỉ private trong một
// file khác. Giữ lại đây làm bằng chứng rằng "để nguyên chỗ cũ" cần một lý do
// tốt hơn là một lý do nghe hợp lý.
//
// ═══════════════════════════════════════════════════════════════════════════
// HỘP THOẠI ĐÓNG ĐƯỢC — có chủ đích
// ═══════════════════════════════════════════════════════════════════════════
//
// Khách đóng được hộp thoại này, dù họ không phải người xử lý được vấn đề.
// Phương án chặn cứng đã bị bác vì nó nhốt khách trong một thông báo nói về một
// việc họ không có quyền làm — và nhốt luôn cả màn Hướng dẫn, thứ duy nhất còn
// hữu ích khi máy chưa dò được sóng.
//
// Lối vào tour vẫn ẩn cho tới khi máy sẵn sàng (xem `visibleMenuActions`), nên
// đóng hộp thoại KHÔNG mở ra một đường đi hỏng. Hai cơ chế, hai việc: hộp thoại
// GIẢI THÍCH, danh sách mục CHẶN.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/presentation/app/app_restarter.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Thẻ trạng thái máy, hoặc `null` khi máy đã sẵn sàng giao cho khách.
///
/// Thứ tự ưu tiên: Bluetooth trước, nội dung sau — không có sóng thì có nội
/// dung cũng không tham quan được.
///
/// Trả về `null` là một PHẦN CỦA HỢP ĐỒNG, không phải một trường hợp lười: chỗ
/// gọi dùng chính giá trị đó để biết máy đã sẵn sàng chưa (xem `deviceIsReady`
/// bên dưới và tham số `deviceReady` của `visibleMenuActions`).
Widget? deviceStatusCard({
  required StartupProvider startup,
  required StartupStatus bleStatus,
  required bool needsSync,
}) {
  if (bleStatus != StartupStatus.ready) {
    return _BleNotReady(status: bleStatus, startup: startup);
  }
  if (needsSync) return _SyncNotice(startup: startup);
  return null;
}

/// Máy đã đủ điều kiện giao cho khách chưa.
///
/// Cùng một phép kiểm với [deviceStatusCard], phát biểu bằng `bool`. Có mặt
/// riêng để chỗ gọi không phải dựng một widget rồi so `null` chỉ để hỏi một câu
/// hỏi có/không — và để hai câu trả lời không bao giờ lệch nhau.
bool deviceIsReady({
  required StartupStatus bleStatus,
  required bool needsSync,
}) =>
    bleStatus == StartupStatus.ready && !needsSync;

/// Bật hộp thoại trạng thái, và GIỮ nó cho tới khi máy sẵn sàng.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// HAI LỖI ĐÃ SỬA Ở ĐÂY — đọc trước khi "đơn giản hoá" lại
/// ═══════════════════════════════════════════════════════════════════════════
///
/// **1. Hộp thoại từng CHỤP MỘT ẢNH TĨNH của trạng thái.** Bản đầu nhận
/// `bleStatus` làm tham số rồi dựng thẻ MỘT LẦN trong `builder`. Hậu quả nhìn
/// thấy được trên máy thật: tắt Bluetooth ⇒ hộp thoại hiện đúng; bật lại ⇒ hộp
/// thoại **không đổi gì**, và nút "Thử lại" bấm cũng như không.
///
/// Nút ấy KHÔNG hỏng — `retryBluetooth()` vẫn chạy và `startup.bleStatus` vẫn
/// lật sang `ready`. Cái hỏng là không ai nghe. Thẻ này trước đây sống trong
/// `ValueListenableBuilder` của màn Menu nên nó được vẽ lại miễn phí; chuyển nó
/// vào một hộp thoại đã cắt mất sợi dây đó mà không ai để ý.
///
/// Nên `ValueListenableBuilder` phải nằm BÊN TRONG `builder` của hộp thoại.
/// Đây là bẫy chung của mọi thứ hiện qua `showDialog`: route của hộp thoại là
/// một nhánh riêng của cây, nó KHÔNG dựng lại khi màn gọi nó dựng lại.
///
/// **2. Hộp thoại từng đóng được khi máy chưa sẵn sàng.** Đó là quyết định ban
/// đầu và nó đã bị lật sau khi nhìn trên máy: đóng được nghĩa là khách có thể
/// gạt thông báo đi rồi đứng trước một màn Menu không có lối vào tour và không
/// còn lời giải thích nào. Nay `barrierDismissible: false` + [PopScope] chặn cả
/// chạm-ra-ngoài lẫn nút lùi.
///
/// Cái giá đã biết và đã chấp nhận: trong lúc bị chặn, khách không đọc được màn
/// Hướng dẫn. Đổi lại, trạng thái bị chặn giờ là một trạng thái **tự thoát** —
/// bật Bluetooth lên là hộp thoại tự đóng, không cần chạm gì.
Future<void> showDeviceStatusDialog(
  BuildContext context, {
  required StartupProvider startup,
}) async {
  final t = context.tokens;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: ValueListenableBuilder<StartupStatus>(
        valueListenable: startup.bleStatus,
        builder: (ctx, bleStatus, _) {
          final card = deviceStatusCard(
            startup: startup,
            bleStatus: bleStatus,
            needsSync: startup.needsSync,
          );

          // MÁY ĐÃ SẴN SÀNG ⇒ TỰ ĐÓNG. Post-frame vì ta đang ở giữa một lần
          // dựng cây; pop tại chỗ là gỡ chính cái đang được dựng.
          if (card == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final nav = Navigator.of(ctx);
              if (nav.canPop()) nav.pop();
            });
            return const SizedBox.shrink();
          }

          return Dialog(
            backgroundColor: t.surface,
            shape: RoundedRectangleBorder(borderRadius: t.sharpAll),
            insetPadding: const EdgeInsets.all(AppSpace.gutter),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: card,
            ),
          );
        },
      ),
    ),
  );
}

/// Khung thẻ nhân viên (sync notice / BLE not ready). Gom lại từ hai bản sao
/// giống hệt nhau: cùng padding, cùng viền, cùng bo góc, chỉ khác ruột.
///
/// Hai thẻ này chiếm ĐÚNG vị trí mà _StartButton sẽ chiếm, nên chúng phải
/// ngồi trên cùng đường dọc — chuyện đó do Padding của màn lo, thẻ chỉ cần
/// KHÔNG tự thêm lề ngang của riêng mình.
class _StaffCard extends StatelessWidget {
  final String title;
  final String body;
  final Widget? action;
  const _StaffCard({required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        border: Border.all(color: t.outline), // xem doc token; trước là ink@.35
        borderRadius: t.sharpAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vai trò kicker tự viết hoa — call site truyền chuỗi thường.
          // Trước đây có HAI lối làm song song trong cùng file này:
          // _BleNotReady viết hoa sẵn trong literal, _SyncNotice gọi
          // .toUpperCase() ở call site. Hai lối làm = không có luật nào.
          Text(title.toUpperCase(),
              style: AppText.kicker.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.x2), // trong khối: kicker -> thân
          Text(body, style: AppText.guidance.copyWith(color: t.inkMuted)),
          if (action != null) ...[
            const SizedBox(height: AppSpace.x3), // thân -> hành động
            action!,
          ],
        ],
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
    final content = context.read<ContentProvider>();
    setState(() {
      _syncing = false;
      _readyToRestart = report.readyToRestart;
      _message = switch (report.status) {
        SyncStatus.updated =>
          content.uif(UiKeys.gateSyncUpdated, {'version': report.version ?? ''}),
        SyncStatus.upToDate =>
          content.uif(UiKeys.gateSyncUpToDate, {'version': report.version ?? ''}),
        SyncStatus.noConnectivity => content.ui(UiKeys.gateSyncNoConnectivity),
        SyncStatus.failed =>
          content.uif(UiKeys.gateSyncFailed, {'error': report.error ?? ''}),
        SyncStatus.mockMode => content.ui(UiKeys.gateSyncMockMode),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    return _StaffCard(
      title: content.ui(_readyToRestart
          ? UiKeys.gateSyncDoneTitle
          : UiKeys.gateSyncNotReadyTitle),
      body: _message ?? content.ui(UiKeys.gateSyncFreshBody),
      action: _syncing
          ? _ProgressLine(progress: _progress)
          : _readyToRestart
              ? _StaffButton(
                  label: content.ui(UiKeys.gateSyncRestartCta),
                  onPressed: () => context.read<AppRestarter>().call(),
                )
              : _StaffButton(
                  label: content.ui(UiKeys.gateSyncSyncCta), onPressed: _sync),
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

({String title, String body, String cta, bool opensSettings}) _copy(
      ContentProvider content) {
    switch (widget.status) {
      case StartupStatus.permissionDenied:
        return (
          title: content.ui(UiKeys.gateBlePermTitle),
          body: content.ui(UiKeys.gateBlePermBody),
          cta: content.ui(UiKeys.gateBlePermCta),
          opensSettings: false,
        );
      case StartupStatus.permissionPermanentlyDenied:
        return (
          title: content.ui(UiKeys.gateBleDeniedTitle),
          body: content.ui(UiKeys.gateBleDeniedBody),
          cta: content.ui(UiKeys.gateBleDeniedCta),
          opensSettings: true,
        );
      case StartupStatus.bluetoothOff:
        return (
          title: content.ui(UiKeys.gateBleOffTitle),
          body: content.ui(UiKeys.gateBleOffBody),
          cta: content.ui(UiKeys.gateBleRetryCta),
          opensSettings: false,
        );
      case StartupStatus.unsupported:
        return (
          title: content.ui(UiKeys.gateBleUnsupportedTitle),
          body: content.ui(UiKeys.gateBleUnsupportedBody),
          cta: '',
          opensSettings: false,
        );
      default:
        return (
          title: content.ui(UiKeys.gateBleCheckingTitle),
          body: content.ui(UiKeys.gateBleCheckingBody),
          cta: content.ui(UiKeys.gateBleRetryCta),
          opensSettings: false,
        );
    }
  }

  Future<void> _act() async {
    final content = context.read<ContentProvider>();
    final c = _copy(content);
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
    final content = context.watch<ContentProvider>();
    final c = _copy(content);
    return _StaffCard(
      title: c.title,
      body: c.body,
      action: c.cta.isEmpty
          ? null
          : _busy
              ? const _ProgressLine(progress: null)
              : _StaffButton(label: c.cta, onPressed: _act),
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
      excludeSemantics: true, // + onTap: xem doc ở _StartButton
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: t.sharpAll,
          child: Container(
            // 44 trước đây DƯỚI sàn a11y 48dp — nút nhân viên vẫn là nút, và
            // nhân viên vẫn có ngón tay. AppSpace.tap = 48.
            height: AppSpace.tap,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // t.outline, không phải `ink @ 0.35`. Viền này là TOÀN BỘ dấu
              // hiệu "đây là nút" — nút không có nền. Ở 0.35 nó cho 2.18:1
              // trên nền giấy, tức dưới sàn 3:1 của WCAG 1.4.11: nút mất tư
              // cách nút ở đúng preset sáng.
              border: Border.all(color: t.outline),
              borderRadius: t.sharpAll,
            ),
            // Vai trò AppText.button tự viết hoa; call site truyền chuỗi
            // thường. Semantics phía trên nhận `label` chưa hoa — đúng thứ
            // screen reader cần đọc.
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
              // Track = một phần của control ⇒ t.outline. `ink @ 0.25` cho
              // 2.40:1 trên welcomeBackdrop: thấy được vệt đã chạy, không thấy
              // được đoạn còn lại.
              backgroundColor: t.outline,
              valueColor: AlwaysStoppedAnimation<Color>(t.ink),
            ),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(width: AppSpace.x3),
          Text('${(progress! * 100).round()}%',
              style: AppText.timeCode.copyWith(color: t.inkMuted)),
        ],
      ],
    );
  }
}