// Destination: lib/presentation/gate/gate_screen.dart
//
// Screen 1 — welcome / session gate. Matches giaodien.html screen 1 1:1:
// full-bleed hero image + veil, wordmark top, welcome block bottom, white
// "Bắt đầu tham quan" button. Wired to SessionProvider.
//
// Beyond the static mockup it handles real state:
//   • fresh device (repository.lastError set) -> staff "needs sync" notice
//     instead of a Start button (a tour with no content would be broken).
//   • pressing Start -> session.startTour() -> phase becomes touring -> navigate
//     to the zone screen.
//   • listens to phase: when touring begins, route forward (covers both the
//     button tap and, later, any programmatic start).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  SessionPhase? _lastPhase;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final graph = context.read<AppGraph>();

    // React to phase transitions: entering touring -> go to the zone screen.
    _handlePhase(session.phase);

    final museumName = graph.repository.config?.museumName;
    final lang = graph.repository.config?.fallbackLanguage ?? 'vi';
    final needsSync = graph.repository.lastError != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed hero (bundle image later; gradient fallback for now).
          const HeroImage(
            filePath: null, // Screen 1 has no zone image; use fallback tone.
            veil: _welcomeVeil,
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Wordmark, top-left.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      museumName?.resolve(lang, lang) ?? 'Bảo tàng',
                      style: AppText.wordmark,
                    ),
                  ),
                ),

                const Spacer(),

                // Welcome text block, bottom.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Hướng dẫn tham quan tự động'.toUpperCase(),
                          style: AppText.kicker),
                      const SizedBox(height: 6),
                      const Text('Chào mừng\nquý khách',
                          style: AppText.heroTitle),
                      const SizedBox(height: 8),
                      const Text(
                        'Ứng dụng tự nhận biết khu trưng bày quanh bạn qua '
                        'sóng beacon — không cần tìm kiếm. Cắm tai nghe để '
                        'nghe thuyết minh.',
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontWeight: FontWeight.w300,
                          fontSize: 11,
                          height: 1.6,
                          color: Color(0xFFD0D0D0),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Start button — or staff sync notice on a fresh device.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: needsSync
                      ? _SyncNotice(error: graph.repository.lastError!)
                      : _StartButton(
                          enabled: session.isAtGate,
                          onPressed: session.startTour,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePhase(SessionPhase phase) {
    if (phase == _lastPhase) return;
    final was = _lastPhase;
    _lastPhase = phase;
    // On the edge into touring, navigate forward once (post-frame to avoid
    // navigating during build).
    if (was != null && phase == SessionPhase.touring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRouter.zoneRoute);
      });
    }
  }

  static const LinearGradient _welcomeVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF000000), Color(0x59000000), Color(0x8C000000)],
    stops: [0.10, 0.55, 1.0],
  );
}

/// White uppercase CTA, matching .startbtn.
class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _StartButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bắt đầu tham quan',
      child: Material(
        color: enabled ? AppColors.white : const Color(0xFF6E6E6E),
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 48, // >= 48dp tap target (accessibility)
            alignment: Alignment.center,
            child: Text('Bắt đầu tham quan'.toUpperCase(), style: AppText.button),
          ),
        ),
      ),
    );
  }
}

/// Fresh-device state: content not yet synced. Shown to museum STAFF.
class _SyncNotice extends StatelessWidget {
  final String error;
  const _SyncNotice({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CHƯA SẴN SÀNG'.toUpperCase(),
              style: AppText.kicker.copyWith(color: AppColors.white)),
          const SizedBox(height: 6),
          const Text(
            'Thiết bị chưa có nội dung tham quan. Vui lòng đồng bộ dữ liệu '
            'trước khi bàn giao cho khách.',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontWeight: FontWeight.w300,
              fontSize: 11,
              height: 1.5,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}