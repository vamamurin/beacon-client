// Destination: lib/presentation/widgets/zone_change_banner.dart
//
// C2 — the top-of-screen banner shown while a zone change is pending confirmation.
// Overlaid above EVERY screen (including screen 4) via a Stack in MuseumApp's
// builder, so audio for zone A keeps playing under it until the visitor decides.
//
// Design: this is chrome, not a new surface — it borrows the app's MuseumTokens
// and AppText rather than inventing a palette. The one expressive element is the
// countdown ring around the confirm affordance: it makes the 20 s window legible
// without a ticking number shouting at someone who's mid-narration. Reduced-motion
// users still get the shrinking arc (it's information, not decoration) but no
// pulse.
//
// Positioned below the status bar (SafeArea top) per the confirmed spec.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/pending_zone_change_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

/// Drop this once, high in the widget tree (MuseumApp builder), as the top
/// child of a Stack over `child`. Renders nothing when no change is pending.
class ZoneChangeBanner extends StatelessWidget {
  const ZoneChangeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<PendingZoneChangeProvider>().pending;
    if (pending == null) return const SizedBox.shrink();

    final t = Theme.of(context).extension<MuseumTokens>()!;
    final content = context.read<ContentProvider>();
    final toName = content.text(pending.to.name);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: _BannerCard(
          toName: toName,
          deadline: pending.deadline,
          tokens: t,
          onConfirm: () =>
              context.read<PendingZoneChangeProvider>().confirm(),
          onDismiss: () =>
              context.read<PendingZoneChangeProvider>().dismiss(),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.toName,
    required this.deadline,
    required this.tokens,
    required this.onConfirm,
    required this.onDismiss,
  });

  final String toName;
  final DateTime deadline;
  final MuseumTokens tokens;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Material(
      color: t.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.line),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            _CountdownRing(deadline: deadline, color: t.ctaFill, track: t.line),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Bạn đã sang khu vực mới',
                      style: AppText.kicker.copyWith(color: t.inkFaint)),
                  const SizedBox(height: 2),
                  Text(toName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sheetTitle.copyWith(color: t.ink)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onDismiss,
              child: Text('Ở lại',
                  style: AppText.button.copyWith(color: t.inkMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.ctaFill,
                foregroundColor: t.ctaLabel,
              ),
              onPressed: onConfirm,
              child: const Text('Chuyển', style: AppText.button),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shrinking arc from full to empty over the pending window. Drives its own
/// 1-per-second rebuild off the deadline; no external ticker needed.
class _CountdownRing extends StatefulWidget {
  const _CountdownRing({
    required this.deadline,
    required this.color,
    required this.track,
  });

  final DateTime deadline;
  final Color color;
  final Color track;

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final remaining = widget.deadline.difference(DateTime.now());
    _c = AnimationController(
      vsync: this,
      duration: remaining.isNegative ? Duration.zero : remaining,
    )..reverse(from: 1.0); // full -> empty over the remaining window
  }

  @override
  void didUpdateWidget(covariant _CountdownRing old) {
    super.didUpdateWidget(old);
    // Retarget/restart (a new pending or a 20 s reset) -> restart the arc.
    if (old.deadline != widget.deadline) {
      final remaining = widget.deadline.difference(DateTime.now());
      _c.duration = remaining.isNegative ? Duration.zero : remaining;
      _c.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondsLeft = () {
      final d = widget.deadline.difference(DateTime.now());
      return d.isNegative ? 0 : d.inSeconds + 1;
    }();
    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _RingPainter(
            progress: _c.value,
            color: widget.color,
            track: widget.track,
          ),
          child: Center(
            child: Text('$secondsLeft',
                style: AppText.timeCode.copyWith(color: widget.color)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress; // 1 -> 0
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2.5;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = color;
    canvas.drawCircle(center, radius, trackPaint);
    const start = -1.5707963267948966; // -pi/2, 12 o'clock
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
        6.283185307179586 * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}