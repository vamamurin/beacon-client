// Destination: lib/presentation/menu/menu_screen.dart
//
// MÀN MENU — màn gốc của tab Trang chính, và là chỗ CHUYẾN ĐI BẮT ĐẦU.
//
// ═══════════════════════════════════════════════════════════════════════════
// NÓ VỪA NHẬN LẠI TRÁCH NHIỆM TỪ MÀN CHÀO
// ═══════════════════════════════════════════════════════════════════════════
//
//   Poster (màn nghỉ) ──"Tham quan"──► Menu (ở đây) ──"Bắt đầu tham quan"──► tour
//
// Trước đây thứ tự ngược lại và màn chào đứng giữa: Menu hỏi "bạn muốn làm gì",
// rồi màn chào chào khách lần nữa trước khi phát tiếng. Bản vẽ v6 bỏ bước giữa
// — poster là một cái CỔNG, không phải một màn hình có chức năng — nên lời
// tuyên bố ý định "tôi bắt đầu đi" rơi về đây.
//
// BA THỨ THEO CHÂN NÓ SANG, cả ba đều từng sống ở `gate_screen.dart`:
//   1. `session.startTour()` — mục "Bắt đầu tham quan" nay gọi thẳng.
//   2. TRẠNG THÁI MÁY. Đây là màn đầu tiên có chức năng mà nhân viên gặp sau
//      khi nhấc máy khỏi dock, nên "Bluetooth đang tắt" / "chưa có nội dung"
//      phải nói ở đây. Nhưng nói bằng HỘP THOẠI, không bằng một thẻ nội dòng —
//      xem `widgets/device_status.dart`.
//   3. `refreshBluetoothOnResume` — nhân viên rời app đi bật Bluetooth rồi quay
//      lại thì trạng thái phải tự cập nhật, không bắt họ khởi động lại.
//
// LỐI VÀO CÀI ĐẶT THÌ KHÔNG theo sang. Nó rời khỏi cử chỉ nhấn giữ và trở thành
// một hàng công khai trong ngăn kéo (xem `museum_drawer.dart`), nên màn này
// không còn giữ cửa sau nào.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI KHỐI CỦA BẢN VẼ, CẢ HAI ĐỀU CÓ MẶT
// ═══════════════════════════════════════════════════════════════════════════
//
//   trên   hero + nút — LỐI THAM QUAN DUY NHẤT của app: khách đi tới đâu, máy
//          kể tới đó. Bản vẽ gọi nửa dưới là "tuyến chính" và không cần nhãn
//          nào cho điều đó, vì CỠ đã nói.
//   dưới   CÁC TUYẾN THAM QUAN THEO CHỦ ĐỀ — đúng thứ bản vẽ bày ở đó, đọc từ
//          khối `topics` của manifest.
//
// Khối dưới rỗng thì BIẾN MẤT, không để lại tiêu đề treo trên khoảng trống —
// một bảo tàng chưa soạn tuyến nào là trạng thái hợp lệ, khác hẳn một màn chưa
// dựng xong. Ranh giới đó là D18; xem doc [MenuTopics] cho lập luận đầy đủ.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/app/shell_controller.dart';
import 'package:beacon_client/presentation/menu/menu_hero.dart';
import 'package:beacon_client/presentation/menu/menu_topics.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/theme/tab_icons.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/device_status.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with WidgetsBindingObserver {
  /// Đã bật hộp thoại trạng thái trong lần dựng này chưa.
  ///
  /// Cần cờ này vì hộp thoại được bật từ một PHẢN ỨNG với dữ liệu (`bleStatus`
  /// đổi), mà dữ liệu đó có thể phát lại nhiều lần cho cùng một trạng thái. Nếu
  /// không chặn, mỗi lần phát lại là một hộp thoại chồng lên hộp thoại trước —
  /// và khách phải đóng năm cái.
  bool _statusShown = false;

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
    // Nhân viên rời app đi bật Bluetooth / cấp quyền rồi quay lại: tính lại
    // trạng thái mà KHÔNG hỏi quyền lần nữa. Nếu nay đã sẵn sàng, mục "Bắt đầu
    // tham quan" tự hiện ra.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<StartupProvider>().refreshBluetoothOnResume();
      // Cho phép hộp thoại bật lại nếu quay về mà vẫn chưa xong.
      _statusShown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final startup = context.read<StartupProvider>();
    final content = context.watch<ContentProvider>();

    return Scaffold(
      backgroundColor: t.surface,
      // THANH TRÊN NẰM ĐÈ LÊN HERO, không đứng trên nó. Luật của app: màn nào
      // có ảnh hero thì ảnh CHẠM MÉP TRÊN của máy. Nếu thanh chiếm một dải
      // riêng, ảnh thành một khối kẹp giữa hai vùng đặc và cả màn thôi đọc ra
      // là một trang biên tập.
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<StartupStatus>(
              valueListenable: startup.bleStatus,
              builder: (context, bleStatus, _) {
                final ready = deviceIsReady(
                  bleStatus: bleStatus,
                  needsSync: startup.needsSync,
                );
                _maybeShowStatus(startup, ready);
                return _MenuBody(deviceReady: ready);
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MuseumTopBar(
              title: content.ui(UiKeys.menuBarTitle),
              solid: false,
            ),
          ),
        ],
      ),
    );
  }

  /// Bật hộp thoại trạng thái nếu máy chưa sẵn sàng.
  ///
  /// Post-frame vì nó được gọi TỪ TRONG `build` của một builder: đẩy một route
  /// giữa lúc dựng cây là lỗi. Kiểm `mounted` lần nữa trong callback — hộp
  /// thoại là thứ chậm nhất ở đây và màn có thể đã bị gỡ.
  ///
  /// KHÔNG truyền trạng thái vào: hộp thoại tự nghe `startup.bleStatus`. Bản
  /// trước truyền một ảnh chụp, và đó chính là lỗi "bật Bluetooth lên mà hộp
  /// thoại không đổi gì" — xem doc `showDeviceStatusDialog`.
  Future<void> _maybeShowStatus(StartupProvider startup, bool ready) async {
    if (ready || _statusShown) return;
    _statusShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDeviceStatusDialog(context, startup: startup);
      // Mở cờ SAU KHI hộp thoại đóng. Hộp thoại chỉ đóng khi máy đã sẵn sàng,
      // nên trong thực tế cờ này không bật lại lần nữa — trừ khi Bluetooth bị
      // tắt lại giữa chừng, và lúc đó hiện lại đúng là điều cần.
      if (mounted) _statusShown = false;
    });
  }
}

class _MenuBody extends StatelessWidget {
  /// Máy đã đủ điều kiện bắt đầu tour chưa.
  ///
  /// KHÔNG dùng để ẩn gì cả — xem [_onPrimary]. Bố cục của bản vẽ giữ nguyên ở
  /// mọi trạng thái; cái đổi là chạm vào nút thì xảy ra chuyện gì.
  final bool deviceReady;

  const _MenuBody({required this.deviceReady});

  @override
  Widget build(BuildContext context) {
    // HAI KHỐI, KHÔNG LỀ NGANG NÀO Ở TẦNG NÀY. Cả hero lẫn khối tuyến đều
    // TRÀN HẾT bề ngang — ảnh chạm hai mép máy, chữ tự giữ lề bên trong. Bọc
    // màn này trong một `SliverPadding` ngang là cắt ảnh khỏi hai mép, tức làm
    // chúng thôi đọc ra là những nơi chốn.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: MenuHero(onPrimary: () => _onPrimary(context)),
        ),
        // KHỐI THỨ HAI CỦA BẢN VẼ, và là khối DUY NHẤT dưới hero: các tuyến
        // tham quan theo chủ đề. Xem doc [MenuTopics] cho lý do thẻ chưa bấm
        // được và cho trạng thái rỗng.
        const SliverToBoxAdapter(child: MenuTopics()),

        // `.screen.has-tabs { padding-bottom: var(--tabbar-h) }`.
        //
        // Khung máy bơm chiều cao vỏ đáy vào `MediaQuery.padding` (xem
        // `tour_shell.dart`) để mọi màn dùng `SafeArea` tự tránh tab bar. Màn
        // này KHÔNG dùng SafeArea — nó không được phép, vì ảnh hero phải chạm
        // mép trên — nên `CustomScrollView` không tiêu thụ khoản đó và thẻ cuối
        // cùng chui xuống dưới tab bar. Chừa lại đúng bằng khoản đã bơm.
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  /// Nút chính trên hero. Hai nghĩa, một nút — xem doc [MenuHero].
  void _onPrimary(BuildContext context) {
    // MÁY CHƯA SẴN SÀNG ⇒ MỞ LẠI HỘP THOẠI, KHÔNG ẨN NÚT.
    //
    // Bản trước ẩn lối vào tour khi thiếu Bluetooth/nội dung. Cách đó đúng khi
    // lối vào là một hàng trong danh sách; nó SAI ở đây, vì nút này là toàn bộ
    // nửa dưới của hero và bản vẽ luôn có nó. Ẩn đi là để một quyết định kỹ
    // thuật đục một lỗ vào bố cục đã được duyệt.
    if (!deviceReady) {
      showDeviceStatusDialog(context,
          startup: context.read<StartupProvider>());
      return;
    }
    final session = context.read<SessionProvider>();
    if (session.isTouring) {
      // "Tiếp tục" = về chỗ tiếng đang phát. KHÔNG gọi lại `startTour()`: nó sẽ
      // dọn sổ tiến trình và mở lại đồng hồ, tức xoá đúng chuyến đi mà chữ
      // "Tiếp tục" vừa hứa sẽ giữ.
      context.read<ShellController>().selectTab(ShellTab.tour);
      return;
    }
    // Chỉ phát biểu ý định. Phiên vào `touring`, và root dựng lại ngăn xếp
    // thành khung máy mở ở tab Tham quan — màn này không đụng Navigator.
    session.startTour();
  }
}
