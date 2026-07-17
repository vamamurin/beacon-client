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

/// Điểm neo cho test hình học. KHÔNG phải rác test lẫn vào code sản xuất:
/// mỗi key ở đây tương ứng ĐÚNG một quan hệ đã từng gãy và đã tốn một lần sửa.
/// Xem `test/presentation/gate/gate_layout_test.dart` — nó assert quan hệ giữa
/// các rect này, không so ảnh.
///
/// Nếu bạn xoá một key, hãy xoá cả assertion tương ứng và ghi lý do. Đừng để
/// nó thành `find.byType` mò mẫm: bố cục này có bốn `DecoratedBox` và ba
/// `ColoredBox`, và một finder mò sẽ bám nhầm cái khác vào lần sửa sau.
@visibleForTesting
abstract final class GateKeys {
  /// Khung ảnh chính. Đáy của nó khoá với [accentFrame] qua `_offsetY`.
  static const primaryFrame = ValueKey('gate.frame.primary');

  /// Khung ảnh phụ. Mép trái khoá với mép phải khung chính qua `_overlapX`.
  static const accentFrame = ValueKey('gate.frame.accent');

  /// Nền của khối tên bảo tàng. Phải LUÔN bao trọn [museumNameText] và chạm
  /// y=0 — đó là bug đã sửa ở Đợt 2.1.
  static const nameBand = ValueKey('gate.nameBand');

  static const museumNameText = ValueKey('gate.museumName');

  /// Vạch accent 88×2 đầu khối chữ. Khung ảnh KHÔNG được chạm tới nó — đó là
  /// bug gốc mà `Expanded` đã diệt.
  static const accentRule = ValueKey('gate.accentRule');
}

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
    final session = context.watch<SessionProvider>();
    final startup = context.read<StartupProvider>();
    final content = context.watch<ContentProvider>();

    final needsSync = startup.needsSync;

    // Dây nối, không bố cục. Mọi thứ hình học sống ở [GateLayout].
    return GateLayout(
      museumName: content.textOrNull(content.museumName) ?? 'Bảo tàng',
      primaryPath: content.welcomeImagePath,
      accentPath: content.welcomeAccentImagePath,
      action: ValueListenableBuilder<StartupStatus>(
        valueListenable: startup.bleStatus,
        builder: (context, bleStatus, _) =>
            _buildAction(context, startup, session, bleStatus, needsSync),
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

/// BỐ CỤC của màn chào — KHÔNG BIẾT GÌ VỀ PROVIDER.
///
/// ═════════════════════════════════════════════════════════════════════════
/// VÌ SAO TÁCH: DÂY NỐI VÀ BỐ CỤC LÀ HAI VIỆC KHÁC NHAU
/// ═════════════════════════════════════════════════════════════════════════
/// [GateScreen] đọc ba provider và lo vòng đời. Widget này nhận bốn giá trị
/// thường rồi xếp chúng. Ranh giới đó không phải sở thích kiến trúc — nó là
/// điều kiện để bố cục KIỂM CHỨNG ĐƯỢC.
///
/// Trước khi tách, dựng màn này trong một test cần cả `SessionController` với
/// 5 stream + `TourAudioSink` + 4 duration — chỉ để đọc đúng MỘT bool
/// (`isAtGate`). Không ai trả cái giá đó, nên bố cục chưa từng có test, nên
/// HAI bug "hai hệ toạ độ trượt qua nhau" (vạch accent bị ảnh đè; tên bảo tàng
/// trôi khỏi band) sống sót qua nhiều lần sửa. Cái giá của việc không test
/// được không phải là thiếu test — mà là những con bug chỉ hiện ra trên một
/// cái máy không ai cầm.
///
/// Giờ dựng nó cần: một String, hai String?, và một Widget.
///
/// Đây cũng là bản năng sẵn có của file này, chỉ áp ở tầng cao hơn:
/// [_WelcomeBackdrop] "KHÔNG biết gì về chữ"; [_WelcomeFrames] không biết mình
/// cao bao nhiêu. Mỗi lớp biết ít nhất có thể.
///
/// ═════════════════════════════════════════════════════════════════════════
/// LƯỚI CỦA MÀN NÀY — đọc AppSpace trước khi sửa bất kỳ khoảng cách nào
/// ═════════════════════════════════════════════════════════════════════════
/// MỘT đường dọc trái duy nhất = AppSpace.gutter (20). Ngồi trên nó, từ trên
/// xuống: tên bảo tàng · MÉP TRÁI KHUNG ẢNH CHÍNH · vạch accent · "Chào mừng"
/// · câu dẫn · CTA. Sáu phần tử, một đường.
///
/// Khung ảnh phụ ghim mép PHẢI vào gutter ⇒ màn có đúng hai đường dọc, và cả
/// hai đều được nhắc lại ít nhất hai lần. Đó là toàn bộ lưới; không cần hơn.
///
/// Nhịp dọc chỉ dùng hai mức: x3 (12) trong khối chữ, x6 (24) giữa các khối.
@visibleForTesting
class GateLayout extends StatelessWidget {
  const GateLayout({
    super.key,
    required this.museumName,
    required this.primaryPath,
    required this.accentPath,
    required this.action,
  });

  final String museumName;
  final String? primaryPath;
  final String? accentPath;

  /// Khối đáy màn: nút Bắt đầu, hoặc thẻ nhân viên (BLE chưa sẵn / cần đồng bộ).
  ///
  /// NHẬN WIDGET DỰNG SẴN, không nhận trạng thái rồi tự phân nhánh: ba nhánh đó
  /// cần provider, và nếu widget này biết về chúng thì nó lại không dựng được
  /// trong test — tức quay về đúng chỗ cũ.
  ///
  /// ⚠ CHIỀU CAO CỦA NÓ ĐỔI THEO NHÁNH, VÀ ĐIỀU ĐÓ ĐỔI CẢ BỐ CỤC: nút Bắt đầu
  /// cao 72; thẻ nhân viên cao gấp ba. Vùng tự do của [_WelcomeFrames] là phần
  /// CÒN LẠI, nên khung ảnh co lại khi thẻ nhân viên hiện. Đó là hành vi đúng
  /// của `Expanded` — nhưng nó có nghĩa là test bố cục PHẢI chạy cả hai chiều
  /// cao, không chỉ nhánh nút. Xem gate_layout_test.dart.
  final Widget action;

  /// Phơi ngưỡng của [_WelcomeFrames] ra cho test — xem doc ở đó.
  ///
  /// Test PHẢI đọc từ đây chứ không chép lại 1.6: chép là tạo ra một bản sao
  /// thứ hai của cùng một quyết định, và bản sao sẽ trôi. Đó đúng là hình dạng
  /// của bug `decodeWidth 0.56/0.66`.
  @visibleForTesting
  static const double maxFrameAspect = _WelcomeFrames.maxFrameAspect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.welcomeBackdrop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // NỀN — full-bleed, phẳng, KHÔNG biết gì về chữ. Xem _WelcomeBackdrop.
          _WelcomeBackdrop(primaryPath: primaryPath),

          // ═══════════════════════════════════════════════════════════════
          // CUỘN ĐƯỢC KHI KHÔNG ĐỦ CHỖ — `Expanded` KHÔNG chống được tràn
          // ═══════════════════════════════════════════════════════════════
          //
          // `Expanded` bảo đảm khung ảnh không ĐÈ lên chữ. Nó KHÔNG bảo đảm mọi
          // thứ vừa màn: khi các con cố định (band + khối chữ + action) đã vượt
          // chiều cao khả dụng, Expanded chỉ nhận 0 còn Column vẫn tràn — sọc
          // vàng-đen. Đây là bug THỨ BA cùng họ, và test hình học bắt được nó
          // ngay lần chạy đầu, ở đúng cấu hình không ai cầm trên tay: máy 667 ở
          // textScaler 2.0×, và 667 @1.6× khi thẻ nhân viên hiện.
          //
          // Kịch bản đó KHÔNG hiếm — nó là kịch bản thật nhất của một bảo tàng:
          // khách lớn tuổi bật cỡ chữ lớn, Bluetooth chưa cấp quyền ⇒ thẻ nhân
          // viên hiện ⇒ khối đáy cao gấp ba.
          //
          // LỜI SỬA KHÔNG PHẢI HẠ CỠ CHỮ. Khách chọn cỡ đó, và "khách tự chỉnh
          // trong cài đặt" LÀ chiến lược a11y của app này — chống lại nó ở đây
          // là rút lõi chiến lược ra rồi giữ cái vỏ.
          //
          // ── Vì sao đúng BỐN lớp này, không phải ba ────────────────────────
          //   LayoutBuilder      → đọc chiều cao viewport (scroll view sẽ xoá
          //                        thông tin đó: bên trong nó, maxHeight = ∞)
          //   SingleChildScrollView → cho tràn thành cuộn
          //   ConstrainedBox(min) → khi VỪA màn, ép Column cao bằng viewport
          //                        (nếu không, mainAxisSize thu về nội dung và
          //                        khung ảnh mất phần thừa ⇒ hỏng bố cục cũ)
          //   IntrinsicHeight    → cho Column một chiều cao HỮU HẠN. Không có
          //                        nó, `Expanded` ném "unbounded height" — flex
          //                        không sống được trong scroll view.
          //
          // Kết quả: VỪA màn ⇒ bố cục y hệt trước (Expanded ăn phần thừa).
          // KHÔNG vừa ⇒ khung ảnh co về 0 và nội dung cuộn. Khung ảnh nhường
          // trước, vì nó là trang trí còn chữ thì không — cùng luật đã dùng cho
          // preset highContrast.
          LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Tên bảo tàng + NỀN CỦA CHÍNH NÓ. Xem _MuseumNameBar.
                  _MuseumNameBar(museumName: museumName),
                  // HAI KHUNG ẢNH SỐNG Ở ĐÂY — thay cho `Spacer()`.
                  //
                  // Đây là toàn bộ cách chữa lỗi "vạch accent đè lên ảnh". Không
                  // phải thu ảnh nhỏ đi vài phần trăm: Expanded làm khung ảnh
                  // VẬT LÝ KHÔNG THỂ chạm tới chữ, trên mọi máy, ở mọi textScaler.
                  // Xem doc _WelcomeFrames.
                  Expanded(
                    // `SizedBox(height: 0)` KHÔNG làm khung ảnh cao 0 — đọc kỹ
                    // trước khi xoá:
                    //
                    //   • LÚC LAYOUT: RenderConstrainedBox gọi
                    //     `additionalConstraints.enforce(constraints)`. Ràng buộc
                    //     từ Expanded là TIGHT(h=H), nên `tightFor(height: 0)` bị
                    //     kẹp về [H,H] ⇒ khung ảnh nhận đúng H. Không đổi gì.
                    //
                    //   • LÚC HỎI INTRINSIC: `computeMaxIntrinsicHeight` của
                    //     RenderConstrainedBox thoát SỚM khi ràng buộc thêm có
                    //     hasTightHeight, trả về 0 mà KHÔNG hỏi con.
                    //
                    // Vế thứ hai là lý do nó tồn tại. IntrinsicHeight hỏi Column,
                    // Column hỏi từng con — kể cả con flex. `_WelcomeFrames` là
                    // `LayoutBuilder`, và LayoutBuilder KHÔNG hỗ trợ intrinsic: nó
                    // sẽ ném "LayoutBuilder does not support returning intrinsic
                    // dimensions". Chặn ở đây là cách rẻ nhất; cách còn lại là viết
                    // lại _WelcomeFrames thành CustomMultiChildLayout.
                    //
                    // Về ngữ nghĩa nó cũng ĐÚNG, không chỉ tiện: intrinsic height
                    // = "widget này cần bao nhiêu chỗ". Khung ảnh cần 0 — nó lấy
                    // phần thừa, và khi không có phần thừa thì nó không cần gì.
                    child: SizedBox(
                      height: 0,
                      child: _WelcomeFrames(
                        primaryPath: primaryPath,
                        accentPath: accentPath,
                      ),
                    ),
                  ),


                  // Khối chữ + CTA: SafeArea CHỈ ở đây và CHỈ cạnh dưới. Cạnh trên
                  // do _MuseumNameBar tự lo (nó cần vẽ nền LÊN TỚI y=0, dưới cả
                  // thanh trạng thái); một SafeArea bọc cả Column sẽ chặn đúng
                  // điều đó.
                  SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                            Container(
                                key: GateKeys.accentRule,
                                width: 88,
                                height: 2,
                                color: t.accent),
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
                        child: action,
                      ),

                      ],
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tên bảo tàng + DẢI MÀU TRÊN của tường chào — GỘP LÀM MỘT WIDGET, và đó
/// chính là bản sửa lỗi.
///
/// ═════════════════════════════════════════════════════════════════════════
/// HAI HỆ TOẠ ĐỘ ĐÃ TRƯỢT QUA NHAU — LẦN THỨ HAI, CÙNG MỘT BUG
/// ═════════════════════════════════════════════════════════════════════════
/// Bug đã sửa: band trên sống trong [_WelcomeBackdrop] với `height: h * 0.14`
/// của TOÀN MÀN (widget đó nằm ngoài SafeArea), còn tên bảo tàng đo bằng dp từ
/// mép SafeArea xuống VÀ nhân với textScaler:
///     band  = 0.14 × chiều cao màn                    (% , từ y=0)
///     tên   = SafeArea.top + 12 + 8 + 18×1.32×scaler  (dp, từ mép an toàn)
/// Hai gốc toạ độ, một cái phụ thuộc cỡ chữ hệ thống. Máy 667 @1.6× với tên
/// hai dòng: khối tên cao tới 136dp trong khi band chỉ 93dp ⇒ tên TRÔI RA
/// KHỎI NỀN CỦA CHÍNH NÓ.
///
/// Hậu quả không phải xấu mà là KHÔNG ĐỌC ĐƯỢC, và nặng nhất ở preset giấy:
/// band là taupe #D9D0C3 SÁNG, ambient bên dưới là nâu đen #262019 TỐI. Tên
/// bảo tàng là inkMuted #5D554C ⇒ rơi từ ~7:1 xuống ~1.5:1. Doc của cờ
/// `_showUpperBand` đã tính sẵn kịch bản này như một rủi ro của việc TẮT band
/// — không ai thấy rằng textScaler bật nó ra khỏi band mà chẳng cần tắt.
///
/// ĐÂY LÀ ĐÚNG BUG mà `Expanded` đã diệt cho vạch accent, chỉ ở đầu kia của
/// màn hình. Bài học đã học một lần và chưa áp hết: KHÔNG TỒN TẠI giá trị %
/// nào đúng trên mọi máy × mọi textScaler, nên đừng đi tìm nó.
///
/// CÁCH CHỮA — CÙNG THỦ PHÁP: để LAYOUT tính, đừng để một con số đoán. Band
/// giờ là `ColoredBox` BỌC chính khối chữ ⇒ nó cao đúng bằng nội dung, ở mọi
/// máy, ở mọi cỡ chữ, vĩnh viễn. Không còn số nào để sai.
///
/// VÌ SAO SafeArea NẰM BÊN TRONG ColoredBox: band phải vẽ lên tới y=0 (dưới
/// cả thanh trạng thái) — một tường tranh dừng ở mép notch là một tai nạn.
/// Nhưng CHỮ thì phải nằm dưới notch. ColoredBox ngoài / SafeArea trong cho cả
/// hai. Đó cũng là lý do `SafeArea` bọc cả Column đã bị gỡ ở [GateScreen]:
/// nó chặn đúng điều này.
///
/// LƯỚI: outer top/bottom x3 (12) + inner vertical x2 (8) = lề quang học 20 =
/// gutter. BỐN cạnh cùng 20 — trước đây chỉ ba (đáy để 0 vì band lo phần dưới
/// bằng % của nó). Giờ band cao bằng nội dung nên nó cần lề dưới thật.
/// Đừng gộp hai padding: cái ngoài là LỀ, cái trong là VÙNG CHẠM của
/// long-press. Gộp thì mất một trong hai ý nghĩa.
///
/// ═════════════════════════════════════════════════════════════════════════
/// BAND LÀ BẮT BUỘC — cờ `_showBand` đã bị XOÁ, đừng thêm lại
/// ═════════════════════════════════════════════════════════════════════════
/// Câu hỏi "dải màu này là bố cục hay tiếng ồn?" đã đóng, và câu trả lời không
/// phải khẩu vị — nó là số học.
///
///   1. BAND CHIẾM 0dp. Nó là `ColoredBox` BỌC chính khối tên, và ColoredBox
///      không đổi kích thước. Tắt nó giải phóng đúng không. Nó không cạnh
///      tranh với văn bản; nó LÀ nền của một dòng chữ.
///
///   2. TẮT NÓ LÀ MẤT TÊN BẢO TÀNG Ở PRESET GIẤY. Không band, tên rơi xuống
///      [MuseumTokens.welcomeAmbient] — lớp phủ 70% trên ẢNH BUNDLE nhoè, tức
///      trên một ẩn số do bảo tàng nạp:
///          light: 2.45:1 (ảnh rất tối) · 1.47:1 (trung bình) · 1.21:1 (sáng)
///          dark : 11.78 · 7.37 · 4.08 ✗   ← fail trên ảnh sáng
///      Ở light nó fail trên MỌI ảnh. Có band: dark 8.88:1, light 4.80:1 —
///      và KHÔNG phụ thuộc ảnh của bảo tàng. Đó mới là điều đáng giá: một con
///      số ta kiểm được, thay vì một con số bảo tàng quyết hộ khi họ chọn ảnh.
///
/// Nếu bao giờ có người muốn bức tường liền mạch không dải: đường đúng KHÔNG
/// phải xoá ColoredBox, mà là chuyển tên bảo tàng sang HỌ ON-IMAGE (trắng) —
/// vì lúc đó nó ngồi trên ảnh. Hai việc đó đi liền; làm một mà bỏ một là làm
/// tên biến mất.
///
/// Đánh đổi đã chốt: thà để app CUỘN ở cỡ chữ lớn, còn hơn mất tên bảo tàng.
///
/// Lối vào Cài đặt là LONG-PRESS lên tên bảo tàng — khớp thiết kế đã ghi trong
/// settings_screen.dart.
class _MuseumNameBar extends StatelessWidget {
  final String museumName;
  const _MuseumNameBar({required this.museumName});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final bar = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter, AppSpace.x3, AppSpace.gutter, AppSpace.x3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Builder(builder: (context) {
            void openSettings() => Navigator.of(context)
                .pushNamed(AppRouter.settingsRoute);
            return Semantics(
              label: museumName,
              onLongPressHint: 'Mở cài đặt (dành cho nhân viên)',
              // excludeSemantics + onLongPress ĐI THÀNH CẶP, không
              // bao giờ tách. excludeSemantics gỡ CẢ cây con khỏi
              // semantics — kể cả action long-press mà
              // GestureDetector tự khai báo. Chỉ thêm excludeSemantics
              // là nút này thôi bấm được bằng TalkBack, và không test
              // nào bắt được điều đó. Nên action phải khai lại ở đây;
              // `openSettings` dùng chung để hai đường (ngón tay /
              // screen reader) không thể trôi khỏi nhau.
              //
              // Vì sao phải exclude: Semantics(label:) mặc định
              // container:false ⇒ node của Text nằm LÀM CON chứ không
              // gộp vào, và screen reader đọc tên bảo tàng hai lần.
              excludeSemantics: true,
              onLongPress: openSettings,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: openSettings,
                child: Padding(
                  // Nới vùng chạm của long-press mà không xê chữ.
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpace.x2),
                  child: Text(
                    // LUẬT CHỮ HOA (xem app_text.dart): tên bảo tàng
                    // là NỘI DUNG, không phải nhãn hệ thống ⇒ giữ
                    // nguyên chữ của bảo tàng. `.toUpperCase()` đã gỡ.
                    key: GateKeys.museumNameText,
                    museumName,
                    // Tên bảo tàng tiếng Việt dài là MẶC ĐỊNH, không
                    // phải ngoại lệ ("Bảo tàng Lịch sử Quốc gia Việt
                    // Nam"): ở textScaler 1.6× nó xuống 2 dòng.
                    //
                    // maxLines KHÔNG còn phải gánh việc chữa bug —
                    // band giờ bọc chính khối này nên nó cao bao
                    // nhiêu cũng có nền (xem doc class). Việc duy
                    // nhất của maxLines giờ là chặn một cái tên vô lý
                    // dài nuốt hết màn chào. Đó đúng là việc của nó.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.museumName.copyWith(color: t.inkMuted),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );

    // ColoredBox NGOÀI SafeArea: nền vẽ tới y=0, chữ vẫn dưới notch.
    return ColoredBox(
        key: GateKeys.nameBand, color: t.welcomeBandUpper, child: bar);
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
///   3. KHỐI MÀU bố cục [MuseumTokens.welcomeBandLower] — mảng dưới ~42%,
///      cạnh cứng có chủ đích (color-block), chia tường thành các tông để nền
///      không đơn điệu. ([welcomeBandUpper] đã rời sang [_MuseumNameBar]: nó
///      là nền của một khối chữ, không phải mảng tông của tường.)
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

  // BAND TRÊN ĐÃ RỜI KHỎI ĐÂY — nó là nền của khối tên bảo tàng, xem
  // [_MuseumNameBar]. Nó ở đây là sai ngay từ đầu: widget này "KHÔNG biết gì
  // về chữ" (dòng đầu doc), mà band trên thì CÓ một công việc duy nhất là làm
  // nền cho chữ. Đặt nó ở đây buộc nó phải ĐOÁN chữ cao bao nhiêu bằng một %,
  // và đó là toàn bộ bug. Band DƯỚI thì ở đúng chỗ: nó là mảng tông của
  // tường, không phục vụ khối chữ nào cụ thể (scrim mới lo việc đó).

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

  /// Khung phụ ĐÈ lên khung chính bao nhiêu dp theo chiều ngang.
  ///
  /// ⚠ KHAI BÁO, KHÔNG SUY RA. Trước đây con số này KHÔNG TỒN TẠI ở đâu cả —
  /// nó rơi ra từ hiệu của hai hằng số khác:
  ///     mép phải khung chính = gutter + (0.66w − gutter) = 0.66w
  ///     mép trái khung phụ   = w − gutter − 0.34w        = 0.66w − gutter
  ///     ⇒ chồng = gutter = 20, và chỉ vì `frameW` trừ đi đúng một gutter
  ///       còn `accentW` thì không.
  ///
  /// Doc cũ mời người sau "hot-reload và nắn" các %. Nắn 0.66 → 0.60 trên máy
  /// 390: mép phải khung chính = 234.0, mép trái khung phụ = 237.4 ⇒ KHE HỞ
  /// 3.4dp. Collage im lặng biến thành hai khung suýt chạm nhau — đúng thứ mà
  /// doc bên dưới gọi là "giá trị TỆ NHẤT có thể chọn".
  ///
  /// Cùng loại bug với `decodeWidth 0.56 vs 0.66`: hai đại lượng khoá vào nhau
  /// nhưng được viết ra rời nhau. Bài học đã học ở tầng ảnh, chưa áp ở tầng bố
  /// cục. Giờ `accentW` SUY RA từ hằng số này, nên nắn % là an toàn.
  static const double _overlapX = AppSpace.x5;

  /// Đáy khung phụ cao hơn đáy khung chính bao nhiêu dp.
  ///
  /// ⚠ ĐÂY LÀ dp, KHÔNG PHẢI %, VÀ ĐÓ LÀ TOÀN BỘ ĐIỂM. Trước đây độ lệch này
  /// cũng không được khai báo — nó là hiệu của hai %:
  ///     đáy khung chính = 0.03h + 0.90h = 0.93h
  ///     đáy khung phụ   = 0.40h + 0.47h = 0.87h
  ///     ⇒ lệch = 0.06h
  ///
  /// Vì nó là % của VÙNG TỰ DO, chữ to lên ⇒ vùng tự do co ⇒ độ lệch co theo
  /// về 0, và hai khung tiến tới CÙNG MỘT ĐƯỜNG ĐÁY:
  ///     h=521 (máy 932, 1.0×) → 31dp  hai lớp rõ
  ///     h=329 (máy 667, 1.0×) → 20dp  còn được
  ///     h=212 (máy 667, 1.6×) → 13dp  "suýt thẳng hàng" ✗
  ///     h=150 (máy 667, 2.0×) →  9dp  mắt đọc là MỘT đường ✗
  /// Ảnh co lại theo cỡ chữ là ĐÚNG kế hoạch. Độ lệch co theo thì không: nó
  /// là tín hiệu tri giác ("khung nào nằm trước"), và tín hiệu tri giác đo
  /// bằng dp trên võng mạc, không bằng % của một cái hộp.
  ///
  /// Dự án đã ra luật này rồi, chỉ chưa áp cho collage — xem `_dissolveExtent`
  /// ở exhibit_list_screen, chi tiết 3: "TÍNH BẰNG dp CỐ ĐỊNH, không theo %
  /// màn hình. Chất lượng dải chuyển phụ thuộc số pixel VẬT LÝ nó trải qua."
  /// Cùng loại đại lượng, cùng kết luận. (AppSpace luật 7 miễn trừ % cho
  /// collage — nhưng nó miễn trừ cho KÍCH THƯỚC; quan hệ giữa hai vật thì
  /// không, và độ lệch đã ăn ké cái miễn trừ đó.)
  ///
  /// 32 = giá trị tái lập bố cục hiện tại trên máy tham chiếu: ở h=521 công
  /// thức cũ cho 31.3dp. Refactor này KHÔNG đổi pixel nào trên máy 932; nó chỉ
  /// giữ nguyên bố cục đó khi h co lại.
  static const double _offsetY = AppSpace.x8;

  /// Tỉ lệ RỘNG : CAO lớn nhất mà khung ảnh còn đọc ra là một KHUNG ẢNH.
  /// Quá số này nó là một vệt bẹt, và collage biến mất thay vì bị bóp.
  ///
  /// ⚠ ĐÂY LÀ TỈ LỆ, KHÔNG PHẢI dp — và đó là chỗ tôi suýt lặp lại đúng lỗi
  /// vừa chữa ở [_offsetY]. Bản nháp đặt `_minCollageHeight = 160` (dp tuyệt
  /// đối). Nó SAI: chiều rộng khung phụ thuộc chiều rộng MÁY, nên cùng một
  /// ngưỡng dp cho ra tỉ lệ khác nhau ở mỗi máy —
  ///     máy 667 (khung rộng 227) → 160dp cho tỉ lệ 1.58
  ///     máy 932 (khung rộng 264) → 160dp cho tỉ lệ 1.83
  /// tức máy lớn được phép bẹt hơn, vì lý do duy nhất là nó rộng hơn. Ràng
  /// buộc THẬT là hình dạng; dp phải SUY RA từ nó, không phải ngược lại. Cùng
  /// bài học với `decodeWidth 0.56/0.66` và với chồng ngang của collage: cái
  /// gì khoá vào nhau thì phải dẫn xuất, đừng viết rời.
  ///
  /// ── Vì sao ẩn chứ không bóp ─────────────────────────────────────────────
  /// Vùng tự do co theo cỡ chữ hệ thống — đó là `Expanded` làm ĐÚNG việc. Khi
  /// nó co, hai khung không lật thành phong cảnh rồi vỡ (bản sửa tràn đã chặn
  /// đầu đó); chúng đi qua một dải trung gian nơi chúng thành HAI VỆT BẸT: máy
  /// 667 @1.6×, khung chính còn 227×90 — tỉ lệ 2.5. Đó không phải collage thu
  /// nhỏ, đó là collage bị bóp, và mắt đọc ra "hỏng", không đọc ra "gọn".
  ///
  /// Thà KHÔNG CÓ GÌ còn hơn có một thứ trông hỏng. Và ở đây "không có gì"
  /// không phải lỗ trống: [_WelcomeBackdrop] nằm ngay dưới, nên chỗ này để lộ
  /// BỨC TƯỜNG (ảnh nhoè + mảng màu). Tường LÀ thiết kế. Khách bật cỡ chữ lớn
  /// thấy một màn chào chữ-trên-tường — không thấy hai vệt ảnh bẹt.
  ///
  /// Cùng luật đã dùng cho highContrast và cho chỉ số badge: thứ trang trí
  /// không làm nổi việc của nó thì DỌN ĐI, đừng cố nhét vừa.
  ///
  /// ── 1.6 CHƯA ĐƯỢC ĐO BẰNG MẮT ───────────────────────────────────────────
  /// Nó là suy luận: quanh 1.6 khung bắt đầu ngả sang phong cảnh. Con số đúng
  /// chỉ tìm được bằng cách kéo thanh cỡ chữ trên MÁY THẬT và xem chỗ nào
  /// collage thôi là collage. Test hình học KHÔNG tìm hộ được — font trong test
  /// rộng gấp đôi font thật, nên vùng tự do ở đó là một con số khác hẳn.
  ///
  /// Nhưng CẤU TRÚC không cần đo, và nó mới là thứ đáng giá: ngưỡng khai báo ở
  /// MỘT chỗ, và test assert "hoặc ẩn, hoặc tỉ lệ ≤ ngưỡng" — mệnh đề đó đúng
  /// với mọi font, mọi máy. Đổi 1.6 thành số của bạn không phá gì cả.
  @visibleForTesting
  static const double maxFrameAspect = 1.6;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      // h = chiều cao VÙNG TỰ DO (sau tên bảo tàng / khối chữ / CTA), KHÔNG
      // phải chiều cao màn. Đó là toàn bộ điểm của widget này.
      final h = constraints.maxHeight;


      // ── NGANG: khung chính ghim trái, khung phụ ghim phải, chồng = _overlapX
      //
      // Bề rộng hiển thị tính MỘT LẦN, rồi cả Positioned lẫn decodeWidth cùng
      // đọc từ đây. Trước đây hai chỗ mang hai hằng số rời (0.66 vs 0.56) và
      // đã âm thầm lệch nhau ⇒ ảnh chào bị upscale 18%. Ràng buộc "cùng một
      // biến" là thứ ngăn nó tái diễn, không phải sự cẩn thận của người sửa.
      final frameW = w * 0.66 - AppSpace.gutter;
      // accentW SUY RA từ _overlapX, không phải một % rời. Với 0.66/gutter 20
      // nó cho đúng 0.34w như bản cũ — refactor bảo toàn giá trị.
      final accentW = w - AppSpace.gutter * 2 - frameW + _overlapX;

      // ── DỌC: đáy khung phụ cách đáy khung chính đúng _offsetY dp
      final mainTop = h * 0.03;
      final mainH = h * 0.90;
      final accentH = h * 0.47;
      final accentTop = mainTop + mainH - _offsetY - accentH;

      // Không đủ chỗ để CÒN LÀ một collage ⇒ nhường chỗ cho tường. Ngưỡng dp
      // SUY RA từ tỉ lệ, không khai rời — xem [maxFrameAspect].
      //
      // Lợi ích phụ không nhỏ: `_framed` không chạy ⇒ không HeroImage nào được
      // dựng ⇒ không ảnh bundle nào bị decode. Đúng ở cấu hình máy yếu + chữ
      // lớn, tức đúng chỗ cần nó nhất.
      if (mainH < frameW / maxFrameAspect) return const SizedBox.shrink();

      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: AppSpace.gutter, // ghim vào đường dọc của màn
            top: mainTop,
            width: frameW,
            height: mainH,
            child: _framed(t,
                key: GateKeys.primaryFrame,
                path: primaryPath,
                decodeWidth: (frameW * dpr).round()),
          ),
          if (accentPath != null)
            Positioned(
              right: AppSpace.gutter, // cùng đường dọc, phía đối diện
              top: accentTop,
              width: accentW,
              height: accentH,
              child: _framed(t,
                  key: GateKeys.accentFrame,
                  path: accentPath,
                  decodeWidth: (accentW * dpr).round()),
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
      {required Key key, required String? path, required int decodeWidth}) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        borderRadius: t.sharpAll,
        boxShadow: [
          BoxShadow(
            color: t.shadowInk,
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
      // excludeSemantics + onTap ĐI THÀNH CẶP — xem doc ở khối tên bảo tàng.
      // excludeSemantics gỡ cả cây con, kể cả action onTap mà InkWell tự khai;
      // thiếu onTap ở đây là nút không bấm được bằng TalkBack.
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
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
      title: _readyToRestart ? 'Đã tải xong' : 'Chưa sẵn sàng',
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
          title: 'Cần quyền Bluetooth',
          body: 'Ứng dụng cần quyền Bluetooth để nhận diện khu trưng bày. '
              'Nhấn để cấp quyền.',
          cta: 'Cấp quyền',
          opensSettings: false,
        );
      case StartupStatus.permissionPermanentlyDenied:
        return (
          title: 'Quyền bị từ chối',
          body: 'Quyền Bluetooth đã bị tắt. Mở Cài đặt để bật, rồi quay lại — '
              'ứng dụng sẽ tự nhận.',
          cta: 'Mở cài đặt',
          opensSettings: true,
        );
      case StartupStatus.bluetoothOff:
        return (
          title: 'Bluetooth đang tắt',
          body: 'Vui lòng bật Bluetooth để tiếp tục.',
          cta: 'Thử lại',
          opensSettings: false,
        );
      case StartupStatus.unsupported:
        return (
          title: 'Thiết bị không hỗ trợ',
          body: 'Thiết bị này không hỗ trợ Bluetooth Low Energy.',
          cta: '',
          opensSettings: false,
        );
      default:
        return (
          title: 'Đang kiểm tra',
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