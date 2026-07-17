// Destination: lib/presentation/zone/zone_screen.dart
//
// Screen 2 — the zone ranking.
//
// ═══════════════════════════════════════════════════════════════════════════
// LAYOUT A — PHÂN CẤP KHÔNG GIAN (redesign; logic presence giữ nguyên 100%)
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản trước: một chồng thẻ 150px GIỐNG HỆT NHAU. Hàng ghim (khu arbiter đã
// chốt — khu đang PHÁT thuyết minh) khác các hàng còn lại đúng MỘT DÒNG CHỮ
// meta. Doc của chính nó ghi "same size, only the meta line differs (confirmed
// design)" — nhưng kiến trúc bên dưới là HAI TẦNG khác hẳn nhau:
//     hàng ghim    = audio tier   (arbiter, điều khiển thuyết minh)
//     hàng đánh số = display tier (NearbyZonesTracker, xếp theo khoảng cách)
// Hai tầng có hai công việc, và thị giác nói chúng như nhau. Giờ tầng audio là
// một HERO, tầng display là các hàng gọn. Bố cục nói đúng thứ kiến trúc nói.
//
// Đây cũng là ngữ pháp màn 3 ĐÃ CÓ (hero + danh sách) — không phải phát minh
// mới. Hàng ở đây gần như là bản sao `_StopRow`: kệ [surfaceRaised], thumb 56,
// đĩa [badgeWell], khe x3. Một app, một mẫu danh sách.
//
// ═══════════════════════════════════════════════════════════════════════════
// MÀN NÀY TRƯỚC ĐÂY KHÔNG NÓI NGÔN NGỮ CỦA APP
// ═══════════════════════════════════════════════════════════════════════════
// Đo được, không phải cảm tính — bản trước dùng: 0 lần `accent`, 0 lần
// `surfaceRaised`, 0 lần `badgeWell`, 0 lần `shadowInk`, 0 lần `outline`, và
// KHÔNG MỘT LẦN NÀO `AppSpace`. Nó là màn hình từ trước khi ngôn ngữ tồn tại.
//
// Hệ quả đo được: NĂM đường dọc — 18 (tiêu đề), 14 (mép thẻ), 26 (badge trong
// thẻ), 30 (tên khu trong thẻ), 40 (chữ radar). Màn 1 và màn 3 có ĐÚNG MỘT.
// Đó là phần lớn cái "chưa đẹp", và nó không chữa được bằng cách thêm trang
// trí — thêm dải màu lên một lưới gãy chỉ cho ta một lưới gãy có dải màu.
//
// LƯỚI GIỜ: MỘT đường dọc = AppSpace.gutter (20). Ngồi trên nó, từ trên xuống:
// tiêu đề · câu dẫn · mép trái hero · vạch accent · tên khu · mép trái hàng.
//
// ═══════════════════════════════════════════════════════════════════════════
// BA TRẠNG THÁI, KHÔNG PHẢI HAI — và trạng thái thứ ba suýt bị bỏ sót
// ═══════════════════════════════════════════════════════════════════════════
// `ZoneProvider.isStandby` chỉ true khi CẢ HAI rỗng:
//     bool get isStandby => _status.zone == null && _ranking.isEmpty;
// Nên tồn tại một trạng thái mà `_status.zone == null` NHƯNG `_ranking` có
// phần tử ⇒ `rankedZones` KHÔNG có hàng `isCurrent` nào. Đó là hành lang giữa
// các khu: nghe thấy beacon, arbiter chưa chốt. Layout A giả định luôn có khu
// ghim ⇒ nó sẽ không có hero để dựng.
//
// Bản cũ né được điều này một cách TÌNH CỜ (mọi hàng giống nhau nên thiếu một
// hàng chẳng ảnh hưởng gì). Layout A phải xử lý tường minh:
//
//     _ranking rỗng            → _RadarStandby (toàn màn)
//     có khu ghim              → _CurrentZoneHero với ảnh + "ĐANG Ở ĐÂY"
//     nghe thấy, chưa chốt     → _CurrentZoneHero KHÔNG ảnh, "ĐANG XÁC ĐỊNH"
//
// Ô hero LUÔN TỒN TẠI, chỉ đổi mặt. Nếu nó biến mất khi arbiter thả khu, cả bố
// cục sẽ NHẢY trong lúc khách đang đi — và trạng thái đó xảy ra ở mỗi lần
// chuyển khu, tức thường xuyên nhất. Một ô cố định đổi nội dung thì đọc là
// "trạng thái của bạn đang đổi"; một ô biến mất thì đọc là "app lỗi".
//
// TOKEN FAMILIES: chữ trên hero nằm TRÊN ẢNH ⇒ inkOnImage / mutedOnImage /
// accentOnImage (đóng băng, không theo theme). Tiêu đề, hàng, radar nằm trên
// `surface` ⇒ ink / inkMuted / inkFaint / accent. Chỗ dễ trượt nhất: thumb 56
// trong hàng LÀ ảnh, nhưng chữ nằm BÊN CẠNH nó, không nằm TRÊN nó ⇒ hàng là
// surface.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

class ZoneScreen extends StatelessWidget {
  const ZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final zp = context.watch<ZoneProvider>();
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: zp.isStandby ? const _RadarStandby() : const _ZoneRankingView(),
      ),
    );
  }
}

/// Tiêu đề + hero khu hiện tại + danh sách khu lân cận.
class _ZoneRankingView extends StatelessWidget {
  const _ZoneRankingView();

  static RankedZone? _firstCurrentOrNull(List<RankedZone> rows) {
    for (final r in rows) {
      if (r.isCurrent) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final rows = context.watch<ZoneProvider>().rankedZones;
    final showDistance = context.watch<SettingsProvider>().showDistanceDebug;

    // Tách hai tầng. `isCurrent` CÓ THỂ KHÔNG TỒN TẠI — xem doc đầu file.
    final current = _firstCurrentOrNull(rows);
    final nearby = [
      for (final r in rows)
        if (!r.isCurrent) r,
    ];

    // CustomScrollView chứ không phải Column + Expanded(ListView): ở textScaler
    // lớn, tiêu đề + hero + hàng đầu có thể vượt chiều cao màn, và Column sẽ
    // TRÀN (sọc vàng-đen). Cùng bug đã sửa ở Gate — `Expanded` chống được va
    // chạm, không chống được tràn. Cuộn là lời giải, và nó vốn đúng cho một
    // danh sách dài tuỳ số khu nghe thấy.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.x4, AppSpace.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Khu vực quanh bạn',
                    style: AppText.sheetTitle.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.x2),
                Text(
                  'Ứng dụng nhận diện các khu trưng bày gần bạn qua sóng beacon.',
                  style: AppText.sheetSub.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            // x6 (24) trên và dưới hero: khe GIỮA CÁC KHỐI, cùng mức với Gate.
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.x6, AppSpace.gutter, AppSpace.x6),
            child: _CurrentZoneHero(
              row: current,
              content: content,
              showDistance: showDistance,
              onTap: current == null
                  ? null
                  : () => Navigator.of(context).pushNamed(
                        AppRouter.exhibitListRoute,
                        arguments: current.zone.major,
                      ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter, 0, AppSpace.gutter, AppSpace.x6),
          sliver: SliverList.builder(
            itemCount: nearby.length,
            itemBuilder: (context, i) {
              final row = nearby[i];
              // Thứ hạng đếm từ 2 KHI có khu ghim (khu ghim là 1, không hiện
              // số vì nhãn của nó là "Đang ở đây"). Không có khu ghim thì đếm
              // từ 1 — lúc đó không khu nào là "thứ nhất" theo nghĩa arbiter,
              // nhưng chúng vẫn xếp theo khoảng cách và số phải phản ánh đúng
              // thứ tự đang thấy.
              final rank = current == null ? i + 1 : i + 2;
              return _NearbyZoneRow(
                key: ValueKey(row.zone.major),
                row: row,
                rank: rank,
                content: content,
                showDistance: showDistance,
                onTap: () => Navigator.of(context).pushNamed(
                    AppRouter.exhibitListRoute,
                    arguments: row.zone.major),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Ô TRẠNG THÁI CỦA KHÁCH — luôn tồn tại, đổi mặt theo arbiter.
///
/// `row == null` ⇒ nghe thấy beacon nhưng arbiter chưa chốt khu (hành lang).
/// Lúc đó KHÔNG có ảnh để hiện — không khu nào được chọn — nên ô thành một
/// mảng [surfaceRaised] với chữ trên `surface`. Đó là lý do widget này không
/// dùng [HeroImage] vô điều kiện: một ảnh ở đây buộc phải là ảnh của MỘT khu cụ
/// thể, và chọn đại một khu là nói dối về thứ arbiter chưa quyết.
class _CurrentZoneHero extends StatelessWidget {
  final RankedZone? row;
  final ContentProvider content;
  final bool showDistance;
  final VoidCallback? onTap;

  const _CurrentZoneHero({
    required this.row,
    required this.content,
    required this.showDistance,
    required this.onTap,
  });

  /// 0.32 màn hình. Đây là KÍCH THƯỚC theo tỷ lệ màn — ngoại lệ hợp lệ duy
  /// nhất với "không số thô cho khoảng cách" (AppSpace luật 7): nó là bố cục
  /// compositional, không phải spacing.
  ///
  /// ⚠ Là chiều cao TỐI THIỂU, không phải cố định. Ở textScaler lớn khối chữ
  /// có thể cao hơn nó, và lúc đó ô phải GIÃN chứ không được cắt. Xem [Stack]
  /// trong [_zone]: khối chữ là con KHÔNG-positioned nên nó định cỡ Stack.
  ///
  /// Bản trước dùng `SizedBox(height: 150)` cứng với chữ trong `Positioned`: ở
  /// 2.0× với tên hai dòng, khối chữ tràn LÊN TRÊN và bị `Stack` cắt IM LẶNG —
  /// không sọc vàng-đen, không exception, chỉ mất chữ. Đó là kiểu lỗi tệ nhất:
  /// nó không báo, và nó chỉ xảy ra với khách cần chữ to nhất.
  static const double _minHeightFraction = 0.32;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final r = row;

    return Semantics(
      button: r != null,
      label: r == null
          ? 'Đang xác định khu trưng bày quanh bạn'
          : 'Bạn đang ở khu ${content.text(r.zone.name)}, '
              '${r.zone.exhibits.length} hiện vật',
      // excludeSemantics + onTap ĐI THÀNH CẶP: excludeSemantics gỡ cả cây con
      // khỏi semantics, kể cả action onTap mà InkWell tự khai. Thiếu vế thứ hai
      // là ô thôi bấm được bằng TalkBack — hồi quy im lặng, không test nào bắt
      // được. (Bản trước của màn này thiếu CẢ HAI: không exclude nên screen
      // reader đọc nhãn rồi đọc lại từng dòng chữ bên trong.)
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: r == null ? t.surfaceRaised : Colors.transparent,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.sharpAll,
          child: ClipRRect(
            borderRadius: t.sharpAll,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: media.size.height * _minHeightFraction,
              ),
              child: r == null
                  ? _searching(t)
                  : _zone(t, r, media.devicePixelRatio, media.size.width),
            ),
          ),
        ),
      ),
    );
  }

  /// Mặt "chưa chốt": không ảnh, KHÔNG vạch accent. Vạch accent là dấu hiệu
  /// "đây là khu của bạn" — dùng nó khi chưa có khu nào là nói dối bằng màu.
  Widget _searching(MuseumTokens t) => Padding(
        padding: const EdgeInsets.all(AppSpace.x5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vai trò kicker tự viết hoa — call site truyền chuỗi thường (luật
            // chữ hoa, xem app_text.dart).
            Text('Đang xác định'.toUpperCase(),
                style: AppText.kicker.copyWith(color: t.inkMuted)),
            const SizedBox(height: AppSpace.x2),
            Text(
              'Hãy tiến vào một khu trưng bày để bắt đầu nghe thuyết minh.',
              style: AppText.guidance.copyWith(color: t.inkMuted),
            ),
          ],
        ),
      );

  /// Mặt "đang ở đây": ảnh + veil + vạch accent + tên khu.
  Widget _zone(MuseumTokens t, RankedZone r, double dpr, double screenWidth) {
    final name = content.text(r.zone.name);
    final count = r.zone.exhibits.length;
    final dist = (showDistance && r.distanceMeters != null)
        ? ' · ~${r.distanceMeters!.toStringAsFixed(1)} m'
        : '';

    // Bề ngang hiển thị THẬT = màn trừ hai lề. Bản trước là hằng số 800: đúng
    // trên một máy nào đó, upscale trên 430@3x (cần 1170), phí RAM trên máy 2x.
    // Cùng LOẠI lỗi với `decodeWidth` ở Gate và `cacheWidth` ở màn 3 — ràng
    // buộc "cùng một biến" là thứ ngăn nó tái diễn, không phải sự cẩn thận.
    final decodeWidth = ((screenWidth - AppSpace.gutter * 2) * dpr).round();

    return Stack(
      // Chữ căn đáy-trái: mỏ neo của cả ô, ngồi trên đường dọc của màn.
      alignment: Alignment.bottomLeft,
      children: [
        // Positioned.fill: ảnh KHÔNG định cỡ Stack — nó lấp đầy cỡ mà khối chữ
        // (con không-positioned duy nhất) quyết định.
        Positioned.fill(
          child: HeroImage(
            filePath: content.imagePath(r.zone.heroImagePath),
            veil: t.tourCardVeil,
            cacheWidth: decodeWidth,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // mainAxisSize.min + không-positioned ⇒ Stack cao bằng khối này khi
            // nó vượt minHeight. Đây là bản sửa cho việc cắt im lặng.
            mainAxisSize: MainAxisSize.min,
            children: [
              // accentOnImage, KHÔNG phải accent: vạch này nằm TRÊN ẢNH dưới
              // veil — nền tối ở mọi theme. `accent` của preset giấy là #7E5620
              // và sẽ biến mất ở đây. Cùng lý lẽ với inkOnImage.
              Container(width: 88, height: 2, color: t.accentOnImage),
              const SizedBox(height: AppSpace.x3),
              Text('Đang ở đây'.toUpperCase(),
                  style: AppText.kicker.copyWith(color: t.accentOnImage)),
              const SizedBox(height: AppSpace.x2),
              Text(name, style: AppText.heroTitle.copyWith(color: t.inkOnImage)),
              const SizedBox(height: AppSpace.x2),
              Text('$count hiện vật$dist',
                  style: AppText.meta.copyWith(color: t.mutedOnImage)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Một khu lân cận — bản sao ngữ pháp `_StopRow` của màn 3.
///
/// Kệ [surfaceRaised] + thumb 56 + đĩa [badgeWell]. Đây KHÔNG phải trùng lặp
/// cần khử: hai màn có hai lý do đổi khác nhau (màn 3 liệt kê hiện vật trong
/// một khu; màn này liệt kê khu). Nhưng chúng phải TRÔNG như nhau, vì khách đọc
/// chúng bằng cùng một thói quen.
class _NearbyZoneRow extends StatelessWidget {
  final RankedZone row;
  final int rank;
  final ContentProvider content;
  final bool showDistance;
  final VoidCallback onTap;

  const _NearbyZoneRow({
    super.key,
    required this.row,
    required this.rank,
    required this.content,
    required this.showDistance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(row.zone.name);
    final count = row.zone.exhibits.length;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final dist = (showDistance && row.distanceMeters != null)
        ? ' · ~${row.distanceMeters!.toStringAsFixed(1)} m'
        : '';

    return Semantics(
      button: true,
      // Số thứ hạng KHÔNG đọc lên. Nó suy ra từ RSSI — chính lý do
      // `showDistance` là cờ debug chỉ dành cho nhân viên: con số đó không đủ
      // tin để đưa cho khách. "Gần bạn thứ 3" nghe như một sự thật; nó là một
      // ước lượng nhiễu. Thứ tự trong danh sách đã nói điều đó, đủ mềm.
      label: 'Khu $name, $count hiện vật',
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        // Khe giữa các hàng = x3, cùng mức với màn 3 — các hàng là MỘT khối
        // danh sách, không phải nhiều khối rời.
        padding: const EdgeInsets.only(bottom: AppSpace.x3),
        child: Material(
          color: t.surfaceRaised,
          borderRadius: t.sharpAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: t.sharpAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: t.sharpAll,
                    child: SizedBox(
                      width: AppSpace.thumb,
                      height: AppSpace.thumb,
                      child: HeroImage(
                        filePath: content.imagePath(row.zone.heroImagePath),
                        cacheWidth: (AppSpace.thumb * dpr).round(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            style: AppText.cardTitle.copyWith(color: t.ink)),
                        const SizedBox(height: AppSpace.x1),
                        Text('$count hiện vật$dist',
                            style: AppText.meta.copyWith(color: t.inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  _RankBadge(rank: rank),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Đĩa lõm mang số thứ hạng — cùng vật liệu với badge màn 3.
///
/// [MuseumTokens.badgeWell] + [MuseumTokens.inkFaint], KHÔNG phải
/// `Colors.black.withValues(alpha: 0.55)` như bản trước. Đen thô đó nằm ngoài
/// hệ token, và nó là một alpha THỨ HAI bên cạnh `scrimBack` (0x66) cho cùng
/// một ý "đĩa tối dưới một glyph" — hai con số cho một quyết định, và không con
/// số nào được đo.
///
/// Số ở đây KHÔNG chìm sâu như badge màn 3, và đó là chủ đích: ở màn 3 con số
/// là `exhibit.minor` — minor ID beacon, vô nghĩa với khách, nên nó chìm gần
/// hết. Ở đây nó là THỨ HẠNG, và thứ hạng là thông tin thật (dù mềm). Nên nó
/// dùng `inkFaint` trên `badgeWell`: bậc thấp nhất của thang ink — đọc được khi
/// nhìn, không tranh với tên khu.
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      // 36 = AppSpace.badge, cùng cỡ badge màn 3. Bản trước là 26 — không nằm
      // trên lưới 4dp, và khác màn 3 mà không có lý do nào.
      width: AppSpace.badge,
      height: AppSpace.badge,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.badgeWell, shape: BoxShape.circle),
      child: Text('$rank', style: AppText.meta.copyWith(color: t.inkFaint)),
    );
  }
}

/// Standby: không nghe thấy beacon nào. Trạng thái "đang quét" — xem doc đầu
/// file cho ba trạng thái và ranh giới giữa chúng.
class _RadarStandby extends StatefulWidget {
  const _RadarStandby();

  @override
  State<_RadarStandby> createState() => _RadarStandbyState();
}

class _RadarStandbyState extends State<_RadarStandby>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => CustomPaint(
              size: const Size(120, 120),
              // Một CustomPainter không có BuildContext, nên màu phải truyền
              // vào. Xem _RadarPainter.shouldRepaint.
              painter: _RadarPainter(_pulse.value, t.ink),
            ),
          ),
          const SizedBox(height: AppSpace.x6),
          // Vạch accent — cùng từ vựng với Gate và hero. `accent` (không phải
          // accentOnImage): khối này đứng trên `surface`, không trên ảnh.
          Container(width: 88, height: 2, color: t.accent),
          const SizedBox(height: AppSpace.x3),
          Text('Đang quét không gian'.toUpperCase(),
              style: AppText.kicker.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.x2),
          Padding(
            // Lề đo CHIỀU DÀI DÒNG (measure), không phải lề lưới — khối này căn
            // giữa nên nó không ngồi trên đường dọc nào. Cùng ngoại lệ với
            // `_NoneNearby` ở màn 3.
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x10),
            child: Text(
              'Hãy tiến vào khu trưng bày để bắt đầu nghe thuyết minh.',
              textAlign: TextAlign.center,
              style: AppText.guidance.copyWith(color: t.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t; // 0..1
  final Color ink;

  _RadarPainter(this.t, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    // Hai vòng lan ra, mờ dần khi lớn.
    for (final phase in [0.0, 0.5]) {
      final p = (t + phase) % 1.0;
      final r = maxR * p;
      final opacity = (1.0 - p) * 0.5;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = ink.withValues(alpha: opacity);
      canvas.drawCircle(center, r, paint);
    }
    canvas.drawCircle(center, 2.5, Paint()..color = ink.withValues(alpha: 0.8));
  }

  // Phải so cả `ink`: không có nó, đổi theme sẽ để radar vẽ bằng màu cũ cho tới
  // khi tick animation kế tiếp tình cờ khác.
  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.ink != ink;
}