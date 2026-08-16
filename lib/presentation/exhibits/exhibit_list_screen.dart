// Destination: lib/presentation/exhibits/exhibit_list_screen.dart
//
// MÀN 04b · HIỆN VẬT TRONG MỘT KHU — một BẢNG ẢNH, không phải danh sách chữ.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO KHÔNG CÒN CHỮ NÀO TRÊN Ô
// ═══════════════════════════════════════════════════════════════════════════
//
// Khách đang ĐỨNG TRƯỚC hiện vật thật. Thứ giúp họ tìm đúng mục trong máy là
// cái NHÌN GIỐNG, không phải cái tên ĐỌC GIỐNG. Nên màn này bỏ hẳn danh sách
// chữ: tên, xuất xứ, thời lượng, câu chuyện đều dời sang màn 4c, nơi có chỗ cho
// chữ và nơi khách đã chọn xong rồi mới đọc.
//
// ═══════════════════════════════════════════════════════════════════════════
// BẢNG PHÂN LOẠI CỦA CẢ APP — ba hình dáng, phân biệt bằng LỀ chứ không bằng chữ
// ═══════════════════════════════════════════════════════════════════════════
//
//     ảnh tràn hết mép máy  →  một NƠI CHỐN.  Khách đang Ở TRONG nó.
//     ảnh có lề bao quanh   →  một HIỆN VẬT.  Khách đang NHÌN nó từ ngoài.
//     hàng có dấu ›         →  một THAO TÁC hoặc một lối đi.
//
// Vì sao luật này phải được viết ra: hai bản dựng trước của màn 4b đều để lưới
// tràn mép và dính sát ảnh khu ở trên, nên cả trang đọc thành "khu vực và mấy
// tấm ảnh của khu vực" thay vì "khu vực và những hiện vật trong đó". Bản dùng
// lưới mosaic còn sai nặng hơn: trong hệ thống này mosaic ĐÃ CÓ NGHĨA — ở màn
// Menu nó là ba ảnh của MỘT chủ đề — nên mượn nó về đây là mượn luôn nghĩa ấy.
//
// Ba thứ cùng làm việc để mỗi ô đọc thành một vật riêng: lề 20 hai bên với khe
// 16 giữa các ô; một dải nền 32 ngăn lưới với ảnh khu; và ô không mang chữ nào.
//
// ═══════════════════════════════════════════════════════════════════════════
// NHỮNG GÌ ĐÃ MẤT Ở BƯỚC NÀY — ghi lại để không ai phải học lại
// ═══════════════════════════════════════════════════════════════════════════
//
// `_ZoneHeroBar` (hero co giãn 80% màn, tự thu về thanh ghim khi cuộn) và
// gradient "hoà tan" đáy ảnh của nó đã bị gỡ, thay bằng `.zhero` TĨNH 480 dùng
// chung khuôn với màn Khu vực. Bốn quyết định kỹ thuật của gradient đó là công
// sức thật và chúng đúng; chúng chỉ không còn chỗ đứng khi bản vẽ bỏ hẳn hero
// co giãn. Nếu một ngày cần dựng lại, chúng nằm trong lịch sử git:
//
//   1. KHÔNG BAO GIỜ `Colors.transparent` trong một gradient — nó là #00000000,
//      tức ĐEN alpha 0, và khoảng giữa sẽ ám xám bẩn. Luôn dùng
//      `mauDich.withValues(alpha: 0)`.
//   2. Ramp phải CONG, không tuyến tính: mắt cảm nhận độ chói theo hàm mũ, nên
//      một ramp alpha đều tay lại TRÔNG như có một đường bắt đầu (dải Mach).
//   3. Độ dài vùng tan tính bằng dp CỐ ĐỊNH, không theo % màn: chất lượng dải
//      chuyển phụ thuộc số pixel VẬT LÝ nó trải qua.
//   4. Gradient phải sống TRONG hero, không phải là một sliver riêng — một
//      sliver sẽ cuộn đi mất và "đường nối" chỉ tồn tại ở offset 0.
//
// ═══════════════════════════════════════════════════════════════════════════
// KHU VẪN ĐÓNG BĂNG, DANH SÁCH VẪN THEO MANIFEST
// ═══════════════════════════════════════════════════════════════════════════
//
// `major` đến từ route arguments. Arbiter đổi khu bên dưới thì màn này GIỮ
// nguyên major của nó — chỉ màn Khu vực đi theo arbiter.
//
// Bảng hiện TRỌN bộ hiện vật của khu theo thứ tự manifest, KHÔNG lọc theo sóng
// minor: một khu có thể chỉ mang một beacon, và thu sóng từng hiện vật thì mong
// manh. Manifest là nguồn sự thật cho cả thứ bày ra ở đây LẪN thứ auto-tour
// phát. Một beacon hiện vật chết vì thế không làm hiện vật đó biến mất.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/tour_progress.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/audio_feedback.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/tour_progress_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/theme/on_image_text.dart';
import 'package:beacon_client/presentation/theme/player_marks.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class ExhibitListScreen extends StatelessWidget {
  /// Khu ĐÓNG BĂNG, lấy từ route arguments — mỏ neo của cả màn.
  final int major;

  const ExhibitListScreen({super.key, required this.major});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final zone = content.zoneByMajor(major);

    if (zone == null) {
      // Major lạ (route cũ còn sót sau một lần đổi bundle) — nói ra, không sập.
      return Scaffold(
        backgroundColor: t.surface,
        body: Center(
          child: Text(content.ui(UiKeys.exhibitListZoneNotFound),
              style: AppText.meta.copyWith(color: t.inkMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.surface,
      // Thanh trên ĐÈ LÊN ảnh khu — cùng luật với màn Menu và màn Khu vực.
      body: Stack(
        children: [
          Positioned.fill(child: _Body(zone: zone, major: major)),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            // TIÊU ĐỀ ĐỂ TRỐNG, đúng bản vẽ. Tên khu nằm ngay bên dưới trong
            // hero ở cỡ 28; lặp nó ở cỡ 15 trên thanh là nói một điều hai lần,
            // và màn này chỉ sâu một cấp nên không ai lạc.
            child: MuseumTopBar(
              title: '',
              leading: TopBarLeading.back,
              solid: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ZoneInfo zone;
  final int major;

  const _Body({required this.zone, required this.major});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();

    // Đọc MỘT LẦN ở đây thay vì trong từng ô: `heardExhibits` là một Set và
    // mỗi ô chỉ hỏi nó một câu. Cho mỗi ô tự `watch` provider là 6–9 lần đăng
    // ký cho cùng một mẩu dữ liệu, và cả chín cùng rebuild mỗi lần tiến trình
    // đổi — trong khi thứ đổi chỉ là MỘT ô.
    final progress = context.select<TourProgressProvider, TourProgress>(
      (p) => p.progress,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _ZoneHero(zone: zone, major: major)),

        if (zone.exhibits.isEmpty)
          const SliverToBoxAdapter(child: _ZoneEmpty())
        else
          SliverPadding(
            // `.exgrid { padding: 0 gutter }` + dải nền 32 phía trên cắt mạch
            // với ảnh khu, và 40 phía dưới. Dải trên là thứ khiến trang thôi
            // đọc thành "khu vực và mấy tấm ảnh của khu vực".
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.x8, AppSpace.gutter, AppSpace.x10),
            sliver: SliverGrid.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpace.x4,
                crossAxisSpacing: AppSpace.x4,
                // Ô VUÔNG — tỉ lệ trung tính nhất cho một vật chụp trong tủ
                // kính. Không cắt theo tỉ lệ nào khác vì ảnh do bảo tàng nạp
                // và ta không biết trước vật nằm ngang hay dọc.
                childAspectRatio: 1,
              ),
              itemCount: zone.exhibits.length,
              itemBuilder: (context, i) {
                final exhibit = zone.exhibits[i];
                return _ExhibitTile(
                  key: ValueKey(exhibit.minor),
                  exhibit: exhibit,
                  major: major,
                  content: content,
                  heard: progress.heardExhibits
                      .contains(ExhibitKey(major, exhibit.minor)),
                  onTap: () => _openExhibit(context, exhibit),
                );
              },
            ),
          ),

        // `.screen.has-tabs` — màn này là trang con của tab Tham quan.
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  void _openExhibit(BuildContext context, ExhibitInfo exhibit) {
    // Chạm là một yêu cầu TƯỜNG MINH ⇒ cắt ngang và phát. `major` là khu đóng
    // băng của màn này, không phải khu hiện tại của arbiter.
    //
    // Cố ý gọi showAudioFeedback TRƯỚC pushNamed: ScaffoldMessenger resolve tới
    // messenger của MaterialApp, nên snackbar nổi trên màn Chi tiết vừa mở —
    // đúng nơi khách đang tự hỏi vì sao không có tiếng. Đừng đảo thứ tự.
    final r = context
        .read<AudioProvider>()
        .tapExhibit(major: major, minor: exhibit.minor);
    showAudioFeedback(context, r);

    Navigator.of(context).pushNamed(
      AppRouter.exhibitDetailRoute,
      arguments: ExhibitDetailArgs(major: major, minor: exhibit.minor),
    );
  }
}

/// `.zhero` của màn 4b — cùng khối ảnh với màn Khu vực, cộng cụm `.zplay`.
///
/// KHÔNG LỚP PHỦ, cùng quyết định đã áp cho màn Khu vực: veil tan vào `surface`,
/// mà preset mặc định là giấy, nên nó rót màu giấy lên ảnh thay vì dìm ảnh.
///
/// ⚠ HỆ QUẢ DÂY CHUYỀN, và nó là thứ dễ bỏ sót nhất ở đây: bản vẽ ghi cụm
/// `.zplay` dùng MỰC CỦA TRANG, với lý do "nó nằm ở đáy khối ảnh, chỗ lớp veil
/// đã kéo gần hết về màu trang — tức nó ngồi trên nền trang chứ không trên ảnh".
/// Bỏ veil thì tiền đề đó mất: cụm ấy nay ngồi trên ẢNH TRẦN, nên nó phải theo
/// họ on-image y như dấu phát trong lưới. Dùng mực trang ở đây sẽ cho chữ tối
/// trên một tấm ảnh tư liệu tối.
class _ZoneHero extends StatelessWidget {
  final ZoneInfo zone;
  final int major;

  const _ZoneHero({required this.zone, required this.major});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final media = MediaQuery.of(context);
    final summary = content.textOrNull(zone.summary);

    return SizedBox(
      height: DesignSize.zoneHero * DesignSize.verticalScale(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          HeroImage(
            filePath: content.imagePath(zone.heroImagePath),
            cacheWidth: (media.size.width * media.devicePixelRatio).round(),
          ),
          Positioned(
            left: AppSpace.gutter,
            right: AppSpace.gutter,
            bottom: AppSpace.x6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // KHU VỰC THÌ VẪN PHẢI CÓ CHỮ, và đây là chỗ luật "ít chữ" của
                // màn này dừng lại: hiện vật bỏ được tên vì khách đang nhìn
                // thấy nó thật, còn một khu trưng bày không có "vật" nào để đối
                // chiếu — tên và câu mô tả là thứ duy nhất nói cho khách biết
                // họ sắp bước vào cái gì.
                OnImageText(content.text(zone.name),
                    style: AppText.heroTitle.copyWith(color: t.inkOnImage)),
                if (summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.x3),
                  OnImageText(summary,
                      style: AppText.heroSub.copyWith(color: t.mutedOnImage)),
                ],
                const SizedBox(height: AppSpace.x4),
                _ZoneIntro(major: major),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trạng thái của dấu phát phần dẫn, tính từ `AudioQueueState`.
///
/// Enum riêng thay vì hai bool rời để `Selector` so MỘT giá trị và `switch` bên
/// dưới exhaustive.
enum _IntroState {
  /// Phần dẫn CỦA KHU NÀY đang phát → hai gạch, chạm = tạm dừng.
  playingThis,

  /// Phần dẫn của khu này là clip hiện tại nhưng đang dừng → tam giác, chạm =
  /// PHÁT TIẾP giữa chừng, KHÔNG quay về đầu.
  pausedThis,

  /// Mọi trường hợp khác (chưa nạp / đang phát clip khác) → tam giác, chạm =
  /// nạp phần dẫn từ đầu rồi phát.
  idle,
}

/// `.zplay` — dấu phát phần dẫn của cả khu, kèm thanh thời lượng.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// MỘT NÉT, KHÔNG PHẢI MỘT NÚT — và bản vẽ đã bác chính nó một lần ở đây
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Bản trước của màn này (và của bản vẽ) để đây là một đĩa tròn ĐẶC 56dp, biện
/// minh rằng nó là hành động chính. Lý lẽ đó sai ở gốc: `10-menu.css` ghi rõ
/// `.mcta` là "ngoại lệ DUY NHẤT còn nút có viền" trong cả app, nên thêm một
/// cái nút nữa làm câu ấy thành sai.
///
/// Thứ bậc phải do CỠ gánh, đúng luật chung: 20 cho một hiện vật trong bảng, 28
/// cho phần dẫn của cả khu, 34 cho nút chính ở trình phát màn 4c. Ba cỡ, một
/// hình dáng, không hộp nào.
class _ZoneIntro extends StatelessWidget {
  final int major;

  const _ZoneIntro({required this.major});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Selector<AudioProvider, _IntroState>(
      selector: (_, audio) {
        final c = audio.current;
        final isThisIntro = c != null && c.isIntro && c.zoneMajor == major;
        if (!isThisIntro) return _IntroState.idle;
        if (audio.isPlaying) return _IntroState.playingThis;
        if (audio.isPaused) return _IntroState.pausedThis;
        return _IntroState.idle;
      },
      builder: (context, state, _) {
        final playing = state == _IntroState.playingThis;

        // Nhấc ra khỏi cây widget: nó phải chạy ở HAI chỗ (ngón tay và screen
        // reader) và hai chỗ đó không được phép trôi khỏi nhau.
        void onTap() {
          final audio = context.read<AudioProvider>();
          switch (state) {
            case _IntroState.playingThis:
              // Không kèm showAudioFeedback: kết quả nghe thấy tức thì, snackbar
              // chỉ dành cho những ý định có thể bị chính sách chặn trong im lặng.
              audio.pause();
            case _IntroState.pausedThis:
              showAudioFeedback(context, audio.play());
            case _IntroState.idle:
              showAudioFeedback(context, audio.tapZoneIntro(major: major));
          }
        }

        return Row(
          children: [
            PlayMark(
              glyph: playing ? PlayGlyph.pause : PlayGlyph.play,
              size: PlayMark.zone,
              // Họ ON-IMAGE, không phải mực trang — xem doc [_ZoneHero].
              color: t.inkOnImage,
              semanticLabel: content.ui(playing
                  ? UiKeys.exhibitListIntroPause
                  : UiKeys.exhibitListIntroPlay),
              onTap: onTap,
            ),
            const SizedBox(width: AppSpace.x2),
            Expanded(child: _IntroTrack(major: major)),
          ],
        );
      },
    );
  }
}

/// Thanh thời lượng của phần dẫn.
///
/// ⚠ `StreamBuilder` RIÊNG, và nó phải nằm ở widget nhỏ nhất có thể.
/// `AudioProvider.position` nhích vài lần mỗi giây và CỐ Ý không đi qua
/// `notifyListeners()`. Đọc vị trí ở tầng trên rồi truyền xuống là kéo cả màn
/// vào nhịp đó — cả sáu ô ảnh sẽ dựng lại mỗi 100ms.
class _IntroTrack extends StatelessWidget {
  final int major;

  const _IntroTrack({required this.major});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final audio = context.watch<AudioProvider>();
    final c = audio.current;
    final isThisIntro = c != null && c.isIntro && c.zoneMajor == major;
    final total = audio.state.duration;

    // Chưa nạp phần dẫn của khu này ⇒ vạch rỗng. KHÔNG ẩn nó đi: cụm này giữ
    // chỗ của mình ở mọi trạng thái, và một vạch rỗng nói "phần dẫn có độ dài,
    // bạn chưa nghe" — còn một vạch biến mất thì đọc ra là app hỏng.
    if (!isThisIntro || total == null || total.inMilliseconds <= 0) {
      return ProgressTrack(
        value: 0,
        trackColor: t.inkOnImage.withValues(alpha: 0.28),
        fillColor: t.accentOnImage,
        showHead: false,
      );
    }

    return StreamBuilder<Duration>(
      stream: audio.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        return ProgressTrack(
          value: pos.inMilliseconds / total.inMilliseconds,
          // `--line` quá tối để nhìn ra khi nằm trên ảnh — bản vẽ đổi đúng chỗ
          // này và chỉ chỗ này.
          trackColor: t.inkOnImage.withValues(alpha: 0.28),
          fillColor: t.accentOnImage,
          showHead: false,
        );
      },
    );
  }
}

/// `.extile` — một hiện vật trong bảng ảnh.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// HAI TRẠNG THÁI, HAI VẬT LIỆU KHÁC NHAU — và đó là chủ đích
/// ═══════════════════════════════════════════════════════════════════════════
///
///   ĐANG PHÁT   dấu phát đổi sang màu nhấn. Cả bảng chỉ có MỘT ô như vậy, nên
///               một nét vàng ấm giữa những nét trắng mờ là đủ để mắt bắt —
///               không cần viền quanh ảnh, không cần đổi cả ô.
///   ĐÃ NGHE     ẢNH TỐI ĐI. Quyết định sản phẩm (14/08/2026) cho một câu hỏi
///               mà bản thiết kế tự để ngỏ — "mờ" nên nghĩa là *đã nghe* hay
///               *chưa ghé* — rồi chỉnh lại cách thể hiện (16/08/2026): làm mờ
///               trên nền giấy là kéo ảnh về phía trắng, cùng một lỗi với lớp
///               veil đã bị gỡ. Phủ đen thì giữ nguyên tương phản bên trong.
///
/// ⚠ MÓN NỢ ĐI KÈM QUYẾT ĐỊNH ĐÓ: màn Tổng kết dùng `ink-faint` cho khu CHƯA
/// ghé (`.zline.off .nm`). Sau quyết định này, hai màn dùng cùng một sắc độ cho
/// hai nghĩa ngược nhau. Ba thứ làm nhẹ bớt — chúng không bao giờ ở cùng một
/// màn; ở màn Tổng kết chữ mờ nằm trong một khối xổ có nhãn ghi rõ "N khu chưa
/// ghé" nên nghĩa do NHÃN gánh chứ không do sắc độ; và hai bên khác vật liệu
/// (ở kia là chữ, ở đây là ảnh). Vẫn phải chốt lại khi dựng màn Tổng kết.
///

/// Dấu phát KHÔNG mờ theo ảnh: nó là thứ nói "ô này còn bấm được", và một ô đã
/// nghe vẫn phải nghe lại được.
class _ExhibitTile extends StatelessWidget {
  final ExhibitInfo exhibit;
  final int major;
  final ContentProvider content;
  final bool heard;
  final VoidCallback onTap;

  const _ExhibitTile({
    super.key,
    required this.exhibit,
    required this.major,
    required this.content,
    required this.heard,
    required this.onTap,
  });

  /// Độ đậm của lớp phủ đen khi đã nghe. Xem chú giải tại chỗ dùng.
  static const double _heardDarken = 0.42;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(exhibit.name);
    final media = MediaQuery.of(context);

    // Ô rộng nửa màn trừ lề và khe. Tính từ dpr thay vì một hằng số: 168 đúng
    // trên 3x và over-decode 1.5× trên 2x — cùng LOẠI lỗi đã sửa ở Gate.
    final tileWidth =
        (media.size.width - AppSpace.gutter * 2 - AppSpace.x4) / 2;
    final decodeWidth = (tileWidth * media.devicePixelRatio).round();

    return Selector<AudioProvider, bool>(
      selector: (_, audio) {
        final c = audio.current;
        return audio.isPlaying &&
            c != null &&
            !c.isIntro &&
            c.zoneMajor == major &&
            c.exhibitMinor == exhibit.minor;
      },
      builder: (context, playing, _) {
        return Semantics(
          button: true,
          // Tên hiện vật KHÔNG hiện trên màn, nên nó phải có ở đây — nếu không,
          // người dùng screen reader gặp sáu ô "hình ảnh" không phân biệt được.
          // Đây là chỗ mà "bảng ảnh không chữ" phải trả giá, và giá đó trả bằng
          // semantics chứ không bằng cách thêm chữ lại vào ô.
          label: heard
              ? content.uif(UiKeys.exhibitListHeardSemantics, {'name': name})
              : name,
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: t.surface,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ĐÃ NGHE ⇒ TỐI ĐI, KHÔNG PHẢI MỜ ĐI.
                  //
                  // Bản trước dùng `Opacity` và nó sai cùng một lỗi với lớp
                  // veil đã bị gỡ khắp app: hoà độ đục xuống nền GIẤY là kéo
                  // ảnh về phía trắng, ảnh bạc màu và mất hết chi tiết ở vùng
                  // sáng. Một lớp đen phủ lên thì GIỮ NGUYÊN tương phản bên
                  // trong ảnh — vật vẫn nhìn ra hình dạng, nó chỉ lùi ra sau.
                  //
                  // `srcATop` chứ không phải `darken`: nó chỉ tô lên phần ảnh
                  // ĐÃ CÓ, nên vùng trong suốt của một ảnh PNG không bị bôi đen
                  // thành một khối vuông.
                  if (heard)
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        const Color(0xFF000000)
                            .withValues(alpha: _heardDarken),
                        BlendMode.srcATop,
                      ),
                      child: HeroImage(
                        filePath: content.imagePath(exhibit.thumbnailPath),
                        cacheWidth: decodeWidth,
                      ),
                    )
                  else
                    HeroImage(
                      filePath: content.imagePath(exhibit.thumbnailPath),
                      cacheWidth: decodeWidth,
                    ),
                  // `.extile .ph .pmark { left: 0; bottom: 0 }` — vùng chạm 44
                  // là padding trong suốt của chính PlayMark, nên nét rơi đúng
                  // 12 cách mép mà mắt không thấy hộp nào.
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: PlayMark(
                      glyph: playing ? PlayGlyph.pause : PlayGlyph.play,
                      size: PlayMark.grid,
                      color: playing
                          ? t.accentOnImage
                          : t.inkOnImage.withValues(alpha: 0.62),
                      semanticLabel: name,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Khu không khai hiện vật nào trong manifest.
///
/// KHÔNG PHẢI trạng thái "chưa nghe thấy beacon nào" — bảng này đọc thẳng từ
/// manifest, nên rỗng ở đây nghĩa là bảo tàng chưa nhập hiện vật cho khu, không
/// phải khách đang đứng sai chỗ.
///
/// Ngữ pháp đúng bằng ngữ pháp của Poster, thu nhỏ: vạch accent → tiêu đề serif
/// → câu sans. Không icon Material — đó là tiếng nói của Material, không phải
/// của app này.
class _ZoneEmpty extends StatelessWidget {
  const _ZoneEmpty();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Padding(
      // Lề ngang KHÔNG phải gutter — nó là lề đo CHIỀU DÀI DÒNG, không phải lề
      // lưới. x10 giữ dòng ở ~45–55 ký tự. Khối này căn giữa nên nó không ngồi
      // trên đường dọc nào của màn.
      padding: const EdgeInsets.fromLTRB(
          AppSpace.x10, AppSpace.x8, AppSpace.x10, AppSpace.x10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: AppSpace.x12, height: 2, color: t.accent),
          const SizedBox(height: AppSpace.x4),
          Text(
            content.ui(UiKeys.exhibitListEmptyTitle),
            textAlign: TextAlign.center,
            style: AppText.cardTitle.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSpace.x2),
          Text(
            content.ui(UiKeys.exhibitListEmptyBody),
            textAlign: TextAlign.center,
            style: AppText.guidance.copyWith(color: t.inkMuted),
          ),
        ],
      ),
    );
  }
}
