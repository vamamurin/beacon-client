// Destination: lib/presentation/zone/zone_screen.dart
//
// Screen 2 — the current zone. Per the confirmed design it shows exactly ONE
// .tourcard (the arbiter's currentMajor) inside a list container, so tomorrow's
// "nearby zones" feature just adds more cards. When currentMajor is null it
// becomes the radar/standby screen (walking a corridor between zones).
//
// Visual language matches giaodien.html's commented screen-2: sheet-title +
// sheet-sub header, 150px tourcard with veil + serif title + meta. No browsing
// tab bar (zone-first is automatic, not a menu).
//
// The card auto-swaps when the arbiter changes zone (no pop, no flicker —
// hysteresis handled it upstream). Tapping the card -> exhibit list (screen 3).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/zone_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

class ZoneScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final zone = context.watch<ZoneProvider>().currentZone;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: zone == null ? const _RadarStandby() : _CurrentZoneView(zone: zone),
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
    final content = context.watch<ContentProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Text('Khu vực của bạn', style: AppText.sheetTitle),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Text(
            'Ứng dụng đã nhận diện khu trưng bày bạn đang đứng qua sóng beacon.',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontWeight: FontWeight.w300,
              fontSize: 11,
              color: AppColors.grey,
            ),
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
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRouter.exhibitListRoute, arguments: zone.major),
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
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    final name = content.text(zone.name);
    final count = zone.exhibits.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Semantics(
        button: true,
        label: 'Khu $name, $count hiện vật, bạn đang ở đây',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HeroImage(
                      filePath: content.imagePath(zone.heroImagePath),
                      veil: AppColors.tourCardVeil,
                      cacheWidth: 800,
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name, style: AppText.cardTitle),
                          const SizedBox(height: 3),
                          Text(
                            '$count hiện vật · Đang ở đây',
                            style: const TextStyle(
                              fontFamily: AppFonts.sans,
                              fontWeight: FontWeight.w300,
                              fontSize: 10,
                              color: Color(0xFFCFCFCF),
                            ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Simple concentric pulse — calm, not attention-grabbing.
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => CustomPaint(
              size: const Size(120, 120),
              painter: _RadarPainter(_pulse.value),
            ),
          ),
          const SizedBox(height: 28),
          Text('ĐANG QUÉT KHÔNG GIAN'.toUpperCase(),
              style: AppText.kicker.copyWith(color: AppColors.white)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Hãy tiến vào khu trưng bày để bắt đầu nghe thuyết minh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontWeight: FontWeight.w300,
                fontSize: 12,
                height: 1.5,
                color: AppColors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t; // 0..1
  _RadarPainter(this.t);

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
        ..color = AppColors.white.withValues(alpha: opacity);
      canvas.drawCircle(center, r, paint);
    }
    // Center dot.
    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = AppColors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}