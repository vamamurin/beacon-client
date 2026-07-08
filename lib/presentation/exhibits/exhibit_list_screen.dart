// Destination: lib/presentation/exhibits/exhibit_list_screen.dart
//
// Screen 3 — the exhibit list of ONE zone. Matches giaodien.html screen 3:
// 250px tour-hero (image + heroVeil + back button + serif h2 + meta), a white
// hint bar "Chọn theo số ghi trên nhãn", then .stop rows: 26px circled number
// + 40x40 thumb + serif name + grey meta, hairline separators.
//
// The circled number is the exhibit's MINOR — the number physically printed on
// the label next to the display case (mockup note: "Danh sách hiện vật
// (minor)") — NOT the tour index. Visitors match what they see on the wall.
//
// FREEZE-BY-DESIGN: this screen does NOT watch ZoneProvider. It takes a fixed
// `major` from route arguments and reads the ZoneInfo from the repository once.
// If the arbiter switches zones underneath (visitor's feet moved), this screen
// stays exactly as-is — the confirmed Phase-1 rule. Only the Zone screen
// (screen 2) follows the arbiter.
//
// Tapping a row = rule 2a: interrupt + play that exhibit (tapExhibit), then
// open its detail screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

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
          const _HintBar(text: 'Chọn theo số ghi trên nhãn'),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              itemCount: zone.exhibits.length,
              itemBuilder: (context, i) => _StopRow(
                exhibit: zone.exhibits[i],
                lang: lang,
                graph: graph,
                onTap: () => _openExhibit(context, zone.exhibits[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openExhibit(BuildContext context, ExhibitInfo exhibit) {
    // Rule 2a: a tap is an explicit request — interrupt & play (or load-for-
    // transcript in reading mode; the controller decides).
    context.read<AudioProvider>().tapExhibit(exhibit.minor);
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
    final count = zone.exhibits.length;

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
          // Title + meta, bottom-left.
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
                Text(
                  '$count hiện vật · chọn theo số trên nhãn',
                  style: const TextStyle(
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