// Destination: lib/presentation/guide/guide_screen.dart
//
// MÀN 03 · HƯỚNG DẪN — mục lục ba lựa chọn.
//
// ═══════════════════════════════════════════════════════════════════════════
// MỘT MÀN TÁCH THÀNH HAI
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản trước bày cả ba bước ĐÃ MỞ SẴN trên một trang: tiêu đề, thân bài, icon,
// ảnh minh hoạ, rồi một nút "Xong". Bản vẽ v6 tách làm hai màn:
//
//   03   mục lục — mỗi mục là tiêu đề + MỘT CÂU, cả hàng bấm được
//   03b  một mục một trang — tiêu đề 26 + thân bài 15/1.75
//
// Vì sao tách: ba bài đọc mở sẵn nối đuôi nhau thì khách phải cuộn qua thứ mình
// KHÔNG hỏi để tới thứ mình hỏi. Một mục lục trả lời được câu "tôi cần cái nào"
// trong một cái liếc, và đó là câu duy nhất khách có ở màn này.
//
// ═══════════════════════════════════════════════════════════════════════════
// ☰ CHỨ KHÔNG PHẢI ‹
// ═══════════════════════════════════════════════════════════════════════════
//
// Màn này là GỐC của một tab, tức một đích cấp một. Một màn vừa để tab của
// chính nó sáng vừa đeo nút lùi thì đang nói hai điều ngược nhau. Trang chi
// tiết mới là trang con, và nó giữ ‹.
//
// Thanh ĐỤC (`solid`), khác ba màn có ảnh hero: ở đây phía sau thanh là nền
// trang, và một thanh trong suốt sẽ để chữ cuộn lộn thẳng qua nó.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/guide_content.dart';
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/guide/guide_detail_screen.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_row.dart';
import 'package:beacon_client/presentation/theme/app_rule.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Một mục của mục lục, đã giải sẵn sang chuỗi của ngôn ngữ đang chọn.
///
/// Tồn tại vì mục lục phục vụ HAI nguồn: khối `guide` của manifest, và bộ mục
/// nhúng sẵn khi bảo tàng chưa viết gì. Không có lớp này thì mỗi widget bên
/// dưới phải tự biết mình đang đọc nguồn nào.
class GuideEntry {
  final String title;
  final String? summary;
  final String body;

  const GuideEntry({
    required this.title,
    required this.summary,
    required this.body,
  });
}

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final entries = resolveGuideEntries(content);

    return Scaffold(
      backgroundColor: t.surface,
      body: Column(
        children: [
          MuseumTopBar(title: content.ui(UiKeys.guideTitle)),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // `.olist { margin-top: x8; border-top: 1px solid line }` —
                // vạch tóc mở đầu danh sách. Đây là vạch DUY NHẤT của màn: các
                // mục không có vạch xen giữa, vì chiều cao hàng đã đủ tách
                // chúng ra (cùng luật với hàng ở Poster).
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpace.x8),
                    child: AppHairline(),
                  ),
                ),
                SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _Option(
                    entry: entries[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GuideDetailScreen(entry: entries[i]),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mục lục đọc từ manifest, lùi về bộ nhúng sẵn khi bảo tàng chưa viết gì.
///
/// Bộ nhúng sẵn KHÔNG có câu tóm tắt riêng — chúng là ba chuỗi ui, và thêm ba
/// chuỗi nữa chỉ để lấp một dòng là bịa nội dung của bảo tàng. Mục lục tự co
/// lại còn tiêu đề, và đó là trạng thái đúng.
List<GuideEntry> resolveGuideEntries(ContentProvider content) {
  final GuideContent g = content.guide;
  if (g.isEmpty) {
    return [
      GuideEntry(
        title: content.ui(UiKeys.guideDefaultHeadphonesTitle),
        summary: null,
        body: content.ui(UiKeys.guideDefaultHeadphonesBody),
      ),
      GuideEntry(
        title: content.ui(UiKeys.guideDefaultWalkTitle),
        summary: null,
        body: content.ui(UiKeys.guideDefaultWalkBody),
      ),
      GuideEntry(
        title: content.ui(UiKeys.guideDefaultHelpTitle),
        summary: null,
        body: content.ui(UiKeys.guideDefaultHelpBody),
      ),
    ];
  }
  return [
    for (final s in g.steps)
      GuideEntry(
        title: content.text(s.title),
        summary: content.textOrNull(s.summary),
        body: content.text(s.body),
      ),
  ];
}

/// `.opt` — một hàng của mục lục.
///
/// Cùng ngữ pháp với hàng 58 của Poster: tràn hết bề ngang, nền trong suốt, dấu
/// › ở mép phải, không hairline xen giữa. Chỉ khác là CAO HƠN vì mang thêm một
/// dòng tóm tắt, nên nó không dùng lại [AppRow] — hàng ở đó cao cố định và chỉ
/// chứa một dòng.
class _Option extends StatelessWidget {
  final GuideEntry entry;
  final VoidCallback onTap;

  const _Option({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final summary = entry.summary;

    return Semantics(
      button: true,
      label: summary == null ? entry.title : '${entry.title}. $summary',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          // Cùng phản hồi chạm với AppRow: đổi nền, không gợn sóng.
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: t.ink.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.gutter, vertical: AppSpace.x6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.title,
                          style: AppText.listTitle.copyWith(color: t.ink)),
                      if (summary != null && summary.isNotEmpty) ...[
                        // `.opt-d { margin-top: 5px }` — bù trừ quang học, cùng
                        // con số với thẻ tuyến ở màn Menu.
                        const SizedBox(height: 5),
                        Text(summary,
                            style: AppText.lede.copyWith(color: t.inkMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.x6),
                // Dấu › căn GIỮA theo chiều dọc của cả hàng, không theo dòng
                // đầu: bản vẽ neo nó ở `top: 50%`. Với một hàng hai dòng, căn
                // theo dòng đầu sẽ đẩy nó lên lệch hẳn khỏi tâm thị giác.
                Align(
                  alignment: Alignment.centerRight,
                  child: AppChevron(color: t.inkFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
