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
// Everything below it — section header, rows, empty state — sits on `surface`
// and follows the theme. The 56x56 thumbnail is an image, but the row text
// sits BESIDE it, not on it: that row is surface. Easiest place to slip.
//
// ─────────────────────────────────────────────────────────────────────────────
// BỐ CỤC (redesign bước 1 — thuần thị giác, logic presence giữ nguyên):
//   • Hero CO GIÃN 80% màn hình (SliverAppBar, tham chiếu Rijksmuseum):
//     mở màn là ảnh gần trọn màn, ~20% dưới hé danh sách làm lời mời vuốt;
//     vuốt lên thì ảnh thu lại, nút back ghim ở đỉnh. Chữ trên hero fade
//     theo độ thu để không chui vào thanh ghim.
//   • Hint bar (nền ctaFill nhưng không bấm được — giả dạng nút) đã bỏ, và
//     câu "chọn theo số trên nhãn" cũng bỏ nốt: bảo tàng KHÔNG có nhãn số
//     cạnh hiện vật. Thay bằng _SectionBand — dải màu đặc, cùng thủ pháp
//     color-block với band ở Gate — làm đường nối hero -> danh sách. Meta
//     trên hero nói điều chưa ai nói: danh sách tự xuất hiện theo khoảng cách.
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
              else ...[
                const SliverToBoxAdapter(child: _SectionBand()),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      18, 14, 18, 18 + MediaQuery.paddingOf(context).bottom),
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

/// Hero co giãn của khu trưng bày. Mở rộng = 62% màn hình; thu về = thanh ghim
/// chỉ còn nút back (không lặp tên khu trên thanh ghim — người dùng vừa đọc nó
/// trên hero và màn này chỉ sâu một cấp; thêm title fade là việc của lần sau
/// nếu thấy cần). Everything in here is ON the image.
class _ZoneHeroBar extends StatelessWidget {
  final ZoneInfo zone;
  final ContentProvider content;

  const _ZoneHeroBar({required this.zone, required this.content});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(zone.name);
    // 0.80 (tham chiếu Rijksmuseum): ảnh gần trọn màn nhưng ~20% dưới vẫn
    // hé section header + mép hàng đầu — lời mời vuốt tự nhiên. KHÔNG lên
    // 0.9: dải hé còn ~10% dễ bị đọc nhầm thành footer, khách không biết
    // bên dưới có danh sách.
    final expandedHeight = MediaQuery.sizeOf(context).height * 0.80;
    final collapsedHeight =
        kToolbarHeight + MediaQuery.paddingOf(context).top;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: t.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      // Back button — scrimBack tròn như bản cũ, giờ sống trong leading để
      // luôn ghim ở đỉnh khi hero thu lại. 48x48 giữ tap target.
      leading: Center(
        child: Semantics(
          button: true,
          label: 'Quay lại',
          child: Material(
            color: t.scrimBack,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.chevron_left, color: t.inkOnImage, size: 26),
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
              // Hero giờ cao 62% màn hình — decode lớn hơn bản banner 250px.
              cacheWidth: 1200,
            ),
            // Title + meta, bottom-left. The meta is intentionally STATIC (no
            // live count) — a number that changed as you walked would itself
            // flicker; the list below already tells you what's near.
            Positioned(
              left: 18,
              // Chừa chỗ nút play 56px + khoảng thở — tên khu dài không được
              // tràn vào cột của nút.
              right: 18 + 56 + 14,
              bottom: 24, // hero 80% màn: chữ cần rời mép ảnh xa hơn bản 62%
              child: Opacity(
                opacity: textOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kicker accent — nối ngôn ngữ với vạch accent ở Gate.
                    Text('KHU TRƯNG BÀY',
                        style: AppText.kicker.copyWith(color: t.accent)),
                    const SizedBox(height: 6),
                    Text(name,
                        style:
                            AppText.heroTitle.copyWith(color: t.inkOnImage)),
                    const SizedBox(height: 6),
                    Text(
                      // Điều chưa ai nói trên màn này: cơ chế đặc biệt nhất
                      // của app — danh sách sống theo khoảng cách.
                      'Hiện vật tự xuất hiện khi bạn tới gần',
                      style: AppText.meta.copyWith(color: t.mutedOnImage),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 24, // thẳng hàng đáy với khối chữ
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
        final isThisIntro =
            c != null && c.isIntro && c.zoneMajor == major;
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
                width: 56,
                height: 56,
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

/// Dải màu ngăn hero với danh sách — thay cho section header chữ.
///
/// Câu "Chọn theo số trên nhãn" đã bỏ theo thực tế vận hành: bảo tàng KHÔNG
/// có nhãn số cạnh hiện vật, nên câu đó chỉ dẫn tới một thứ không tồn tại.
/// Thay bằng một dải màu đặc full-bleed: đường nối liền mạch giữa ảnh hero và
/// danh sách, cùng thủ pháp color-block với hai band ở Gate ([sectionBand]
/// giữ cùng tông — xem doc của token).
///
/// KHÔNG hoa văn, KHÔNG chữ, KHÔNG viền: ngôn ngữ của app là hình học tối
/// giản, một khối màu đặc là đủ. Trang trí thuần tuý nên không phát semantics.
class _SectionBand extends StatelessWidget {
  const _SectionBand();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ColoredBox(color: context.tokens.sectionBand),
    );
  }
}

/// Shown when the frozen zone currently has no exhibit beacon in range. Not an
/// error — a direction: walk up to a display case and it appears in the list.
class _NoneNearby extends StatelessWidget {
  const _NoneNearby();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, color: t.inkFaint, size: 34),
            const SizedBox(height: 16),
            Text('CHƯA CÓ HIỆN VẬT NÀO Ở GẦN',
                style: AppText.kicker.copyWith(color: t.ink)),
            const SizedBox(height: 8),
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
/// việc phân tách hàng sau khi hairline bị bỏ — nền + khoảng cách 10px làm
/// việc mà gạch mờ từng làm, nhưng không cắt ngang thị giác.
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
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: t.surfaceRaised,
              borderRadius: t.sharpAll,
              child: InkWell(
                onTap: onTap,
                borderRadius: t.sharpAll,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 56x56 thumbnail — mỏ neo trái của hàng.
                      ClipRRect(
                        borderRadius: t.sharpAll,
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: HeroImage(
                            filePath: content.imagePath(exhibit.thumbnailPath),
                            cacheWidth: 168,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
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
                                style:
                                    AppText.stopName.copyWith(color: t.ink)),
                            const SizedBox(height: 3),
                            Text(
                                nowPlaying
                                    ? 'Đang phát thuyết minh'
                                    : _metaLine(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.stopMeta.copyWith(
                                    color:
                                        nowPlaying ? t.accent : t.inkMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Badge số — đĩa lõm; đang phát thì bừng accent.
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: nowPlaying ? t.accent : t.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: t.frameShadow,
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: nowPlaying
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