// Destination: lib/presentation/exhibits/exhibit_detail_screen.dart
//
// Screen 4 — exhibit detail + audio player.
//
// CONTROLS SEMANTICS (coherent with the auto-advance tour):
//   • begin (left, "Về đầu"): restart THIS exhibit from 0. If it isn't the
//     loaded clip yet, load+play it from the start (tapExhibit).
//   • play/pause (centre): toggle THIS exhibit; if it isn't loaded, load+play.
//   • next (right, "Tiếp"): advance to the NEXT exhibit in tour order — play it
//     (rule 2a: an explicit tap) and pushReplacement its detail. Disabled on
//     the last exhibit. Uses the frozen `major`; only `minor` moves.
//
// PERFORMANCE — the key rule: the progress bar advances several times/second.
// Only a small StreamBuilder bound to AudioProvider.position rebuilds for it;
// the rest rebuilds solely on AudioQueueState changes (clip / play-pause).
//
// FREEZE-BY-DESIGN like screen 3: fixed {major, minor} from route args, read
// once from ContentProvider, does NOT follow the arbiter.
//
// TOKEN FAMILIES — the screen is split in two:
//   • _PlayerPane fills the first viewport and sits ON the exhibit photograph.
//     EVERYTHING inside it — kicker, title, artist, timecodes, track bar, play
//     button, round icons, num badge — uses the on-image family.
//   • _DetailBody scrolls up over `surface` and uses ink / inkMuted / inkFaint.
// Getting this backwards is invisible in dark theme and destroys light theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/audio_feedback.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_motion.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class ExhibitDetailScreen extends StatelessWidget {
  final int major;
  final int minor;

  const ExhibitDetailScreen({
    super.key,
    required this.major,
    required this.minor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final zone = content.zoneByMajor(major);
    final exhibit = content.exhibitAt(major, minor);

    if (zone == null || exhibit == null) {
      return Scaffold(
        backgroundColor: t.surface,
        body: Center(
          child: Text(content.ui(UiKeys.exhibitNotFound),
              style: AppText.meta.copyWith(color: t.inkMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.surface,
      body: CustomScrollView(
        slivers: [
          // Player lấp trọn viewport đầu; chi tiết cuộn lên bên dưới.
          //
          // ConstrainedBox(minHeight) chứ KHÔNG phải SizedBox(height) — sàn,
          // không phải trần. `SizedBox` ép ĐÚNG một chiều cao, và `Column` bên
          // trong có `Spacer()`: ở textScaler lớn, hàng back + khối chữ +
          // controls vượt chiều cao màn ⇒ Spacer nhận 0 và Column TRÀN. Cùng
          // bug đã sửa ở Gate: `Spacer`/`Expanded` chống được va chạm, không
          // chống được tràn.
          //
          // Với minHeight, pane vẫn lấp trọn viewport khi vừa, và GIÃN khi
          // không vừa — CustomScrollView vốn đã ở đây nên nó cuộn, miễn phí.
          SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height,
              ),
              child: _PlayerPane(zone: zone, exhibit: exhibit, content: content),
            ),
          ),
          SliverToBoxAdapter(
            child: _DetailBody(exhibit: exhibit, content: content),
          ),
        ],
      ),
    );
  }
}

/// Player — bố cục kiểu "now playing": ẢNH LÀ MỘT THẺ, không phải một tấm nền.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO ẢNH THÔI LÀM NỀN — và vì sao đó không chỉ là bắt chước Spotify
/// ═══════════════════════════════════════════════════════════════════════════
/// Bản trước: ảnh hiện vật full-bleed, phủ `playerVeil` ~70%, rồi kicker +
/// tên + nghệ sĩ + timecode + thanh tiến trình + ba nút xếp ĐÈ LÊN NÓ.
///
/// Một app bảo tàng làm mờ hiện vật đi 70% để lấy chỗ đặt chữ lên trên nó là
/// một app đang đánh nhau với chính mình. Khách mở màn này vì họ muốn NHÌN cái
/// hiện vật đó. Đó là toàn bộ lý lẽ, và Spotify chỉ tình cờ đã học nó trước:
/// ảnh bìa là CHỦ THỂ, chữ đứng BÊN DƯỚI, không đứng lên trên.
///
/// Hệ quả kỹ thuật rất lớn và rất tốt: cả màn rời khỏi HỌ ON-IMAGE. Không
/// veil, không `inkOnImage`, không `mutedOnImage`, không `scrimBack`. Chỉ còn
/// `ink` / `inkMuted` / `accent` trên `surface` — cùng họ với màn 2 và phần
/// dưới của màn 3. Toàn bộ nhóm bug "chữ trắng trên nền sáng" biến mất khỏi
/// màn này vì KHÔNG CÒN chữ nào nằm trên ảnh.
///
/// ẢNH KHÔNG BỊ CẮT: [HeroImage.fit] = `contain`, nền thẻ là [surfaceRaised].
/// Xem doc của field đó — dải trống là tấm BO, không phải lỗi.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// KHÔNG CÒN Stack — và đó là bản sửa cho một lỗi tôi vừa gây ra
/// ═══════════════════════════════════════════════════════════════════════════
/// Bản ngay trước dùng `Stack` (fit mặc định = `StackFit.loose`) + `Column`
/// `spaceBetween` bọc trong `ConstrainedBox(minHeight: screenH)`. Nó SAI:
/// `StackFit.loose` gọi `constraints.loosen()` trước khi truyền xuống con
/// không-positioned ⇒ `minHeight` bị XOÁ ⇒ Column co về đúng nội dung ⇒
/// `spaceBetween` không còn khe nào để chia ⇒ Stack (vẫn cao screenH) đặt nó ở
/// `topStart` ⇒ THANH TIẾN TRÌNH BỊ ĐẨY LÊN ĐỈNH MÀN.
///
/// Bản gốc dùng `StackFit.expand` nên không dính; tôi bỏ `expand` để pane giãn
/// được ở cỡ chữ lớn, và làm mất luôn cái sàn. (`StackFit.passthrough` là lối
/// sửa tại chỗ — nó truyền nguyên ràng buộc, giữ cả minHeight lẫn maxHeight ∞.)
///
/// Giờ không cần: ảnh là một con của Column, nên không có Stack nào để cấu
/// hình sai. Một lớp ít đi là một lỗi ít đi.
class _PlayerPane extends StatelessWidget {
  final ZoneInfo zone;
  final ExhibitInfo exhibit;
  final ContentProvider content;

  const _PlayerPane({
    required this.zone,
    required this.exhibit,
    required this.content,
  });

  /// Trần chiều cao của thẻ ảnh, theo tỷ lệ màn.
  ///
  /// TRẦN, không phải cỡ cố định: `AspectRatio(1)` lấy chiều nhỏ hơn giữa bề
  /// ngang khả dụng và trần này. Máy hẹp ⇒ bề ngang quyết định; máy cao ⇒ trần
  /// quyết định. Không có nó, thẻ vuông trên máy 375 sẽ chiếm 335 trong 647dp
  /// vùng an toàn và đẩy cụm điều khiển ra sát mép dưới.
  ///
  /// KÍCH THƯỚC theo tỷ lệ màn — ngoại lệ hợp lệ với "không số thô cho khoảng
  /// cách" (AppSpace luật 7): compositional, không phải spacing.
  static const double _artMaxFraction = 0.42;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final zoneName = content.text(zone.name);
    final name = content.text(exhibit.name);
    final artistLine = _artistLine();

    // Bề ngang hiển thị THẬT của thẻ. Bản trước là hằng số 1000: đúng trên một
    // máy nào đó, upscale trên 430@3x, phí RAM trên máy 2x. Cùng LOẠI lỗi với
    // `decodeWidth` ở Gate, `cacheWidth` ở màn 3 và màn 2 — bốn màn, một bug.
    final decodeWidth =
        ((media.size.width - AppSpace.gutter * 2) * media.devicePixelRatio)
            .round();

    return SafeArea(
      child: Column(
        // min + spaceBetween thay cho `Spacer()`: `Spacer` là `Expanded` và
        // cần chiều cao BỊ CHẶN — thứ `ConstrainedBox(minHeight)` cố tình
        // không cho, để pane giãn được ở cỡ chữ lớn thay vì tràn.
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.gutter, vertical: AppSpace.x2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundIcon(
                  icon: Icons.chevron_left,
                  onTap: () => Navigator.of(context).pop(),
                  label: content.ui(UiKeys.exhibitBack),
                ),
                _NumBadge(minor: exhibit.minor),
              ],
            ),
          ),

          // THẺ ẢNH — chủ thể của màn hình. Một hiện vật có thể có nhiều ảnh:
          // vuốt ngang ngay trên thẻ để xem ảnh kế tiếp (xem [_ArtGallery]).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: _ArtGallery(
              paths: exhibit.imagePaths,
              content: content,
              decodeWidth: decodeWidth,
              maxHeight: media.size.height * _artMaxFraction,
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter, AppSpace.x4, AppSpace.gutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // `accent` (họ surface), KHÔNG `accentOnImage`: dòng này
                    // giờ đứng trên `surface`, không trên ảnh. Đây đúng là chỗ
                    // dễ trượt nhất khi một màn đổi họ.
                    Text(zoneName.toUpperCase(),
                        style: AppText.kicker.copyWith(color: t.accent)),
                    const SizedBox(height: AppSpace.x2),
                    Text(name,
                        style: AppText.playerTitle.copyWith(color: t.ink)),
                    if (artistLine != null) ...[
                      const SizedBox(height: AppSpace.x2),
                      Text(artistLine,
                          style: AppText.artist.copyWith(color: t.inkMuted)),
                    ],
                  ],
                ),
              ),
              _Controls(zone: zone, exhibit: exhibit, content: content),
              // Lời mời vuốt.
              Icon(Icons.keyboard_arrow_down, color: t.inkFaint, size: 20),
              const SizedBox(height: AppSpace.x2),
            ],
          ),
        ],
      ),
    );
  }

  String? _artistLine() {
    if (exhibit.specs.isEmpty) return null;
    return exhibit.specs.map((s) => content.text(s.value)).join(' · ');
  }
}

/// Tag nối một tấm ảnh ở THẺ NHỎ với chính nó ở MÀN XEM LỚN.
///
/// Khoá là ĐƯỜNG DẪN BUNDLE, không phải chỉ số trang: chỉ số đổi khi khách
/// vuốt, và hai route không bao giờ đảm bảo cùng một `_index` tại đúng khoảnh
/// khắc Hero đi tìm bạn nhảy. Đường dẫn thì bất biến và đã là duy nhất trong
/// bundle (parser lọc trùng ngay khi parse), nên cặp tag luôn khớp đúng tấm
/// ảnh khách đang nhìn — kể cả khi khách lật vài ảnh ở màn lớn rồi mới đóng.
Object _imageHeroTag(String bundlePath) => 'exhibit-image:$bundlePath';

/// Thẻ ảnh + dải ảnh vuốt ngang.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// MỘT HIỆN VẬT KHÔNG CHỈ CÓ MỘT MẶT
/// ═══════════════════════════════════════════════════════════════════════════
/// Một khẩu súng có báng và có khoá nòng; một chiếc bình có hoa văn ở thân và
/// một vết nứt ở đáy. Bundle mang được nhiều ảnh cho một hiện vật
/// ([ExhibitInfo.imagePaths]) và màn này cho khách vuốt ngang qua đúng bấy
/// nhiêu ảnh — không vòng lại, hết ảnh là hết vuốt.
///
/// ── VÌ SAO KHÔNG ĐỔI GÌ KHÁC TRONG BỐ CỤC ───────────────────────────────
/// Thẻ vẫn là thẻ: cùng `AspectRatio(1)`, cùng trần [maxHeight], cùng tấm bo
/// `surfaceRaised`, cùng `BoxFit.contain`. Chỉ phần RUỘT của thẻ đổi từ một
/// [HeroImage] thành một [PageView] các [HeroImage]. Với hiện vật một ảnh —
/// tức toàn bộ nội dung đã phát hành trước tính năng này — màn hình trông
/// KHÔNG khác một pixel nào: chấm chỉ số cũng không vẽ.
///
/// ── CHẤM CHỈ SỐ Ở DƯỚI THẺ, KHÔNG ĐÈ LÊN ẢNH ────────────────────────────
/// Đè chỉ báo lên ảnh là kéo cả màn ngược về HỌ ON-IMAGE mà `_PlayerPane` vừa
/// bỏ được (xem doc của nó): lại cần veil, lại cần `inkOnImage`, và lại có một
/// vật sáng nằm trên hiện vật. Chấm đứng dưới thẻ, trên `surface`, dùng
/// `accent` / `outline` — cùng hai token thanh tiến trình đang dùng.
///
/// ── NHIỀU ẢNH QUÁ THÌ ĐỔI SANG SỐ ───────────────────────────────────────
/// Quá [_maxDots] chấm, hàng chấm thành một vạch nhiễu không đếm được bằng
/// mắt và bắt đầu tranh chỗ với bề ngang thẻ. Từ đó trở đi hiện "3/12" — cùng
/// thông tin, một dòng chữ.
///
/// ── CHẠM ĐỂ XEM LỚN ─────────────────────────────────────────────────────
/// Thẻ cao nhiều nhất 42% màn: đủ để nhận ra hiện vật, không đủ để đọc chữ
/// khắc hay nhìn hoa văn. Chạm mở [_FullScreenGallery]; vị trí ảnh đi cả hai
/// chiều nên đóng lại là thẻ nhỏ đang ở đúng ảnh khách vừa xem.
class _ArtGallery extends StatefulWidget {
  /// Đường dẫn bundle-relative, ảnh chính đứng đầu. Luôn không rỗng.
  final List<String> paths;
  final ContentProvider content;
  final int decodeWidth;
  final double maxHeight;

  const _ArtGallery({
    required this.paths,
    required this.content,
    required this.decodeWidth,
    required this.maxHeight,
  });

  @override
  State<_ArtGallery> createState() => _ArtGalleryState();
}

class _ArtGalleryState extends State<_ArtGallery> {
  /// Trên ngưỡng này thì đổi chấm sang bộ đếm "i/n".
  static const int _maxDots = 8;
  static const double _dot = 6;

  final _controller = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _ArtGallery old) {
    super.didUpdateWidget(old);
    // Đồng bộ nội dung giữa lúc khách đang xem có thể làm dải ngắn lại. Không
    // kẹp lại, `_index` sẽ trỏ ra ngoài và bộ đếm nói "5/3".
    if (_index >= widget.paths.length) {
      _index = widget.paths.length - 1;
      // jumpTo cần controller đã gắn viewport — sau frame này thì chắc chắn.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = widget.content;
    final n = widget.paths.length;

    final card = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: AspectRatio(
          aspectRatio: 1,
          // Chạm để xem ảnh lớn. `Semantics(button:)` + `onTap` đi thành cặp
          // như mọi nút khác ở màn này — GestureDetector KHÔNG tự khai action
          // cho screen reader. Vuốt ngang vẫn thuộc về PageView bên trong: tap
          // và horizontal drag không tranh nhau trong gesture arena.
          child: Semantics(
            button: true,
            label: content.ui(UiKeys.exhibitImageOpen),
            onTap: _openViewer,
            child: GestureDetector(
              onTap: _openViewer,
              child: ClipRRect(
                borderRadius: t.sharpAll,
                // Tấm bo. `surfaceRaised` chứ không phải `surface`: thẻ phải
                // đọc ra là một vật ĐẶT TRÊN trang, không phải một lỗ thủng
                // trên trang.
                child: ColoredBox(
                  color: t.surfaceRaised,
                  child: n == 1
                      // Một ảnh ⇒ KHÔNG dựng PageView. Không phải để tiết kiệm:
                      // một viewport cuộn được mà không cuộn đi đâu vẫn khai
                      // scrollLeft/scrollRight với screen reader — hứa một thao
                      // tác không tồn tại, đúng lỗi doc `_TrackBar` đã cấm.
                      ? _page(0)
                      : PageView.builder(
                          controller: _controller,
                          itemCount: n,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (_, i) => _page(i),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (n == 1) return card;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Semantics BỌC NGOÀI, không `excludeSemantics`: các thao tác cuộn
        // (scrollLeft/scrollRight) là của chính PageView bên trong — TalkBack
        // lật ảnh bằng chúng. Ở đây chỉ thêm TÊN và VỊ TRÍ; `value` đổi mỗi lần
        // lật nên screen reader đọc lên "Ảnh 2 trên 4" mà không cần chạm gì.
        Semantics(
          container: true,
          label: content.ui(UiKeys.exhibitGalleryLabel),
          value: content.uif(UiKeys.exhibitGalleryPosition, {
            'i': '${_index + 1}',
            'n': '$n',
          }),
          child: card,
        ),
        const SizedBox(height: AppSpace.x3),
        // Chỉ báo là TRANG TRÍ cho mắt: vị trí đã nằm trong `value` ở trên,
        // đọc lần hai chỉ làm dài thêm câu của TalkBack.
        ExcludeSemantics(
          child: n <= _maxDots
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < n; i++)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpace.x1 / 2),
                        child: Container(
                          width: _dot,
                          height: _dot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index ? t.accent : t.outline,
                          ),
                        ),
                      ),
                  ],
                )
              : Text(
                  content.uif(UiKeys.exhibitGalleryCounter, {
                    'i': '${_index + 1}',
                    'n': '$n',
                  }),
                  style: AppText.timeCode.copyWith(color: t.inkMuted),
                ),
        ),
      ],
    );
  }

  Widget _page(int i) => _heroWrapped(
        index: i,
        child: HeroImage(
          filePath: widget.content.imagePath(widget.paths[i]),
          fit: BoxFit.contain,
          cacheWidth: widget.decodeWidth,
        ),
      );

  /// Bọc [Hero] CHỈ cho trang đang xem.
  ///
  /// `PageView` lúc nghỉ chỉ dựng một trang, nhưng trong lúc cuộn nó dựng cả
  /// trang kề. Nếu bọc Hero cho mọi trang thì có lúc HAI cặp tag khớp nhau
  /// cùng lúc giữa hai route, và Flutter sẽ cho cả hai cùng bay — một tấm ảnh
  /// ngoài màn hình bay ngang qua mà khách không hiểu nó là gì. Ràng buộc
  /// `i == _index` biến "thường là một" thành "luôn luôn một".
  Widget _heroWrapped({required int index, required Widget child}) {
    if (index != _index) return child;
    return Hero(tag: _imageHeroTag(widget.paths[index]), child: child);
  }

  /// Mở ảnh toàn màn hình từ ĐÚNG ảnh đang xem, và nhận lại vị trí khi khách
  /// lật ảnh ở trong đó — đóng lại thì thẻ nhỏ đang ở cùng một ảnh. Đồng bộ
  /// bằng CALLBACK chứ không bằng giá trị trả về của `pop`: nút back của hệ
  /// thống pop mà không mang theo giá trị nào, và khi đó thẻ nhỏ sẽ lệch.
  void _openViewer() {
    // Thời lượng của route CŨNG là thời lượng chuyến bay Hero — Flutter lấy
    // thẳng từ đây. Nên `AppMotion.of` ở chỗ này tắt luôn cả hai khi khách bật
    // "Giảm chuyển động": ảnh hiện ra tức thì, không nở, không mờ dần.
    final duration = AppMotion.of(context, AppMotion.slow);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (_, __, ___) => _FullScreenGallery(
          paths: widget.paths,
          initialIndex: _index,
          content: widget.content,
          onIndexChanged: _syncIndex,
        ),
        // NỀN mờ dần, ẢNH thì bay — hai việc khác nhau và Hero lo việc thứ
        // hai. Nếu fade cả trang, tấm ảnh sẽ vừa bay vừa nhạt và chuyến bay
        // mất đúng thứ nó sinh ra để nói: vật này ĐẾN TỪ cái thẻ kia.
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: AppMotion.enter),
          child: child,
        ),
      ),
    );
  }

  void _syncIndex(int i) {
    if (!mounted || i == _index) return;
    setState(() => _index = i);
    if (_controller.hasClients) _controller.jumpToPage(i);
  }
}

/// Ảnh toàn màn hình: vuốt để đổi ảnh, chụm/nhấn đúp để phóng to.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO CÓ MÀN NÀY
/// ═══════════════════════════════════════════════════════════════════════════
/// Thẻ ảnh ở màn 4 cao nhiều nhất 42% chiều màn và luôn `contain` — nghĩa là
/// một hiện vật có hoa văn nhỏ hoặc chữ khắc thì khách KHÔNG đọc được. Đây
/// chính là thứ mà tủ kính ở bảo tàng cũng không cho làm: đến gần hơn.
///
/// ── NỀN `surface`, KHÔNG PHẢI ĐEN ────────────────────────────────────────
/// Lightbox thường mặc định nền đen. Ở đây nền đen là một MÀU THÔ nằm ngoài
/// hệ token, và nó phá preset giấy / tương phản cao đúng kiểu doc
/// `HeroImage.fallback` đã cảnh báo. `surface` + `ink` giữ màn này cùng họ với
/// phần còn lại của app; ảnh vẫn nổi vì nó là vật duy nhất trên trang.
///
/// ── PHÓNG TO KHOÁ VUỐT ───────────────────────────────────────────────────
/// Khi đã phóng to, kéo ngang là DI CHUYỂN TRONG ẢNH, không phải lật ảnh. Nếu
/// để `PageView` giữ nguyên physics, mỗi lần khách kéo sang mép ảnh sẽ nhảy
/// mất sang ảnh khác. `physics` đổi sang `NeverScrollableScrollPhysics` ngay
/// khi scale > 1 — và về lại khi thu về 1x.
///
/// ── MỘT `TransformationController` DÙNG CHUNG ────────────────────────────
/// Chỉ trang ĐANG xem mới phóng to được, và mỗi lần lật trang là reset về 1x.
/// Các trang kề bên tuy còn sống trong viewport cache cũng nhận cùng ma trận,
/// nhưng lúc lật được thì ma trận luôn là identity ⇒ không nhìn thấy gì.
class _FullScreenGallery extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final ContentProvider content;
  final ValueChanged<int> onIndexChanged;

  const _FullScreenGallery({
    required this.paths,
    required this.initialIndex,
    required this.content,
    required this.onIndexChanged,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  /// Mức phóng khi nhấn đúp. 2.5 đọc được chữ khắc mà chưa vỡ ảnh bundle.
  static const double _doubleTapScale = 2.5;
  static const double _maxScale = 4;

  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  final _view = TransformationController();
  bool _zoomed = false;
  Offset? _doubleTapAt;

  @override
  void initState() {
    super.initState();
    _view.addListener(_onTransform);
  }

  void _onTransform() {
    final zoomed = _view.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  Widget _viewerImage(ContentProvider content, int i, int decodeWidth) =>
      HeroImage(
        filePath: content.imagePath(widget.paths[i]),
        fit: BoxFit.contain,
        cacheWidth: decodeWidth,
      );

  void _toggleZoom() {
    if (_zoomed) {
      _view.value = Matrix4.identity();
      return;
    }
    final p = _doubleTapAt;
    if (p == null) return;
    // Neo vào điểm khách nhấn: dịch trước, phóng sau. `…ByDouble` chứ không
    // phải `translate`/`scale` — hai cái kia đã deprecated trong vector_math.
    final d = -p * (_doubleTapScale - 1);
    _view.value = Matrix4.identity()
      ..translateByDouble(d.dx, d.dy, 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  @override
  void dispose() {
    _view.removeListener(_onTransform);
    _view.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final content = widget.content;
    final n = widget.paths.length;
    // Ở đây ảnh chiếm TRỌN bề ngang màn — không trừ gutter như thẻ nhỏ, và
    // nhân thêm hệ số phóng để lúc zoom vẫn còn điểm ảnh mà xem.
    final decodeWidth =
        (media.size.width * media.devicePixelRatio * 1.5).round();

    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: n,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (i) {
                  _view.value = Matrix4.identity(); // trang mới luôn ở 1x
                  setState(() => _index = i);
                  widget.onIndexChanged(i);
                },
                itemBuilder: (_, i) => GestureDetector(
                  onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _view,
                    minScale: 1,
                    maxScale: _maxScale,
                    // CHƯA PHÓNG TO THÌ TẮT PAN — nếu không, InteractiveViewer
                    // giành mất cú kéo ngang một ngón trong gesture arena và
                    // PageView không bao giờ lật trang (ở 1x cú kéo đó còn
                    // chẳng dịch được ảnh đi đâu vì đã kịch biên). Đã phóng to
                    // thì ngược lại: pan là của ảnh, và physics của PageView
                    // đã chuyển sang NeverScrollable ở trên.
                    panEnabled: _zoomed,
                    // Hero CHỈ ở trang đang xem — xem doc `_heroWrapped` bên
                    // `_ArtGalleryState`: hai cặp tag cùng khớp một lúc thì
                    // Flutter cho cả hai cùng bay.
                    child: i == _index
                        ? Hero(
                            tag: _imageHeroTag(widget.paths[i]),
                            child: _viewerImage(content, i, decodeWidth),
                          )
                        : _viewerImage(content, i, decodeWidth),
                  ),
                ),
              ),
            ),
            // Hàng đỉnh: đóng bên trái (cùng chỗ nút back của màn 4, ngón tay
            // không phải học lại), vị trí ảnh bên phải (cùng chỗ số hiện vật).
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.gutter, vertical: AppSpace.x2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundIcon(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                      label: content.ui(UiKeys.exhibitImageClose),
                    ),
                    if (n > 1)
                      Semantics(
                        liveRegion: true,
                        label: content.uif(UiKeys.exhibitGalleryPosition, {
                          'i': '${_index + 1}',
                          'n': '$n',
                        }),
                        excludeSemantics: true,
                        child: Text(
                          content.uif(UiKeys.exhibitGalleryCounter, {
                            'i': '${_index + 1}',
                            'n': '$n',
                          }),
                          style:
                              AppText.timeCode.copyWith(color: t.inkMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Play/pause + progress + begin/next. Only the progress sub-tree rebuilds on
/// position ticks; the rest rebuilds on AudioQueueState changes.
class _Controls extends StatelessWidget {
  final ZoneInfo zone;
  final ExhibitInfo exhibit;
  final ContentProvider content;
  const _Controls({
    required this.zone,
    required this.exhibit,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final audio = context.watch<AudioProvider>(); // rebuilds on state change
    final state = audio.state;
    final major = zone.major;

    // Is THIS exhibit the currently loaded clip? Compare BOTH major and minor —
    // minor is only unique within a zone, so minor alone would false-match an
    // exhibit with the same number in a different zone.
    final isThis = state.current?.zoneMajor == major &&
        state.current?.exhibitMinor == exhibit.minor;
    // FIX B8: timecode tổng phải là thời lượng của CHÍNH hiện vật đang xem.
    // state.duration là của clip đang load trong engine — khi khách mở detail
    // hiện vật B trong lúc clip A còn load, dùng state.duration sẽ hiện tổng
    // thời gian của A. Manifest của mỗi hiện vật đã mang durationSec sẵn.
    final ownResolved =
        exhibit.audio.resolve(content.language, content.fallbackLanguage);
    final ownDuration = ownResolved == null
        ? Duration.zero
        : Duration(
            milliseconds: (ownResolved.track.durationSec * 1000).round());
    final duration =
        isThis ? (state.duration ?? ownDuration) : ownDuration;

    // Next exhibit in tour order (manifest order), if any.
    final curIdx = zone.tourIndexOf(exhibit.minor);
    final hasNext = curIdx >= 0 && curIdx + 1 < zone.exhibits.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter, AppSpace.x3, AppSpace.gutter, AppSpace.x4),
      child: Column(
        children: [
          // Progress track — isolated StreamBuilder so only this repaints.
          StreamBuilder<Duration>(
            stream: audio.position,
            builder: (context, snap) {
              final pos = isThis ? (snap.data ?? Duration.zero) : Duration.zero;
              final frac = (duration.inMilliseconds == 0)
                  ? 0.0
                  : (pos.inMilliseconds / duration.inMilliseconds)
                      .clamp(0.0, 1.0);
              return Column(
                children: [
                  _TrackBar(
                    fraction: frac,
                    duration: duration,
                    // Chỉ tua được clip ĐANG LOAD. Tua một clip chưa nạp là vô
                    // nghĩa — nút "Về đầu" và nút Phát đã lo việc nạp.
                    enabled: isThis && duration.inMilliseconds > 0,
                    onSeek: audio.seek,
                  ),
                  const SizedBox(height: AppSpace.x2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // inkMuted, KHÔNG mutedOnImage: cả màn đã rời khỏi ảnh.
                      Text(_fmt(isThis ? pos : Duration.zero),
                          style: AppText.timeCode.copyWith(color: t.inkMuted)),
                      Text(_fmt(duration),
                          style: AppText.timeCode.copyWith(color: t.inkMuted)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpace.x3),
          // Nút.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SkipButton(
                icon: Icons.first_page,
                label: content.ui(UiKeys.exhibitRestart),
                onTap: () {
                  final r = isThis
                      ? audio.replay()
                      : audio.tapExhibit(major: major, minor: exhibit.minor);
                  showAudioFeedback(context, r);
                },
              ),
              const SizedBox(width: AppSpace.x8),
              _PlayButton(
                playing: isThis && state.isPlaying,
                label: content.ui((isThis && state.isPlaying)
                    ? UiKeys.exhibitPause
                    : UiKeys.exhibitPlay),
                onTap: () {
                  if (isThis && state.isPlaying) {
                    audio.pause();
                    return;
                  }
                  final r = isThis
                      ? audio.play()
                      : audio.tapExhibit(major: major, minor: exhibit.minor);
                  showAudioFeedback(context, r);
                },
              ),
              const SizedBox(width: AppSpace.x8),
              _SkipButton(
                icon: Icons.last_page,
                label: content.ui(UiKeys.exhibitNext),
                // Advance to the next exhibit in tour order and open it. Off at
                // the last exhibit (onTap null greys the control out).
                onTap: hasNext ? () => _goNext(context, audio) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goNext(BuildContext context, AudioProvider audio) {
    final curIdx = zone.tourIndexOf(exhibit.minor);
    if (curIdx < 0 || curIdx + 1 >= zone.exhibits.length) return;
    final next = zone.exhibits[curIdx + 1];
    // Rule 2a: an explicit request interrupts and plays the chosen clip.
    final r = audio.tapExhibit(major: zone.major, minor: next.minor);
    showAudioFeedback(context, r);
    // Replace (don't stack) so back from any detail returns to the list.
    Navigator.of(context).pushReplacementNamed(
      AppRouter.exhibitDetailRoute,
      arguments: ExhibitDetailArgs(major: zone.major, minor: next.minor),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Thanh tiến trình — KÉO ĐƯỢC. Trên `surface`.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// KNOB ĐÃ QUAY LẠI, LẦN NÀY KÈM CHỨC NĂNG
/// ═══════════════════════════════════════════════════════════════════════════
/// Doc cũ tự chẩn đoán đúng: "The knob reads as 'drag me' but nothing here
/// handles a gesture yet. Either wire seek (userSeek exists on the controller)
/// or drop the knob — a control that promises interaction and refuses it is
/// worse than a plain indicator." Nó đưa ra HAI đường; đợt trước chọn bỏ knob,
/// và đó là đường hèn hơn. Giờ chọn đường kia.
///
/// Đường ống đã chờ sẵn từ lâu: `AudioProvider.seek` → `TourAudioController
/// .userSeek` → `IAudioEngine.seek`, và doc của controller ghi "Chưa có UI
/// dùng — chuẩn bị cho seek ở bước 6."
///
/// ── VÙNG CHẠM 48, THANH 2 ───────────────────────────────────────────────
/// Thanh cao 2dp; ngón tay không nhắm được 2dp. Vùng chạm là [AppSpace.tap]
/// (48) trong suốt, thanh vẽ ở giữa. Đây là lý do widget này KHÔNG dùng
/// `Slider` của Material: Slider mang cả một bảng màu M3 riêng (`activeColor`,
/// `thumbColor`, `overlayColor`…) và một `SliderTheme` cần khoá lại từng
/// trường — nhiều bề mặt hơn để lệch khỏi hệ token so với 30 dòng này.
///
/// ── VÌ SAO CÓ `_dragFraction` ───────────────────────────────────────────
/// Khi đang kéo, vị trí PHẢI theo ngón tay, không theo stream. Không có nó,
/// mỗi tick `position` (vài lần/giây) sẽ giật knob về chỗ engine đang phát và
/// nó đánh nhau với ngón tay. Chỉ khi thả mới `seek` và trả quyền cho stream.
///
/// ── SEEK CHỈ KHI CLIP NÀY ĐANG LOAD ─────────────────────────────────────
/// `enabled` = false khi hiện vật này không phải clip đang load. Tua một clip
/// chưa nạp là vô nghĩa; nút "Về đầu" và nút Phát đã lo việc nạp nó. Lúc đó
/// thanh vẫn vẽ (ở 0) như một chỉ báo trung thực — nhưng KHÔNG có knob, vì
/// knob là lời hứa kéo được, và luật ở đây không đổi: không hứa thứ không làm.
class _TrackBar extends StatefulWidget {
  final double fraction;
  final Duration duration;
  final bool enabled;
  final ValueChanged<Duration> onSeek;

  const _TrackBar({
    required this.fraction,
    required this.duration,
    required this.enabled,
    required this.onSeek,
  });

  @override
  State<_TrackBar> createState() => _TrackBarState();
}

class _TrackBarState extends State<_TrackBar> {
  double? _dragFraction;

  static const double _knob = 12;

  double _fracFromDx(double dx, double w) => (dx / w).clamp(0.0, 1.0);

  void _commit(double frac) {
    widget.onSeek(widget.duration * frac);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final frac = _dragFraction ?? widget.fraction;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final bar = SizedBox(
          // Vùng chạm 48 — thanh 2dp chỉ là thứ được VẼ ở giữa nó.
          height: AppSpace.tap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Rail.
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 2,
                  width: w,
                  // `outline`, KHÔNG `lineOnImage`: thanh này giờ đứng trên
                  // `surface`. `outline` là "viền/rail của CONTROL" và có sàn
                  // 3:1 — xem doc token. `lineOnImage` mất call site cuối cùng
                  // của nó ở đây; kiểm trước khi giữ field đó.
                  child: ColoredBox(color: t.outline),
                ),
              ),
              // Fill.
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 2,
                  width: w * frac,
                  child: ColoredBox(color: t.accent),
                ),
              ),
              if (widget.enabled)
                Positioned(
                  left: (w * frac) - _knob / 2,
                  child: Container(
                    width: _knob,
                    height: _knob,
                    decoration:
                        BoxDecoration(color: t.accent, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        );

        if (!widget.enabled) {
          return ExcludeSemantics(child: bar);
        }

        // Feature B: nhãn + giá trị đọc-màn-hình lấy từ bundle qua ui()/uif().
        // read() đủ vì cả subtree này đã rebuild theo ContentProvider ở tầng trên
        // (widget cha watch<ContentProvider>()), nên đổi ngôn ngữ vẫn cập nhật.
        final content = context.read<ContentProvider>();
        return Semantics(
          slider: true,
          label: content.ui(UiKeys.exhibitProgressLabel),
          value: _spokenDuration(content, widget.duration * frac),
          // Screen reader không kéo được. `onIncrease`/`onDecrease` là cách
          // DUY NHẤT để tua bằng TalkBack, và thiếu chúng thì thanh này là một
          // control chỉ dùng được bằng mắt — tức lại đúng cái lỗi "hứa rồi từ
          // chối", chỉ đổi nhóm người bị từ chối.
          onIncrease: () => _commit(
              ((frac * widget.duration.inMilliseconds + 10000) /
                      widget.duration.inMilliseconds)
                  .clamp(0.0, 1.0)),
          onDecrease: () => _commit(
              ((frac * widget.duration.inMilliseconds - 10000) /
                      widget.duration.inMilliseconds)
                  .clamp(0.0, 1.0)),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _commit(_fracFromDx(d.localPosition.dx, w)),
            onHorizontalDragStart: (d) => setState(
                () => _dragFraction = _fracFromDx(d.localPosition.dx, w)),
            onHorizontalDragUpdate: (d) => setState(
                () => _dragFraction = _fracFromDx(d.localPosition.dx, w)),
            onHorizontalDragEnd: (_) {
              final f = _dragFraction;
              if (f != null) _commit(f);
              setState(() => _dragFraction = null);
            },
            onHorizontalDragCancel: () => setState(() => _dragFraction = null),
            child: bar,
          ),
        );
      },
    );
  }

  /// Thời lượng cho screen reader, template lấy từ bundle: '{m} phút {s} giây'
  /// (mặc định VI). `{s}` đã zero-pad 2 chữ số như bản cũ.
  static String _spokenDuration(ContentProvider content, Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return content.uif(UiKeys.exhibitDurationSpoken, {
      'm': '$m',
      's': s.toString().padLeft(2, '0'),
    });
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  final String label;
  const _PlayButton({required this.playing, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      // excludeSemantics + onTap ĐI THÀNH CẶP: excludeSemantics gỡ cả cây con
      // khỏi semantics, kể cả action onTap mà InkWell tự khai. Thiếu vế thứ
      // hai là nút thôi bấm được bằng TalkBack — hồi quy im lặng, không test
      // nào bắt được.
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        // ctaFill/ctaLabel (họ surface), KHÔNG ctaOnImage*: nút giờ đứng trên
        // `surface`. Đây là chỗ dễ trượt nhất khi một màn đổi họ — và nó vô
        // hình ở preset tối, nơi cả hai token đều gần trắng.
        color: t.ctaFill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            // 56 = AppSpace.actionCircle, cùng cỡ nút intro của khu ở màn 3.
            // Bản trước là 60 — không nằm trên lưới 4dp, và khác màn 3 mà
            // không có lý do nào.
            width: AppSpace.actionCircle,
            height: AppSpace.actionCircle,
            child: Icon(playing ? Icons.pause : Icons.play_arrow,
                color: t.ctaLabel, size: 26),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Null disables the control (dimmed, no ripple) — used for "Tiếp" at the
  /// last exhibit.
  final VoidCallback? onTap;
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true, // + onTap: xem doc ở _PlayButton
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: AppSpace.tap,
            height: AppSpace.tap,
            // ink / ctaDisabled thay cho `inkOnImage @ .85/.3` tự chế. Alpha
            // 0.3 trên ảnh là gần như vô hình, và cả hai con số đều không được
            // đo. `ctaDisabled` có sàn 3:1 với inkMuted — xem test hợp đồng.
            child: Icon(icon,
                color: enabled ? t.ink : t.ctaDisabled, size: 24),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  const _RoundIcon(
      {required this.icon, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true, // + onTap: xem doc ở _PlayButton
      onTap: onTap,
      child: Material(
        // KHÔNG còn `scrimBack` + `inkOnImage`: scrim là để tách một glyph
        // khỏi ẢNH, và ở màn này không còn ảnh nào dưới nút. Một đĩa scrim
        // trên `surface` là đúng cái "nút back mắc cạn" đã sửa ở màn 3.
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: AppSpace.tap,
            height: AppSpace.tap,
            child: Icon(icon, color: t.ink, size: 26),
          ),
        ),
      ),
    );
  }
}

/// Số hiện vật ở góc phải-trên. CHỮ TRẦN, không đĩa — và cả hai điều đó là
/// bản sửa.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// BẢN TRƯỚC LÀ MỘT ĐĨA TRẮNG `ctaOnImageFill`, VÀ ĐÓ LÀ HAI LỖI CHỒNG NHAU
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 1. GIẢ DẠNG NÚT. `ctaOnImageFill` là nền của NÚT PHÁT — đĩa trắng 60dp ngay
///    bên dưới. Badge dùng cùng token, cùng hình tròn, cùng cỡ gần bằng, và
///    KHÔNG bấm được. Doc màn 3 ghi rõ pattern này đã bị khai tử ở đó: "Hint
///    bar (nền ctaFill nhưng không bấm được — giả dạng nút) đã bỏ". Nó sống
///    lại ở màn này. Một vật mang màu CTA mà không phải CTA là một lời hứa bị
///    rút lại, và khách chỉ phát hiện bằng cách chạm vào và không có gì xảy ra.
///
/// 2. `TextStyle` THÔ NGAY TẠI CALL SITE — `fontFamily: AppFonts.serif,
///    fontWeight: w700, fontSize: 13`, ngoài [AppText] hoàn toàn. Một style
///    thứ mười tám không ai biết là có, không nằm trong thang, và sẽ không đi
///    theo bất kỳ lần chỉnh typography nào.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO KHÔNG PHẢI MỘT ĐĨA KHÁC
/// ═══════════════════════════════════════════════════════════════════════════
/// Lối sửa hiển nhiên là đổi `ctaOnImageFill` sang `scrimBack`. KHÔNG — vì
/// `scrimBack` là đĩa của NÚT BACK, ngay bên trái trên cùng một hàng. Đổi lời
/// hứa "tôi là nút Phát" thành "tôi là nút Back" không phải sửa lỗi.
///
/// App có [MuseumTokens.badgeWell] cho đúng việc này — đĩa LÕM mang một con số
/// không bấm được — nhưng nó thuộc HỌ SURFACE, và ở đây ta đứng trên ẢNH. Họ
/// on-image không có đĩa-lõm, và phát minh một cái chỉ để đặt hai chữ số là
/// thêm một token cho một call site.
///
/// Nên: KHÔNG ĐĨA. Chữ trần trên veil — cùng cách kicker ngay bên dưới đang
/// làm, cùng token [mutedOnImage], cùng vai. Không hình tròn thì không hứa hẹn
/// gì. Đây cũng là luật đã dùng ba lần trong dự án này: thứ không làm nổi việc
/// của nó thì dọn đi, đừng tô lại.
///
/// SỐ NÀY LÀ TRANG TRÍ — quyết định sản phẩm, xem doc [MuseumTokens.badgeWell]:
/// bảo tàng KHÔNG đánh số hiện vật, và giá trị đang hiện là `minor` ID của
/// beacon BLE. Nó ở lại để cân bằng hàng đỉnh với nút back. Vì thế nó cũng
/// không nằm trong Semantics của bất cứ thứ gì, và dòng "Hiện vật số N" đã bị
/// gỡ khỏi kicker — nó nói cùng một lời hai lần, và cả hai lần đều sai.
class _NumBadge extends StatelessWidget {
  final int minor;
  const _NumBadge({required this.minor});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // ExcludeSemantics: TalkBack không đọc một minor ID beacon lên. Cùng lý lẽ
    // đã gỡ "Hiện vật số N" khỏi label của `_StopRow` ở màn 3 — làm nó chìm
    // bằng mắt mà để nguyên cho screen reader là giấu vấn đề khỏi đúng nhóm
    // người ít có khả năng phát hiện nhất.
    return ExcludeSemantics(
      child: Text('$minor',
          style: AppText.kicker.copyWith(color: t.inkFaint)),
    );
  }
}

/// Below-the-fold: summary, meaning, specs. Sits on `surface`, follows theme.
class _DetailBody extends StatelessWidget {
  final ExhibitInfo exhibit;
  final ContentProvider content;

  const _DetailBody({required this.exhibit, required this.content});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final summary = content.text(exhibit.summary);
    final meaning = content.textOrNull(exhibit.meaning);

    return Container(
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter, AppSpace.x6, AppSpace.gutter, AppSpace.x10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, content.ui(UiKeys.exhibitSectionIntro)),
          const SizedBox(height: AppSpace.x2),
          Text(summary, style: AppText.body.copyWith(color: t.inkMuted)),
          if (meaning != null) ...[
            const SizedBox(height: AppSpace.x6),
            _sectionLabel(context, content.ui(UiKeys.exhibitSectionMeaning)),
            const SizedBox(height: AppSpace.x2),
            Text(meaning, style: AppText.body.copyWith(color: t.inkMuted)),
          ],
          if (exhibit.specs.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x6),
            _sectionLabel(context, content.ui(UiKeys.exhibitSectionSpecs)),
            const SizedBox(height: AppSpace.x3),
            ...exhibit.specs.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        // Cột nhãn cố định 120: hai cột thẳng hàng đọc ra là
                        // một BẢNG. ⚠ Ở textScaler lớn nhãn dài sẽ xuống dòng
                        // trong 120 trong khi giá trị có Expanded — bảng lệch
                        // nhưng KHÔNG tràn và KHÔNG mất chữ. Chấp nhận: đây là
                        // thông số phụ dưới fold, không phải nội dung chính.
                        width: 120,
                        child: Text(content.text(s.label),
                            style:
                                AppText.stopMeta.copyWith(color: t.inkFaint)),
                      ),
                      Expanded(
                        // `stopMeta`, KHÔNG phải `body.copyWith(fontSize: 12)`.
                        // Ghi đè fontSize tại call site là BỊA một style thứ
                        // mười tám — nó không nằm trong thang, không ai biết là
                        // có, và sẽ không đi theo bất kỳ lần chỉnh typography
                        // nào. `stopMeta` đã LÀ 12 và đã là vai "chữ phụ trong
                        // một hàng"; nhãn bên trái đang dùng chính nó.
                        child: Text(content.text(s.value),
                            style:
                                AppText.stopMeta.copyWith(color: t.inkMuted)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text.toUpperCase(),
        style: AppText.kicker.copyWith(color: context.tokens.ink),
      );
}