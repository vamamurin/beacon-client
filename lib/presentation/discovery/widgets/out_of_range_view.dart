import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kText = Color(0xFFEDE5D5);
const _kMuted = Color(0xFF7A6E5E);
const _kBlue = Color(0xFF4FA3E0);

class OutOfRangeView extends StatelessWidget {
  final bool isInitializing;

  const OutOfRangeView({super.key, required this.isInitializing});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _RadarAnimation(),
            const SizedBox(height: 28),
            Text(
              isInitializing
                  ? 'Đang khởi động...'
                  : 'Chưa phát hiện hiện vật nào.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kText.withValues(alpha: 0.75),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isInitializing
                  ? 'Hệ thống beacon đang quét xung quanh...'
                  : 'Di chuyển để khám phá bảo tàng.',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: _kMuted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarAnimation extends StatefulWidget {
  const _RadarAnimation();

  @override
  State<_RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<_RadarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _RadarRingPainter(_ctrl.value),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _kBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _kBlue.withValues(alpha: 0.7),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarRingPainter extends CustomPainter {
  final double t;
  _RadarRingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = phase * maxRadius;
      final opacity = (1.0 - phase) * 0.45;

      canvas.drawCircle(
        center,
        radius.clamp(0.0, maxRadius),
        Paint()
          ..color = _kBlue.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarRingPainter old) => old.t != t;
}
