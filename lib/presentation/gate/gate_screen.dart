// Destination: lib/presentation/gate/gate_screen.dart
//
// Screen 1 — welcome / session gate. Collage hai khung ảnh + khối chữ neo đáy
// + CTA. Wired to SessionProvider, StartupProvider + ContentProvider.
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
// LƯỚI CỦA MÀN NÀY — đọc AppSpace trước khi sửa bất kỳ khoảng cách nào
// ═══════════════════════════════════════════════════════════════════════════
//
// MỘT đường dọc trái duy nhất = AppSpace.gutter (20). Ngồi trên nó, từ trên
// xuống: tên bảo tàng · MÉP TRÁI KHUNG ẢNH CHÍNH · vạch accent · "Chào mừng"
// · câu dẫn · CTA. Sáu phần tử, một đường.
//
// Khung ảnh phụ ghim mép PHẢI vào gutter ⇒ màn có đúng hai đường dọc, và cả
// hai đều được nhắc lại ít nhất hai lần. Đó là toàn bộ lưới; không cần hơn.
//
// Nhịp dọc chỉ dùng hai mức: x3 (12) trong khối chữ, x6 (24) giữa các khối.
//
// LỖI ĐÃ SỬA (đừng để tái diễn):
//   • Khung ảnh chính từng ở `left: w * 0.08` ≈ 31dp trên máy 390 — KHÔNG
//     thẳng hàng với đường 18/20 mà chỉ gần. "Gần thẳng hàng" đọc là lỗi;
//     "lệch hẳn" mới đọc là ý đồ. Xem doc _WelcomeFrames.
//   • decodeWidth từng là hằng số rời (0.56/0.26) trong khi width đã đổi
//     (0.66/0.34) ⇒ ảnh chào bị upscale 18% và 30%. Giờ cả hai lấy từ CÙNG
//     một biến, không thể lệch lại được.
//   • _StaffButton cao 44 — DƯỚI sàn a11y 48. Giờ là AppSpace.tap.
//   • Vạch accent 88×2 bị khung ảnh đè, và đầu vạch trùng khít mép trái ảnh.
//     Nguyên nhân KHÔNG phải ảnh to: collage đo theo % màn hình còn khối chữ
//     đo theo dp từ đáy — hai hệ toạ độ trượt qua nhau, biên độ phụ thuộc cả
//     textScaler. Khung ảnh giờ sống trong `Expanded` ⇒ nó nhận đúng phần
//     thừa và không thể chạm tới chữ. Xem doc _WelcomeFrames.
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
import 'package:beacon_client/presentation/theme/app_space.dart';
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
          // NỀN — full-bleed, phẳng, KHÔNG biết gì về chữ. Xem _WelcomeBackdrop.
          _WelcomeBackdrop(primaryPath: content.welcomeImagePath),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tên bảo tàng, top-left — HẠ CẤP từ wordmark 30px xuống
                // museumName: màn hình chỉ được có MỘT tiêu đề, và tiêu đề đó
                // là khối "Chào mừng" phía dưới. Tên bảo tàng vẫn hiện diện,
                // nhưng nhường vai chính.
                //
                // LƯỚI: outer top x3 (12) + inner vertical x2 (8) = lề quang
                // học 20 = gutter. Ba cạnh trên/trái/phải cùng 20 — cố ý.
                // Đừng gộp hai padding lại: cái ngoài là LỀ, cái trong là VÙNG
                // CHẠM của long-press. Gộp thì mất một trong hai ý nghĩa.
                //
                // Lối vào Cài đặt là LONG-PRESS lên tên bảo tàng — khớp thiết
                // kế đã ghi trong settings_screen.dart. Nút icon hiện rõ trước
                // đây để khách bấm được vào màn có URL máy chủ; chức năng
                // (route + điều kiện) giữ nguyên, chỉ đổi cách kích hoạt.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter, AppSpace.x3, AppSpace.gutter, 0),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.x2),
                          child: Text(
                            museumName.toUpperCase(),
                            style:
                                AppText.museumName.copyWith(color: t.inkMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // HAI KHUNG ẢNH SỐNG Ở ĐÂY — thay cho `Spacer()`.
                //
                // Đây là toàn bộ cách chữa lỗi "vạch accent đè lên ảnh". Không
                // phải thu ảnh nhỏ đi vài phần trăm: Expanded làm khung ảnh
                // VẬT LÝ KHÔNG THỂ chạm tới chữ, trên mọi máy, ở mọi textScaler.
                // Xem doc _WelcomeFrames.
                Expanded(
                  child: _WelcomeFrames(
                    primaryPath: content.welcomeImagePath,
                    accentPath: content.welcomeAccentImagePath,
                  ),
                ),

                // Welcome text block, bottom. Kicker "HƯỚNG DẪN THAM QUAN TỰ
                // ĐỘNG" đã bỏ: chữ hoa tiếng Việt có dấu + tracking rộng đọc
                // lởm chởm, và nội dung của nó đã nằm trong câu dẫn bên dưới.
                //
                // LƯỚI: bottom = x6 (24) thay cho `SizedBox(height: 10)` rời
                // trước đây — khoảng cách giữa hai khối phải sống trong padding
                // của khối, không phải trong một SizedBox lơ lửng mà lần sửa
                // sau sẽ không ai thấy.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter, 0, AppSpace.gutter, AppSpace.x6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Điểm nhấn màu duy nhất của màn hình — phá thế đơn sắc
                      // trắng/xám/đen. Trang trí thuần tuý nên không Semantics.
                      // 88 = 4×22, nằm trên lưới.
                      Container(width: 88, height: 2, color: t.accent),
                      const SizedBox(height: AppSpace.x3),

                      // MỘT CÂU, HAI CỠ — CHỦ ĐÍCH, KHÔNG PHẢI LỖI.
                      // Hierarchy ở đây theo NHỊP ĐỌC chứ không theo nghĩa:
                      // "Chào mừng" là tiếng chào, "quý khách" là người nhận —
                      // hai vai, hai trọng lượng. Thủ pháp editorial/thời trang
                      // chuẩn mực.
                      //
                      // Khoảng cách giữa hai dòng CỐ Ý = 0: chúng là một cụm,
                      // dựng chồng sát nhau như một khối chữ tạc. `height` của
                      // hai style đã lo phần leading. Chèn SizedBox vào đây là
                      // tách chúng thành hai câu — hỏng ý đồ.
                      //
                      // Muốn thử hai FONT khác nhau: đổi trong AppText, không
                      // đổi ở đây. Xem doc của welcomeTitle/welcomeSubTitle.
                      Text('Chào mừng',
                          style: AppText.welcomeTitle.copyWith(color: t.ink)),
                      Text('quý khách',
                          style:
                              AppText.welcomeSubTitle.copyWith(color: t.ink)),

                      const SizedBox(height: AppSpace.x3),
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

                // Bottom action area. Rebuilds on BLE-status change (grant /
                // enable BT) via bleStatus, and on session change via the outer
                // watch. Branches: BLE not ready -> needs sync -> Start.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter, 0, AppSpace.gutter, AppSpace.x6),
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

/// LỚP NỀN của màn chào — full-bleed, phẳng, KHÔNG biết gì về chữ.
///
/// Từ dưới lên:
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
///   4. Scrim đáy màu-của-backdrop. LƯU Ý: scrim CỐ Ý phủ đè lên phần lớn
///      band dưới — đó không phải tai nạn. Nâu đất đặc + scrim backdrop =
///      một gradient nâu trầm dần, đủ tối cho chữ, mà KHÔNG phải căn đo màu
///      thủ công cho từng preset. Bỏ một trong hai thì nền thành đơn điệu.
///      Cặp này định nghĩa lẫn nhau — đổi `stops: 0.55` phải soát lại band.
///
/// TẤT CẢ Ở ĐÂY ĐO THEO % MÀN HÌNH, và đó là HỢP LỆ: chúng là mảng nền thuần
/// bố cục, không có gì phải tránh né. Chỉ HAI KHUNG ẢNH mới cần biết chữ nằm
/// ở đâu — nên chúng đã dọn sang [_WelcomeFrames].
///
/// KHUNG ẢNH GIỜ NẰM TRÊN SCRIM, không còn dưới nữa (chúng ở trong Column, lớp
/// trên). Chấp nhận có ý thức: scrim vốn sinh ra để bảo vệ khối chữ, mà khung
/// ảnh không còn chạm tới khối chữ. Đáy khung không fade nữa — nó kết thúc
/// bằng cạnh cứng + bóng đổ, tức là ĐÚNG cái mà một bức ảnh đóng khung phải
/// làm. Trước đây nó nhoè đi là tác dụng phụ, không phải thiết kế.
class _WelcomeBackdrop extends StatelessWidget {
  final String? primaryPath;
  const _WelcomeBackdrop({required this.primaryPath});

  /// Bật/tắt mảng màu TRÊN (~14% đỉnh màn) để so sánh trực tiếp.
  ///
  /// VÌ SAO CÓ CỜ NÀY: band dưới có việc rõ ràng — nó là nền của khối chữ và
  /// là một nửa của cặp band+scrim. Band TRÊN thì chưa chứng minh được mình:
  /// nó chỉ kẻ một đường ngang sau lưng tên bảo tàng. Có thể nó đang giữ nhịp
  /// đối trọng cho band dưới (2 mảng = bố cục), cũng có thể nó là tiếng ồn.
  ///
  /// Không quyết được bằng suy luận — chỉ quyết được bằng mắt, trên máy thật,
  /// với ảnh bundle thật, ở CẢ BA preset. Đổi `false` rồi hot-reload, xem
  /// khoảng 30 giây, rồi mới quyết.
  ///
  /// Ba điều cần soát khi tắt:
  ///   • dark: tên bảo tàng đang là inkMuted #D4CCC2 trên band #42231B (~7:1).
  ///     Tắt band ⇒ nó rơi xuống lớp ambient — kiểm lại tương phản ở đó.
  ///   • light: band là taupe #D9D0C3 SÁNG, còn ambient bên dưới là nâu đen
  ///     #262019 TỐI. Đây là chỗ tắt band nguy hiểm nhất: inkMuted #5D554C
  ///     rơi từ nền sáng xuống nền tối ⇒ tương phản sập về ~1.5:1. Nếu bỏ
  ///     band trên, tên bảo tàng ở light PHẢI đổi sang họ on-image.
  ///   • highContrast: band vốn đã trong suốt ⇒ cờ này không ảnh hưởng gì.
  ///
  /// Khi đã quyết: xoá cờ VÀ nhánh thua cuộc. Một cờ debug sống sót qua ba
  /// lần sửa sẽ thành vĩnh viễn, và nhánh không ai chạy sẽ mục.
  static const bool _showUpperBand = true;

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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: h * 0.42,
            child: ColoredBox(color: t.welcomeBandLower),
          ),
          if (_showUpperBand)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: h * 0.14,
              child: ColoredBox(color: t.welcomeBandUpper),
            ),

          // ── 4. Scrim đáy — xem doc của class ──
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  t.welcomeBackdrop,
                  // KHÔNG BAO GIỜ Colors.transparent ở đây: đó là ĐEN alpha 0
                  // ⇒ ám xám bẩn ở khoảng giữa. RGB phải đứng yên, chỉ alpha
                  // chạy. (Cùng luật với hoà tan ở màn 3.)
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
}

/// HAI KHUNG ẢNH — sống trong CHỖ TRỐNG CÒN LẠI của Column, không phải trong
/// một phần trăm màn hình.
///
/// ═════════════════════════════════════════════════════════════════════════
/// VÌ SAO TÁCH RA KHỎI NỀN: HAI HỆ TOẠ ĐỘ ĐÃ TRƯỢT QUA NHAU
/// ═════════════════════════════════════════════════════════════════════════
/// Bug đã sửa: vạch accent 88×2 (đầu khối chữ) bị khung ảnh chính đè lên, và
/// đầu vạch trùng khít mép trái ảnh — hai đường trùng nhau chính xác thì mắt
/// đọc ra tai nạn chứ không đọc ra ý đồ.
///
/// Nguyên nhân KHÔNG phải ảnh to quá:
///     khối chữ đo bằng dp TỪ ĐÁY LÊN   (≈260dp: CTA + lede + tiêu đề + khe)
///     khung ảnh đo bằng % TỪ ĐỈNH XUỐNG (đáy = h × 0.66)
///   máy 844: vạch ở 65%, đáy ảnh ở 66%  → đè  9dp
///   máy 667: vạch ở 56%, đáy ảnh ở 66%  → đè 69dp
/// Hai hệ đo trượt qua nhau, và biên độ trượt còn phụ thuộc textScaler của
/// khách. KHÔNG TỒN TẠI giá trị % nào đúng trên cả 667 lẫn 932 — nên "thu ảnh
/// nhỏ đi một chút" chỉ chữa đúng cái máy đang cầm trên tay.
///
/// CÁCH CHỮA: widget này ngồi trong `Expanded`, tức nó nhận ĐÚNG phần thừa sau
/// khi tên bảo tàng, khối chữ và CTA đã lấy phần của mình. `h` dưới đây là
/// chiều cao VÙNG TỰ DO, không phải chiều cao màn. Khung ảnh giờ vật lý không
/// thể chạm tới vạch accent — trên mọi máy, ở mọi cỡ chữ hệ thống. Các % bên
/// dưới đổi nghĩa: chúng là % của vùng tự do, và đó luôn là điều chúng cố nói.
///
/// Phần thưởng: khung ảnh giờ tôn trọng SafeArea (nó ở trong Column), nên
/// không còn chui xuống dưới tai thỏ.
///
/// ⚠ CÁC % DƯỚI ĐÂY CẦN BẠN CHỈNH BẰNG MẮT. Chúng được đặt lại cho khung toạ
/// độ MỚI (vùng tự do ≈ 460dp trên máy 844, ≈ 335dp trên máy 667) chứ không
/// phải khung cũ — số cũ (0.16/0.50) sẽ ra bố cục khác hẳn. Đây là chỗ duy
/// nhất trong hai màn mà tôi không thấy được kết quả; hãy hot-reload và nắn.
///
/// ═════════════════════════════════════════════════════════════════════════
/// LƯỚI: MÉP ẢNH LÀ MỘT PHẦN TỬ CỦA LƯỚI, KHÔNG PHẢI TRANG TRÍ TỰ DO
/// ═════════════════════════════════════════════════════════════════════════
/// Khung chính ghim mép TRÁI vào [AppSpace.gutter]; khung phụ ghim mép PHẢI
/// vào cùng giá trị. Hai mép còn lại thả tự do theo tỷ lệ ⇒ bố cục vẫn lệch,
/// vẫn là collage, nhưng nó lệch TỪ một đường thẳng chứ không lệch bừa.
///
/// Trước đây khung chính ở `left: w * 0.08` ≈ 31dp trên máy 390: gần đường
/// 18/20 nhưng không trùng. Đó là giá trị TỆ NHẤT có thể chọn — mắt thấy hai
/// đường suýt soát và đọc ra sự cẩu thả, chứ không đọc ra ý đồ.
///
/// Chỉ có hai phương án đọc được. Nếu muốn kịch tính hơn, đổi khung chính
/// sang `left: 0` (ảnh tràn mép trái, phá lề) — cũng hợp lệ, và cũng là một
/// phát biểu rõ ràng. Mọi giá trị Ở GIỮA 0 và gutter đều là tai nạn.
///
/// Suy biến có chủ đích, không nhánh lỗi nào ra broken box:
///   • [accentPath] null (bundle cũ) ⇒ chỉ vẽ khung 1 — bố cục vẫn đứng được.
///   • [primaryPath] null ⇒ khung 1 tự vẽ fallback BÊN TRONG, giữ nhịp bố cục.
///     (Lớp ambient đã tự bỏ ở [_WelcomeBackdrop] khi không có ảnh.)
class _WelcomeFrames extends StatelessWidget {
  final String? primaryPath;
  final String? accentPath;
  const _WelcomeFrames({required this.primaryPath, required this.accentPath});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      // h = chiều cao VÙNG TỰ DO (sau tên bảo tàng / khối chữ / CTA), KHÔNG
      // phải chiều cao màn. Đó là toàn bộ điểm của widget này.
      final h = constraints.maxHeight;

      // Bề rộng hiển thị tính MỘT LẦN, rồi cả Positioned lẫn decodeWidth cùng
      // đọc từ đây. Trước đây hai chỗ mang hai hằng số rời (0.66 vs 0.56) và
      // đã âm thầm lệch nhau ⇒ ảnh chào bị upscale 18%. Ràng buộc "cùng một
      // biến" là thứ ngăn nó tái diễn, không phải sự cẩn thận của người sửa.
      final frameW = w * 0.66 - AppSpace.gutter;
      final accentW = w * 0.34;

      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: AppSpace.gutter, // ghim vào đường dọc của màn
            top: h * 0.03,
            width: frameW,
            height: h * 0.9,
            child: _framed(t,
                path: primaryPath, decodeWidth: (frameW * dpr).round()),
          ),
          if (accentPath != null)
            Positioned(
              right: AppSpace.gutter, // cùng đường dọc, phía đối diện
              top: h * 0.40,
              width: accentW,
              height: h * 0.47,
              child: _framed(t,
                  path: accentPath, decodeWidth: (accentW * dpr).round()),
            ),
        ],
      );
    });
  }

  /// Khung ảnh có bóng — dùng chung cho cả hai vùng để hai khung không bao
  /// giờ lệch nhau về bóng/bo góc khi chỉnh về sau. Màu bóng là token (theo
  /// theme); hình học bóng là AppShadow (một nguồn sáng cho cả app — trước
  /// đây offset viết thẳng ở đây và ở màn 3, và hai chỗ đã đổ bóng ngược
  /// hướng nhau).
  Widget _framed(MuseumTokens t,
      {required String? path, required int decodeWidth}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: t.sharpAll,
        boxShadow: [
          BoxShadow(
            color: t.frameShadow,
            blurRadius: AppShadow.frameBlur,
            offset: AppShadow.frameOffset,
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
            // 72 = 4×18. Số cũ (70) không nằm trên lưới và không đổi lấy gì.
            height: AppSpace.ctaHeight,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon nhắc lại lời dẫn "đeo tai nghe" — trang trí, đã có
                // label ở Semantics bên ngoài.
                Icon(Icons.headphones, size: 16, color: fg),
                const SizedBox(width: AppSpace.x2),
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
        border: Border.all(color: t.ink.withValues(alpha: 0.35)),
        borderRadius: t.sharpAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.kicker.copyWith(color: t.ink)),
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
    return _StaffCard(
      title: (_readyToRestart ? 'Đã tải xong' : 'Chưa sẵn sàng').toUpperCase(),
      body: _message ??
          'Thiết bị chưa có nội dung tham quan. Nhấn Đồng bộ để tải '
              'dữ liệu trước khi bàn giao cho khách.',
      action: _syncing
          ? _ProgressLine(progress: _progress)
          : _readyToRestart
              ? _StaffButton(
                  label: 'Khởi động lại ứng dụng',
                  onPressed: () => context.read<AppRestarter>().call(),
                )
              : _StaffButton(label: 'Đồng bộ nội dung', onPressed: _sync),
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
    final c = _copy;
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
          const SizedBox(width: AppSpace.x3),
          Text('${(progress! * 100).round()}%',
              style: AppText.timeCode.copyWith(color: t.inkMuted)),
        ],
      ],
    );
  }
}