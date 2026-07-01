import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:beacon_client/domain/models/proximity_info.dart';
import 'package:beacon_client/presentation/discovery/widgets/artifact_deck_card.dart';
import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Swipeable, distance-sorted deck of every in-range artifact (the Screen 2
/// body). Renamed from the old `ArtifactCarouselView`.
///
/// The list is owned upstream ([ProximityProvider.leaderboard]); this widget
/// only renders it. Its one piece of local state is **focus preservation**:
/// keeping the card the user is reading centred when the leaderboard reorders
/// underneath them (a ~1 Hz, distance-driven event from the registry sweep).
class ArtifactDeck extends StatefulWidget {
  final List<ProximityInfo> leaderboard;

  const ArtifactDeck({super.key, required this.leaderboard});

  @override
  State<ArtifactDeck> createState() => _ArtifactDeckState();
}

class _ArtifactDeckState extends State<ArtifactDeck> {
  late final PageController _controller;
  int? _focusedKey; // packed beacon key of the centred card
  int _currentPage = 0;

  /// Packed composite key — identical to the backend's `(major << 16) | minor`.
  static int _keyOf(ProximityInfo i) =>
      (i.reading.major << 16) | i.reading.minor;

  @override
  void initState() {
    super.initState();
    // viewportFraction < 1 lets the neighbouring card "peek" at the edges.
    _controller = PageController(viewportFraction: 0.84);
    if (widget.leaderboard.isNotEmpty) {
      _focusedKey = _keyOf(widget.leaderboard.first);
    }
  }

  @override
  void didUpdateWidget(covariant ArtifactDeck old) {
    super.didUpdateWidget(old);
    _preserveFocus();
  }

  /// Re-centre the focused artifact after a reorder so the card the user is
  /// reading is never swapped out from under their finger.
  void _preserveFocus() {
    final board = widget.leaderboard;
    if (board.isEmpty) return;

    if (_focusedKey == null) {
      _focusedKey = _keyOf(board.first);
      return;
    }

    final newIndex = board.indexWhere((i) => _keyOf(i) == _focusedKey);

    if (newIndex == -1) {
      // Focused artifact left RF range → fall back to the new nearest.
      _focusedKey = _keyOf(board.first);
      _currentPage = 0;
      _jumpTo(0);
    } else if (newIndex != _currentPage) {
      // Focused artifact merely changed rank → recentre it silently so the
      // card it owns appears stationary while its neighbours reshuffle.
      _currentPage = newIndex;
      _jumpTo(newIndex);
    }
  }

  void _jumpTo(int page) {
    // Defer to post-frame: the PageView must finish laying out the new item
    // count before jumpToPage is valid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      // Never fight an in-progress swipe; reorders are rare enough to skip.
      if (_controller.position.isScrollingNotifier.value) return;
      _controller.jumpToPage(page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.leaderboard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DeckHeader(count: board.length),
        const SizedBox(height: 4),
        Expanded(
          child: PageView.custom(
            controller: _controller,
            onPageChanged: (page) {
              _currentPage = page;
              if (page < widget.leaderboard.length) {
                _focusedKey = _keyOf(widget.leaderboard[page]);
              }
            },
            childrenDelegate: SliverChildBuilderDelegate(
              (context, index) {
                final info = board[index];
                return ArtifactDeckCard(
                  // Stable identity → animation state (and the Hero) follows the
                  // artifact, not the slot, across reorders.
                  key: ValueKey(_keyOf(info)),
                  info: info,
                  rank: index,
                  isNearest: index == 0,
                );
              },
              childCount: board.length,
              // Lets the framework re-locate a keyed child's new index on a
              // reorder, so its element (and in-flight animations) is reused
              // instead of rebuilt cold.
              findChildIndexCallback: (Key key) {
                if (key is! ValueKey<int>) return null;
                final idx = board.indexWhere((i) => _keyOf(i) == key.value);
                return idx == -1 ? null : idx;
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PageDots(count: board.length, controller: _controller),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────── Header ───────────────────────────────

class _DeckHeader extends StatelessWidget {
  final int count;
  const _DeckHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 0),
      child: Row(
        children: [
          Text(
            'HIỆN VẬT GẦN BẠN',
            style: GoogleFonts.beVietnamPro(
              fontSize: 9,
              letterSpacing: 2.5,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.beVietnamPro(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.goldLight,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Container(height: 1, color: AppColors.border)),
        ],
      ),
    );
  }
}

// ────────────────────────────── Page dots ──────────────────────────────

/// Continuous page indicator driven by the controller's fractional page, so the
/// active dot stretches in lock-step with the swipe gesture.
class _PageDots extends StatelessWidget {
  final int count;
  final PageController controller;
  const _PageDots({required this.count, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 6);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = (controller.hasClients ? controller.page : null) ?? 0.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final t = (1.0 - (page - i).abs()).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6 + 14 * t,
              height: 6,
              decoration: BoxDecoration(
                color: Color.lerp(AppColors.border, AppColors.gold, t),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}
