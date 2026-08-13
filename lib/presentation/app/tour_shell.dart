// Destination: lib/presentation/app/tour_shell.dart
//
// KHUNG MÁY — tab bar cố định + ngăn kéo, và các màn chạy BÊN TRONG nó.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO MỖI TAB CÓ MỘT Navigator RIÊNG
// ═══════════════════════════════════════════════════════════════════════════
//
// Ba tab có trang con: Tham quan (→ danh sách hiện vật → chi tiết hiện vật),
// Hướng dẫn (→ trang chi tiết), và sau này Sơ đồ. Nếu tất cả dùng chung
// Navigator gốc thì trang con sẽ PHỦ LÊN tab bar, và tab của chính nó tắt đi —
// hai tín hiệu ngược nhau, đúng lỗi mà thiết kế đã bác ở màn Hướng dẫn (*"một
// màn vừa có tab của chính nó sáng vừa đeo nút lùi thì đang nói hai điều ngược
// nhau"*).
//
// `IndexedStack` giữ cả ba cây sống cùng lúc, nên đổi tab KHÔNG mất chỗ đang
// đứng: khách đang xem hiện vật thứ tư, nhảy sang Hướng dẫn tra một thứ, quay
// lại thì vẫn ở hiện vật thứ tư. Với một app mà khách vừa đi vừa dùng, mất chỗ
// là mất luôn mạch của chuyến đi.
//
// Cái giá: cả ba cây cùng giữ RAM. Chấp nhận được vì chỉ có ba, và vì ảnh nặng
// nhất (hero khu) đã đi qua `cacheWidth` tính theo dpr.
//
// ═══════════════════════════════════════════════════════════════════════════
// SHELL BỊ DỰNG LẠI Ở MỖI RANH GIỚI PHIÊN — VÀ ĐÓ LÀ TÍNH NĂNG
// ═══════════════════════════════════════════════════════════════════════════
//
// `app.dart` ánh xạ mọi chuyển phase sang `pushNamedAndRemoveUntil(shellRoute)`,
// nên bắt đầu tour / kết thúc tour / cắm máy lại đều dựng shell mới với ba ngăn
// xếp trống. Khách kế tiếp không bao giờ nhận máy đang dở dang của người trước.
//
// Vì vậy các `GlobalKey<NavigatorState>` sống trong `State` này chứ không sống
// trong `ShellController` — xem khối doc ở đầu `shell_controller.dart` cho cái
// bẫy "Duplicate GlobalKey" mà điều đó tránh được.
//
// ═══════════════════════════════════════════════════════════════════════════
// TAB "THAM QUAN" TỰ BẮT ĐẦU TOUR — quyết định của phía sản phẩm
// ═══════════════════════════════════════════════════════════════════════════
//
// Chạm tab đó khi phiên chưa `touring` sẽ gọi `startTour()`, y như bấm nút trên
// hero của màn Menu.
//
// ⚠ HỆ QUẢ KHÔNG HOÀN TÁC ĐƯỢC, ghi ở đây để không ai tưởng là bug: lệnh đó dọn
// sổ `TourProgressService` và MỞ ĐỒNG HỒ chuyến đi. Chạm nhầm tab là chuyến đi
// bắt đầu tính giờ, và không có đường lùi — hệt như bấm nhầm nút CTA.
//
// Phương án đã bị bác: để tab dẫn tới màn khu vực ở trạng thái quét. Nó tệ hơn,
// vì `SessionController` bỏ qua MỌI tín hiệu beacon trước `userStartedTour()` —
// màn hình sẽ quét mãi mà không bao giờ chốt được khu, tức là nói dối rằng nó
// đang tìm.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/app/museum_drawer.dart';
import 'package:beacon_client/presentation/app/shell_controller.dart';
import 'package:beacon_client/presentation/guide/guide_screen.dart';
import 'package:beacon_client/presentation/menu/menu_screen.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/theme/app_motion.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/theme/tab_icons.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/zone/zone_screen.dart';

/// Tab này đã có màn hình thật chưa.
///
/// CẬP NHẬT ĐÚNG MỘT DÒNG ở đây khi dựng xong một màn mới — cùng khuôn với
/// `menuActionIsImplemented`, và vì cùng một lý do: một tab dẫn tới chỗ chưa
/// tồn tại là một cái nút bấm không đi đâu cả.
///
/// Bản vẽ có đủ năm tab. Hai tab dưới đây vắng mặt vì thiếu DỮ LIỆU chứ không
/// phải thiếu code: Sơ đồ cần khối `floors[]` trong manifest, và Gợi ý cần một
/// màn hình dựng từ `NearbyZonesTracker` + `TourProgress` (dữ liệu đã đủ, chưa
/// có UI).
bool shellTabIsImplemented(ShellTab tab) => switch (tab) {
      ShellTab.home => true,
      ShellTab.tour => true,
      ShellTab.map => false,
      ShellTab.foryou => false,
      ShellTab.guide => true,
    };

String _tabLabelKey(ShellTab tab) => switch (tab) {
      ShellTab.home => UiKeys.tabHome,
      ShellTab.tour => UiKeys.tabTour,
      ShellTab.map => UiKeys.tabMap,
      ShellTab.foryou => UiKeys.tabForYou,
      ShellTab.guide => UiKeys.tabGuide,
    };

/// Màn gốc của mỗi tab. Trang con đi qua `AppRouter.onGenerateRoute`.
Widget _tabRoot(ShellTab tab) => switch (tab) {
      ShellTab.home => const MenuScreen(),
      ShellTab.tour => const ZoneScreen(),
      ShellTab.guide => const GuideScreen(),
      // Không tới được: `shellTabIsImplemented` đã lọc.
      ShellTab.map || ShellTab.foryou => const SizedBox.shrink(),
    };

class TourShell extends StatefulWidget {
  const TourShell({super.key});

  @override
  State<TourShell> createState() => _TourShellState();
}

class _TourShellState extends State<TourShell> implements ShellCommands {
  static final List<ShellTab> _tabs =
      ShellTab.values.where(shellTabIsImplemented).toList(growable: false);

  late final Map<ShellTab, GlobalKey<NavigatorState>> _navKeys = {
    for (final t in _tabs) t: GlobalKey<NavigatorState>(debugLabel: t.name),
  };

  late ShellTab _current;
  bool _drawerOpen = false;

  /// Giữ tham chiếu thay vì gọi `context.read` trong [dispose]: lúc dispose
  /// chạy, element đã bị gỡ khỏi cây và việc tra ngược lên provider có thể ném.
  /// Đây là khuôn mẫu chuẩn cho mọi thứ phải huỷ đăng ký.
  ShellController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<ShellController>();
  }

  @override
  void initState() {
    super.initState();
    // Tab mở đầu là một HÀM CỦA PHASE, không phải một giá trị nhớ lại. Shell
    // được dựng lại ở mỗi ranh giới phiên, nên "mở ở tab nào" luôn là câu hỏi
    // mới. `read` chứ không `watch`: đây là ảnh chụp lúc mount.
    final touring = context.read<SessionProvider>().isTouring;
    _current = touring ? ShellTab.tour : ShellTab.home;

    // Đăng ký sau frame đầu: `attach` gọi `notifyListeners`, và gọi nó trong
    // `initState` sẽ đánh dirty các widget đang dựng dở ở cùng frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller?.attach(this);
    });
  }

  @override
  void dispose() {
    _controller?.detach(this);
    super.dispose();
  }

  // ── ShellCommands ────────────────────────────────────────────────────────

  @override
  void selectTab(ShellTab tab) {
    if (!shellTabIsImplemented(tab)) return;

    // Chạm lại tab ĐANG mở ⇒ về gốc của tab đó. Quy ước chung của mọi tab bar,
    // và ở đây nó là đường về nhanh nhất từ đáy một chuỗi hiện vật.
    if (tab == _current) {
      _navKeys[tab]?.currentState?.popUntil((r) => r.isFirst);
      return;
    }

    // Xem khối doc "TAB THAM QUAN TỰ BẮT ĐẦU TOUR" ở đầu file.
    if (tab == ShellTab.tour) {
      final session = context.read<SessionProvider>();
      if (!session.isTouring) session.startTour();
    }

    setState(() => _current = tab);
  }

  @override
  void followZoneChange(int major) {
    final nav = _navKeys[ShellTab.tour]?.currentState;
    // `canPop` false ⇒ khách đang ở gốc tab Tham quan, tức màn khu vực. Ở đó
    // `ZoneProvider` đã tự cập nhật sang khu mới — xem doc của phương thức này.
    if (nav == null || !nav.canPop()) return;

    selectTab(ShellTab.tour);
    nav.popUntil((r) => r.isFirst);
    nav.pushNamed(AppRouter.exhibitListRoute, arguments: major);
  }

  @override
  void openDrawer() => setState(() => _drawerOpen = true);

  @override
  void closeDrawer() => setState(() => _drawerOpen = false);

  // ── nút lùi vật lý ───────────────────────────────────────────────────────

  void _handleBack() {
    if (_drawerOpen) {
      closeDrawer();
      return;
    }
    final nav = _navKeys[_current]?.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (_current != ShellTab.home) {
      setState(() => _current = ShellTab.home);
      return;
    }
    // Ở gốc của tab đầu tiên thì KHÔNG LÀM GÌ — cố ý.
    //
    // Đây là máy của bảo tàng đưa cho khách, không phải điện thoại của họ. Cho
    // nút lùi thoát ra màn hình chính của Android là để khách rơi ra khỏi ứng
    // dụng giữa chuyến tham quan, và họ sẽ không biết đường quay vào. Nhân viên
    // vẫn có lối riêng: nhấn giữ tên bảo tàng để mở Cài đặt.
  }

  // ── dựng ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // Chỉ đọc "có clip nào đang nạp không" — KHÔNG đọc vị trí phát. Vị trí là
    // stream riêng và đi qua đây sẽ kéo cả shell vào nhịp 1/10 giây.
    final audioLoaded = context.select<AudioProvider, bool>(
      (a) => a.state.current != null,
    );
    final chromeH = ShellInsets.chrome(audioLoaded: audioLoaded);

    final mq = MediaQuery.of(context);
    final inTour = context.select<SessionProvider, bool>((s) => s.isTouring);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: t.surface,
        body: Stack(
          children: [
            // NỘI DUNG. Chèn chiều cao vỏ đáy vào `MediaQuery.padding` thay vì
            // bọc `Padding`: nhờ vậy mọi màn đã dùng `SafeArea` tự tránh tab
            // bar mà KHÔNG phải sửa một dòng nào — và một `ListView` cuộn tới
            // đáy vẫn cuộn được hết, thay vì bị cắt cụt bởi một khung cứng.
            Positioned.fill(
              child: MediaQuery(
                data: mq.copyWith(
                  padding:
                      mq.padding.copyWith(bottom: mq.padding.bottom + chromeH),
                  viewPadding: mq.viewPadding
                      .copyWith(bottom: mq.viewPadding.bottom + chromeH),
                ),
                child: IndexedStack(
                  index: _tabs.indexOf(_current),
                  children: [
                    for (final tab in _tabs)
                      _TabBranch(tab: tab, navigatorKey: _navKeys[tab]!),
                  ],
                ),
              ),
            ),

            // THANH "ĐANG PHÁT" — chỗ đã giữ, nội dung ở Đợt C. Nó KHÔNG được
            // vẽ gì lúc này; khoảng trống phía trên tab bar là có thật và đã
            // được tính vào `chromeH`, nên khi widget thật vào đây thì không
            // một màn nào phải đo lại.

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TabBar(
                tabs: _tabs,
                current: _current,
                onSelect: selectTab,
              ),
            ),

            // LUÔN CÓ MẶT, chỉ trượt ra/vào. Dựng-khi-mở thì không có gì để
            // hoạt hoạ: widget xuất hiện đã ở đúng vị trí cuối. Mà "trượt từ
            // trái" không phải trang trí — nó là thứ nói cho khách biết ngăn
            // kéo đến từ đâu, và vì thế biết chạm ra ngoài là trả nó về.
            _DrawerLayer(open: _drawerOpen, inTour: inTour, state: this),
          ],
        ),
      ),
    );
  }
}

/// Một nhánh của [IndexedStack]: Navigator riêng, màn gốc riêng.
class _TabBranch extends StatelessWidget {
  final ShellTab tab;
  final GlobalKey<NavigatorState> navigatorKey;

  const _TabBranch({required this.tab, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      // Trang con ĐI QUA BẢNG ĐỊNH TUYẾN CHUNG thay vì một bảng riêng ở đây.
      // `AppRouter.onGenerateRoute` đã giữ toàn bộ phần kiểm tra tham số (kiểu
      // của `arguments`, thông báo lỗi khi sai), và chép nó sang đây là tạo ra
      // một bản sao sẽ lệch ở lần sửa đầu tiên.
      onGenerateRoute: (settings) {
        if (settings.name == Navigator.defaultRouteName) {
          return MaterialPageRoute<dynamic>(
            builder: (_) => _tabRoot(tab),
            settings: settings,
          );
        }
        return AppRouter.onGenerateRoute(settings);
      },
    );
  }
}

/// Thanh tab cố định. Nằm NGOÀI vùng cuộn — nó là anh em của màn, không phải
/// con — nên đổi màn thì thanh này đứng yên.
class _TabBar extends StatelessWidget {
  final List<ShellTab> tabs;
  final ShellTab current;
  final void Function(ShellTab) onSelect;

  const _TabBar({
    required this.tabs,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    // `Material` TÔ MÀU, không phải một `Container` có `decoration` — và đây là
    // một lỗi đã bắt được trước khi nó ra tới máy: `InkWell` vẽ phản hồi chạm
    // lên `Material` GẦN NHẤT phía trên nó trong cây. Với một Container tô màu,
    // Material gần nhất là cái của `Scaffold`, nằm SAU màu `chrome` — nên lớp
    // nước phủ khi chạm bị màu nền che mất và năm cái tab trở thành năm vùng
    // bấm không phản hồi gì.
    //
    // Vạch mép trên tách khỏi màu nền vì cùng lý do: nó phải là con của
    // Material, không phải một `border` của thứ đứng ngoài.
    return Material(
      color: t.chrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: t.line),
          SafeArea(
            top: false,
            child: SizedBox(
              height: ShellInsets.tabBar,
              child: Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: _TabItem(
                        tab: tab,
                        label: content.ui(_tabLabelKey(tab)),
                        selected: tab == current,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final ShellTab tab;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = selected ? t.ink : t.chromeOff;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: t.ink.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.only(top: 9, bottom: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TabIcon(tab: tab, color: color),
              const SizedBox(height: 5),
              // KHOÁ CỠ CHỮ — xem doc `AppText.tabLabel`. Năm nhãn tiếng Việt
              // có dấu nằm trong ~78dp một ô; ở textScaler 1.6× nhãn thành 16px
              // và hàng vỡ. Nhãn tab là NHÃN HỆ THỐNG (icon phía trên đã mang
              // nghĩa), nên khoá cỡ ở đây hợp lệ — khoá cỡ một câu do bảo tàng
              // viết thì không.
              MediaQuery.withNoTextScaling(
                child: Text(
                  label,
                  style: AppText.tabLabel.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lớp phủ + ngăn kéo. Nằm trên CẢ tab bar: lúc ngăn kéo mở thì không có gì
/// khác bấm được, và điều đó phải nhìn thấy được.
class _DrawerLayer extends StatelessWidget {
  final bool open;
  final bool inTour;
  final _TourShellState state;

  const _DrawerLayer({
    required this.open,
    required this.inTour,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.of(context, AppMotion.base);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !open,
        child: Stack(
          children: [
            // Chạm ra ngoài là quay lại — khách không phải học nút nào. Đó cũng
            // là lý do ngăn kéo chỉ rộng 312dp: dải lộ ra ở mép phải vừa là chỗ
            // để chạm, vừa là bằng chứng màn phía sau vẫn nguyên vẹn.
            AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: d,
              curve: open ? AppMotion.enter : AppMotion.exit,
              child: GestureDetector(
                onTap: state.closeDrawer,
                child: const ColoredBox(color: Color(0x9E000000)),
              ),
            ),
            AnimatedPositioned(
              duration: d,
              curve: open ? AppMotion.enter : AppMotion.exit,
              left: open ? 0 : -kDrawerWidth,
              top: 0,
              bottom: 0,
              width: kDrawerWidth,
              child: MuseumDrawer(
                inTour: inTour,
                onClose: state.closeDrawer,
                onResult: (r) => _handle(context, r),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handle(BuildContext context, DrawerResult r) {
    switch (r) {
      case DrawerResult.guide:
        state.selectTab(ShellTab.guide);
      case DrawerResult.summary:
        // Màn tổng kết KHÔNG sống trong một tab: nó là một màn xác nhận của cả
        // phiên, và nó phải phủ tab bar — để khách không vừa đọc bản tổng kết
        // vừa thấy năm lối mời đi tiếp ở dưới chân.
        Navigator.of(context, rootNavigator: true)
            .pushNamed(AppRouter.summaryRoute);
    }
  }
}
