// Destination: lib/presentation/summary/summary_screen.dart
//
// MÀN TỔNG KẾT CHUYẾN ĐI.
//
// ═══════════════════════════════════════════════════════════════════════════
// MÀN NÀY NẰM TRONG PHASE `touring` — ĐỌC TRƯỚC KHI SỬA
// ═══════════════════════════════════════════════════════════════════════════
//
// Nó KHÔNG phải màn hiện ra sau khi phiên kết thúc. Nó là màn XÁC NHẬN: khách
// xem lại chuyến đi, rồi tự quyết định kết thúc hay quay lại. Phiên chỉ thật sự
// đóng khi họ bấm "Kết thúc chuyến đi".
//
// Ba thứ có được nhờ đặt ở đây, và cả ba đều mất nếu chuyển nó ra sau endTour():
//
//   1. CÓ ĐƯỜNG LUI. Kết thúc là thao tác KHÔNG hoàn tác được — nó dừng audio
//      và đóng phiên. Bấm nhầm một nút không hoàn tác được là mất cả buổi tham
//      quan của khách.
//   2. ĐÁNH GIÁ NỐI ĐƯỢC VỚI TOUR. AnalyticsRecorder xoá session id ngay khi
//      rời `touring` (xem doc [FeedbackGiven]).
//   3. SỐ LIỆU CÒN SỐNG. TourProgressService chỉ dọn ở ĐẦU tour sau, nhưng mẫu
//      số và mốc thời gian đọc tự nhiên nhất khi phiên còn chạy.
//
// Màn TIẾP THEO — "Cảm ơn / xin gửi lại máy" — thì ngược lại, nằm hẳn sau khi
// phiên đóng, và nó có một phase riêng ([SessionPhase.farewell]) chứ không phải
// một cờ ở tầng điều hướng.
//
// Đổi lại, hai thứ vẫn "sống" trong lúc khách đọc màn này và phải được xử lý:
//   • ÂM THANH — tạm dừng lúc mở, phát lại nếu khách quay về tour (chỉ khi
//     trước đó ĐANG phát: xem [_wasPlaying]).
//   • BANNER ĐỔI KHU — bị chặn ở root (MuseumApp), vì nó nổi trên MỌI màn hình
//     và ở đây nó sẽ kéo khách sang khu khác giữa lúc đang đọc tổng kết.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/tour_progress.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/tour_progress_provider.dart';
import 'package:beacon_client/presentation/summary/feedback_panel.dart';
import 'package:beacon_client/presentation/summary/tour_qr.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  /// Thời điểm mở màn — mốc để tính thời lượng chuyến đi.
  ///
  /// ĐÓNG BĂNG CÓ CHỦ ĐÍCH: một con số nhảy từng giây trong lúc khách đọc "bạn
  /// đã đi 47 phút" biến bản tổng kết thành cái đồng hồ bấm giờ. Chuyến đi kết
  /// thúc ở khoảnh khắc họ mở màn này.
  late final DateTime _shownAt = DateTime.now();

  /// Có đang phát tiếng lúc mở màn không. Chỉ phát lại nếu ĐÚNG — khách đã tự
  /// tạm dừng trước đó thì "quay lại tham quan" không được bật tiếng lên hộ họ.
  bool _wasPlaying = false;

  /// Đã bấm kết thúc: chặn nhánh phát-lại trong [dispose], vì lúc đó phiên đã
  /// dọn và ý định của khách là im lặng.
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioProvider>();
    _wasPlaying = audio.isPlaying;
    if (_wasPlaying) audio.pause();
  }

  @override
  void dispose() {
    // Đi qua đây với MỌI đường rời màn: nút "Quay lại", cử chỉ back của hệ điều
    // hành, và cả khi root dựng lại stack vì phiên kết thúc theo đường khác
    // (về bàn / hết pin / im lặng). Một chỗ, không ba chỗ nhớ gọi.
    if (_wasPlaying && !_ended) {
      // Không dùng context ở đây (widget đang bị gỡ): đọc provider TRƯỚC.
      _resumeAudio?.call();
    }
    super.dispose();
  }

  /// Được gán ở [didChangeDependencies] để [dispose] không phải chạm context.
  VoidCallback? _resumeAudio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audio = context.read<AudioProvider>();
    _resumeAudio = () => audio.play();
  }

  void _endTour() {
    setState(() => _ended = true);
    // MỘT lời gọi, không có bước phối hợp nào khác: phiên chuyển sang
    // `SessionPhase.farewell`, và root ánh xạ phase đó sang màn Cảm ơn như nó
    // ánh xạ mọi phase khác. Không có cờ nào phải bật trước, và cũng không có
    // thứ tự nào để làm sai.
    context.read<SessionProvider>().endTourWithFarewell();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final progress = context.watch<TourProgressProvider>().progress;
    final elapsed = progress.elapsedAt(_shownAt);
    final cfg = content.summary;

    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: CustomScrollView(
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
                  Text(content.ui(UiKeys.summaryTitle),
                      style: AppText.heroTitle.copyWith(color: t.ink)),
                  const SizedBox(height: AppSpace.x3),
                  Text(content.ui(UiKeys.summarySubtitle),
                      style: AppText.lede.copyWith(color: t.inkMuted)),
                  const SizedBox(height: AppSpace.x6),

                  if (progress.isUntouched)
                    const _EmptyState()
                  else ...[
                    _Stats(progress: progress, elapsed: elapsed),
                    const SizedBox(height: AppSpace.x6),
                    _ZoneChecklist(progress: progress),
                  ],

                  if (cfg.showFeedback) ...[
                    const SizedBox(height: AppSpace.x6),
                    const FeedbackPanel(),
                  ],

                  if (cfg.showQr) ...[
                    const SizedBox(height: AppSpace.x6),
                    TourQrCard(progress: progress, elapsed: elapsed),
                  ],

                  const SizedBox(height: AppSpace.x6),
                  Text(
                    content.textOrNull(cfg.closing) ??
                        content.ui(UiKeys.summaryClosingFallback),
                    style: AppText.lede.copyWith(color: t.inkMuted),
                  ),

                  const SizedBox(height: AppSpace.x8),
                  _SecondaryButton(
                    label: content.ui(UiKeys.summaryContinueCta),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpace.x3),
                  _PrimaryButton(
                    label: content.ui(UiKeys.summaryEndCta),
                    onPressed: _endTour,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khách bấm Kết thúc khi chưa đi đâu cả. Không hiện "0/6 khu, 0 phút" — một
/// bảng số 0 đọc như một lời trách.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    return Container(
      decoration:
          BoxDecoration(color: t.surfaceRaised, borderRadius: t.sharpAll),
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content.ui(UiKeys.summaryEmptyTitle),
              style: AppText.cardTitle.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.x2),
          Text(content.ui(UiKeys.summaryEmptyBody),
              style: AppText.body.copyWith(color: t.inkMuted)),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final TourProgress progress;
  final Duration elapsed;

  const _Stats({required this.progress, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();

    String fraction(int a, int b) =>
        content.uif(UiKeys.summaryStatFraction, {'a': '$a', 'b': '$b'});

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatTile(
            label: content.ui(UiKeys.summaryStatZones),
            value: fraction(progress.visitedMajors.length, progress.totalZones),
          ),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: _StatTile(
            label: content.ui(UiKeys.summaryStatExhibits),
            value: fraction(
                progress.heardExhibits.length, progress.totalExhibits),
          ),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: _StatTile(
            label: content.ui(UiKeys.summaryStatDuration),
            value: content.uif(
                UiKeys.summaryStatMinutes, {'m': '${elapsed.inMinutes}'}),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    return Semantics(
      // Con số và nhãn của nó là MỘT phát biểu. Để screen reader đọc rời ra
      // thì người dùng nghe "4 trên 6" mà không biết 4 cái gì.
      label: content
          .uif(UiKeys.summaryStatSemantics, {'label': label, 'value': value}),
      excludeSemantics: true,
      child: Container(
        decoration:
            BoxDecoration(color: t.surfaceRaised, borderRadius: t.sharpAll),
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppText.cardTitle.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.x1),
            Text(label, style: AppText.meta.copyWith(color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// Danh sách khu kèm dấu đã ghé / chưa ghé.
///
/// CÓ HIỆN CẢ KHU CHƯA GHÉ, và đó là quyết định có cân nhắc: nó vừa là bản đồ
/// của những gì còn bỏ lỡ (lý do thật để bấm "Quay lại tham quan"), vừa là câu
/// trả lời cho "tôi đã xem hết chưa". Một danh sách chỉ có khu đã đi thì không
/// trả lời được câu nào trong hai câu đó.
class _ZoneChecklist extends StatelessWidget {
  final TourProgress progress;

  const _ZoneChecklist({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final zones = content.allZones;
    if (zones.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(content.ui(UiKeys.summaryZonesHeader).toUpperCase(),
            style: AppText.kicker.copyWith(color: t.inkFaint)),
        const SizedBox(height: AppSpace.x3),
        for (final z in zones)
          _ZoneRow(
            zone: z,
            visited: progress.visitedMajors.contains(z.major),
          ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final ZoneInfo zone;
  final bool visited;

  const _ZoneRow({required this.zone, required this.visited});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final name = content.text(zone.name);
    final badge = content
        .ui(visited ? UiKeys.summaryZoneVisited : UiKeys.summaryZoneMissed);

    return Semantics(
      label: '$name. $badge',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x3),
        child: Row(
          children: [
            Icon(
              visited ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: visited ? t.accent : t.inkFaint,
            ),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: Text(name,
                  style: AppText.body
                      .copyWith(color: visited ? t.ink : t.inkMuted)),
            ),
            const SizedBox(width: AppSpace.x3),
            Text(badge, style: AppText.meta.copyWith(color: t.inkFaint)),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: t.ctaFill,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: t.sharpAll,
          child: Container(
            height: AppSpace.ctaHeight,
            alignment: Alignment.center,
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: t.ctaLabel)),
          ),
        ),
      ),
    );
  }
}

/// Nút viền — "Quay lại tham quan".
///
/// Đứng TRÊN nút kết thúc và nhẹ hơn về trọng lượng thị giác, nhưng vẫn là một
/// nút đầy đủ chiều cao chứ không phải một dòng chữ: đây là đường lui khỏi một
/// thao tác không hoàn tác được, nó phải dễ bấm ít nhất bằng thao tác kia.
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: t.sharpAll,
          child: Container(
            height: AppSpace.ctaHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: t.outline),
              borderRadius: t.sharpAll,
            ),
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: t.ink)),
          ),
        ),
      ),
    );
  }
}
