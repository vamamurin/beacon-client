// Destination: lib/presentation/exhibits/exhibit_list_screen.dart
//
// Screen 3 — the exhibit list of ONE zone.
//
// MANIFEST-DRIVEN LIST (confirmed with product): once in the zone (major
// detected), the list shows the FULL set of exhibits from the manifest, in
// manifest order — it does NOT filter by which per-exhibit (minor) beacon is
// currently heard. Rationale: a zone may carry only ONE beacon (the major), and
// per-minor reception is fragile; the manifest is the single source of truth for
// BOTH what's shown here AND what the auto-tour plays (see TourAudioController
// ._playNextFrom, which likewise walks the whole manifest). A dead/weak exhibit
// beacon therefore no longer hides its exhibit — it's still listed and tappable.
//
// (History: an earlier Phase-4 change made this presence-driven via
// ExhibitPresenceTracker. That tracker has since been removed everywhere.)
//
// ZONE STILL FROZEN: `major` comes from route arguments. If the arbiter switches
// zones underneath, this screen keeps its frozen `major` (Phase-1 rule); only
// screen 2 follows the arbiter.
//
// NO RANKING: rows keep MANIFEST ORDER. The list is now static per zone (no
// live membership stream), so it rebuilds only on zone content change.
//
// TOKEN FAMILIES: only the hero is ON the image (inkOnImage / mutedOnImage —
// fixed across themes, because the photograph doesn't brighten in light mode).
// Everything below it — section band, rows, empty state — sits on `surface`
// and follows the theme. The 56x56 thumbnail is an image, but the row text
// sits BESIDE it, not on it: that row is surface. Easiest place to slip.
//
// ═══════════════════════════════════════════════════════════════════════════
// LƯỚI CỦA MÀN NÀY — đọc AppSpace trước khi sửa bất kỳ khoảng cách nào
// ═══════════════════════════════════════════════════════════════════════════
//
// ĐƯỜNG DỌC TRÁI = AppSpace.gutter (20). Ngồi trên nó: nút back · kicker "KHU
// TRƯNG BÀY" · tên khu · meta hero · mép trái thẻ hiện vật.
// ĐƯỜNG DỌC PHẢI = gutter. Ngồi trên nó: nút intro của khu · mép phải thẻ.
//
// LỖI ĐÃ SỬA (đừng để tái diễn):
//   • Nút back nằm trong `leading` MẶC ĐỊNH của SliverAppBar (rộng 56, nút
//     48) ⇒ mép trái nút rơi ở 4dp. Nó không thẳng hàng với BẤT CỨ THỨ GÌ
//     trên màn. Giờ leadingWidth = gutter + tap và có padding tường minh.
//   • Hero text `right: 18 + 56 + 14` — ba số thô cộng lại thành 88, không ai
//     đọc ra ý nghĩa. Giờ là gutter + actionCircle + x4, đọc thành câu: "chừa
//     lề, chừa nút, chừa khoảng thở".
//   • cacheWidth hằng số (1200 cho hero, 168 cho thumb). 1200 đúng trên máy
//     390@3x, sai trên 430@3x (upscale). 168 đúng trên 3x, over-decode 1.5×
//     trên 2x. Cùng LOẠI lỗi với decodeWidth ở Gate — giờ cả hai tính từ dpr.
//   • Nhịp dọc 6/3/13/14/10 → thu về hai mức: x2 (8) trong khối, x3 (12) giữa
//     các hàng, x4 (16) cho khe ngang lớn.
//
// ─────────────────────────────────────────────────────────────────────────────
// BỐ CỤC (redesign bước 1 — thuần thị giác, logic presence giữ nguyên):
//   • Hero CO GIÃN 80% màn hình (SliverAppBar, tham chiếu Rijksmuseum):
//     mở màn là ảnh gần trọn màn, ~20% dưới hé danh sách làm lời mời vuốt;
//     vuốt lên thì ảnh thu lại, nút back ghim ở đỉnh. Chữ trên hero fade
//     theo độ thu để không chui vào thanh ghim.
//   • Hint bar (nền ctaFill nhưng không bấm được — giả dạng nút) đã bỏ, và
//     câu "chọn theo số trên nhãn" cũng bỏ nốt: bảo tàng KHÔNG có nhãn số
//     cạnh hiện vật. _SectionBand (dải màu 28px) cũng đã bị gỡ: một dải màu
//     LÀ một cạnh — nó chia cắt hero với danh sách chứ không nối được, và
//     không giá trị màu nào cứu nổi (xem doc _ZoneHeroBar). Thay bằng HOÀ
//     TAN: gradient ease trong hero, ảnh loãng dần đúng về màu surface mà
//     danh sách đứng trên. Meta trên hero nói đúng điều gradient đang làm.
//   • Hàng hiện vật đứng trên "kệ" [surfaceRaised] thay vì trôi trên nền
//     trống; badge số tô [surface] nên đọc là đĩa LÕM trên kệ đó.
//   • Nút intro của khu (_ZoneIntroButton, góc phải-dưới hero): PHẢN CHIẾU
//     trạng thái engine — tam giác khi im, hai gạch khi intro CỦA KHU NÀY
//     đang phát. Chạm đổi hành vi theo trạng thái: pause / phát tiếp giữa
//     chừng / phát từ đầu (tapZoneIntro). Xem doc của widget.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/audio_feedback.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

class ExhibitListScreen extends StatefulWidget {
  /// Fixed zone identity from route arguments — the freeze anchor.
  final int major;

  const ExhibitListScreen({super.key, required this.major});

  @override
  State<ExhibitListScreen> createState() => _ExhibitListScreenState();
}

class _ExhibitListScreenState extends State<ExhibitListScreen> {
  // Nối `open` (độ mở của hero) từ flexibleSpace tới leading — xem doc
  // `scrimBack` ở museum_tokens.dart cho lý do việc nối dây này tồn tại.
  // `Listenable` chứ không phải `ValueNotifier<double>` riêng: ScrollController
  // đã LÀ một Listenable, việc thêm một tầng thông báo thứ hai chỉ tạo ra hai
  // nguồn sự thật có thể trôi khỏi nhau.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final zone = content.zoneByMajor(widget.major);

    if (zone == null) {
      // Unknown major (stale route after a bundle swap) — graceful, not a crash.
      return Scaffold(
        backgroundColor: t.surface,
        body: Center(
          child: Text(content.ui(UiKeys.exhibitListZoneNotFound),
              style: AppText.meta.copyWith(color: t.inkMuted)),
        ),
      );
    }

    // Danh sách hiện vật = TRỌN manifest của khu, theo thứ tự manifest. Chỉ cần
    // đang trong khu (major) là hiện hết — không lọc theo sóng minor. (Trước đây
    // lọc theo ExhibitPresenceTracker; đã gỡ để hiển thị + audio đều dựa trọn
    // vào manifest, đồng nhất với auto-tour phát hết hiện vật.)
    final visible = zone.exhibits;

    return Scaffold(
      backgroundColor: t.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _ZoneHeroBar(
            zone: zone,
            content: content,
            scrollController: _scrollController,
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _ZoneEmpty(),
            )
          else
            SliverPadding(
              // Trái/phải = gutter ⇒ mép thẻ thẳng hàng với kicker và tên
              // khu trên hero. Dưới = x6 + inset hệ thống (gesture bar) —
              // KHÔNG gộp vào một số thô, nó khác nhau trên mỗi máy.
              // Trên = x6: hero và danh sách là hai KHỐI. Vùng tan đã kết thúc
              // bên trong hero, nên đây là surface sạch — khe này cho
              // dải chuyển kịp "hạ cánh" trước khi thẻ đầu tiên xuất hiện.
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x6,
                AppSpace.gutter,
                AppSpace.x6 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, i) => _StopRow(
                  exhibit: visible[i],
                  content: content,
                  major: widget.major,
                  onTap: () => _openExhibit(context, visible[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openExhibit(BuildContext context, ExhibitInfo exhibit) {
    // Rule 2a: tap là yêu cầu tường minh -> interrupt & play (hoặc load-for-
    // transcript trong reading mode). `major` là zone ĐÓNG BĂNG của màn hình
    // này, không phải zone hiện tại của arbiter.
    //
    // Cố ý gọi showAudioFeedback TRƯỚC pushNamed: ScaffoldMessenger resolve tới
    // messenger của MaterialApp, nên snackbar nổi trên màn Chi tiết vừa mở —
    // đúng nơi visitor đang tự hỏi vì sao không có tiếng. Đừng đảo thứ tự.
    final r = context
        .read<AudioProvider>()
        .tapExhibit(major: widget.major, minor: exhibit.minor);
    showAudioFeedback(context, r);

    Navigator.of(context).pushNamed(
      AppRouter.exhibitDetailRoute,
      arguments: ExhibitDetailArgs(major: widget.major, minor: exhibit.minor),
    );
  }
}

/// Hero co giãn của khu trưng bày. Mở rộng = 80% màn hình; thu về = thanh ghim
/// chỉ còn nút back (không lặp tên khu trên thanh ghim — người dùng vừa đọc nó
/// trên hero và màn này chỉ sâu một cấp; thêm title fade là việc của lần sau
/// nếu thấy cần). Everything in here is ON the image.
///
/// ═════════════════════════════════════════════════════════════════════════
/// HOÀ TAN — ẢNH KHÔNG KẾT THÚC, NÓ TAN
/// ═════════════════════════════════════════════════════════════════════════
///
/// Trước đây có `_SectionBand`: một dải màu 28px, sliver riêng, đặt giữa hero
/// và danh sách. Nó KHÔNG BAO GIỜ nối được hai phần — một dải màu là một
/// CẠNH, và cạnh thì chia cắt. Đó là bản chất của nó, không phải lỗi chỉnh
/// màu. Hạ tông nó xuống trung tính chỉ làm nó thành một sợi hairline béo;
/// tăng tông lên nâu đất thì nó cắt càng mạnh. Không có giá trị màu nào cứu
/// được một widget đang làm đúng ngược lại việc ta cần.
///
/// Nó còn có một lỗi nặng hơn mà không ai thấy: nó là SLIVER. Nó cuộn theo
/// danh sách và biến mất sau vài chục pixel. "Đường nối" chỉ tồn tại ở offset
/// 0 — sau đó ảnh và danh sách gặp nhau bằng một cạnh cứng trần trụi, không
/// có gì ở giữa cả.
///
/// Giờ: gradient tan ĐẶT TRONG HERO, phủ [_dissolveExtent] pixel đáy, chạy về
/// đúng màu `surface` mà danh sách đứng trên. Ảnh không dừng ở một đường — nó
/// loãng dần rồi thành nền, và hiện vật hiện ra từ chỗ nó loãng. Đây là ánh
/// sáng rọi tường phòng trưng bày tắt dần, không phải hai tấm giấy dán cạnh
/// nhau.
///
/// BỐN CHI TIẾT KỸ THUẬT quyết định nó "sang" hay "rẻ tiền":
///
/// 1. TUYỆT ĐỐI KHÔNG `Colors.transparent`. Đó là #00000000 — ĐEN với alpha 0.
///    Gradient nội suy sang nó sẽ ám xám bẩn ở khoảng giữa (ai cũng dính bug
///    này). Luôn là `mauDich.withValues(alpha: 0)`: RGB đứng yên, chỉ alpha
///    chạy ⇒ không lệch sắc. Scrim ở Gate đã làm đúng — chỗ này phải khớp.
///
/// 2. RAMP EASE, KHÔNG TUYẾN TÍNH. Mắt cảm nhận độ chói theo hàm mũ, nên một
///    ramp alpha đều tay lại TRÔNG như có một đường bắt đầu (dải Mach). Bảy
///    stop cong ⇒ tốc độ đổi cảm nhận được mới đều.
///
/// 3. [_dissolveExtent] TÍNH BẰNG dp CỐ ĐỊNH, không theo % màn hình. Chất
///    lượng dải chuyển phụ thuộc số pixel VẬT LÝ nó trải qua: cùng một ramp
///    nén vào 60px sẽ vỡ dải, giãn ra 112px thì mượt. Đây là ngoại lệ hợp lệ
///    của luật "tỷ lệ theo màn hình" ở doc _WelcomeCollage.
///
/// 4. TẮT Ở highContrast BẰNG MỘT `if` TƯỜNG MINH — `if (t.heroDissolveEnabled)`.
///    Ảnh gặp danh sách bằng cạnh cứng: hoà tan là PHẢN ĐỀ của tương phản cao.
///
///    Bản trước làm việc này bằng một mẹo — nhân mọi stop với alpha của token
///    `heroDissolve`, vốn trong suốt ở HC ⇒ ramp tự biến mất, không cần nhánh
///    nào. Mẹo đó gọn và nó SAI, chỉ chưa lộ: nó khoá chặt hai thứ không liên
///    quan — "ramp hạ cánh vào MÀU nào" và "preset này CÓ ramp không" — vào
///    cùng một field. Khi 1.8 gỡ field đó (nó chỉ là `surface` chép lại, xem
///    doc token) thì mẹo mất chỗ bám: `surface` đục ở cả ba preset, nên ramp
///    sẽ BẬT ở HC. Điều kiện phải hiện ra thành chữ mới soát được.
///
///    Lợi ích phụ: HC không dựng gradient nào cả, thay vì dựng bảy stop trong
///    suốt rồi vẽ chúng lên nhau.
///
/// ⚠ HỆ QUẢ HÌNH HỌC — lý do [_heroTextBottom] tồn tại: chữ hero từng neo ở
/// `bottom: x6` (24), tức NẰM GIỮA vùng tan. Ở light theme, đáy hero bị kéo về
/// giấy #F6F3EE trong khi tên khu là inkOnImage (TRẮNG cố định) ⇒ tên khu biến
/// mất. Hoà tan và chữ neo đáy không thể cùng tồn tại; chữ phải dời lên.
///
/// LƯỚI: nút back, khối chữ và nút intro đều neo vào hai đường dọc của màn.
/// Khối chữ và nút intro CÙNG `bottom` ⇒ chúng nằm trên một đường ngang. Lưu ý
/// quang học: hộp chữ có phần chân (descender) trống ở đáy, nên hình tròn căn
/// đáy tuyệt đối sẽ trông hơi thấp ~2dp. Chấp nhận: bù trừ quang học bằng số
/// lẻ sẽ phá lưới, và ở cỡ này mắt không bắt được.
class _ZoneHeroBar extends StatelessWidget {
  final ZoneInfo zone;
  final ContentProvider content;

  /// Nguồn CHUNG của `open` cho cả [leading] lẫn [flexibleSpace]. Trước bản
  /// sửa này, hai vùng đó tính `open` ở hai nơi tách biệt — `flexibleSpace` có
  /// nó qua `LayoutBuilder`, `leading` không có đường nào tới nó — nên nút back
  /// mặc định luôn là `inkOnImage`, bất kể hero đang mở hay đã thu. Xem doc
  /// `scrimBack` ở museum_tokens.dart.
  final ScrollController scrollController;

  const _ZoneHeroBar({
    required this.zone,
    required this.content,
    required this.scrollController,
  });

  /// Chiều cao vùng hoà tan. 144 = 4×36. Cố định theo dp — xem chi tiết 3 ở
  /// doc class.
  ///
  /// ⚠ BA HẰNG SỐ NÀY KHOÁ VÀO NHAU, ĐỔI MỘT LÀ PHẢI TÍNH LẠI CẢ BA:
  ///     [_dissolveExtent]  D   — dài bao nhiêu
  ///     [_heroTextBottom]  B   — chữ đứng ở đâu (phải chỗ alpha ≲ 0.05)
  ///     _heroVeil stop         — vùng phẳng veil ở museum_tokens.dart
  /// Và chúng khoá cả với ĐƯỜNG CONG: đổi [_fadeAlphas] là đổi luôn chỗ nào
  /// có alpha 0.05, tức đổi B.
  ///
  /// Công thức: B ≥ D × (1 − t₀₀₅), với smootherstep t₀₀₅ ≈ 0.19 ⇒ B ≥ D×0.81.
  ///     D=144 → B≥117 → lấy 120 (bội số 4)   → alpha tại chữ = 0.035 ✓
  /// Rồi veil phải phủ phẳng hết khối chữ (B .. B+85):
  ///     cần 205dp; stop 0.42 cho 224dp trên máy 667 (chật nhất) ✓
  ///
  /// 112 → 144 vì bản 112 vẫn đọc ra một đường: dù màu đã khớp và đã có vùng
  /// hạ cánh, độ dốc lớn nhất là thứ mắt gọi là "line", không phải điểm cuối.
  /// 144 + smootherstep = êm hơn bản đầu 42%. Nếu vẫn thấy đường, nấc kế tiếp
  /// là D=176 / B=144 / veil stop 0.46 (êm hơn 52%) — nhưng lúc đó chữ hero
  /// trôi lên gần 1/4 hero, hãy nhìn bố cục trước khi lấy.
  static const double _dissolveExtent = 144;

  /// Đáy khối chữ hero. 120 = 4×30.
  ///
  /// ⚠ ĐÂY LÀ NGHIỆM DUY NHẤT, KHÔNG PHẢI KHẨU VỊ. Đừng hạ xuống cho "bớt lơ
  /// lửng" — đã thử và đã chứng minh là không được:
  ///
  ///   VÙNG CHẾT của hoà tan = α 0.2…0.8 = t 0.32…0.68 = **52dp**.
  ///   Trong dải đó nền là xám trung tính (trộn ảnh với surface), và xám trung
  ///   tính GIẾT CẢ TRẮNG LẪN ĐEN — không tồn tại màu chữ nào sống được, kể cả
  ///   màu riêng cho từng theme. Khe giữa các dòng trong khối chữ chỉ 8dp, nên
  ///   khối chữ KHÔNG THỂ nhảy qua hố 52dp đó. Suy ra: cả khối phải nằm trên
  ///   α=0.2, tức B ≥ 118 → 120.
  ///
  /// Đã bác bỏ bằng số, đừng thử lại:
  ///   • B=60 + đổi màu riêng dòng meta → meta 6.0:1 với ảnh sáng nhưng
  ///     **3.2:1 với ảnh tối** ở theme sáng. Ảnh do bảo tàng nạp, ta không
  ///     kiểm soát được.
  ///   • Gradient màu chữ ngược gradient nền → hai dốc ngược giữa cùng hai cực
  ///     BẮT BUỘC cắt nhau; chỗ cắt là **1.11:1**, tức chữ tàng hình.
  ///
  /// Tại B=120, alpha = 0.035: chữ chỉ bị phủ ~3.5% surface, không đủ lay
  /// chuyển inkOnImage ở preset nào.
  ///
  /// CẢM GIÁC "LƠ LỬNG" đã chữa bằng vạch accent làm sàn — xem chỗ dựng nó
  /// trong flexibleSpace. Chữa bằng cách hạ B là chữa vào chỗ không có bệnh.
  static const double _heroTextBottom = 120;

  /// SMOOTHERSTEP (Perlin: 6t⁵ − 15t⁴ + 10t³), lấy mẫu tại 9 điểm đều — Flutter
  /// nội suy THẲNG giữa các stop, nên số điểm chính là độ mịn của đường cong.
  ///
  /// VÌ SAO ĐỔI TỪ EASE-IN: đường cũ êm lúc khởi hành nhưng LAO NHANH lúc về
  /// đích — chỗ dốc nhất nằm sát ngay đáy, và mắt đọc chỗ dốc nhất thành một
  /// đường kẻ. smootherstep có ĐẠO HÀM BẰNG 0 Ở CẢ HAI ĐẦU: không có điểm nào
  /// để mắt bám vào, ở đầu nào cũng vậy.
  ///
  /// KHÔNG CÒN VÙNG HẠ CÁNH NHÂN TẠO: đường cũ phải thêm stop `0.88 → alpha
  /// 1.0` giữ phẳng tới đáy, vì nó về đích quá gấp. smootherstep tới đích với
  /// đạo hàm 0 nên nó TỰ hạ cánh — ở stop 0.875 alpha đã 0.984, phần dư 1.6%
  /// trải trên 18px cuối là vô hình. Bớt được một mẹo vá.
  static const List<double> _fadeStops =
      [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0];
  static const List<double> _fadeAlphas =
      [0.0, 0.016, 0.104, 0.275, 0.5, 0.725, 0.896, 0.984, 1.0];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(zone.name);
    final media = MediaQuery.of(context);

    // 0.80 (tham chiếu Rijksmuseum): ảnh gần trọn màn nhưng ~20% dưới vẫn
    // hé danh sách — lời mời vuốt tự nhiên. KHÔNG lên 0.9: dải hé còn ~10%
    // dễ bị đọc nhầm thành footer, khách không biết bên dưới có danh sách.
    final expandedHeight = media.size.height * 0.80;
    final collapsedHeight = kToolbarHeight + media.padding.top;

    // Hero phủ trọn bề ngang ⇒ decode đúng bề ngang VẬT LÝ của máy này.
    // Trước đây là hằng số 1200: đúng trên 390@3x, upscale trên 430@3x, phí
    // RAM trên máy 2x. Cùng loại lỗi với decodeWidth ở Gate.
    final heroDecodeWidth = (media.size.width * media.devicePixelRatio).round();

    // NGUỒN DUY NHẤT của `open`, đọc từ scroll offset — KHÔNG phải từ
    // `LayoutBuilder.maxHeight` như bản trước. Hai cách đó cho CÙNG một con số
    // khi mọi thứ yên, nhưng chỉ scroll offset mới đọc được ở `leading`, nơi
    // không có `LayoutBuilder` nào của `flexibleSpace` để hỏi.
    //
    // 1.0 = mở hết, 0.0 = thu hết. `hasClients` false ở khung hình đầu tiên
    // (trước layout) ⇒ coi như đang mở — đúng trạng thái ban đầu thật.
    double open() {
      if (!scrollController.hasClients) return 1.0;
      final range = expandedHeight - collapsedHeight;
      if (range <= 0) return 0.0; // màn quá thấp để hero có chỗ mở — xem 2.3
      return (1 - scrollController.offset / range).clamp(0.0, 1.0);
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: t.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,

      // Back button — scrimBack tròn như bản cũ, sống trong leading để luôn
      // ghim ở đỉnh khi hero thu lại.
      //
      // leadingWidth TƯỜNG MINH: mặc định là 56, và NavigationToolbar căn giữa
      // nút 48 trong đó ⇒ mép trái nút rơi ở 4dp, lệch khỏi đường dọc 20 của
      // màn. Đặt gutter + tap rồi tự padding là cách DUY NHẤT ghim nó đúng.
      leadingWidth: AppSpace.gutter + AppSpace.tap,
      // scrimBack GIỮ NGUYÊN 40% (quyết định thẩm mỹ đã chốt — xem doc token).
      // Cái đổi là CHEVRON: nó chuyển họ theo `open`, thay vì cứng
      // `inkOnImage`. Đây là lời giải mà doc `scrimBack` đã đề xuất nhưng chưa
      // ai nối dây — chỗ nối dây là chính khối này.
      leading: AnimatedBuilder(
        animation: scrollController,
        builder: (context, _) {
          final o = open();
          // Ngưỡng, không phải nội suy liên tục: dưới nó chevron NGẢ sang
          // `ink`, cùng thời điểm scrim của nó nhận nền `surface` thật (ramp
          // hoà tan đã phủ hết ảnh). Nội suy liên tục từng bị bác vì có một
          // dải giữa chừng nơi glyph xám-trung-tính chìm vào cả hai nền — xem
          // `_heroTextBottom` doc, "vùng chết của hoà tan". Ngưỡng cứng tại
          // điểm ramp CHẠM ĐÁY né hẳn dải đó: hai bên ngưỡng đều có nền thuần.
          final onSurface = o < 0.15;
          return Padding(
            padding: const EdgeInsets.only(left: AppSpace.gutter),
            child: Center(
              child: Semantics(
                button: true,
                label: content.ui(UiKeys.exhibitBack),
                // excludeSemantics + onTap ĐI THÀNH CẶP: excludeSemantics gỡ cả
                // cây con khỏi semantics, kể cả action onTap mà InkWell tự
                // khai. Thiếu vế thứ hai là nút thôi bấm được bằng TalkBack —
                // hồi quy im lặng, không test nào bắt được.
                excludeSemantics: true,
                onTap: () => Navigator.of(context).pop(),
                child: Material(
                  color: t.scrimBack,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: AppSpace.tap,
                      height: AppSpace.tap,
                      child: _BackGlyph(onSurface: onSurface),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),

      flexibleSpace: LayoutBuilder(builder: (context, c) {
        // Cùng `open()` với leading — MỘT nguồn, không phải một bản sao tính
        // lại từ `c.maxHeight`. Hai cách cho cùng số khi mọi thứ yên; giữ một
        // nguồn để chúng không có cơ hội trôi khỏi nhau khi ai đó sửa một bên.
        //
        // Chữ hero fade theo bình phương của độ mở (tắt sớm) để không trôi vào
        // vùng thanh ghim khi đang thu.
        final o = open();
        final textOpacity = o * o;

        return Stack(
          fit: StackFit.expand,
          children: [
            HeroImage(
              filePath: content.imagePath(zone.heroImagePath),
              veil: t.heroVeil,
              cacheWidth: heroDecodeWidth,
            ),

            // ── HOÀ TAN — xem doc class ──
            // KHÔNG bọc Opacity: đây là ranh giới, không phải trang trí. Nó
            // giữ nguyên độ mạnh ở mọi trạng thái cuộn.
            //
            // KHI HERO THU HẾT (~103dp < _dissolveExtent 144): vùng tan phủ
            // trọn thanh ghim
            // ⇒ toolbar tự đọc thành `surface` với nút back nổi trên scrimBack.
            // Đó là TÍNH NĂNG, không phải tai nạn: khi đã cuộn, thanh ghim
            // thuộc về danh sách chứ không thuộc về tấm ảnh nữa.
            // `if` TƯỜNG MINH, thay cho mẹo nhân-alpha (1.8).
            //
            // Bản trước tắt ramp ở highContrast bằng cách nhân mọi stop với
            // alpha của token, và token đó trong suốt ở HC. Mẹo đó gọn nhưng
            // nó KHOÁ CHẶT hai thứ chẳng liên quan gì nhau: "ramp hạ cánh vào
            // màu nào" và "preset này có ramp không". Giờ màu lấy thẳng
            // `t.surface` — vốn ĐỤC ở cả ba preset — nên mẹo cũ sẽ để ramp BẬT
            // ở HC. Điều kiện phải hiện ra thành chữ.
            //
            // Nó cũng rẻ hơn: HC không dựng gradient nào cả, thay vì dựng bảy
            // stop trong suốt rồi vẽ chúng lên nhau.
            if (t.heroDissolveEnabled)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _dissolveExtent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: _fadeStops,
                      colors: [
                        for (final a in _fadeAlphas)
                          // `t.surface.withValues`, KHÔNG BAO GIỜ
                          // `Colors.transparent` — xem chi tiết 1 ở doc class:
                          // Colors.transparent là ĐEN alpha 0, và ramp về nó sẽ
                          // ám xám bẩn ở preset giấy. RGB phải đứng yên, chỉ
                          // alpha chạy.
                          //
                          // t.surface chứ không phải một token riêng: ramp PHẢI
                          // hạ cánh đúng màu nền của danh sách bên dưới. Trước
                          // 1.8 đó là `Color heroDissolve` chép lại `surface` ở
                          // mỗi preset — một bất biến không ai canh, và nó đã
                          // trôi một lần (comment "(taupe)" trên một giá trị
                          // bằng surface). Giờ không còn gì để lệch.
                          t.surface.withValues(alpha: a),
                      ],
                    ),
                  ),
                ),
              ),

            // Title + meta, bottom-left. The meta is intentionally STATIC (no
            // live count) — a number that changed as you walked would itself
            // flicker; the list below already tells you what's near.
            Positioned(
              left: AppSpace.gutter,
              // Chừa lề + cột của nút intro + khoảng thở. Ba thành phần, mỗi
              // cái có tên: tên khu dài không được tràn vào cột của nút.
              right: AppSpace.gutter + AppSpace.actionCircle + AppSpace.x4,
              bottom: _heroTextBottom,
              child: Opacity(
                opacity: textOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kicker accent — nối ngôn ngữ với vạch accent ở Gate.
                    //
                    // accentOnImage, KHÔNG phải accent: dòng này nằm trên ảnh
                    // dưới veil ~70% — nền TỐI ở mọi theme. accent của preset
                    // giấy là #7E5620 (nâu sẫm) và sẽ biến mất ở đây. Cùng lý
                    // lẽ với inkOnImage; xem doc accent/accentOnImage.
                    //
                    // Chuỗi để chữ thường: vai trò kicker lo việc viết hoa
                    // (luật ở app_text.dart). Kết quả hiển thị không đổi.
                    Text(content.ui(UiKeys.exhibitListHeroKicker).toUpperCase(),
                        style: AppText.kicker.copyWith(color: t.accentOnImage)),
                    const SizedBox(height: AppSpace.x2),
                    Text(name,
                        style: AppText.heroTitle.copyWith(color: t.inkOnImage)),
                    const SizedBox(height: AppSpace.x2),
                    Text(
                      // Trước đây mô tả hành vi "hiện vật hiện ra khi tới gần"
                      // (lọc theo sóng minor). Đã bỏ lọc đó — giờ hiện trọn
                      // manifest — nên câu này đổi thành lời mời chọn hiện vật.
                      content.ui(UiKeys.exhibitListHeroSubtitle),
                      style: AppText.meta.copyWith(color: t.mutedOnImage),
                    ),
                    const SizedBox(height: AppSpace.x3),
                    // ── SÀN CỦA KHỐI CHỮ ──
                    //
                    // Chữ hero KHÔNG lơ lửng vì đặt sai chỗ — [_heroTextBottom]
                    // = 120 là nghiệm DUY NHẤT (xem doc ở đó). Nó lơ lửng vì
                    // neo vào mép trên vùng hoà tan, mà mép đó VÔ HÌNH. Vạch
                    // này làm đường mực nước hiện ra, và khối chữ có sàn để
                    // đứng.
                    //
                    // VÌ SAO LÀ VẠCH CHỨ KHÔNG PHẢI THANH LÓT: một dải nền sau
                    // lưng chữ chính là _SectionBand sống lại — một CẠNH, và
                    // cạnh thì cắt. Vạch 2px là một DẤU: nó không cắt gì cả,
                    // nó chỉ đánh dấu. Gate đã chứng minh sự phân biệt đó.
                    //
                    // 88×2 accent — CÙNG kích thước, cùng màu, cùng vai trò với
                    // vạch ở Gate. Ngôn ngữ nối: Gate (vạch trên tiêu đề) →
                    // màn 3 (kicker accent + vạch dưới khối) → trạng thái rỗng
                    // (vạch 48×2) → badge đang phát. Một màu nhấn, bốn lần
                    // xuất hiện, không lần nào là trang trí.
                    //
                    // Trang trí thuần tuý ⇒ không Semantics, và không áp ngưỡng
                    // WCAG (ngưỡng chỉ dành cho CHỮ). Ở α≈0.035 nó nằm trên
                    // ảnh dưới veil 70% ⇒ ~3.4:1 với ảnh sáng nhất — thừa cho
                    // một dấu 2px.
                    // accentOnImage: vạch này nằm TRÊN ẢNH, không trên surface.
                    // Vạch 88×2 ở Gate là anh em sinh đôi của nó nhưng nằm trên
                    // welcomeBackdrop ⇒ dùng `accent`. Cùng vai trò, khác nền,
                    // khác họ token — đó là toàn bộ điểm của việc tách.
                    Container(width: 88, height: 2, color: t.accentOnImage),
                  ],
                ),
              ),
            ),
            Positioned(
              right: AppSpace.gutter, // cùng đường dọc phải với mép thẻ
              bottom: _heroTextBottom, // thẳng hàng đáy với khối chữ
              child: Opacity(
                opacity: textOpacity,
                child: _ZoneIntroButton(
                  major: zone.major,
                  // Nút vô hình không được nhận chạm (fade khi hero thu lại).
                  tappable: textOpacity >= 0.3,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Tách riêng chỉ để `SizedBox` bọc nó giữ được `const` (Icon cần token màu,
/// nhưng token đọc được từ context ở đây).
class _BackGlyph extends StatelessWidget {
  /// true khi hero đã thu hết và scrim đứng trên `surface` thật (không còn
  /// ảnh dưới nó). Xem doc `scrimBack` ở museum_tokens.dart cho toàn bộ lý do
  /// field này tồn tại — nó là lời giải thay cho việc nâng alpha của scrim.
  final bool onSurface;
  const _BackGlyph({required this.onSurface});

  @override
  Widget build(BuildContext context) =>
      Icon(
        Icons.chevron_left,
        // ink (chevron SẪM) khi đứng trên surface thật — cùng scrim 40%, nền
        // giờ là surface đục thay vì ảnh, nên chevron phải đổi cực để vẫn nổi.
        // inkOnImage (TRẮNG, đóng băng theo theme) trên mọi trạng thái khác —
        // đúng luật họ on-image, vì lúc đó nền dưới scrim vẫn là ảnh thật.
        color: (onSurface ? context.tokens.ink : context.tokens.inkOnImage),
        size: 26,
      );
}

/// Trạng thái của nút intro, tính từ AudioQueueState. Enum riêng (thay vì hai
/// bool rời) để Selector so sánh MỘT giá trị và switch bên dưới exhaustive.
enum _IntroButtonState {
  /// Intro CỦA KHU NÀY đang phát → hai gạch, chạm = pause.
  playingThis,

  /// Intro của khu này là clip hiện tại nhưng đang dừng → tam giác,
  /// chạm = PHÁT TIẾP giữa chừng (userPlay), KHÔNG quay về đầu.
  pausedThis,

  /// Mọi trường hợp khác (chưa load / đang phát clip khác) → tam giác,
  /// chạm = tapZoneIntro: load intro từ đầu và phát.
  idle,
}

/// Nút intro trên hero — PHẢN CHIẾU trạng thái engine thay vì tĩnh: khách
/// nhìn nút là biết tiếng giới thiệu đang chạy hay không, và chạm luôn làm
/// điều họ mong đợi ở trạng thái đó (toggle chuẩn của mọi player).
///
/// Selector trả về enum nên mỗi notify của engine chỉ so một giá trị; nút chỉ
/// rebuild khi trạng thái NÚT đổi — cùng kỷ luật với _StopRow. So khớp bằng
/// `isIntro && zoneMajor == major`: đổi zone rồi quay lại màn cũ, intro của
/// zone khác đang phát thì nút này vẫn là tam giác (đúng — nó chỉ nói về
/// intro CỦA KHU TRÊN MÀN HÌNH NÀY).
///
/// pause() không kèm showAudioFeedback: kết quả nghe thấy tức thì, snackbar
/// chỉ dành cho các intent có thể bị chính sách chặn trong im lặng.
class _ZoneIntroButton extends StatelessWidget {
  /// Zone đóng băng của màn hình — cùng kỷ luật major với tapExhibit.
  final int major;

  final bool tappable;

  const _ZoneIntroButton({required this.major, required this.tappable});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    return Selector<AudioProvider, _IntroButtonState>(
      selector: (_, audio) {
        final c = audio.current;
        final isThisIntro = c != null && c.isIntro && c.zoneMajor == major;
        if (!isThisIntro) return _IntroButtonState.idle;
        if (audio.isPlaying) return _IntroButtonState.playingThis;
        if (audio.isPaused) return _IntroButtonState.pausedThis;
        return _IntroButtonState.idle;
      },
      builder: (context, state, _) {
        final playing = state == _IntroButtonState.playingThis;

        // Nhấc ra khỏi cây widget: nó phải chạy ở HAI chỗ (InkWell cho ngón
        // tay, Semantics cho screen reader) và hai chỗ đó không được phép trôi
        // khỏi nhau. Viết inline hai lần là mời một lần sửa chỉ sửa một vế.
        final VoidCallback? onTap = !tappable
            ? null
            : () {
                final audio = context.read<AudioProvider>();
                switch (state) {
                  case _IntroButtonState.playingThis:
                    audio.pause();
                  case _IntroButtonState.pausedThis:
                    showAudioFeedback(context, audio.play());
                  case _IntroButtonState.idle:
                    showAudioFeedback(context, audio.tapZoneIntro(major: major));
                }
              };

        return Semantics(
          button: true,
          enabled: tappable,
          label: playing
              ? content.ui(UiKeys.exhibitListIntroPause)
              : content.ui(UiKeys.exhibitListIntroPlay),
          excludeSemantics: true, // + onTap: xem doc ở nút back
          onTap: onTap,
          child: Material(
            color: t.ctaOnImageFill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: AppSpace.actionCircle,
                height: AppSpace.actionCircle,
                child: Icon(playing ? Icons.pause : Icons.play_arrow,
                    color: t.ctaOnImageInk, size: 28),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shown when the frozen zone currently has no exhibit beacon in range. Not an
/// error — a direction: walk up to a display case and it appears in the list.
///
/// KHÔNG CÒN ICON. Trước đây là `Icons.travel_explore`: quả địa cầu + kinh vĩ
/// tuyến + kính lúp + dấu cộng — bốn ý tưởng trong một glyph, đặt giữa một màn
/// chỉ có serif và một vạch màu. Nó không sai về nghĩa, nó sai về TỪ VỰNG: đó
/// là tiếng nói của Material, không phải của app này.
///
/// Thay bằng vạch accent — chính thứ đã có ở Gate (88×2) và ở kicker hero.
///
/// CĂN TRÊN, KHÔNG CĂN GIỮA — và đó là cả sự khác biệt trên màn này.
///
/// Hero cao 80% là CHỦ ĐÍCH (ảnh đại diện cho cả một khu là ảnh quan trọng;
/// tham chiếu Rijksmuseum). Nên `SliverFillRemaining` chỉ còn ~20% màn ≈ 168dp
/// trên máy 844. `Center` đặt khối này vào GIỮA dải đó — tức bắt đầu ~45dp
/// DƯỚI mép fold, lơ lửng giữa một vùng trống, dưới một tấm ảnh chiếm 80%.
/// Nó đọc ra như một chú thích ảnh, không đọc ra như thông điệp của màn hình.
///
/// Mà nó LÀ thông điệp của màn hình: khi không có hiện vật nào ở gần, đây là
/// thứ duy nhất trên trang nói cho khách biết phải làm gì.
///
/// Căn trên dán nó ngay dưới mép hoà tan — đúng chỗ mắt vừa dừng khi hero cuộn
/// hết. Cùng một hero, cùng một dải 20%; chỉ khác chỗ đặt.
///
/// (Bản đánh giá gốc kết luận sai chỗ này: nó đòi THU hero lại. Hero không sai
/// — chỗ đặt sai.)
/// Trạng thái rỗng là chỗ DỄ NHẤT để một app tối giản phản bội chính nó, vì
/// nó trống và ai cũng muốn lấp. Luật của app: hình học tối giản, không hoa
/// văn, không viền — và nếu phải có một dấu thì dấu đó là accent.
///
/// Trạng thái này giờ CŨNG được hoà tan phục vụ, và đó là điều dải màu cũ
/// không làm được: _SectionBand chỉ tồn tại ở nhánh có hiện vật, nên màn rỗng
/// gặp ảnh bằng một cạnh cứng trần. Gradient sống trong hero ⇒ cả hai nhánh
/// nối liền như nhau, miễn phí.
///
/// Nếu sau này muốn một hình thật: dùng lại vòng radar của _RadarStandby (màn
/// 2) — cùng ý nghĩa "chưa nghe thấy gì", và là hình học của chính app. Đừng
/// đi tìm icon Material khác.
class _ZoneEmpty extends StatelessWidget {
  const _ZoneEmpty();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    return Padding(
      // Lề NGANG không phải gutter — nó là lề đo CHIỀU DÀI DÒNG (measure),
      // không phải lề lưới. x10 (40) giữ dòng ở ~45–55 ký tự, ngưỡng đọc thoải
      // mái. Đây là ngoại lệ hợp lệ duy nhất với "một đường dọc cho cả màn":
      // khối này căn giữa, nên nó không ngồi trên đường nào.
      //
      // Lề TRÊN x6: căn TRÊN, không căn giữa — xem doc class.
      padding: const EdgeInsets.fromLTRB(
          AppSpace.x10, AppSpace.x6, AppSpace.x10, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vạch accent — cùng từ vựng với Gate và kicker hero. 48 = 4×12,
            // ngắn hơn vạch 88 ở Gate: đây là trạng thái phụ, không phải màn
            // chào.
            Container(width: AppSpace.x12, height: 2, color: t.accent),
            const SizedBox(height: AppSpace.x4),
            // CHỮ THƯỜNG, và vì thế KHÔNG CÒN LÀ kicker — hai điều đó đi
            // liền nhau, không tách được.
            //
            // Câu hỏi ở đợt trước: đây là "nhãn trạng thái" hay "tiêu đề"?
            // Đã quyết: TIÊU ĐỀ. Nó là một CÂU sáu chữ có dấu chồng (Ệ, Ậ, Ầ),
            // và ở tracking .22em nó đọc lởm chởm — đúng lý do đã khai tử
            // kicker ở Gate. Một nhãn là một hai từ; sáu từ là một câu.
            //
            // Kéo theo: kicker mang sẵn chữ hoa + .22em trong định nghĩa vai
            // trò, nên "kicker viết thường" không tồn tại. Style phải đổi.
            //
            // cardTitle (serif 20) chứ KHÔNG PHẢI sheetTitle (26): trên màn
            // này đã có heroTitle 28 (tên khu). 26 cạnh 28 là hai tiêu đề
            // tranh nhau mà không phân được vai; 20 nói rõ đây là thông điệp
            // NẰM TRONG khu, không phải tên khu.
            //
            // Ngữ pháp thu được đúng bằng ngữ pháp của Gate, thu nhỏ:
            //     Gate:   vạch 88×2 → welcomeTitle (serif) → lede (sans)
            //     ở đây:  vạch 48×2 → cardTitle    (serif) → guidance (sans)
            // Đó là lý do tin được rằng đây là tiếng nói của app, không phải
            // một trạng thái rỗng đi mượn từ vựng ở đâu về.
            Text(content.ui(UiKeys.exhibitListEmptyTitle),
                textAlign: TextAlign.center,
                style: AppText.cardTitle.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.x2),
            Text(
              // inkMuted, KHÔNG phải inkFaint. Hai lý do, và lý do thứ hai
              // đúng cả trước khi có preset giấy:
              //   1. inkFaint #7D7469 trên surface #F6F3EE = 4.15:1 — dưới
              //      chuẩn AA (4.5) cho chữ 12px. inkMuted: 6.61:1 ✓
              //   2. doc của inkFaint viết thẳng: "KHÔNG dùng cho nội dung
              //      khách cần đọc kỹ". Đoạn này LÀ chỉ dẫn hành động duy nhất
              //      của trạng thái rỗng — không có gì trên màn này khách cần
              //      đọc kỹ hơn nó.
              // Token đã bị dùng ngược hợp đồng của chính nó; con số chỉ là
              // chỗ điều đó lộ ra.
              content.ui(UiKeys.exhibitListEmptyBody),
              textAlign: TextAlign.center,
              style: AppText.guidance.copyWith(color: t.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// One .stop row — một "thẻ" đứng trên kệ [surfaceRaised]: 56x56 thumb dẫn đầu
/// (image-first) + serif name + grey meta + badge số bên phải. The thumbnail is
/// an image, but the text sits BESIDE it: this row is surface.
///
/// LỚP MÀU LÓT: hàng có nền riêng thay vì trôi trên nền trống. Nó gánh luôn
/// việc phân tách hàng sau khi hairline bị bỏ — nền + khoảng cách x3 làm việc
/// mà gạch mờ từng làm, nhưng không cắt ngang thị giác.
///
/// ĐĨA LÕM Ở MÉP PHẢI: badge tô [MuseumTokens.badgeWell] — trầm hơn kệ
/// [surfaceRaised] ΔL* ≈ 5 ở mọi preset — một lỗ khoét NÔNG, cố ý.
///
/// CẢ BADGE IM LẶNG cho tới khi nó có gì để nói. Doc cũ ở đây viết "chìm là
/// NỀN, không phải chữ" và tô số bằng [ink] w700. Câu đó giả định con số là
/// thông tin. Nó không phải: bảo tàng không đánh số hiện vật, và giá trị đang
/// hiển thị là minor ID của beacon. Nên số dùng [inkFaint], và hố thì NÔNG —
/// độ sâu của hố là âm lượng của badge, xem doc [MuseumTokens.badgeWell].
///
/// Bóng [shadowInk] thay cho `ink @ 10%`: ở dark theme ink là TRẮNG,
/// `ink @10%` sẽ thành quầng sáng chứ không phải bóng.
///
/// TRẠNG THÁI "ĐANG PHÁT": badge đổi nền [accent] đặc + glyph sóng âm
/// [accentInk] (KHÔNG trắng — trắng trên đồng chỉ ~2.5:1, rớt chuẩn); meta
/// đổi thành "Đang phát thuyết minh". Nghỉ thì chìm, phát thì bừng: tương
/// phản cường độ chính là tín hiệu. Đọc qua Selector — mỗi notify của engine
/// chỉ so một bool, chỉ hàng đổi trạng thái mới rebuild. So khớp bằng CẢ
/// zoneMajor lẫn exhibitMinor: minor chỉ unique trong một zone.
///
/// ═════════════════════════════════════════════════════════════════════════
/// LƯỚI: BA ĐƯỜNG DỌC BÊN TRONG HÀNG — có chủ đích, không phải lỗi
/// ═════════════════════════════════════════════════════════════════════════
/// Mép thẻ ở gutter (20) ⇒ thẳng hàng với tên khu trên hero. Nhưng thumbnail
/// ở 32 và tên hiện vật ở 104 — hai đường KHÁC. Đó là chấp nhận được: thẻ là
/// một VẬT THỂ có lề trong của riêng nó; cái phải thẳng hàng với màn là mép
/// thẻ, không phải ruột thẻ.
///
/// Phương án editorial mạnh hơn nếu muốn thử sau: cho thumbnail TRÀN mép trái
/// thẻ (padding fromLTRB(0,0,x3,0), ảnh cao bằng thẻ) ⇒ mép ảnh về đúng 20,
/// hàng đọc thành "phiến ảnh + nhãn chú thích" — đúng ngôn ngữ nhãn bảo tàng.
/// CÁI GIÁ: chiều cao hàng thôi cố định (tên 2 dòng ở textScale 1.6×) nên ảnh
/// phải dùng IntrinsicHeight hoặc Stretch — tốn layout pass và dễ vỡ. Vì vậy
/// bản này giữ padding đều; đổi có ý thức, đừng đổi vì tiện.
class _StopRow extends StatelessWidget {
  final ExhibitInfo exhibit;
  final ContentProvider content;

  /// Zone đóng băng của màn hình — để so với AudioTrackRef.zoneMajor.
  final int major;

  final VoidCallback onTap;

  const _StopRow({
    required this.exhibit,
    required this.content,
    required this.major,
    required this.onTap,
  });

  /// Meta line: spec values joined " · "; falls back to the one-line summary.
  String _metaLine() {
    if (exhibit.specs.isNotEmpty) {
      return exhibit.specs.map((s) => content.text(s.value)).join(' · ');
    }
    return content.text(exhibit.summary);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(exhibit.name);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Selector<AudioProvider, bool>(
      selector: (_, audio) {
        final c = audio.current;
        return audio.isPlaying &&
            c != null &&
            c.zoneMajor == major &&
            c.exhibitMinor == exhibit.minor;
      },
      builder: (context, nowPlaying, _) {
        return Semantics(
          button: true,
          // KHÔNG còn "Hiện vật số N". Con số là `exhibit.minor` — minor ID
          // của beacon BLE — và bảo tàng KHÔNG đánh số hiện vật. Đọc nó lên
          // là chỉ cho khách dùng TalkBack đi tìm một cái nhãn không tồn tại;
          // một định danh kỹ thuật đọc thành "số hiệu vật" thì tệ hơn im lặng.
          //
          // Đây là vế thứ hai của quyết định "con số là trang trí" — xem doc
          // [MuseumTokens.badgeWell]. Làm nó chìm về màu mà để nguyên câu này
          // là giấu vấn đề khỏi người nhìn thấy được, và giữ nguyên nó cho
          // người không nhìn thấy.
          label: '$name${nowPlaying ? content.ui(UiKeys.exhibitListNowPlayingSuffix) : ''}',
          // excludeSemantics + onTap ĐI THÀNH CẶP — xem doc ở nút back. Ở hàng
          // này exclude còn làm một việc thứ hai: `label` phía trên đã gói tên
          // + số + trạng thái thành MỘT câu đọc được; không exclude thì screen
          // reader đọc thêm tên, meta và số badge rời rạc lần nữa.
          excludeSemantics: true,
          onTap: onTap,
          child: Padding(
            // Khe giữa các hàng = x3 (12). Cùng mức với "trong một khối" ở
            // Gate — cố ý: các hàng là MỘT khối danh sách, không phải nhiều
            // khối rời.
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
                      // 56x56 thumbnail — mỏ neo trái của hàng.
                      ClipRRect(
                        borderRadius: t.sharpAll,
                        child: SizedBox(
                          width: AppSpace.thumb,
                          height: AppSpace.thumb,
                          child: HeroImage(
                            filePath: content.imagePath(exhibit.thumbnailPath),
                            // Trước đây hằng số 168 (= 56×3): đúng trên máy
                            // 3x, over-decode 1.5× trên 2x, under-decode trên
                            // 4x. Nhân dpr thật — cùng kỷ luật với hero.
                            cacheWidth: (AppSpace.thumb * dpr).round(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.x4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                // maxLines 2: at 1.6x text scale a single line
                                // ellipsises the exhibit's name away. Losing
                                // the name is worse than spending 16px.
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.stopName.copyWith(color: t.ink)),
                            const SizedBox(height: AppSpace.x1),
                            Text(
                                nowPlaying
                                    ? content.ui(UiKeys.exhibitListNowPlayingMeta)
                                    : _metaLine(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                // accent (họ surface), KHÔNG phải accentOnImage:
                                // dòng này nằm trên `surfaceRaised`, không trên
                                // ảnh. Ở light nó giờ là #7E5620 = 5.17:1; bản
                                // một-field cho 2.01:1 — tín hiệu quan trọng
                                // nhất của màn 3 gần như vô hình trên giấy.
                                style: AppText.stopMeta.copyWith(
                                    color: nowPlaying ? t.accent : t.inkMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.x3),
                      // ── Badge số — nghỉ thì CHÌM, phát thì NỔI ──
                      //
                      // BÓNG CHỈ TỒN TẠI KHI ĐANG PHÁT. Bản trước luôn có
                      // bóng đổ ra ngoài, trong khi comment tự nhận là "đĩa
                      // lõm". Mâu thuẫn không thương lượng được: bóng hắt ra
                      // ngoài LÀ định nghĩa của vật nằm TRÊN mặt phẳng. Mắt
                      // đọc bóng trước khi đọc tông màu, nên cái bóng đã thắng
                      // và badge luôn đọc là nút lồi — ở cả ba preset.
                      //
                      // Giờ trạng thái là phát biểu thật: nghỉ = phẳng, chìm
                      // bằng TÔNG (surface tối hơn kệ surfaceRaised). Phát =
                      // accent + nhấc lên khỏi kệ, có bóng. Cùng một tương
                      // phản cường độ mà cả hàng đang dùng làm tín hiệu.
                      //
                      // NỢ Ở LIGHT ĐÃ TRẢ: comment cũ ở đây tự chẩn đoán đúng
                      // và tự kê đúng đơn thuốc — "cần token riêng
                      // (`badgeWell`) trầm hơn surfaceRaised ở CẢ BA preset" —
                      // rồi nằm đó qua nhiều lần sửa. Giờ token đó tồn tại.
                      //
                      // Bản cũ tô `surface`, và `surface` chỉ TÌNH CỜ tối hơn
                      // kệ ở preset tối:
                      //   dark  #151312 < #201D1A → ΔL* −4.7 → hố (nhưng mờ)
                      //   light #F6F3EE > #EBE5DB → ΔL* +4.7 → ĐĨA NỔI ✗
                      // badgeWell tách hẳn khỏi `surface` ⇒ ΔL* −8.9 (dark) và
                      // −11.4 (light): hố ở CẢ BA preset, và đủ sâu để mắt bắt
                      // được trên một đĩa 36dp chứ không chỉ trên mảng lớn.
                      //
                      // Lợi ích phụ, quan trọng hơn con số: `surface` và badge
                      // không còn định nghĩa lẫn nhau. Đổi nền app không còn
                      // phá badge.
                      Container(
                        width: AppSpace.badge,
                        height: AppSpace.badge,
                        decoration: BoxDecoration(
                          color: nowPlaying ? t.accent : t.badgeWell,
                          shape: BoxShape.circle,
                          boxShadow: nowPlaying
                              ? [
                                  BoxShadow(
                                    color: t.shadowInk,
                                    blurRadius: AppShadow.liftBlur,
                                    offset: AppShadow.liftOffset,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: nowPlaying
                            // size 18 GIỮ NGUYÊN, và nó KHÔNG phải magic
                            // number: 18/24/36/48 là thang icon chuẩn của
                            // Material, và 18 = đúng một nửa badge. Lưới 4dp
                            // quản khoảng cách và bố cục, không quản cỡ glyph
                            // — ép icon về 16 hay 20 là áp nhầm luật lên một
                            // đại lượng typographic.
                            //
                            // ĐANG PHÁT VẪN BỪNG, và giờ nó là thứ DUY NHẤT
                            // bừng: accent 5.18:1 + glyph accentInk 5.86:1.
                            // Cả badge im lặng cho tới khi có gì để nói.
                            ? Icon(Icons.graphic_eq,
                                size: 18, color: t.accentInk)
                            // Chữ số trang trí. HAI thứ đã bỏ, và `w700` hét
                            // to hơn cả màu:
                            //   ink  → inkFaint (bậc thấp nhất của thang ink)
                            //   w700 → w300 mặc định của `meta` (bỏ override)
                            //
                            // inkFaint chứ KHÔNG phải một token riêng: doc của
                            // nó là "chữ mờ nhất còn đọc được — KHÔNG dùng cho
                            // nội dung khách cần đọc kỹ", tức đúng định nghĩa
                            // một chỉ số trang trí. Từng có `badgeInk` ở đây,
                            // sinh ra để cho số chìm SÂU HƠN thang ink cho
                            // phép; khi hố về lại độ nông đúng, việc đó biến
                            // mất và token theo nó. (highContrast tự lo:
                            // inkFaint của preset đó là #D0D0D0 sáng — số hiện
                            // bình thường, không cần nhánh nào.)
                            //
                            // Thứ tự âm lượng trong hàng, đo bằng ΔL* so với
                            // nền của chính nó:  tên 88.8 > meta 71.2 > số 59.3.
                            // Số là thứ nhỏ tiếng nhất — đúng vai của nó.
                            : Text(
                                '${exhibit.minor}',
                                style: AppText.meta.copyWith(color: t.inkFaint),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}