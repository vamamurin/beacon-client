// Destination: lib/presentation/zone/zone_screen.dart
//
// Screen 2 — the current zone. Per the confirmed design it shows exactly ONE
// .tourcard (the arbiter's currentMajor) inside a list container, so tomorrow's
// "nearby zones" feature just adds more cards. When currentMajor is null it
// becomes the radar/standby screen (walking a corridor between zones).
//
// The card auto-swaps when the arbiter changes zone (no pop, no flicker —
// hysteresis handled it upstream). Tapping the card -> exhibit list (screen 3).
//
// TOKEN FAMILIES: the zone card's title and meta sit ON TOP OF the hero image,
// so they use inkOnImage / mutedOnImage — colours that do NOT follow the theme,
// because the photograph doesn't brighten when light mode turns on. Everything
// else on this screen (header, radar) sits on `surface` and uses ink / inkFaint.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

class ZoneScreen extends StatelessWidget {
  const ZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final zone = context.watch<ZoneProvider>().currentZone;
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child:
            zone == null ? const _RadarStandby() : _CurrentZoneView(zone: zone),
      ),
    );
  }
}

/// Header + single current-zone card (list-of-one, ready for future multi-zone).
class _CurrentZoneView extends StatelessWidget {
  final ZoneInfo zone;
  const _CurrentZoneView({required this.zone});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // No copyWith: sheetTitle has no colour, so it inherits the theme's
        // default ink. That's correct here — this text is on `surface`.
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Text('Khu vực của bạn', style: AppText.sheetTitle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Text(
            'Ứng dụng đã nhận diện khu trưng bày bạn đang đứng qua sóng beacon.',
            style: AppText.sheetSub.copyWith(color: t.inkFaint),
          ),
        ),
        // List container holding exactly one card today.
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 0),
            children: [
              _ZoneCard(
                zone: zone,
                content: content,
                onTap: () => Navigator.of(context).pushNamed(
                    AppRouter.exhibitListRoute,
                    arguments: zone.major),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single .tourcard (150px, veil, serif title, meta line).
class _ZoneCard extends StatelessWidget {
  final ZoneInfo zone;
  final ContentProvider content;
  final VoidCallback onTap;

  const _ZoneCard({
    required this.zone,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = content.text(zone.name);
    final count = zone.exhibits.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Semantics(
        button: true,
        label: 'Khu $name, $count hiện vật, bạn đang ở đây',
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
                      filePath: content.imagePath(zone.heroImagePath),
                      veil: t.tourCardVeil,
                      cacheWidth: 800,
                    ),
                    // Everything below sits ON the photograph.
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
                            '$count hiện vật · Đang ở đây',
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