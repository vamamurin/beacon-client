// Destination: lib/presentation/exhibits/exhibit_list_screen.dart
//
// Screen 3 — the exhibit list of ONE zone.
//
// PRESENCE-DRIVEN LIST (Phase-4 change, confirmed with product): the list shows
// ONLY exhibits whose minor beacon is currently being heard over the air — not
// the full manifest. Consequence accepted by product: a dead-battery beacon
// removes its exhibit from the list (the manifest is no longer the visibility
// source, only the CONTENT source — name/thumb/audio still come from it).
//
// ZONE STILL FROZEN: `major` comes from route arguments; only the SUBSET shown
// is live. If the arbiter switches zones underneath, this screen keeps its
// frozen `major` (Phase-1 rule); only screen 2 follows the arbiter.
//
// NO RANKING / NO FLICKER: visible rows keep MANIFEST ORDER. The present set is
// already debounced and change-gated by ExhibitPresenceTracker.
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
//
// STREAMBUILDER BỌC CẢ CUSTOMSCROLLVIEW: một StreamBuilder chỉ trả về MỘT
// widget nên không thể sinh riêng sliver danh sách. Chấp nhận rebuild cả
// scroll view theo presence vì (a) stream đã debounce + change-gated, tần suất
// thấp; (b) rebuild giữ nguyên Element ⇒ vị trí cuộn và state hero không mất.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/audio_feedback.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/exhibit_presence_provider.dart';
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
  late final ExhibitPresenceProvider _presence;
  late final Stream<Set<int>> _presenceStream;

  @override
  void initState() {
    super.initState();
    // Resolve once. Calling watchMajor() inside build() would hand StreamBuilder
    // a fresh Stream object on every rebuild; it survives today only because
    // _ControllerStream overrides ==, which is a dart:async implementation
    // detail we shouldn't depend on.
    _presence = context.read<ExhibitPresenceProvider>();
    _presenceStream = _presence.watchMajor(widget.major);
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
          child: Text('Không tìm thấy khu trưng bày',
              style: AppText.meta.copyWith(color: t.inkMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.surface,
      body: StreamBuilder<Set<int>>(
        initialData: _presence.currentPresent(widget.major),
        stream: _presenceStream,
        builder: (context, snap) {
          final present = snap.data ?? const <int>{};

          // Filter to heard minors, but keep MANIFEST ORDER (no ranking).
          final visible = <ExhibitInfo>[
            for (final e in zone.exhibits)
              if (present.contains(e.minor)) e,
          ];

          return CustomScrollView(
            slivers: [
              _ZoneHeroBar(zone: zone, content: content),
              if (visible.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoneNearby(),
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
          );
        },
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
/// 4. TỰ TẮT Ở highContrast, KHÔNG CẦN NHÁNH ĐIỀU KIỆN. Alpha của ramp được
///    NHÂN với alpha của chính token [MuseumTokens.heroDissolve]. HC đặt token
///    trong suốt ⇒ mọi stop về 0 ⇒ gradient biến mất ⇒ ảnh gặp danh sách bằng
///    cạnh cứng — đúng thứ preset đó cần (hoà tan là phản đề của tương phản
///    cao). Cùng thủ pháp mà welcomeAmbient đang dùng.
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

  const _ZoneHeroBar({required this.zone, required this.content});

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
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpace.gutter),
        child: Center(
          child: Semantics(
            button: true,
            label: 'Quay lại',
            child: Material(
              color: t.scrimBack,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: AppSpace.tap,
                  height: AppSpace.tap,
                  child: _BackGlyph(),
                ),
              ),
            ),
          ),
        ),
      ),

      flexibleSpace: LayoutBuilder(builder: (context, c) {
        // 1.0 = mở hết, 0.0 = thu hết. Chữ hero fade theo bình phương của độ
        // mở (tắt sớm) để không trôi vào vùng thanh ghim khi đang thu.
        final open = ((c.maxHeight - collapsedHeight) /
                (expandedHeight - collapsedHeight))
            .clamp(0.0, 1.0);
        final textOpacity = open * open;

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
            // KHI HERO THU HẾT (~103dp < 112dp): vùng tan phủ trọn thanh ghim
            // ⇒ toolbar tự đọc thành `surface` với nút back nổi trên scrimBack.
            // Đó là TÍNH NĂNG, không phải tai nạn: khi đã cuộn, thanh ghim
            // thuộc về danh sách chứ không thuộc về tấm ảnh nữa.
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
                        // NHÂN với alpha của token ⇒ HC (token trong suốt) tự
                        // tắt toàn bộ ramp, không cần `if`. Và luôn là
                        // heroDissolve.withValues, KHÔNG BAO GIỜ
                        // Colors.transparent — xem chi tiết 1 ở doc class.
                        t.heroDissolve.withValues(alpha: a * t.heroDissolve.a),
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
                    Text('KHU TRƯNG BÀY',
                        style: AppText.kicker.copyWith(color: t.accent)),
                    const SizedBox(height: AppSpace.x2),
                    Text(name,
                        style: AppText.heroTitle.copyWith(color: t.inkOnImage)),
                    const SizedBox(height: AppSpace.x2),
                    Text(
                      // Câu này giờ ngồi ngay TRÊN vùng tan, và nó mô tả đúng
                      // cái mà gradient đang làm: thứ ở gần thì hiện ra. Hình
                      // thức và nội dung nói cùng một điều — hiếm khi rẻ thế.
                      'Hiện vật tự xuất hiện khi bạn tới gần',
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
                    Container(width: 88, height: 2, color: t.accent),
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
  const _BackGlyph();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_left, color: context.tokens.inkOnImage, size: 26);
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
        return Semantics(
          button: true,
          label: playing
              ? 'Tạm dừng giới thiệu khu trưng bày'
              : 'Nghe giới thiệu khu trưng bày',
          child: Material(
            color: t.ctaOnImageFill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: !tappable
                  ? null
                  : () {
                      final audio = context.read<AudioProvider>();
                      switch (state) {
                        case _IntroButtonState.playingThis:
                          audio.pause();
                        case _IntroButtonState.pausedThis:
                          showAudioFeedback(context, audio.play());
                        case _IntroButtonState.idle:
                          showAudioFeedback(
                              context, audio.tapZoneIntro(major: major));
                      }
                    },
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
class _NoneNearby extends StatelessWidget {
  const _NoneNearby();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      // Empty state căn giữa, nên lề của nó KHÔNG phải gutter — nó là lề đo
      // chiều dài dòng (measure), không phải lề lưới. x10 (40) giữ dòng ở
      // ~45–55 ký tự, ngưỡng đọc thoải mái.
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x10),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vạch accent — cùng từ vựng với Gate và kicker hero. 48 = 4×12,
            // ngắn hơn vạch 88 ở Gate: đây là trạng thái phụ, không phải màn
            // chào.
            Container(width: AppSpace.x12, height: 2, color: t.accent),
            const SizedBox(height: AppSpace.x4),
            Text('CHƯA CÓ HIỆN VẬT NÀO Ở GẦN',
                textAlign: TextAlign.center,
                style: AppText.kicker.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.x2),
            Text(
              'Hãy tiến lại gần một tủ trưng bày. Hiện vật sẽ tự xuất hiện '
              'trong danh sách khi bạn tới đủ gần.',
              textAlign: TextAlign.center,
              style: AppText.guidance.copyWith(color: t.inkFaint),
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
/// SỐ Ở MÉP PHẢI, CỘT THẲNG, ĐỌC LÀ ĐĨA LÕM: badge tô [surface] — chính màu
/// nền gốc — nên trên kệ [surfaceRaised] nó thành một lỗ khoét chìm xuống,
/// đúng yêu cầu "nhạt, chìm". Số [ink] w700 vẫn sắc nét: chìm là NỀN, không
/// phải chữ. Hai màu này định nghĩa lẫn nhau (xem doc surfaceRaised) — đổi
/// một cái phải soát cái kia. Bóng [frameShadow] thay cho `ink @ 10%`: ở dark
/// theme ink là TRẮNG, `ink @10%` sẽ thành quầng sáng chứ không phải bóng.
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
          label: 'Hiện vật số ${exhibit.minor}, $name'
              '${nowPlaying ? ', đang phát' : ''}',
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
                                    ? 'Đang phát thuyết minh'
                                    : _metaLine(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      // ⚠ CÒN NỢ Ở LIGHT THEME — cần soát bằng mắt trên máy:
                      // dark  surface #151312 < surfaceRaised #201D1A → tối
                      //       hơn kệ → là hố ✓
                      // light surface #F6F3EE > surfaceRaised #EBE5DB → SÁNG
                      //       hơn kệ → đọc là đĩa nổi, KHÔNG phải hố ✗
                      // surfaceRaised ở light cố ý trầm hơn giấy (đúng theo
                      // doc token), nên ẩn dụ "lõm" chỉ sống ở dark + HC. Bỏ
                      // bóng đã gỡ phần lớn hiểu nhầm, nhưng nếu vẫn thấy nổi
                      // ở light thì cần token riêng (`badgeWell`) trầm hơn
                      // surfaceRaised ở CẢ BA preset — đừng vá bằng cách đổi
                      // surface, hai màu đó định nghĩa lẫn nhau.
                      Container(
                        width: AppSpace.badge,
                        height: AppSpace.badge,
                        decoration: BoxDecoration(
                          color: nowPlaying ? t.accent : t.surface,
                          shape: BoxShape.circle,
                          boxShadow: nowPlaying
                              ? [
                                  BoxShadow(
                                    color: t.frameShadow,
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
                            ? Icon(Icons.graphic_eq,
                                size: 18, color: t.accentInk)
                            : Text(
                                '${exhibit.minor}',
                                style: AppText.meta.copyWith(
                                  color: t.ink,
                                  fontWeight: FontWeight.w700,
                                ),
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