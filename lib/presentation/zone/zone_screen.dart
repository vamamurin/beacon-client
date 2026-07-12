// Destination: lib/presentation/zone/zone_screen.dart
//
// Screen 2 — the zone ranking. Shows the arbiter-confirmed zone pinned first
// ("Đang ở đây"), then every other audible zone nearest-first, each a 150px
// .tourcard. Radar/standby appears ONLY when nothing is heard at all.
//
// Two tiers, by design (C1/C3): the PINNED row is the audio tier (arbiter's
// engaged zone, drives narration); the numbered rows below are the DISPLAY tier
// (NearbyZonesTracker, hysteresis-stable, ordered by estimated distance). Tapping
// ANY card opens that zone's exhibit list — but only the pinned zone is playing.
//
// Cards auto-swap/reorder as presence changes; the tracker's change-gating means
// this rebuilds on real order changes, not 1 Hz. An optional debug distance
// readout (staff toggle in Settings) shows metres per row for field tuning.
//
// TOKEN FAMILIES: the card's title/meta sit ON the hero image -> inkOnImage /
// mutedOnImage (fixed, don't follow theme). Header/radar sit on `surface` ->
// ink / inkFaint.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

class ZoneScreen extends StatelessWidget {
  const ZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final zp = context.watch<ZoneProvider>();
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: zp.isStandby ? const _RadarStandby() : const _ZoneRankingView(),
      ),
    );
  }
}

/// Header + the ranked list of zone cards (pinned current + numbered nearby).
class _ZoneRankingView extends StatelessWidget {
  const _ZoneRankingView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final rows = context.watch<ZoneProvider>().rankedZones;
    final showDistance =
        context.watch<SettingsProvider>().showDistanceDebug;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Text('Khu vực quanh bạn', style: AppText.sheetTitle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Text(
            'Ứng dụng nhận diện các khu trưng bày gần bạn qua sóng beacon.',
            style: AppText.sheetSub.copyWith(color: t.inkFaint),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 0),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              // Numbered from 2 for non-current rows; the pinned current row
              // shows no number (its label is "Đang ở đây").
              final rank = row.isCurrent ? null : i + 1;
              return _ZoneCard(
                key: ValueKey(row.zone.major),
                row: row,
                rank: rank,
                content: content,
                showDistance: showDistance,
                onTap: () => Navigator.of(context).pushNamed(
                    AppRouter.exhibitListRoute,
                    arguments: row.zone.major),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single .tourcard (150px, veil, serif title, meta line). Renders both the
/// pinned current zone ("Đang ở đây") and numbered nearby zones — same size,
/// only the meta line differs (confirmed design).
class _ZoneCard extends StatelessWidget {
  final RankedZone row;
  final int? rank; // null for the pinned current row
  final ContentProvider content;
  final bool showDistance;
  final VoidCallback onTap;

  const _ZoneCard({
    super.key,
    required this.row,
    required this.rank,
    required this.content,
    required this.showDistance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(row.zone.name);
    final count = row.zone.exhibits.length;

    // Meta line: current -> "Đang ở đây"; nearby -> just the exhibit count.
    // Optional debug distance appended for staff field-tuning.
    final base = row.isCurrent ? 'Đang ở đây' : '$count hiện vật';
    final dist = (showDistance && row.distanceMeters != null)
        ? ' · ~${row.distanceMeters!.toStringAsFixed(1)} m'
        : '';
    final meta = row.isCurrent ? '$count hiện vật · $base$dist' : '$base$dist';

    final semantics = row.isCurrent
        ? 'Khu $name, $count hiện vật, bạn đang ở đây'
        : 'Khu $name, $count hiện vật, gần bạn thứ $rank';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Semantics(
        button: true,
        label: semantics,
        child: Material(
          color: Colors.transparent,
          borderRadius: t.sharpAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: t.sharpAll,
            child: SizedBox(
              height: 150,
              child: ClipRRect(
                borderRadius: t.sharpAll,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HeroImage(
                      filePath: content.imagePath(row.zone.heroImagePath),
                      veil: t.tourCardVeil,
                      cacheWidth: 800,
                    ),
                    // Rank badge (numbered nearby rows only), top-left.
                    if (rank != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _RankBadge(rank: rank!, tokens: t),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: AppText.cardTitle
                                .copyWith(color: t.inkOnImage),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            style:
                                AppText.meta.copyWith(color: t.mutedOnImage),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular rank number sitting on the hero image.
class _RankBadge extends StatelessWidget {
  final int rank;
  final MuseumTokens tokens;
  const _RankBadge({required this.rank, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Text('$rank',
          style: AppText.meta.copyWith(color: tokens.inkOnImage)),
    );
  }
}

/// Standby: no zone confirmed. A calm "scanning" state (corridor between zones).
class _RadarStandby extends StatefulWidget {
  const _RadarStandby();

  @override
  State<_RadarStandby> createState() => _RadarStandbyState();
}

class _RadarStandbyState extends State<_RadarStandby>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Simple concentric pulse — calm, not attention-grabbing.
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => CustomPaint(
              size: const Size(120, 120),
              // A CustomPainter has no BuildContext, so the colour must be
              // handed in. See _RadarPainter.shouldRepaint.
              painter: _RadarPainter(_pulse.value, t.ink),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'ĐANG QUÉT KHÔNG GIAN',
            style: AppText.kicker.copyWith(color: t.ink),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Hãy tiến vào khu trưng bày để bắt đầu nghe thuyết minh.',
              textAlign: TextAlign.center,
              style: AppText.guidance.copyWith(color: t.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t; // 0..1
  final Color ink;

  _RadarPainter(this.t, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    // Two expanding rings, fading as they grow.
    for (final phase in [0.0, 0.5]) {
      final p = (t + phase) % 1.0;
      final r = maxR * p;
      final opacity = (1.0 - p) * 0.5;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = ink.withValues(alpha: opacity);
      canvas.drawCircle(center, r, paint);
    }
    // Center dot.
    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = ink.withValues(alpha: 0.8),
    );
  }

  // Must compare `ink` too: without it, switching theme leaves the radar
  // painted in the old colour until the next animation tick happens to differ.
  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.ink != ink;
}