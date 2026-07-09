// Destination: lib/presentation/exhibits/exhibit_list_screen.dart
//
// Screen 3 — the exhibit list of ONE zone. Matches giaodien.html screen 3:
// 250px tour-hero (image + heroVeil + back button + serif h2 + meta), a white
// hint bar "Chọn theo số ghi trên nhãn", then .stop rows: 26px circled number
// + 40x40 thumb + serif name + grey meta, hairline separators.
//
// PRESENCE-DRIVEN LIST (Phase-4 change, confirmed with product): the list shows
// ONLY exhibits whose minor beacon is currently being heard over the air — not
// the full manifest. A visitor at the front of the room hears the nearest
// exhibits; the far ones simply aren't in the list until they walk closer.
// Consequence accepted by product: a dead-battery beacon removes its exhibit
// from the list (the manifest is no longer the visibility source, only the
// CONTENT source — name/thumb/audio still come from it).
//
// ZONE STILL FROZEN: the `major` comes from route arguments and the ZoneInfo is
// read from the repository once. What's LIVE is only the SUBSET of that zone's
// exhibits shown. If the arbiter switches zones underneath, this screen keeps
// its frozen `major` (Phase-1 rule); only screen 2 follows the arbiter.
//
// NO RANKING / NO FLICKER: rows are NOT sorted by signal strength (no distance
// heuristic here, per product). Visible rows keep MANIFEST ORDER, so nothing
// reorders as RSSI wobbles. The present set arrives already debounced and
// change-gated from ExhibitPresenceTracker (appears instantly, disappears only
// after sustained silence), so the list doesn't blink step-to-step.
//
// Tapping a row = rule 2a: interrupt + play that exhibit (tapExhibit), then
// open its detail screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/audio_feedback.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';

class ExhibitListScreen extends StatelessWidget {
  /// Fixed zone identity from route arguments — the freeze anchor.
  final int major;

  const ExhibitListScreen({super.key, required this.major});

  @override
  Widget build(BuildContext context) {
    final graph = context.read<AppGraph>();
    final zone = graph.repository.zoneByMajor(major);
    final lang = graph.repository.config?.fallbackLanguage ?? 'vi';

    if (zone == null) {
      // Unknown major (stale route after a bundle swap) — graceful, not a crash.
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Không tìm thấy khu trưng bày',
              style: AppText.meta.copyWith(color: AppColors.muted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _ZoneHero(zone: zone, lang: lang, graph: graph),
          // Live subset: rebuilds only when the set of heard minors changes.
          Expanded(
            child: StreamBuilder<Set<int>>(
              initialData: graph.exhibitPresence.currentPresent(major),
              stream: graph.exhibitPresence.watchMajor(major),
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
                          lang: lang,
                          graph: graph,
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

/// 250px hero: zone image + heroVeil + back button + serif title + meta.
class _ZoneHero extends StatelessWidget {
  final ZoneInfo zone;
  final String lang;
  final AppGraph graph;
  const _ZoneHero({required this.zone, required this.lang, required this.graph});

  @override
  Widget build(BuildContext context) {
    final name = zone.name.resolve(lang, lang);

    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HeroImage(
            filePath: graph.imagePathResolver(zone.heroImagePath),
            veil: AppColors.heroVeil,
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
                color: const Color(0x66000000),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.chevron_left,
                        color: AppColors.white, size: 26),
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
                Text(name, style: AppText.heroTitle),
                const SizedBox(height: 5),
                const Text(
                  'Hiện vật quanh bạn · chọn theo số trên nhãn',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontWeight: FontWeight.w300,
                    fontSize: 11,
                    color: Color(0xFFD0D0D0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White uppercase hint bar (same visual as .startbtn, but static — a label).
class _HintBar extends StatelessWidget {
  final String text;
  const _HintBar({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Text(text.toUpperCase(), style: AppText.button),
    );
  }
}

/// Shown when the frozen zone currently has no exhibit beacon in range. Not an
/// error — a direction: walk up to a display case and it appears in the list.
class _NoneNearby extends StatelessWidget {
  const _NoneNearby();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore, color: AppColors.greyDark, size: 34),
            const SizedBox(height: 16),
            Text('CHƯA CÓ HIỆN VẬT NÀO Ở GẦN'.toUpperCase(),
                style: AppText.kicker.copyWith(color: AppColors.white)),
            const SizedBox(height: 8),
            const Text(
              'Hãy tiến lại gần một tủ trưng bày. Hiện vật sẽ tự xuất hiện '
              'trong danh sách khi bạn tới đủ gần.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontWeight: FontWeight.w300,
                fontSize: 12,
                height: 1.5,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One .stop row: circled MINOR + 40x40 thumb + serif name + grey meta.
class _StopRow extends StatelessWidget {
  final ExhibitInfo exhibit;
  final String lang;
  final AppGraph graph;
  final VoidCallback onTap;

  const _StopRow({
    required this.exhibit,
    required this.lang,
    required this.graph,
    required this.onTap,
  });

  /// Meta line: spec values joined " · " (matches the mockup's "Liên Xô ·
  /// 1944 · 7.62mm"); falls back to the one-line summary when no specs.
  String _metaLine() {
    if (exhibit.specs.isNotEmpty) {
      return exhibit.specs
          .map((s) => s.value.resolve(lang, lang))
          .join(' · ');
    }
    return exhibit.summary.resolve(lang, lang);
  }

  @override
  Widget build(BuildContext context) {
    final name = exhibit.name.resolve(lang, lang);

    return Semantics(
      button: true,
      label: 'Hiện vật số ${exhibit.minor}, $name',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                // Circled minor — the number on the physical label.
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${exhibit.minor}',
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                // 40x40 thumbnail.
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: HeroImage(
                      filePath:
                          graph.imagePathResolver(exhibit.thumbnailPath),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.stopName),
                      const SizedBox(height: 2),
                      Text(_metaLine(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.stopMeta),
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