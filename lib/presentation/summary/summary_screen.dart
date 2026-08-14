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
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/tour_progress_provider.dart';
import 'package:beacon_client/presentation/summary/feedback_panel.dart';
import 'package:beacon_client/presentation/summary/tour_qr.dart';
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/theme/app_motion.dart';
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
      body: Column(
        children: [
          // Thanh ĐỤC: phía sau là nền trang, không có ảnh hero nào. Nút ‹ là
          // đường lui về tour — bản vẽ không còn nút "Quay lại tham quan" riêng
          // ở chân trang, vì hai đường lui cho cùng một việc là thừa một.
          MuseumTopBar(
            title: content.ui(UiKeys.summaryTitle),
            leading: TopBarLeading.back,
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverList(
                  delegate: SliverChildListDelegate([
                    if (progress.isUntouched)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(AppSpace.gutter,
                            AppSpace.x6, AppSpace.gutter, 0),
                        child: _EmptyState(),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.gutter,
                            AppSpace.x5, AppSpace.gutter, 0),
                        child: _Stats(progress: progress, elapsed: elapsed),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.gutter,
                            AppSpace.x5, AppSpace.gutter, 0),
                        child: _ZoneLedger(progress: progress),
                      ),
                    ],

                    if (cfg.showFeedback)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                            AppSpace.gutter, AppSpace.x8, AppSpace.gutter, 0),
                        child: FeedbackPanel(),
                      ),

                    if (cfg.showQr)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.gutter,
                            AppSpace.x8, AppSpace.gutter, 0),
                        child: TourQrCard(progress: progress, elapsed: elapsed),
                      ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter, AppSpace.x8, AppSpace.gutter, 0),
                      child: Text(
                        content.textOrNull(cfg.closing) ??
                            content.ui(UiKeys.summaryClosingFallback),
                        style: AppText.lede.copyWith(color: t.inkMuted),
                      ),
                    ),

                    // `.cta` — KHỐI ĐẶC DUY NHẤT CÒN LẠI TRONG CẢ APP, và nó
                    // xuất hiện đúng một lần: ở hành động không quay lui được.
                    // Vì không có gì khác cạnh tranh, sức nặng của nó CHÍNH LÀ
                    // ý nghĩa — đây là dấu chấm hết.
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.gutter,
                        AppSpace.x10,
                        AppSpace.gutter,
                        AppSpace.x12 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: _PrimaryButton(
                        label: content.ui(UiKeys.summaryEndCta),
                        onPressed: _endTour,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
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

/// `.stats` — BA CON SỐ, không phải ba ô dashboard.
///
/// Không nền, không bo góc: chỉ hai vạch dọc chia cột và một vạch tóc dưới
/// chân. Không cần vạch trên, vì phía trên đã là thanh điều hướng.
class _Stats extends StatelessWidget {
  final TourProgress progress;
  final Duration elapsed;

  const _Stats({required this.progress, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatTile(
                label: content.ui(UiKeys.summaryStatZones),
                value: '${progress.visitedMajors.length}',
                // MẪU SỐ NÓI QUY MÔ mà không cần một câu nào: khách thấy ngay
                // mình mới đi một phần ba bảo tàng. Nửa cỡ tử số để tử số vẫn
                // là thứ đọc trước.
                scale: '/${progress.totalZones}',
              ),
            ),
            _StatTile(
              label: content.ui(UiKeys.summaryStatExhibits),
              value: '${progress.heardExhibits.length}',
              divider: true,
            ),
            _StatTile(
              label: content.ui(UiKeys.summaryStatDuration),
              value: '${elapsed.inMinutes}',
              divider: true,
            ),
          ].map((w) => w is Expanded ? w : Expanded(child: w)).toList(),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? scale;
  final bool divider;

  const _StatTile({
    required this.label,
    required this.value,
    this.scale,
    this.divider = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final spoken = scale == null ? value : '$value$scale';

    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(left: BorderSide(color: t.line)))
          : null,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.x3, AppSpace.x2, AppSpace.x3, AppSpace.x6),
      child: Semantics(
        // Con số và nhãn của nó là MỘT phát biểu. Để screen reader đọc rời ra
        // thì người dùng nghe "9/26" mà không biết 9 cái gì.
        label: content.uif(
            UiKeys.summaryStatSemantics, {'label': label, 'value': spoken}),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                text: value,
                style: AppText.statNumber.copyWith(color: t.ink),
                children: [
                  if (scale != null)
                    TextSpan(
                      text: scale,
                      style: AppText.statNumberScale
                          .copyWith(color: t.inkFaint),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x2),
            // Bản vẽ ghi 9px cho nhãn này. GIỮ 11 của [AppText.kicker]: cỡ chữ
            // phụ đã được nâng một lần vì lý do a11y (khách bảo tàng lệch về
            // người lớn tuổi), và hạ riêng một chỗ xuống dưới sàn ấy là mở lại
            // đúng cái đã đóng.
            Text(label.toUpperCase(),
                style: AppText.kicker.copyWith(color: t.inkFaint)),
          ],
        ),
      ),
    );
  }
}

/// `.zline` + `.zrest` — SỔ HÀNH TRÌNH.
///
/// Khu ĐÃ GHÉ bày thẳng, không tiêu đề, không đường kẻ giữa các dòng: tên bên
/// trái và cột phải đã đủ dựng nên hai cột cho mắt bám, đúng cách một mục lục
/// sách hoạt động. Có mặt ở đây nghĩa là đã đi qua.
///
/// Khu CHƯA GHÉ nằm trong một khối xổ, ĐÓNG SẴN: bản ghi của một chuyến đi
/// không nên mở đầu bằng thứ chưa làm — nhưng ai muốn xem thì chỉ cách một cú
/// chạm. Nó vừa là bản đồ của những gì còn bỏ lỡ (lý do thật để quay lại), vừa
/// là câu trả lời cho "tôi đã xem hết chưa".
///
/// ═══════════════════════════════════════════════════════════════════════════
/// KHU CHƯA GHÉ KHÔNG BỊ LÀM MỜ, VÀ ĐÓ LÀ MỘT LẦN ĐI KHỎI BẢN VẼ
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Bản vẽ ghi `.zline.off .nm { color: ink-faint }` — tên khu chưa ghé thì mờ
/// đi. Ở app này quy ước đã chốt theo hướng NGƯỢC LẠI: **mờ = ĐÃ NGHE**, dùng ở
/// bảng ảnh màn danh sách hiện vật. Giữ cả hai là để một sắc độ mang hai nghĩa
/// trái nhau trong cùng một chuyến đi, và khách không có cách nào biết mình
/// đang đọc nghĩa nào.
///
/// Nên ở đây tên giữ nguyên mực `ink`, và NGHĨA DO NHÃN GÁNH: dòng "N khu chưa
/// ghé" trên nắp khối xổ đã nói ra điều đó bằng chữ, rõ hơn bất kỳ sắc độ nào.
/// Bản vẽ vốn cũng đã đặt cái nhãn ấy ở đó — lớp mờ chỉ nói lại cùng một điều
/// lần thứ hai, và nó là lớp phải bỏ.
class _ZoneLedger extends StatefulWidget {
  final TourProgress progress;

  const _ZoneLedger({required this.progress});

  @override
  State<_ZoneLedger> createState() => _ZoneLedgerState();
}

class _ZoneLedgerState extends State<_ZoneLedger> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final zones = content.allZones;
    if (zones.isEmpty) return const SizedBox.shrink();

    final visited = [
      for (final z in zones)
        if (widget.progress.visitedMajors.contains(z.major)) z,
    ];
    final missed = [
      for (final z in zones)
        if (!widget.progress.visitedMajors.contains(z.major)) z,
    ];

    final missedLabel =
        content.uif(UiKeys.summaryZonesMissed, {'n': '${missed.length}'});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final z in visited) _ZoneLine(name: content.text(z.name)),
        if (missed.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(top: AppSpace.x4),
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: t.line))),
            child: Semantics(
              button: true,
              expanded: _open,
              label: missedLabel,
              excludeSemantics: true,
              onTap: _toggle,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: _toggle,
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: t.ink.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.x5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(missedLabel,
                              style: AppText.lede.copyWith(color: t.inkFaint)),
                        ),
                        // Dấu › QUAY 90° khi mở — cùng một dấu, cùng một nghĩa
                        // "còn nữa ở phía kia", chỉ đổi hướng. Không sinh một
                        // glyph thứ hai chỉ để nói trạng thái mở.
                        AnimatedRotation(
                          turns: _open ? 0.25 : 0,
                          duration: AppMotion.base,
                          curve: AppMotion.enter,
                          child: AppChevron(color: t.inkFaint, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final z in missed) _ZoneLine(name: content.text(z.name)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  void _toggle() => setState(() => _open = !_open);
}

/// Một dòng của sổ hành trình.
///
/// ⚠ CỘT PHÚT CỦA BẢN VẼ CHƯA CÓ DỮ LIỆU, và cột này CỐ Ý để trống. `.zline
/// .zt` in số phút ở mỗi khu ("12′"), nhưng `TourProgress` chỉ ghi tổng thời
/// gian chuyến đi chứ không ghi thời gian TỪNG KHU — đó là hạng mục B7 ở tầng
/// service. Điền một con số ước lượng vào đây thì tệ hơn hẳn để trống: một sổ
/// hành trình nói sai số phút là một bản ghi sai, không phải một bản ghi thiếu.
class _ZoneLine extends StatelessWidget {
  final String name;

  const _ZoneLine({required this.name});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
      child: Text(name, style: AppText.cardTitle.copyWith(color: t.ink)),
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
