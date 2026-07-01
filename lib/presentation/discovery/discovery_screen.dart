import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/proximity_info.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/presentation/app/app.dart' show routeObserver;
import 'package:beacon_client/presentation/discovery/widgets/artifact_deck.dart';
import 'package:beacon_client/presentation/discovery/widgets/out_of_range_view.dart';
import 'package:beacon_client/presentation/providers/proximity_provider.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Screen 2 — the reactive spatial feed (formerly the home screen).
///
/// Renders the [ArtifactDeck] when artifacts are in range, [OutOfRangeView] when
/// the leaderboard is empty, or a [_StartupBlockedView] when the Gatekeeper
/// reports a blocking condition (permission denied / Bluetooth off / unsupported).
///
/// ── Freeze-on-obscured ──────────────────────────────────────────────────
/// This screen deliberately does NOT use `Consumer`/`watch`. It attaches a
/// **manual listener** and mirrors provider state into local fields behind a
/// [_frozen] flag, and it implements [RouteAware]. While Screen 3 (Detail) is
/// pushed on top, [_frozen] is true and provider notifications are dropped — so
/// the deck does not reshuffle and the Hero source card stays pinned. On pop we
/// unfreeze and **snap** to the live state.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with RouteAware {
  ProximityProvider? _provider;
  List<ProximityInfo> _displayed = const [];
  StartupStatus _status = StartupStatus.checking;
  bool _initializing = true;
  bool _frozen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // (1) Attach the provider listener exactly once, seeding local state from
    // whatever the (already-running) provider currently holds.
    final p = context.read<ProximityProvider>();
    if (!identical(p, _provider)) {
      _provider?.removeListener(_onProviderUpdate);
      _provider = p;
      p.addListener(_onProviderUpdate);
      _displayed = p.leaderboard;
      _status = p.status;
      _initializing = p.isInitializing;
    }

    // (2) Subscribe to the global observer for THIS route. subscribe() is
    // idempotent for an already-registered (route, subscriber) pair.
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  void _onProviderUpdate() {
    // The crux of the freeze: drop updates entirely while Detail is on top.
    if (_frozen || !mounted) return;
    setState(_syncFromProvider);
  }

  void _syncFromProvider() {
    _displayed = _provider!.leaderboard;
    _status = _provider!.status;
    _initializing = _provider!.isInitializing;
  }

  // ── RouteAware ──────────────────────────────────────────────────────────
  @override
  void didPushNext() {
    // Screen 3 pushed over us → stop reacting (protects the deck + Hero source).
    _frozen = true;
  }

  @override
  void didPopNext() {
    // Screen 3 popped → resume and snap to current state, since emissions during
    // the freeze were intentionally dropped.
    _frozen = false;
    if (!mounted) return;
    setState(_syncFromProvider);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _provider?.removeListener(_onProviderUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showLiveDot =
        _status == StartupStatus.ready && _displayed.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(active: showLiveDot),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case StartupStatus.checking:
        return const OutOfRangeView(
          key: ValueKey('state-checking'),
          isInitializing: true,
        );

      case StartupStatus.permissionDenied:
        return _StartupBlockedView(
          key: const ValueKey('state-perm'),
          icon: Icons.lock_outline,
          title: 'Cần quyền Bluetooth & Vị trí',
          message:
              'Ứng dụng cần quyền Bluetooth và Vị trí để phát hiện hiện vật '
              'quanh bạn. Hãy cấp quyền rồi thử lại.',
          actionLabel: 'Thử lại',
          onAction: () => context.read<ProximityProvider>().retry(),
        );
      
      case StartupStatus.permissionPermanentlyDenied:
        return _StartupBlockedView(
          key: const ValueKey('state-perm-perm'),
          icon: Icons.lock_outline,
          title: 'Quyền đã bị tắt',
          message:
              'Bạn đã chặn quyền Bluetooth/Vị trí. Hãy mở Cài đặt để cấp lại '
              'quyền cho ứng dụng, sau đó quay lại — ứng dụng sẽ tự tiếp tục.',
          actionLabel: 'Mở cài đặt',
          onAction: () => context.read<ProximityProvider>().openSettings(),
        );

      case StartupStatus.bluetoothOff:
        return _StartupBlockedView(
          key: const ValueKey('state-bt-off'),
          icon: Icons.bluetooth_disabled,
          title: 'Bluetooth đang tắt',
          message:
              'Vui lòng bật Bluetooth để bắt đầu khám phá. Ứng dụng sẽ tự động '
              'tiếp tục khi Bluetooth được bật.',
          actionLabel: 'Kiểm tra lại',
          onAction: () => context.read<ProximityProvider>().retry(),
        );

      case StartupStatus.unsupported:
        return const _StartupBlockedView(
          key: ValueKey('state-unsupported'),
          icon: Icons.sensors_off,
          title: 'Thiết bị không hỗ trợ',
          message:
              'Thiết bị này không hỗ trợ Bluetooth Low Energy nên không thể '
              'sử dụng tính năng khám phá theo vị trí.',
        );

      case StartupStatus.ready:
        return _displayed.isEmpty
            ? OutOfRangeView(
                key: ValueKey(_initializing ? 'state-init' : 'state-empty'),
                isInitializing: _initializing,
              )
            : ArtifactDeck(
                // Constant key → the deck State (PageController + focus
                // tracking) survives every leaderboard update.
                key: const ValueKey('state-deck'),
                leaderboard: _displayed,
              );
    }
  }

  PreferredSizeWidget _buildAppBar({required bool active}) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(11, 3, 17, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pushed route → offer a back affordance (safe no-op at root).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(6, 6, 10, 6),
                  child: Icon(Icons.arrow_back_ios_new,
                      color: AppColors.text, size: 18),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Khám phá',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'BẢO TÀNG TÔN ĐỨC THẮNG',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 9.5,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusDot(active: active),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen blocking state for the Gatekeeper failure modes, with an optional
/// retry CTA wired to [ProximityProvider.retry].
class _StartupBlockedView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StartupBlockedView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
              ),
              child: Icon(icon, color: AppColors.gold, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh,
                          size: 17, color: AppColors.goldLight),
                      const SizedBox(width: 8),
                      Text(
                        actionLabel!,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox(width: 10);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.25 + _ctrl.value * 0.75,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.green, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}