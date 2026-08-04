// Destination: lib/presentation/menu/menu_screen.dart
//
// MÀN MENU — hiện là MÀN NGHỈ của máy ([AppRouter.restRoute]).
//
// ═══════════════════════════════════════════════════════════════════════════
// NÓ ĐỨNG TRƯỚC MÀN CHÀO, KHÔNG PHẢI SAU
// ═══════════════════════════════════════════════════════════════════════════
//
//   Menu (ở đây) ──"Bắt đầu tham quan"──► Gate (chào + ngôn ngữ + BẮT ĐẦU) ──► tour
//
// Menu hỏi "bạn muốn làm gì"; Gate là lời chào ngay trước khi chuyến đi bắt
// đầu. Sau này màn poster/giới thiệu sẽ chen vào TRƯỚC Menu và trở thành màn
// nghỉ mới — lúc đó chỉ [AppRouter.restRoute] đổi, và hai trách nhiệm dưới đây
// đi theo nó.
//
// HAI TRÁCH NHIỆM CỦA MÀN NGHỈ, thừa kế từ Gate cùng với vị trí:
//   1. THẺ TRẠNG THÁI MÁY. Đây là màn nhân viên nhìn khi nhấc máy khỏi dock,
//      nên "Bluetooth đang tắt" / "chưa có nội dung" phải hiện ngay tại đây.
//      Dùng chung `deviceNotReadyCard` với Gate — một nguồn, hai chỗ vẽ.
//   2. LỐI VÀO CÀI ĐẶT. Nhấn giữ tên bảo tàng, y như Gate vẫn làm.
//
// Vòng đời: màn này sống ở cả `atDesk` lẫn `gate` và không phân biệt hai phase
// đó — hệt như Gate trước đây. Máy được cắm lại giữa chừng thì root dựng lại
// stack về đúng đây, nên không có gì phải xử lý tại chỗ.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/menu_config.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/gate/gate_screen.dart'
    show deviceNotReadyCard;
import 'package:beacon_client/presentation/menu/menu_items.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/language_picker.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final startup = context.read<StartupProvider>();

    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        // ValueListenableBuilder chứ không watch: `bleStatus` là ValueListenable
        // của graph, và Gate đọc nó đúng cách này. Cấp quyền Bluetooth xong là
        // thẻ tự biến mất, mục "Bắt đầu tham quan" tự hiện ra, không cần khởi
        // động lại app.
        child: ValueListenableBuilder<StartupStatus>(
          valueListenable: startup.bleStatus,
          builder: (context, bleStatus, _) => _MenuBody(
            startup: startup,
            bleStatus: bleStatus,
          ),
        ),
      ),
    );
  }
}

class _MenuBody extends StatelessWidget {
  final StartupProvider startup;
  final StartupStatus bleStatus;

  const _MenuBody({required this.startup, required this.bleStatus});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final museum = content.textOrNull(content.museumName) ??
        content.ui(UiKeys.gateMuseumFallback);

    final notReady = deviceNotReadyCard(
      startup: startup,
      bleStatus: bleStatus,
      needsSync: startup.needsSync,
    );

    // CustomScrollView chứ không Column: ở textScaler 1.6× với năm mục cộng
    // một thẻ trạng thái, nội dung vượt chiều cao màn và Column sẽ tràn.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.x6,
            AppSpace.gutter,
            AppSpace.x8,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _MuseumKicker(name: museum),
              const SizedBox(height: AppSpace.x3),
              Text(content.ui(UiKeys.menuTitle),
                  style: AppText.heroTitle.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.x3),
              Text(content.ui(UiKeys.menuSubtitle),
                  style: AppText.lede.copyWith(color: t.inkMuted)),
              const SizedBox(height: AppSpace.x6),

              // Thẻ trạng thái đứng TRÊN danh sách: nó vừa giải thích vì sao
              // lối vào tour vắng mặt, vừa là việc nhân viên phải xử lý trước.
              if (notReady != null) ...[
                notReady,
                const SizedBox(height: AppSpace.x6),
              ],

              MenuItemList(
                placement: MenuPlacement.beforeTour,
                deviceReady: notReady == null,
                onSelect: (a) => _onSelect(context, a),
              ),

              const SizedBox(height: AppSpace.x6),
              // Ngôn ngữ đổi được từ đây và từ cả màn chào — khách nhận máy từ
              // tay nhân viên thường chỉ nhận ra mình cần đổi ở một trong hai
              // chỗ, và không đoán được là chỗ nào.
              const LanguagePicker(),
            ]),
          ),
        ),
      ],
    );
  }

  void _onSelect(BuildContext context, MenuAction action) {
    switch (action) {
      case MenuAction.startTour:
        // KHÔNG gọi startTour() ở đây. Màn chào mới là chỗ phát biểu ý định đó
        // — nó còn phải chào khách và cho đổi ngôn ngữ lần cuối trước khi
        // thuyết minh bắt đầu phát.
        Navigator.of(context).pushNamed(AppRouter.gateRoute);
      case MenuAction.guide:
        Navigator.of(context).pushNamed(AppRouter.guideRoute);
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

/// Tên bảo tàng + lối vào cài đặt bằng NHẤN GIỮ.
///
/// Cùng cử chỉ, cùng vị trí, cùng chuỗi gợi ý a11y với màn chào: nhân viên đã
/// học một lần thì không phải học lại chỉ vì màn nghỉ đổi chỗ. `excludeSemantics`
/// + `onLongPress` đi thành cặp — excludeSemantics gỡ cả cây con kể cả action
/// mà InkWell tự khai, thiếu onLongPress ở Semantics là không mở được bằng
/// TalkBack.
class _MuseumKicker extends StatelessWidget {
  final String name;

  const _MuseumKicker({required this.name});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    void openSettings() =>
        Navigator.of(context).pushNamed(AppRouter.settingsRoute);

    return Semantics(
      label: name,
      onLongPressHint: content.ui(UiKeys.gateSettingsHint),
      excludeSemantics: true,
      onLongPress: openSettings,
      child: GestureDetector(
        onLongPress: openSettings,
        child: Text(name.toUpperCase(),
            style: AppText.kicker.copyWith(color: t.inkFaint)),
      ),
    );
  }
}
