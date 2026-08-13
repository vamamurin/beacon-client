// Destination: lib/presentation/app/app.dart (REPLACES current)
//
// Root MaterialApp: new palette/fonts + the zone-first route table, PLUS the
// single owner of session→route mapping.
//
// Why the navigation lives here (Phase-4 Step 7 wiring): a tour session can end
// at any moment from deep in the stack (charging / desk / silence / staff).
// When it does, the visitor may be on screen 2/3/4 — none of which can see the
// Gate anymore (Gate was removed from the stack when the tour began). So the
// ONE place that reshapes the stack on a lifecycle boundary is here, at the
// root, watching SessionProvider through a navigatorKey. Screens never reset
// the stack themselves; they only push forward within a live tour.
//
// LUẬT: đây là một ÁNH XẠ THUẦN TỪ PHASE SANG ROUTE, và không được phép trở
// thành gì hơn (xem [tourNavigationTarget]).
//
//   touring   -> [Zone]        tour bắt đầu
//   farewell  -> [Farewell]    khách tự bấm kết thúc ở màn tổng kết
//   atDesk    -> [màn nghỉ]    mọi đường về trạng thái nghỉ
//   gate      -> [màn nghỉ]    khách kế tiếp nhấc máy khỏi dock
//   ending    -> (không làm gì; nó là một cạnh, xem SessionPhase.ending)
//
// Cám dỗ đã bị từ chối ở đây, ghi lại để không ai đi lại: cho bộ định tuyến giữ
// một cờ kiểu "lần kết thúc này là do khách bấm" rồi ép đích đến theo cờ đó.
// Nó CHẠY, và nó sai chỗ — sự thật đó thuộc về vòng đời phiên, nên nó phải là
// một phase ([SessionPhase.farewell]). Đặt ở tầng điều hướng thì mọi thứ khác
// đọc phiên (analytics, keep-alive, đồng bộ) không bao giờ nghe được, và thứ tự
// "bật cờ trước, gọi endTour sau" trở thành một luật bất thành văn mà không gì
// bắt được khi ai đó viết ngược.
//
// Ánh xạ atDesk/gate -> màn nghỉ KHÔNG phải no-op như bản trước (khi cả hai
// phase đều là màn Gate). Hai kịch bản thật cần nó:
//   • Nhân viên cắm máy lại khi khách còn đang đứng giữa Menu / Hướng dẫn.
//     Không reset thì khách kế tiếp nhận máy đang dở dang của người trước.
//   • Máy bị bỏ quên ở màn Cảm ơn (cố ý giữ vô hạn), rồi được cắm lên dock và
//     khách sau rút ra.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/app/shell_controller.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/pending_zone_change_provider.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/widgets/bluetooth_lost_overlay.dart';
import 'package:beacon_client/presentation/widgets/zone_change_banner.dart';

/// Global route observer, available for any RouteAware screen that wants to
/// pause work while obscured. Registered on the Navigator so it's ready; the
/// current 4 screens don't subscribe (their freeze is structural — they read
/// their route args once), but new screens can opt in without re-plumbing.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Route mà ngăn xếp phải bị dựng lại thành, cho một bước chuyển phase — hoặc
/// null nếu không phải điều hướng.
///
/// ÁNH XẠ THUẦN TỪ PHASE SANG ROUTE, không có trạng thái nào của riêng nó. Đó
/// là điều kiện để bộ định tuyến không trở thành một máy trạng thái thứ hai
/// chạy song song với [SessionController] — mọi sự thật về vòng đời phiên đều
/// nằm ở đó, kể cả sự thật "khách chủ động kết thúc" ([SessionPhase.farewell]).
///
/// Tách thành hàm thuần vì tất cả các tổ hợp (prev × next) kiểm được bằng bảng,
/// không cần dựng cây provider.
String? tourNavigationTarget({
  required SessionPhase? prev,
  required SessionPhase next,
}) {
  // prev == null: quan sát đầu tiên, initialRoute đã đúng rồi.
  if (prev == null || prev == next) return null;

  return switch (next) {
    // Cả hai nhánh dưới đây HÔM NAY trỏ về cùng một route ([AppRouter.restRoute]
    // == [AppRouter.shellRoute]), nhưng chúng được viết riêng vì chúng là hai ý
    // khác nhau và sẽ TÁCH RA: khi màn poster trở thành màn nghỉ, `restRoute`
    // đổi còn `shellRoute` thì không. Gộp chúng lại bây giờ là hẹn một lần sửa
    // sai vào ngày đó.
    //
    // Dựng lại shell ở MỌI chuyển phase là chủ đích, không phải lãng phí: ba
    // ngăn xếp tab trở lại rỗng, nên khách kế tiếp không nhận máy đang dở dang
    // của người trước. Shell tự chọn tab mở đầu theo phase.
    SessionPhase.touring => AppRouter.shellRoute,
    SessionPhase.farewell => AppRouter.farewellRoute,

    // `ending` là một CẠNH ở lối kết thúc tự động: nó bị `atDesk` thay thế
    // trong cùng một lần gọi đồng bộ, nên không frame nào được bơm và điều
    // hướng ở đây chỉ tốn một lần dựng lại stack. Để `atDesk` ngay sau đó lo.
    SessionPhase.ending => null,

    // Mọi đường về trạng thái nghỉ: rời tour theo lối tự động, rời màn Cảm ơn,
    // máy được cắm lại giữa lúc khách đang ở Menu, khách kế tiếp rút máy khỏi
    // dock. Tất cả đều về màn nghỉ.
    SessionPhase.atDesk || SessionPhase.gate => AppRouter.restRoute,
  };
}

class MuseumApp extends StatefulWidget {
  const MuseumApp({super.key});

  @override
  State<MuseumApp> createState() => _MuseumAppState();
}

class _MuseumAppState extends State<MuseumApp> {
  /// Lets the root drive the Navigator that lives inside MaterialApp. Stable
  /// across rebuilds, so route state survives a MaterialApp reconfigure.
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  /// Tracks the name of the route currently on top, so a confirmed zone switch
  /// only re-navigates when the visitor is actually on screen 3 or 4 (not on
  /// screen 2, where ZoneProvider already reflects the change in place).
  final _RouteNameTracker _routeTracker = _RouteNameTracker();

  /// Last session phase we acted on, so a rebuild that didn't change phase is
  /// a no-op. Null until the first observation (initialRoute is already right).
  SessionPhase? _lastPhase;

  @override
  void dispose() {
    _routeTracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the session state changes (rare: phase transitions).
    final phase = context.watch<SessionProvider>().phase;
    final themeCtrl = context.watch<ThemeController>();
    _syncNavigation(phase);

    // C2/C3-fix: after the visitor CONFIRMS a zone switch (banner "Chuyển"),
    // route to screen 3 (exhibit list) of the new zone — so a visitor who was
    // deep in zone A's exhibits lands in zone B's, matching the audio switch.
    // App owns stack reshaping; the provider only reports the target.
    final navTarget = context.watch<PendingZoneChangeProvider>().confirmedNavTarget;
    if (navTarget != null) _syncConfirmedNav(context, navTarget);

    return MaterialApp(
      title: 'Museum Guide',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: themeCtrl.theme,
      initialRoute: AppRouter.initialRoute,
      // ⚠ ĐỪNG BỎ DÒNG NÀY. Mặc định của Flutter cho `initialRoute` là
      // `Navigator.defaultGenerateInitialRoutes`, và nó CẮT TÊN ROUTE THEO DẤU
      // '/' rồi dựng một ngăn xếp cho từng tiền tố. Với `/shell` nó sẽ sinh ra
      // ['/', '/shell'] — mà '/' là màn chào. Tức app khởi động với một màn
      // chào nằm SẴN dưới khung máy, vô hình nhưng có thật: nút lùi rơi vào nó,
      // và nó giữ nguyên một cây widget không ai nhìn thấy.
      //
      // Lỗi này đã có từ trước bản sửa này (màn nghỉ khi ấy là `/menu`, và ngăn
      // xếp khởi động là ['/', '/menu']). Nó không lộ ra vì màn chào lúc đó
      // cũng là một đích hợp lệ để lùi về.
      //
      // Một route, đúng một route: app này không có deep-link phân cấp nào.
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        AppRouter.onGenerateRoute(RouteSettings(name: name)),
      ],
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      navigatorObservers: [routeObserver, _routeTracker],
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.6,
        // C2: the confirm banner floats above EVERY screen (incl. screen 4).
        // Directionality + the app child sit under it; the banner renders
        // nothing when no change is pending, so this is free when idle.
        //
        // …TRỪ hai màn cuối luồng. Cả hai lớp phủ này đều được viết cho một
        // khách ĐANG ĐI GIỮA BẢO TÀNG, và cả hai đều sai chỗ khi khách đang
        // đọc bản tổng kết:
        //   • banner đổi khu sẽ kéo họ sang khu khác giữa lúc đọc;
        //   • overlay mất Bluetooth CHẶN cả màn — mà phiên vẫn đang `touring`
        //     ở màn tổng kết, nên nó sẽ nhốt khách lại đúng lúc họ muốn kết
        //     thúc, vì một thứ (sóng beacon) không còn liên quan nữa.
        child: ValueListenableBuilder<String?>(
          valueListenable: _routeTracker.currentRoute,
          child: child,
          builder: (context, route, child) {
            final atEndOfTour = route == AppRouter.summaryRoute ||
                route == AppRouter.farewellRoute;
            return Stack(
              children: [
                child!,
                if (!atEndOfTour) ...[
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ZoneChangeBanner(),
                  ),
                  // ABOVE the zone banner on purpose: "the radio is gone"
                  // outranks "you may have changed zone", and the latter is
                  // meaningless without a radio. Renders nothing unless a tour
                  // is live AND BLE is unavailable.
                  const BluetoothLostOverlay(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// React to session-lifecycle transitions. Post-frame so we never push during
  /// build; guarded so only genuine phase changes navigate.
  void _syncNavigation(SessionPhase phase) {
    final prev = _lastPhase;
    if (phase == prev) return;
    _lastPhase = phase;

    final target = tourNavigationTarget(prev: prev, next: phase);
    if (target == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navKey.currentState?.pushNamedAndRemoveUntil(target, (_) => false);
    });
  }

  /// Sau khi khách XÁC NHẬN chuyển khu, đưa họ tới danh sách hiện vật của khu
  /// mới — nhưng chỉ khi họ đang ở sâu trong tab Tham quan.
  ///
  /// ⚠ QUYẾT ĐỊNH ĐÃ CHUYỂN CHỖ Ở, và đó là bản sửa chứ không phải bản dời.
  /// Trước đây chỗ này tự kiểm "khách có đang ở màn 3/4 không" bằng cách so tên
  /// route trên navigator GỐC. Từ khi ba màn đó sống trong `Navigator` của một
  /// tab, navigator gốc không còn nhìn thấy chúng — phép so ấy sẽ luôn cho sai,
  /// và tính năng lặng lẽ chết. Câu hỏi "khách đang đứng đâu trong tab Tham
  /// quan" chỉ shell trả lời được, nên nó thuộc về shell.
  ///
  /// Ở đây chỉ còn: chuyển tiếp ý định, rồi tiêu thụ one-shot. Post-frame để
  /// không điều hướng giữa lúc build; tiêu thụ DÙ shell có làm gì hay không,
  /// nếu không nó sẽ bắn lại ở mọi rebuild sau đó.
  void _syncConfirmedNav(BuildContext context, int major) {
    final provider = context.read<PendingZoneChangeProvider>();
    final shell = context.read<ShellController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      shell.followZoneChange(major);
      provider.consumeConfirmedNavTarget();
    });
  }
}
/// NavigatorObserver nhớ tên route đang ở trên cùng.
///
/// Hai người dùng, và họ cần hai thứ khác nhau từ cùng một giá trị:
///   • lớp phủ toàn cục (banner đổi khu, overlay mất Bluetooth) phải VẼ LẠI khi
///     route đổi — nên giá trị là một [ValueNotifier], không phải một field.
///
/// NGƯỜI DÙNG THỨ HAI ĐÃ RA ĐI: `_syncConfirmedNav` từng đọc tên route ở đây để
/// biết khách có đang ở màn 3/4 không. Từ khi ba màn đó sống trong Navigator
/// của một tab, navigator gốc không còn nhìn thấy chúng — câu hỏi ấy nay do
/// shell trả lời. Getter `currentRouteName` bị xoá cùng lúc: một API chỉ còn
/// phục vụ một câu hỏi không ai hỏi nữa.
///
/// Không giẫm lên [routeObserver] (RouteAware) — hai observer độc lập.
class _RouteNameTracker extends NavigatorObserver {
  final ValueNotifier<String?> currentRoute = ValueNotifier<String?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute.value = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute.value = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRoute.value = newRoute?.settings.name;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute.value = previousRoute?.settings.name;
  }

  void dispose() => currentRoute.dispose();
}