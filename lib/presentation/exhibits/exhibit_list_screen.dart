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
// TOKEN FAMILIES: only the 250px hero is ON the image (inkOnImage /
// mutedOnImage — fixed across themes, because the photograph doesn't brighten
// in light mode). Everything below it — hint bar, rows, empty state — sits on
// `surface` and follows the theme. The 40x40 thumbnail is an image, but the row
// text sits BESIDE it, not on it: that row is surface. Easiest place to slip.

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
      body: Column(
        children: [
          _ZoneHero(zone: zone, content: content),
          // Live subset: rebuilds only when the set of heard minors changes.
          Expanded(
            child: StreamBuilder<Set<int>>(
              initialData: _presence.currentPresent(widget.major),
              stream: _presenceStream,
              builder: (context, snap) {
                final present = snap.data ?? const <int>{};

                // Filter to heard minors, but keep MANIFEST ORDER (no ranking).
                final visible = <ExhibitInfo>[
                  for (final e in zone.exhibits)
                    if (present.contains(e.minor)) e,
                ];

                if (visible.isEmpty) return const _NoneNearby();

                return Column(
                  children: [
                    const _HintBar(text: 'Chọn theo số ghi trên nhãn'),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        itemCount: visible.length,
                        itemBuilder: (context, i) => _StopRow(
                          exhibit: visible[i],
                          content: content,
                          onTap: () => _openExhibit(context, visible[i]),
                        ),
                      ),
                    ),
                  ],
                );
              },
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

/// 250px hero: zone image + heroVeil + back button + serif title + meta.
/// Everything in here is ON the image.
class _ZoneHero extends StatelessWidget {
  final ZoneInfo zone;
  final ContentProvider content;

  const _ZoneHero({required this.zone, required this.content});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(zone.name);

    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HeroImage(
            filePath: content.imagePath(zone.heroImagePath),
            veil: t.heroVeil,
            cacheWidth: 900,
          ),
          // Back button, safe-area top-left.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 10,
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
                    child: Icon(Icons.chevron_left,
                        color: t.inkOnImage, size: 26),
                  ),
                ),
              ),
            ),
          ),
          // Title + meta, bottom-left. The meta is intentionally STATIC (no
          // live count) — a number that changed as you walked would itself
          // flicker; the list below already tells you what's near.
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: AppText.heroTitle.copyWith(color: t.inkOnImage)),
                const SizedBox(height: 5),
                Text(
                  'Hiện vật quanh bạn · chọn theo số trên nhãn',
                  style: AppText.meta.copyWith(color: t.mutedOnImage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase hint bar. Same fill as the visitor CTA, but static — a label.
class _HintBar extends StatelessWidget {
  final String text;
  const _HintBar({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: t.ctaFill,
        borderRadius: t.sharpAll,
      ),
      alignment: Alignment.center,
      child: Text(text.toUpperCase(),
          style: AppText.button.copyWith(color: t.ctaLabel)),
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

/// One .stop row: circled MINOR + 40x40 thumb + serif name + grey meta.
/// The thumbnail is an image, but the text sits BESIDE it: this row is surface.
class _StopRow extends StatelessWidget {
  final ExhibitInfo exhibit;
  final ContentProvider content;
  final VoidCallback onTap;

  const _StopRow({
    required this.exhibit,
    required this.content,
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

    return Semantics(
      button: true,
      label: 'Hiện vật số ${exhibit.minor}, $name',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                // Circled minor — the number on the physical label.
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.ink),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${exhibit.minor}',
                    style: AppText.meta.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                // 40x40 thumbnail.
                ClipRRect(
                  borderRadius: t.sharpAll,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: HeroImage(
                      filePath: content.imagePath(exhibit.thumbnailPath),
                      cacheWidth: 120,
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
                          // ellipsises the exhibit's name away. Losing the name
                          // is worse than spending 16px.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.stopName.copyWith(color: t.ink)),
                      const SizedBox(height: 2),
                      Text(_metaLine(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.stopMeta.copyWith(color: t.inkMuted)),
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
