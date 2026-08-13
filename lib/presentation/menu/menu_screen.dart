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
// ⚠ CÒN THIẾU SO VỚI BẢN VẼ: hero 69% chiều cao màn và lưới thẻ chủ đề. Cả hai
// chờ khối `topics` trong manifest — chưa có dữ liệu thì dựng ra một cái vỏ
// rỗng cũng không nói được gì. Hiện màn này vẫn là danh sách hàng.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/menu_config.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/app/shell_controller.dart';
import 'package:beacon_client/presentation/menu/menu_items.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/theme/tab_icons.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/device_status.dart';
import 'package:beacon_client/presentation/widgets/language_picker.dart';

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
      body: Column(
        children: [
          MuseumTopBar(title: content.ui(UiKeys.menuTitle)),
          Expanded(
            // ValueListenableBuilder chứ không watch: `bleStatus` là
            // ValueListenable của graph. Cấp quyền xong là mục "Bắt đầu tham
            // quan" tự hiện, không cần khởi động lại app.
            child: ValueListenableBuilder<StartupStatus>(
              valueListenable: startup.bleStatus,
              builder: (context, bleStatus, _) {
                final ready = deviceIsReady(
                  bleStatus: bleStatus,
                  needsSync: startup.needsSync,
                );
                _maybeShowStatus(startup, bleStatus, ready);
                return _MenuBody(deviceReady: ready);
              },
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
  void _maybeShowStatus(
      StartupProvider startup, StartupStatus bleStatus, bool ready) {
    if (ready || _statusShown) return;
    _statusShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDeviceStatusDialog(
        context,
        startup: startup,
        bleStatus: bleStatus,
        needsSync: startup.needsSync,
      );
    });
  }
}

class _MenuBody extends StatelessWidget {
  /// false ⇒ ẩn lối vào tour. ẨN chứ không làm mờ: hộp thoại vừa hiện đã giải
  /// thích vì sao, và một nút xám không bấm được bên cạnh một lời giải thích là
  /// nói hai lần.
  final bool deviceReady;

  const _MenuBody({required this.deviceReady});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final museum = content.textOrNull(content.museumName) ??
        content.ui(UiKeys.gateMuseumFallback);

    // BA SLIVER, KHÔNG PHẢI MỘT — và lý do là hình học, không phải thẩm mỹ:
    // [MenuItemList] dựng bằng `AppRow`, mà hàng thì TRÀN HẾT bề ngang và TỰ
    // MANG lề [AppSpace.gutter]. Để nó nằm trong một `SliverPadding` ngang là
    // cộng lề thành 40dp, và hàng thôi tràn mép — tức nó thôi đọc ra là một
    // thao tác. Khối chữ ở trên và bộ chọn tiếng ở dưới vẫn cần lề, nên lề đi
    // theo CHÚNG chứ không đi theo cả màn.
    const hPad = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: hPad.add(const EdgeInsets.only(top: AppSpace.x6)),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(museum.toUpperCase(),
                  style: AppText.kicker.copyWith(color: t.inkFaint)),
              const SizedBox(height: AppSpace.x3),
              Text(content.ui(UiKeys.menuTitle),
                  style: AppText.heroTitle.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.x3),
              Text(content.ui(UiKeys.menuSubtitle),
                  style: AppText.lede.copyWith(color: t.inkMuted)),
              const SizedBox(height: AppSpace.x6),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: MenuItemList(
            placement: MenuPlacement.beforeTour,
            deviceReady: deviceReady,
            onSelect: (a) => _onSelect(context, a),
          ),
        ),
        SliverPadding(
          padding:
              hPad.add(const EdgeInsets.fromLTRB(0, AppSpace.x6, 0, AppSpace.x8)),
          // Ngôn ngữ đổi được từ đây và từ chip `VI` trên thanh trên — khách
          // nhận máy từ tay nhân viên thường chỉ nhận ra mình cần đổi ở một
          // trong hai chỗ, và không đoán được là chỗ nào.
          sliver: const SliverToBoxAdapter(child: LanguagePicker()),
        ),
      ],
    );
  }

  void _onSelect(BuildContext context, MenuAction action) {
    switch (action) {
      case MenuAction.startTour:
        // GỌI THẲNG, không đẩy màn nào. Phiên vào `touring`, và root dựng lại
        // ngăn xếp thành khung máy mở ở tab Tham quan — màn này không đụng
        // Navigator, đúng luật "màn hình chỉ phát biểu ý định".
        context.read<SessionProvider>().startTour();
      case MenuAction.guide:
        // ĐỔI TAB, KHÔNG ĐẨY ROUTE. Hướng dẫn là một đích CẤP MỘT — nó có tab
        // của riêng nó. Đẩy nó vào ngăn xếp của tab Trang chính sẽ cho ra một
        // màn Hướng dẫn mà tab đang sáng lại là Trang chính, đúng hai tín hiệu
        // ngược nhau mà bản vẽ đã bác.
        context.read<ShellController>().selectTab(ShellTab.guide);
      case MenuAction.catalog:
      case MenuAction.map:
      case MenuAction.tours:
        // Không tới được: [menuActionIsImplemented] đã lọc từ trước. Để trống
        // có chủ đích thay vì ném — thêm màn mới là bật cờ ở đó, không phải
        // nhớ ra chỗ này.
        break;
    }
  }
}
