// Destination: lib/presentation/exhibits/exhibit_detail_screen.dart
//
// Screen 4 — exhibit detail + audio player. Matches giaodien.html screen 4:
// full-bleed exhibit image + playerVeil, top (back + minor numbadge), info
// (kicker "Khu · Hiện vật số N" + serif name + italic artist line), controls
// (progress track + times + begin/play/next), then below the fold: summary,
// meaning, specs.
//
// CONTROLS SEMANTICS (Phase-4 Step 7, coherent with the auto-advance tour):
//   • begin (left, "Về đầu"): restart THIS exhibit from 0. If it isn't the
//     loaded clip yet, load+play it from the start (tapExhibit). Always "play
//     this from the beginning".
//   • play/pause (centre): toggle THIS exhibit; if it isn't loaded, load+play.
//   • next (right, "Tiếp"): advance to the NEXT exhibit in tour order — play it
//     (rule 2a: an explicit tap) and pushReplacement its detail. Disabled on
//     the last exhibit. Uses the frozen `major`; only `minor` moves.
//
// PERFORMANCE — the key rule: the progress bar advances several times/second.
// Only a small StreamBuilder bound to AudioProvider.position rebuilds for it;
// the rest of the screen rebuilds solely on AudioQueueState changes (clip /
// play-pause), exactly the Phase-2 discipline (position excluded from state
// equality). Never route the position stream through the whole tree.
//
// FREEZE-BY-DESIGN like screen 3: takes fixed {major, minor} from route args,
// reads the exhibit once from the repository, and does NOT follow the arbiter.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/presentation/audio_feedback.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';


class ExhibitDetailScreen extends StatelessWidget {
  final int major;
  final int minor;

  const ExhibitDetailScreen({
    super.key,
    required this.major,
    required this.minor,
  });

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final zone = content.zoneByMajor(major);
    final exhibit = content.exhibitAt(major, minor);
    

    if (zone == null || exhibit == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Không tìm thấy hiện vật',
              style: AppText.meta.copyWith(color: AppColors.muted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // The player fills the first viewport; details scroll below.
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: _PlayerPane(
                zone: zone,
                exhibit: exhibit,
                content: content,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _DetailBody(exhibit: exhibit, content: content),
          ),
        ],
      ),
    );
  }
}

/// The full-screen player (image + veil + info + controls).
class _PlayerPane extends StatelessWidget {
  final ZoneInfo zone;
  final ExhibitInfo exhibit;
  final ContentProvider content;

  const _PlayerPane({
    required this.zone,
    required this.exhibit,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final zoneName = content.text(zone.name);
    final name = content.text(exhibit.name);
    final artistLine = _artistLine();

    return Stack(
      fit: StackFit.expand,
      children: [
        HeroImage(
          filePath: content.imagePath(exhibit.imagePath),
          veil: AppColors.playerVeil,
          cacheWidth: 1000,
        ),
        SafeArea(
          child: Column(
            children: [
              // Top: back + minor numbadge.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundIcon(
                      icon: Icons.chevron_left,
                      onTap: () => Navigator.of(context).pop(),
                      label: 'Quay lại',
                    ),
                    _NumBadge(minor: exhibit.minor),
                  ],
                ),
              ),
              const Spacer(),
              // Info block.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$zoneName · Hiện vật số ${exhibit.minor}'.toUpperCase(),
                        style: AppText.kicker),
                    const SizedBox(height: 6),
                    Text(name, style: AppText.playerTitle),
                    if (artistLine != null) ...[
                      const SizedBox(height: 5),
                      Text(artistLine, style: AppText.artist),
                    ],
                  ],
                ),
              ),
              // Controls (progress + times + buttons).
              _Controls(zone: zone, exhibit: exhibit),
              const SizedBox(height: 4),
              // Scroll affordance.
              const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.grey, size: 20),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  String? _artistLine() {
    if (exhibit.specs.isEmpty) return null;
    return exhibit.specs.map((s) => content.text(s.value)).join(' · ');
  }
}

/// Play/pause + progress + begin/next. Only the progress sub-tree rebuilds on
/// position ticks; the rest rebuilds on AudioQueueState changes.
class _Controls extends StatelessWidget {
  final ZoneInfo zone;
  final ExhibitInfo exhibit;
  const _Controls({required this.zone, required this.exhibit});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>(); // rebuilds on state change
    final state = audio.state;
    final major = zone.major;

    // Is THIS exhibit the currently loaded clip? Compare BOTH major and minor —
    // minor is only unique within a zone, so minor alone would false-match an
    // exhibit with the same number in a different zone.
    final isThis = state.current?.zoneMajor == major &&
        state.current?.exhibitMinor == exhibit.minor;
    final duration = state.duration ?? Duration.zero;

    // Next exhibit in tour order (manifest order), if any.
    final curIdx = zone.tourIndexOf(exhibit.minor);
    final hasNext = curIdx >= 0 && curIdx + 1 < zone.exhibits.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        children: [
          // Progress track — isolated StreamBuilder so only this repaints.
          StreamBuilder<Duration>(
            stream: audio.position,
            builder: (context, snap) {
              final pos = isThis ? (snap.data ?? Duration.zero) : Duration.zero;
              final frac = (duration.inMilliseconds == 0)
                  ? 0.0
                  : (pos.inMilliseconds / duration.inMilliseconds)
                      .clamp(0.0, 1.0);
              return Column(
                children: [
                  _TrackBar(fraction: frac),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(isThis ? pos : Duration.zero),
                          style: AppText.timeCode),
                      Text(_fmt(duration), style: AppText.timeCode),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Buttons.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SkipButton(
                icon: Icons.first_page,
                label: 'Về đầu',
                onTap: () {
                  final r = isThis
                      ? audio.replay()
                      : audio.tapExhibit(major: major, minor: exhibit.minor);
                  showAudioFeedback(context, r);
                },
              ),
              const SizedBox(width: 34),
              _PlayButton(
                playing: isThis && state.isPlaying,
                onTap: () {
                  if (isThis && state.isPlaying) {
                    audio.pause();
                    return;
                  } 
                  final r = isThis
                      ? audio.play()
                      : audio.tapExhibit(major: major, minor: exhibit.minor);
                  showAudioFeedback(context, r);
                },
              ),
              const SizedBox(width: 34),
              _SkipButton(
                icon: Icons.last_page,
                label: 'Tiếp',
                // Advance to the next exhibit in tour order and open it. Off at
                // the last exhibit (onTap null greys the control out).
                onTap: hasNext ? () => _goNext(context, audio) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goNext(BuildContext context, AudioProvider audio) {
    final curIdx = zone.tourIndexOf(exhibit.minor);
    if (curIdx < 0 || curIdx + 1 >= zone.exhibits.length) return;
    final next = zone.exhibits[curIdx + 1];
    // Rule 2a: an explicit request interrupts and plays the chosen clip.
    final r = audio.tapExhibit(major: zone.major, minor: next.minor);
    showAudioFeedback(context, r);
    // Replace (don't stack) so back from any detail returns to the list.
    Navigator.of(context).pushReplacementNamed(
      AppRouter.exhibitDetailRoute,
      arguments: ExhibitDetailArgs(major: zone.major, minor: next.minor),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _TrackBar extends StatelessWidget {
  final double fraction;
  const _TrackBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Rail.
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.greyDark,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Fill.
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 2,
                  width: w * fraction,
                  color: AppColors.white,
                ),
              ),
              // Knob.
              Positioned(
                left: (w * fraction) - 5,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  const _PlayButton({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Tạm dừng' : 'Phát',
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Icon(playing ? Icons.pause : Icons.play_arrow,
                color: AppColors.black, size: 26),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Null disables the control (dimmed, no ripple) — used for "Tiếp" at the
  /// last exhibit.
  final VoidCallback? onTap;
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon,
                color: AppColors.white
                    .withValues(alpha: enabled ? 0.85 : 0.3),
                size: 24),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  const _RoundIcon(
      {required this.icon, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.scrimBack,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: AppColors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _NumBadge extends StatelessWidget {
  final int minor;
  const _NumBadge({required this.minor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text('$minor',
          style: const TextStyle(
            fontFamily: AppFonts.serif,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.black,
          )),
    );
  }
}

/// Below-the-fold: summary, meaning, specs. The "more info".
class _DetailBody extends StatelessWidget {
  final ExhibitInfo exhibit;
  final ContentProvider content;

  const _DetailBody(
      {required this.exhibit, required this.content});

  @override
  Widget build(BuildContext context) {
    final summary = content.text(exhibit.summary);
    final meaning = content.textOrNull(exhibit.meaning);

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Giới thiệu'),
          const SizedBox(height: 8),
          Text(summary, style: _bodyStyle),
          if (meaning != null) ...[
            const SizedBox(height: 24),
            _sectionLabel('Ý nghĩa'),
            const SizedBox(height: 8),
            Text(meaning, style: _bodyStyle),
          ],
          if (exhibit.specs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('Thông số'),
            const SizedBox(height: 10),
            ...exhibit.specs.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(content.text(s.label),
                            style: AppText.stopMeta),
                      ),
                      Expanded(
                        child: Text(content.text(s.value),
                            style: _bodyStyle.copyWith(fontSize: 12)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: AppText.kicker.copyWith(color: AppColors.white),
      );

  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 13,
    height: 1.7,
    color: AppColors.subText,
  );
}