import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// One section behind a tab: a [label] and an optional [body]. A null/empty
/// body renders a "content coming soon" placeholder — used for sections the
/// content model doesn't carry yet (Ý nghĩa, 360), so the UI is complete without
/// fabricating text.
@immutable
class DetailSection {
  final String label;
  final String? body;
  const DetailSection({required this.label, this.body});
}

/// Horizontal tab bar (e.g. Thông tin / Ý nghĩa / 360) with a gold active
/// underline. Owns the selected-tab index and cross-fades the body beneath it.
class DetailSectionTabs extends StatefulWidget {
  final List<DetailSection> sections;

  const DetailSectionTabs({super.key, required this.sections});

  @override
  State<DetailSectionTabs> createState() => _DetailSectionTabsState();
}

class _DetailSectionTabsState extends State<DetailSectionTabs> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant DetailSectionTabs old) {
    super.didUpdateWidget(old);
    // Guard against the section list shrinking under a stale index.
    if (_index >= widget.sections.length) _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    if (sections.isEmpty) return const SizedBox.shrink();
    final selected = sections[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < sections.length; i++)
                _TabItem(
                  label: sections[i].label,
                  active: i == _index,
                  onTap: () => setState(() => _index = i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _SectionBody(key: ValueKey(_index), body: selected.body),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.gold : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? AppColors.gold : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String? body;
  const _SectionBody({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final text = body;
    if (text == null || text.trim().isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_empty, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nội dung đang được cập nhật.',
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      text,
      style: GoogleFonts.beVietnamPro(
        fontSize: 14.5,
        color: AppColors.text.withValues(alpha: 0.92),
        height: 1.75,
      ),
    );
  }
}
