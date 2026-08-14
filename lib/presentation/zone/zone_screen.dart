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
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/tour_progress_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class ZoneScreen extends StatelessWidget {
  const ZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final zp = context.watch<ZoneProvider>();

    return Scaffold(
      backgroundColor: t.surface,
      // THANH TRÊN ĐÈ LÊN ẢNH KHU, KHÔNG ĐỨNG TRÊN NÓ — cùng luật với màn Menu:
      // màn nào có ảnh hero thì ảnh chạm MÉP TRÊN của máy. Hàng chrome tạm thời
      // trước đây (một nút ☰ trôi lẻ ở góc phải) đã biến mất cùng bước này, đúng
      // như doc của nó tự hẹn.
      body: Stack(
        children: [
          Positioned.fill(
            child:
                zp.isStandby ? const _StandbyView() : const _ZoneRankingView(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // ⚠ HAI BIẾN THỂ, VÀ ĐÂY LÀ RANH GIỚI CỦA CHÚNG: standby không có
            // ảnh nào phía sau, nên thanh phải ĐỤC — để trong suốt thì chữ radar
            // cuộn lộn thẳng qua nó. Có khu thì thanh trong suốt và dựa vào màn
            // chắn của chính nó.
            child: MuseumTopBar(
              title: content.ui(UiKeys.zoneNearbyTitle),
              solid: zp.isStandby,
            ),
          ),
        ],
      ),
    );
  }
}

/// Không nghe thấy beacon nào: radar toàn màn.
///
/// CHỪA CHỖ CHO THANH TRÊN, khác hẳn nhánh kia. Ở đây thanh đục và không đè lên
/// ảnh nào, nên nội dung chui xuống dưới nó là bị che thật.
class _StandbyView extends StatelessWidget {
  const _StandbyView();

  @override
  Widget build(BuildContext context) => const SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: MuseumTopBar.height),
            _CompletionPrompt(),
            Expanded(child: _RadarStandby()),
          ],
        ),
      );
}

/// "Bạn đã đi hết N khu trưng bày" — GỢI Ý, không phải chuyển màn.
///
/// ═════════════════════════════════════════════════════════════════════════
/// VÌ SAO KHÔNG TỰ ĐẨY SANG MÀN TỔNG KẾT
/// ═════════════════════════════════════════════════════════════════════════
/// Điều kiện "đã ghé đủ mọi khu" chạm được tại đúng khoảnh khắc khách BƯỚC VÀO
/// khu cuối — tức là lúc họ vừa mới bắt đầu xem nó, và thuyết minh của khu đó
/// còn chưa phát xong câu đầu. Tự chuyển màn ở đó là cắt ngang chính cái phần
/// mà khách vừa đi tới. "Ghé đủ" không có nghĩa là "xem xong".
///
/// Nên nó là một thẻ nằm im, tắt được, và không bao giờ tự làm gì.
class _CompletionPrompt extends StatefulWidget {
  const _CompletionPrompt();

  @override
  State<_CompletionPrompt> createState() => _CompletionPromptState();
}

class _CompletionPromptState extends State<_CompletionPrompt> {
  /// Đã bấm "Để sau". Sống cùng ZoneScreen — mà ZoneScreen là gốc ngăn xếp
  /// suốt tour, nên một lần tắt là tắt tới hết chuyến đi. Tour sau dựng lại
  /// cây từ đầu nên cờ tự sạch.
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final progress = context.watch<TourProgressProvider>().progress;
    if (!progress.hasVisitedEveryZone) return const SizedBox.shrink();

    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter, AppSpace.x3, AppSpace.gutter, 0),
      child: Container(
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: t.sharpAll,
          border: Border.all(color: t.outline),
        ),
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content.uif(UiKeys.tourCompleteTitle,
                  {'n': '${progress.totalZones}'}),
              style: AppText.cardTitle.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSpace.x2),
            Text(content.ui(UiKeys.tourCompleteBody),
                style: AppText.meta.copyWith(color: t.inkMuted)),
            const SizedBox(height: AppSpace.x3),
            Row(
              children: [
                _PromptAction(
                  label: content.ui(UiKeys.tourCompleteCta),
                  emphasised: true,
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppRouter.summaryRoute),
                ),
                const SizedBox(width: AppSpace.x2),
                _PromptAction(
                  label: content.ui(UiKeys.tourCompleteDismiss),
                  emphasised: false,
                  onTap: () => setState(() => _dismissed = true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptAction extends StatelessWidget {
  final String label;
  final bool emphasised;
  final VoidCallback onTap;

  const _PromptAction({
    required this.label,
    required this.emphasised,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: emphasised ? t.ctaFill : Colors.transparent,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.sharpAll,
          child: Container(
            height: AppSpace.tap,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            alignment: Alignment.center,
            child: Text(
              label.toUpperCase(),
              style: AppText.button
                  .copyWith(color: emphasised ? t.ctaLabel : t.inkMuted),
            ),
          ),
        ),
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
    final content = context.watch<ContentProvider>();
    final rows = context.watch<ZoneProvider>().rankedZones;

    // Tách hai tầng. `isCurrent` CÓ THỂ KHÔNG TỒN TẠI — xem doc đầu file.
    final current = _firstCurrentOrNull(rows);
    final nearby = [
      for (final r in rows)
        if (!r.isCurrent) r,
    ];

    // CustomScrollView chứ không phải Column + Expanded(ListView): số khu nghe
    // thấy là dữ liệu, có lúc một có lúc năm, và ở textScaler lớn khối chữ trong
    // hero cũng cao lên. Column sẽ TRÀN (sọc vàng-đen); cuộn là lời giải.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ZoneHero(
            row: current,
            content: content,
            onTap: current == null
                ? null
                : () => _open(context, current.zone.major),
          ),
        ),

        // Thẻ gợi ý kết thúc — KHÔNG có trong bản vẽ, và nó nằm ĐÂY chứ không
        // đè lên ảnh: bản vẽ để cả khối ảnh cho bức ảnh, và một cái thẻ nổi trên
        // đó sẽ là vật thể duy nhất trong app làm việc ấy. Rỗng thì nó tự co về
        // 0 nên khe x4 bên dưới vẫn đúng.
        const SliverToBoxAdapter(child: _CompletionPrompt()),

        // `.nearset { margin-top: x4; gap: 8px; margin-bottom: x8 }`.
        //
        // Khe 16 với khối trên, 8 giữa hai khối — hai khu bên cạnh gần nhau hơn
        // khoảng cách tới khu đang đứng, nên mắt tự gom chúng thành một nhóm mà
        // không cần một dòng nhãn nào tuyên bố điều đó.
        SliverPadding(
          padding: const EdgeInsets.only(
              top: AppSpace.x4, bottom: AppSpace.x8),
          sliver: SliverList.builder(
            itemCount: nearby.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _NearZoneBlock(
                key: ValueKey(nearby[i].zone.major),
                row: nearby[i],
                content: content,
                onTap: () => _open(context, nearby[i].zone.major),
              ),
            ),
          ),
        ),

        // `.screen.has-tabs` — vỏ đáy do shell bơm vào MediaQuery.padding; màn
        // này không dùng SafeArea (ảnh phải chạm mép trên) nên phải tự chừa.
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, int major) => Navigator.of(context)
      .pushNamed(AppRouter.exhibitListRoute, arguments: major);
}

/// `.zhero` — KHU ĐANG ĐỨNG. Ảnh 480 chạm cả hai mép máy và chạm mép trên.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// BA THỨ VỪA BỊ GỠ, VÀ CẢ BA ĐỀU LÀ QUYẾT ĐỊNH CỦA BẢN VẼ
/// ═══════════════════════════════════════════════════════════════════════════
///
///   vạch accent 88×2   ─┐ hai thứ này là tín hiệu "đây là khu CỦA BẠN".
///   kicker "ĐANG Ở ĐÂY" ─┘ Bản vẽ chuyển tín hiệu ấy hết vào TÊN MÀN ở thanh
///                          trên ("Khu vực quanh bạn").
///   dòng "N hiện vật"     thay bằng câu mô tả — con số ấy nay chỉ còn ở khối
///                          nhỏ bên dưới, nên hai cỡ không nói cùng một thứ.
///
/// ⚠ GHI CHÚ THIẾT KẾ TỰ NÊU RỦI RO CỦA CHÍNH NÓ, và nó chưa được kiểm trên máy
/// thật: ảnh khu ở màn này và ảnh khu ở màn 4b nay cao bằng nhau, nên thứ duy
/// nhất phân biệt *khu tôi đang đứng* với *khu tôi đang xem* là mấy chữ ở thanh
/// trên. Nếu thực địa cho thấy khách nhầm hai màn, đây là chỗ để nhìn lại — và
/// câu trả lời có thể là trả kicker về, không phải thêm một dòng chữ mới.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// ẢNH ĐỂ NGUYÊN — KHÔNG LỚP PHỦ, VÀ ĐÂY LÀ MỘT LẦN ĐI KHỎI BẢN VẼ
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Bản vẽ có `.zhero .veil` (0.94 ở 4% đáy → 0.30 giữa khối → 0.38 đỉnh) và
/// `.zhero.near .veil`. CẢ HAI ĐÃ BỊ GỠ, theo quyết định sản phẩm sau khi nhìn
/// trên máy thật.
///
/// Vì sao chúng hại ở đây: veil tan vào `surface`, mà preset mặc định của app là
/// GIẤY (#EEEEE2). Nên lớp phủ ấy không dìm ảnh xuống — nó RÓT MÀU GIẤY LÊN ẢNH,
/// 30–38% trên gần hết bề mặt. Bức ảnh tư liệu đọc ra như bị bạc màu. Luật veil
/// của bản vẽ được cân khi app còn một preset tối duy nhất; nó không sống sót
/// qua lần đảo preset, và đây là chỗ thứ hai nó lộ ra (chỗ thứ nhất là màn chắn
/// riêng của thanh trên, xem `museum_top_bar.dart`).
///
/// HỆ QUẢ VỀ MÀU CHỮ, và nó đi kèm chứ không tách rời: chữ ở đây giữ họ
/// `inkOnImage` / `mutedOnImage`. Với veil, chữ trắng nằm trên vùng ảnh vừa bị
/// phủ trắng — đó chính là "chữ mờ" mà lần chạy thử bắt được. Không veil thì
/// chữ trắng lại đúng, và đúng theo định nghĩa của token: `--on-img` sinh ra cho
/// *chữ nằm trên ảnh CHƯA bị phủ*, cố định sáng ở cả hai preset vì thứ quyết
/// định màu chữ ở đó là BỨC ẢNH, không phải cái theme.
///
/// ⚠ RỦI RO CÒN LẠI, phải canh bằng mắt khi bảo tàng thay ảnh: một bức ảnh khu
/// SÁNG MÀU sẽ nuốt chữ trắng. Bản vẽ chống điều đó bằng veil; ta vừa bỏ veil,
/// nên hàng phòng thủ duy nhất còn lại là kỷ luật chọn ảnh ở CMS. Nếu một ngày
/// cần chống lại điều đó bằng code, cách rẻ nhất KHÔNG phải là trả veil toàn
/// khối về — mà là một dải tối ngắn chỉ sau khối chữ, như màn chắn của thanh
/// trên đang làm.
///
/// (Thanh trên vẫn có màn chắn riêng của nó và không phụ thuộc quyết định này —
/// đó đúng là lý do màn chắn ấy tồn tại.)
///
/// `row == null` ⇒ nghe thấy beacon nhưng arbiter chưa chốt khu (hành lang giữa
/// hai khu). Lúc đó KHÔNG có ảnh để hiện — chọn đại ảnh một khu là nói dối về
/// thứ arbiter chưa quyết — nên khối giữ nguyên chiều cao và đổi thành một mảng
/// [MuseumTokens.surfaceRaised]. Giữ nguyên chiều cao là cố ý: trạng thái này
/// xảy ra ở MỖI lần chuyển khu, và một khối co giãn ở đó làm cả màn nhảy.
class _ZoneHero extends StatelessWidget {
  final RankedZone? row;
  final ContentProvider content;
  final VoidCallback? onTap;

  const _ZoneHero({
    required this.row,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = row;
    final media = MediaQuery.of(context);
    final height = DesignSize.zoneHero * DesignSize.verticalScale(context);

    return Semantics(
      button: r != null,
      label: r == null
          ? content.ui(UiKeys.zoneIdentifyingSemantics)
          : content.uif(UiKeys.zoneCurrentSemantics, {
              'zone': content.text(r.zone.name),
              'count': '${r.zone.exhibits.length}',
            }),
      // excludeSemantics + onTap ĐI THÀNH CẶP: excludeSemantics gỡ cả cây con
      // khỏi semantics, kể cả action onTap mà InkWell tự khai. Thiếu vế thứ hai
      // là ô thôi bấm được bằng TalkBack — hồi quy im lặng, không test nào bắt.
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Material(
          color: r == null ? t.surfaceRaised : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: r == null
                ? _searching(t)
                : _zone(t, r, media.devicePixelRatio, media.size.width),
          ),
        ),
      ),
    );
  }

  /// Mặt "chưa chốt": không ảnh, và vì không ảnh nên chữ về họ `surface`.
  Widget _searching(MuseumTokens t) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter, 0, AppSpace.gutter, AppSpace.x6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vai trò kicker tự viết hoa — call site truyền chuỗi thường.
            Text(content.ui(UiKeys.zoneIdentifying).toUpperCase(),
                style: AppText.kicker.copyWith(color: t.inkMuted)),
            const SizedBox(height: AppSpace.x2),
            Text(
              content.ui(UiKeys.zoneEnterPromptA),
              style: AppText.guidance.copyWith(color: t.inkMuted),
            ),
          ],
        ),
      );

  /// Mặt "đang ở đây": ảnh tràn mép + veil + tên khu + câu mô tả.
  Widget _zone(MuseumTokens t, RankedZone r, double dpr, double screenWidth) {
    final summary = content.textOrNull(r.zone.summary);

    // Bề ngang hiển thị THẬT = cả màn, vì ảnh nay tràn hai mép. Bản trước trừ
    // hai lề 20 — đúng khi khối còn có lề, sai từ lúc nó hết lề.
    final decodeWidth = (screenWidth * dpr).round();

    return Stack(
      fit: StackFit.expand,
      children: [
        // KHÔNG LỚP PHỦ NÀO. Xem khối doc "ẢNH ĐỂ NGUYÊN" ở đầu class.
        HeroImage(
          filePath: content.imagePath(r.zone.heroImagePath),
          // `.zhero .img { background-position: center }` — KHÁC hai màn khoảnh
          // khắc (34%), vì ở đây không có lớp phủ nào dồn vùng nhìn được lên
          // trên; cả bức ảnh đều được nhìn.
          cacheWidth: decodeWidth,
        ),
        // `.zhero .txt { left/right: gutter; bottom: x6 }`
        Positioned(
          left: AppSpace.gutter,
          right: AppSpace.gutter,
          bottom: AppSpace.x6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content.text(r.zone.name),
                  style: AppText.heroTitle.copyWith(color: t.inkOnImage)),
              // Thiếu `summary` thì KHÔNG có dòng nào, và cũng không có khe —
              // bundle ngoài hiện trường chưa có khoá này. Xem [ZoneInfo.summary].
              if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: AppSpace.x3),
                Text(summary,
                    style: AppText.heroSub.copyWith(color: t.mutedOnImage)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// `.zhero.near` — KHU BÊN CẠNH. Cùng khối ảnh với khu đang đứng, chỉ nhỏ lại.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// ĐÂY LÀ CHỖ DỄ HỎNG NHẤT CỦA MÀN NÀY, VÀ NÓ ĐÃ TỪNG HỎNG
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Bản trước vẽ khu bên cạnh thành một HÀNG: kệ `surfaceRaised`, ảnh vuông 56,
/// chữ nằm bên cạnh ảnh, một đĩa số thứ hạng ở mép phải. Đó là hình dáng của một
/// MỤC NỘI DUNG — và một danh sách mục nội dung nằm ngay dưới một tiêu đề lớn
/// thì trong app nào cũng có nghĩa "những thứ THUỘC VỀ cái ở trên". Khách đọc ra
/// *đây là các hiện vật trong khu này*, ngược hẳn sự thật.
///
/// Cách sửa không phải thêm một dòng chữ giải thích, mà trả cho chúng đúng hình
/// dáng: ảnh tràn hai mép, chữ NẰM TRONG ảnh, cùng veil, chỉ khác chiều cao.
/// Một hình dáng lặp lại ở hai cỡ đọc ra "cùng loại, khác khoảng cách"; hình
/// dáng khác nhau mới đọc ra "cái này thuộc về cái kia".
///
/// KHÔNG DẤU ›, KHÔNG SỐ THỨ HẠNG. Cả khối đã bấm được và hình dáng của nó đã
/// nói "đây là một nơi để đi tới" — thêm mũi tên là nói lại lần thứ hai. Số thứ
/// hạng thì suy ra từ RSSI, một ước lượng nhiễu được trình bày như một sự thật;
/// thứ tự trong danh sách đã nói điều đó, đủ mềm.
///
/// KHÔNG LỚP PHỦ, cùng lý do và cùng rủi ro với khối lớn — xem khối doc "ẢNH ĐỂ
/// NGUYÊN" ở [_ZoneHero]. Hai khối phải cùng quyết định: chúng là MỘT hình dáng
/// ở hai cỡ, và một cái bị phủ còn cái kia không thì lời tuyên bố "cùng loại,
/// khác khoảng cách" gãy ngay.
class _NearZoneBlock extends StatelessWidget {
  final RankedZone row;
  final ContentProvider content;
  final VoidCallback onTap;

  const _NearZoneBlock({
    super.key,
    required this.row,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(row.zone.name);
    final count = row.zone.exhibits.length;
    final media = MediaQuery.of(context);
    final height = DesignSize.nearZone * DesignSize.verticalScale(context);

    return Semantics(
      button: true,
      label: content.uif(
          UiKeys.zoneRowSemantics, {'zone': name, 'count': '$count'}),
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HeroImage(
                  filePath: content.imagePath(row.zone.heroImagePath),
                  cacheWidth: (media.size.width * media.devicePixelRatio).round(),
                ),
                // `.zhero.near .txt { bottom: x4 }` — thấp hơn bản lớn một nấc,
                // vì khối thấp hơn.
                Positioned(
                  left: AppSpace.gutter,
                  right: AppSpace.gutter,
                  bottom: AppSpace.x4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          style:
                              AppText.cardTitle.copyWith(color: t.inkOnImage)),
                      // `margin-top: 2px` — bù trừ quang học, không phải khe bố
                      // cục; xem luật (2b) ở app_space.dart.
                      const SizedBox(height: 2),
                      Text(
                        content.uif(
                            UiKeys.zoneExhibitCount, {'count': '$count'}),
                        style: AppText.meta.copyWith(color: t.mutedOnImage),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final content = context.read<ContentProvider>();
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
          Text(content.ui(UiKeys.zoneScanning).toUpperCase(),
              style: AppText.kicker.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.x2),
          Padding(
            // Lề đo CHIỀU DÀI DÒNG (measure), không phải lề lưới — khối này căn
            // giữa nên nó không ngồi trên đường dọc nào. Cùng ngoại lệ với
            // `_NoneNearby` ở màn 3.
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x10),
            child: Text(
              content.ui(UiKeys.zoneEnterPromptB),
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