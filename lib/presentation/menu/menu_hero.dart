// Destination: lib/presentation/menu/menu_hero.dart
//
// HERO CỦA MÀN MENU — `.mhero` của bản vẽ, và là tuyến chính của cả app.
//
// ═══════════════════════════════════════════════════════════════════════════
// KHÔNG CÓ NHÃN "TUYẾN CHÍNH", VÀ ĐÓ LÀ MỘT QUYẾT ĐỊNH CỦA BẢN VẼ
// ═══════════════════════════════════════════════════════════════════════════
//
// Hero cao ~69% màn với một nút mở tour, so với thẻ chủ đề cao ~215dp bên dưới:
// CỠ đã nói cái nào là tuyến chính. Một cái nhãn ghi "Tuyến chính" còn sai lần
// nữa — nó dùng màu nhấn, mà màu nhấn trong app này chỉ được nói "cái này đang
// xảy ra", không nói "cái này là gì".
//
// ═══════════════════════════════════════════════════════════════════════════
// MỘT MÀN, HAI TRẠNG THÁI — khác đúng HAI DÒNG CHỮ
// ═══════════════════════════════════════════════════════════════════════════
//
// Từ khi Trang chính trở thành một tab, khách bấm về đây bất cứ lúc nào giữa
// chuyến. Với người đã đi được nửa bảo tàng, một cái nút ghi "Bắt đầu tham
// quan" đọc thành "bắt đầu LẠI" — nghe như sắp mất hết những khu đã ghé.
//
//   trước tour   câu mô tả BÁN chuyến đi     · nút "Bắt đầu tham quan"
//   giữa tour    câu mô tả BÁO CÁO tiến độ   · nút "Tiếp tục"
//
// Không sinh vật liệu mới nào, và không thêm một trường dữ liệu nào:
// `TourProgress` đã có `visitedMajors` và `totalZones`, `ZoneProvider` đã có
// khu đang đứng.
//
// ═══════════════════════════════════════════════════════════════════════════
// HỌ TOKEN — chỗ dễ nối nhầm nhất của màn này
// ═══════════════════════════════════════════════════════════════════════════
//
// Chữ trong hero dùng họ SURFACE (`ink` / `inkMuted`), KHÔNG dùng họ on-image,
// dù nó nằm trên một tấm ảnh. Nghe ngược, nhưng đúng: lớp veil của `.mhero`
// đóng tới 0.97 ở 2% cuối, tức khối chữ ngồi trên một mặt phẳng đã gần như là
// `surface` đặc. Dùng `inkOnImage` ở đây sẽ cho chữ TRẮNG trên nền GIẤY ở
// preset sáng.
//
// Ranh giới nằm ở ĐỘ ĐÓNG CỦA VEIL, không ở "có ảnh hay không có ảnh". Cùng
// luật đã áp cho cụm `.zplay` ở màn danh sách hiện vật.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/tour_progress_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class MenuHero extends StatelessWidget {
  /// Chạm nút chính. Trước tour = bắt đầu; giữa tour = về tab Tham quan.
  final VoidCallback onPrimary;

  const MenuHero({super.key, required this.onPrimary});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final touring = context.select<SessionProvider, bool>((s) => s.isTouring);

    final size = MediaQuery.sizeOf(context);

    return SizedBox(
      // 580dp ĐÚNG NHƯ BẢN VẼ, không quy đổi theo chiều cao màn — xem doc
      // [DesignSize] cho lý do bản tỉ lệ trước đó đã bị gỡ.
      height: DesignSize.menuHero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HeroImage(
            filePath: content.welcomeImagePath,
            veil: _veil(t),
            cacheWidth:
                (size.width * MediaQuery.devicePixelRatioOf(context)).round(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpace.x8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(content.ui(UiKeys.menuTitle),
                      style: AppText.menuHeroTitle.copyWith(color: t.ink)),
                  const SizedBox(height: AppSpace.x4),
                  Text(
                    touring ? _progressLine(context) : content.ui(UiKeys.menuSubtitle),
                    style: AppText.heroSub.copyWith(color: t.inkMuted),
                  ),
                  const SizedBox(height: AppSpace.x5),
                  _Cta(
                    label: content.ui(touring
                        ? UiKeys.menuHeroCtaResume
                        : UiKeys.menuItemStart),
                    onTap: onPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Đang ở khu X · đã đi N trong M khu."
  ///
  /// Câu này BÁO CÁO, không mô tả — đó là toàn bộ khác biệt giữa hai trạng
  /// thái. Nếu chưa chốt được khu (khách đang ở hành lang giữa hai khu), lùi về
  /// câu mô tả thường: một câu báo cáo thiếu mất chủ ngữ còn tệ hơn không báo.
  String _progressLine(BuildContext context) {
    final content = context.read<ContentProvider>();
    final zone = context.select<ZoneProvider, String?>(
      (z) => z.currentZone == null ? null : content.text(z.currentZone!.name),
    );
    final progress = context.select<TourProgressProvider, (int, int)>(
      (p) => (p.progress.visitedMajors.length, p.progress.totalZones),
    );
    if (zone == null || progress.$2 == 0) {
      return content.ui(UiKeys.menuSubtitle);
    }
    return content.uif(UiKeys.menuHeroProgress, {
      'zone': zone,
      'done': '${progress.$1}',
      'total': '${progress.$2}',
    });
  }

  /// Veil của `.mhero`. Bốn chặng, và chặng thứ hai là chỗ bức ảnh được nhìn.
  LinearGradient _veil(MuseumTokens t) {
    final s = t.surface;
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        s.withValues(alpha: 0.97),
        s.withValues(alpha: 0.86),
        s.withValues(alpha: 0.28),
        s.withValues(alpha: 0.34),
      ],
      stops: const [0.02, 0.22, 0.62, 1.0],
    );
  }
}

/// `.mcta` — NGOẠI LỆ DUY NHẤT CÒN NÚT CÓ VIỀN trong cả app.
///
/// Ghi rõ ở đây vì nó là một hạn ngạch, không phải một kiểu dáng: mọi thứ bậc
/// khác trong app do CỠ và KHOẢNG TRẮNG gánh. Đã có lúc hai cái nút viền nữa
/// được thêm vào (nút phát của khu, nút chính của trình phát) và câu "ngoại lệ
/// duy nhất" thành sai ba lần — cả hai đã bị gỡ về dạng nét trần.
///
/// Nó được miễn trừ vì lý do hình học chứ không vì nó quan trọng: ở đây một
/// hàng tràn mép (`AppRow`) không dùng được — hàng cần hai mép máy, mà khối này
/// nằm trong lề của hero. Nền bán trong suốt, KHÔNG phải khối trắng đặc.
class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Cta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: t.surface.withValues(alpha: 0.55),
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.sharpAll,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: t.surface.withValues(alpha: 0.35),
          child: Container(
            height: AppSpace.tap,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x5),
            decoration: BoxDecoration(
              border: Border.all(color: t.ink.withValues(alpha: 0.24)),
              borderRadius: t.sharpAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(),
                    style: AppText.button.copyWith(color: t.ink)),
                const SizedBox(width: AppSpace.x3),
                AppChevron(color: t.ink.withValues(alpha: 0.6), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
