import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:beacon_client/domain/models/proximity_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/detail/artifact_detail_args.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// One artifact card in the [ArtifactDeck] — extracted from the old carousel so
/// the Hero source has a clean home.
///
/// Self-contained interaction: it carries its own [Hero] (the image area, which
/// expands into Screen 3's full-screen image) and pushes the Detail route on
/// tap, handing over an immutable [ArtifactDetailArgs] snapshot.
///
/// Hero tag = the packed beacon key. It is unique per card (satisfying Hero's
/// per-route tag rule) and Screen 3 MUST derive its destination tag the same
/// way — `(info.reading.major << 16) | info.reading.minor` — for the flight to
/// connect.
class ArtifactDeckCard extends StatelessWidget {
  final ProximityInfo info;
  final int rank;
  final bool isNearest;

  const ArtifactDeckCard({
    super.key,
    required this.info,
    required this.rank,
    required this.isNearest,
  });

  int get _heroTag => (info.reading.major << 16) | info.reading.minor;

  static int _litBars(ProximityZone z) => switch (z) {
        ProximityZone.near5m => 2,
        ProximityZone.near3m => 3,
        ProximityZone.near2m => 4,
        _ => 1,
      };

  static String _zoneLabel(ProximityZone z) => switch (z) {
        ProximityZone.near5m => 'ĐANG TIẾP CẬN',
        ProximityZone.near3m => 'GẦN ĐÂY',
        ProximityZone.near2m => 'RẤT GẦN',
        _ => 'PHÁT HIỆN',
      };

  static Color _zoneColor(ProximityZone z) => switch (z) {
        ProximityZone.near5m => AppColors.amber,
        ProximityZone.near3m => AppColors.goldLight,
        ProximityZone.near2m => AppColors.green,
        _ => AppColors.muted,
      };

  void _openDetail(BuildContext context) {
    Navigator.of(context).pushNamed(
      AppRouter.detailRoute,
      arguments: ArtifactDetailArgs(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zone = info.zone;
    final accent = _zoneColor(zone);

    return Padding(
      // Horizontal gap forms the gutter between peeking cards.
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: GestureDetector(
        // Opaque → a tap anywhere on the card (even over the scrollable summary)
        // opens Detail; vertical/horizontal DRAGS still go to the scroll view /
        // PageView, since a tap is neither.
        behavior: HitTestBehavior.opaque,
        onTap: () => _openDetail(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: 0.10), AppColors.card],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isNearest ? accent.withValues(alpha: 0.55) : AppColors.border,
              width: isNearest ? 1.5 : 1,
            ),
            boxShadow: isNearest
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 26,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroImage(tag: _heroTag, accent: accent, rank: rank, imageUrl: info.artifact?.imageUrl),
                Expanded(
                  child: _CardBody(
                    info: info,
                    accent: accent,
                    zoneLabel: _zoneLabel(zone),
                    litBars: _litBars(zone),
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

/// Image placeholder + Hero source. The morphable base (gradient + proximity
/// rings + glyph) is wrapped in the [Hero]; the rank chip and bottom fade sit
/// *outside* it so they don't distort during the flight into Screen 3.
class _HeroImage extends StatelessWidget {
  final int tag;
  final Color accent;
  final int rank;
  final String? imageUrl; 
  const _HeroImage({
    required this.tag,
    required this.accent,
    required this.rank,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(tag: tag, child: _HeroImageBase(accent: accent, imageUrl: imageUrl)),
          Positioned(
            top: 11,
            left: 11,
            child: _RankChip(rank: rank, accent: accent),
          ),
          // Bottom fade for seamless hand-off into the card body.
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.card],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The flight-morphable visual: gradient wash + concentric proximity rings +
/// framed museum glyph. With no artwork field on [ArtifactInfo] yet, this ties
/// the BLE-ranging concept into the card's identity until real imagery lands.
class _HeroImageBase extends StatelessWidget {
  final Color accent;
  final String? imageUrl;
  const _HeroImageBase({required this.accent, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl; 
    
    if (url == null || url.isEmpty) {
      // Hiện icon cây bút vàng nếu không có ảnh
      return const Center(
        child: Icon(Icons.history_edu, color: AppColors.gold, size: 48), 
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Center(
            child: CircularProgressIndicator(color: accent),
          ),
      errorBuilder: (context, error, stack) => Center(
        child: Icon(Icons.broken_image, color: accent.withValues(alpha: 0.5), size: 48),
      ),
    );
  }
}

class _RankChip extends StatelessWidget {
  final int rank;
  final Color accent;
  const _RankChip({required this.rank, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        rank == 0 ? '◆ Gần nhất' : '#${rank + 1}',
        style: GoogleFonts.beVietnamPro(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: rank == 0 ? accent : AppColors.text,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  final ProximityInfo info;
  final Color accent;
  final String zoneLabel;
  final int litBars;

  const _CardBody({
    required this.info,
    required this.accent,
    required this.zoneLabel,
    required this.litBars,
  });

  @override
  Widget build(BuildContext context) {
    final artifact = info.artifact;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone badge + live signal bars
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  zoneLabel,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 8.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              _SignalBars(lit: litBars, color: accent),
            ],
          ),
          const SizedBox(height: 11),

          // Artifact name (display serif)
          Text(
            artifact?.name ?? 'Hiện vật không xác định',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              height: 1.12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Floor subtitle
          if (info.floor != null) ...[
            const SizedBox(height: 3),
            Text(
              info.floor!.name,
              style: GoogleFonts.beVietnamPro(
                fontSize: 10.5,
                color: AppColors.muted,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 11),

          _DistancePill(distance: info.smoothedDistance, accent: accent),
          const SizedBox(height: 13),

          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 11),

          // Summary fills the remaining space and scrolls if it overflows.
          Expanded(
            child: artifact == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      artifact.summary,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.7,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),

          // Tap affordance — the whole card is tappable → Detail.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Chạm để xem chi tiết',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 9, color: accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// Distance chip whose number eases between successive (~1 Hz) readings via
/// [TweenAnimationBuilder], so it counts smoothly instead of snapping. Because
/// the parent card is keyed by beacon id, this resets — rather than animating
/// from a stranger's value — whenever a different artifact takes the slot.
class _DistancePill extends StatelessWidget {
  final double distance;
  final Color accent;
  const _DistancePill({required this.distance, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: distance),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sensors, size: 13, color: accent),
                const SizedBox(width: 6),
                Text(
                  '${value.toStringAsFixed(1)} m',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldLight,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int lit;
  final Color color;
  const _SignalBars({required this.lit, required this.color});

  static const _heights = [6.0, 9.0, 12.0, 15.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 4; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 3.5,
            height: _heights[i],
            decoration: BoxDecoration(
              color: i < lit ? color : AppColors.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < 3) const SizedBox(width: 2),
        ],
      ],
    );
  }
}
