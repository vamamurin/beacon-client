// Destination: lib/presentation/menu/menu_sheet.dart
//
// MENU GIỮA TOUR — cùng các mục với [MenuScreen], hiện dưới dạng sheet.
//
// Vì sao là sheet chứ không phải một route đầy đủ: giữa tour, khách đang ở một
// chỗ cụ thể trong bảo tàng và màn phía sau (khu vực / hiện vật) là ngữ cảnh
// của họ. Sheet để ngữ cảnh đó lộ ra ở rìa và đóng lại là về đúng chỗ cũ —
// một màn hình đầy đủ thì không.
//
// ĐÂY CŨNG LÀ NƠI ĐẶT "KẾT THÚC CHUYẾN ĐI", và đó là quyết định có chủ đích:
//   • Màn khu vực và màn hiện vật đã được dựng rất kỹ; thêm HAI nút vào chrome
//     của chúng (menu + kết thúc) là hai vật thể lạ, thêm MỘT thì còn chịu được.
//   • Kết thúc thành thao tác hai bước (mở sheet → bấm kết thúc → màn tổng kết
//     → xác nhận). Với một thao tác không hoàn tác được, đó là tính năng chứ
//     không phải phiền phức.
// Nút này KHÔNG kết thúc phiên — nó mở màn tổng kết. Phiên chỉ đóng khi khách
// xác nhận ở đó.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/menu_config.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/menu/menu_items.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Mở menu giữa tour. Trả về sau khi sheet đóng.
///
/// Điều hướng diễn ra SAU KHI sheet đã đóng (`await` rồi mới push) để ngăn xếp
/// không có một route mới nằm dưới một sheet đang tan biến.
Future<void> showMenuSheet(BuildContext context) async {
  final t = context.tokens;
  final navigator = Navigator.of(context);

  final action = await showModalBottomSheet<_SheetResult>(
    context: context,
    backgroundColor: t.surface,
    // Sheet có thể cao hơn nửa màn ở textScaler lớn với năm mục.
    isScrollControlled: true,
    builder: (_) => const _MenuSheetBody(),
  );

  if (action == null) return;
  switch (action) {
    case _SheetResult.guide:
      await navigator.pushNamed(AppRouter.guideRoute);
    case _SheetResult.summary:
      await navigator.pushNamed(AppRouter.summaryRoute);
  }
}

/// Những gì sheet có thể yêu cầu chỗ gọi làm. Cố tình KHÔNG phải [MenuAction]:
/// "kết thúc" không phải một mục menu do bundle điều khiển, và "bắt đầu tham
/// quan" không tồn tại ở đây.
enum _SheetResult { guide, summary }

class _MenuSheetBody extends StatelessWidget {
  const _MenuSheetBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.x6,
            AppSpace.gutter,
            AppSpace.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content.ui(UiKeys.menuSheetTitle),
                  style: AppText.sheetTitle.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.x6),
              MenuItemList(
                placement: MenuPlacement.duringTour,
                onSelect: (a) {
                  switch (a) {
                    case MenuAction.guide:
                      Navigator.of(context).pop(_SheetResult.guide);
                    case MenuAction.startTour:
                    case MenuAction.catalog:
                    case MenuAction.map:
                    case MenuAction.tours:
                      // startTour bị lọc ở duringTour; ba mục còn lại chưa có
                      // màn hình nên chưa hiện ra.
                      break;
                  }
                },
              ),
              const SizedBox(height: AppSpace.x3),
              _EndTourRow(
                label: content.ui(UiKeys.tourEndCta),
                onTap: () => Navigator.of(context).pop(_SheetResult.summary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hàng "Kết thúc" — tách hình khỏi các mục menu vì nó là loại việc khác.
/// Dùng [MuseumTokens.outline] chứ không phải màu lỗi: kết thúc chuyến đi là
/// một việc bình thường và được mong đợi, không phải một cảnh báo.
class _EndTourRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EndTourRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.sharpAll,
          child: Container(
            height: AppSpace.ctaHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: t.outline),
              borderRadius: t.sharpAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_outlined, size: 16, color: t.ink),
                const SizedBox(width: AppSpace.x2),
                Text(label.toUpperCase(),
                    style: AppText.button.copyWith(color: t.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút ☰ đặt trên các màn trong tour. Một vật thể duy nhất, cỡ [AppSpace.tap].
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = context.watch<ContentProvider>().ui(UiKeys.menuOpen);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => showMenuSheet(context),
      child: Material(
        color: t.badgeWell,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: () => showMenuSheet(context),
          borderRadius: t.sharpAll,
          child: SizedBox(
            width: AppSpace.tap,
            height: AppSpace.tap,
            child: Icon(Icons.menu, size: 18, color: t.ink),
          ),
        ),
      ),
    );
  }
}
