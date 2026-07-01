import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:beacon_client/presentation/detail/artifact_detail_args.dart';
import 'package:beacon_client/presentation/detail/widgets/detail_section_tabs.dart';
import 'package:beacon_client/presentation/detail/widgets/media_player_card.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Screen 3 — the immersive artifact deep-dive.
///
/// COMPLETELY ISOLATED: it takes an immutable [ArtifactDetailArgs] snapshot and
/// subscribes to NOTHING — no `Provider`, `watch`, `Consumer`, or stream. There
/// is therefore no path by which a background RSSI fluctuation can rebuild this
/// screen or reset the (future) audio player. All mutable UI state lives in the
/// child widgets ([MediaPlayerCard] play/pause, [DetailSectionTabs] selection),
/// so the screen itself is a pure, stateless projection of the snapshot.
class ArtifactDetailScreen extends StatelessWidget {
  final ArtifactDetailArgs args;

  const ArtifactDetailScreen({super.key, required this.args});

  /// EXACT same derivation as the Screen 2 deck card — this is what connects the
  /// Hero flight. Must stay byte-for-byte identical to `ArtifactDeckCard._heroTag`.
  int get _heroTag => (args.info.reading.major << 16) | args.info.reading.minor;

  // Unsplash URL is a documented stand-in so this screen matches the design
  // during the UI build; replace it with the artifact's real hero asset once
  // domain/ + ArtifactRepository are enriched. The backdrop degrades to the
  // gold/glyph treatment (identical to the Screen 2 source) on load failure or
  // offline, so the Hero morph stays clean either way.

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.62;

    final artifact = args.info.artifact;
    final floor = args.info.floor;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Scrollable content. The image is the first element of the column,
          //    so it scrolls WITH the content (matching the HTML, where the
          //    image is the background of the scrolling block). ──
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero header: image (flies) + scrim + overlaid text ──
                SizedBox(
                  height: headerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Only the image is wrapped in the Hero, so the flight is
                      // a clean image morph; the scrim and text belong to this
                      // screen and fade in with the route, not the Hero.
                      Hero(
                        tag: _heroTag,
                        // child: const _HeroImage(imageUrl: _placeholderHeroImage),
                        child: _HeroImage(imageUrl: artifact?.imageUrl),
                      ),
                      const _Scrim(),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (floor != null) _RoomChip(label: floor.name),
                              const SizedBox(height: 16),
                              Text(
                                artifact?.name ?? 'Hiện vật không xác định',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                  height: 1.04,
                                ),
                              ),
                              if (floor != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  floor.description,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 13.5,
                                    color: AppColors.text.withValues(alpha: 0.78),
                                    height: 1.6,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body on solid dark. The scrim bottoms out at exactly
                //    AppColors.background, so this seam is invisible. ──
                Container(
                  width: double.infinity,
                  color: AppColors.background,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // const MediaPlayerCard(),
                      MediaPlayerCard(videoUrl: artifact?.videoUrl),
                      const SizedBox(height: 28),
                      DetailSectionTabs(
                        sections: [
                          DetailSection(
                            label: 'Thông tin',
                            body: artifact?.summary,
                          ),
                          // Pending the Step 6 content model — render a "coming
                          // soon" placeholder rather than inventing a body.
                          const DetailSection(label: 'Ý nghĩa'),
                          const DetailSection(label: '360'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Pinned glass back button, floating over the image ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassBackButton(
                    onTap: () => Navigator.of(context).maybePop(),
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

/// Hero child — the photographic backdrop, or the gold/glyph fallback (which
/// mirrors the Screen 2 source so the morph reads cleanly while the network
/// image loads or if it fails / the device is offline). No scrim here.
class _HeroImage extends StatelessWidget {
  final String? imageUrl;
  const _HeroImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null) return const _HeroFallback();
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _HeroFallback(),
      errorBuilder: (context, error, stack) => const _HeroFallback(),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x33C8973A), AppColors.surface],
        ),
      ),
      child: Center(
        child: Icon(Icons.history_edu, color: AppColors.gold, size: 64),
      ),
    );
  }
}

/// Top-to-bottom scrim that fades the image into the page — translucent at the
/// top, opaque [AppColors.background] at the bottom (mirrors the HTML gradient
/// reaching ~.95 black by 58%), keeping the overlaid title legible.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 0.85, 1.0],
          colors: [
            Color(0x26000000),
            Color(0x73000000),
            Color(0xF00B0905),
            AppColors.background,
          ],
        ),
      ),
    );
  }
}

class _RoomChip extends StatelessWidget {
  final String label;
  const _RoomChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GlassBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 17),
          ),
        ),
      ),
    );
  }
}
