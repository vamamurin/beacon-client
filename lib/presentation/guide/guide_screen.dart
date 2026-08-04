// Destination: lib/presentation/guide/guide_screen.dart
//
// Màn HƯỚNG DẪN SỬ DỤNG.
//
// Nội dung đến từ bundle (`guide.steps`) vì đây là màn thay đổi nhiều nhất
// theo thực địa: sau vài tuần đứng quầy, nhân viên biết chính xác ba câu hỏi
// khách hay hỏi nhất, và nó khác nhau giữa các bảo tàng.
//
// KHI BUNDLE CHƯA KHAI BÁO GÌ, màn này vẫn phải đầy đủ — nó là thứ nhân viên
// chỉ vào khi khách hỏi, và một máy vừa cài xong chưa đồng bộ lần nào chính là
// lúc cần nó nhất. Bộ ba bước mặc định ([_defaultSteps]) đọc từ [kUiDefaults],
// nên vẫn dịch được qua khối `ui` mà không cần khai báo `guide`.
//
// CUỘN DỌC, KHÔNG PHẢI CAROUSEL từng bước: số bước do server quyết (có thể là
// 2, có thể là 7), và một carousel bắt người đọc phải vuốt hết mới biết còn
// gì phía sau. Danh sách cuộn hiện toàn bộ chiều dài ngay từ đầu.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/guide_content.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_icons.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Một bước ĐÃ RESOLVE sang chuỗi hiển thị — gộp hai nguồn (bundle và bộ mặc
/// định) về một hình dạng để phần vẽ chỉ có một nhánh.
class _Step {
  final String? iconName;
  final String? imagePath; // đã resolve sang đường dẫn tuyệt đối
  final String title;
  final String body;

  const _Step({
    required this.title,
    required this.body,
    this.iconName,
    this.imagePath,
  });
}

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final steps = _resolveSteps(content);

    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x6,
                AppSpace.gutter,
                AppSpace.x8,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(content.ui(UiKeys.guideTitle),
                      style: AppText.heroTitle.copyWith(color: t.ink)),
                  const SizedBox(height: AppSpace.x3),
                  Text(content.ui(UiKeys.guideSubtitle),
                      style: AppText.lede.copyWith(color: t.inkMuted)),
                  const SizedBox(height: AppSpace.x6),
                  for (var i = 0; i < steps.length; i++)
                    _StepCard(
                      step: steps[i],
                      position: content.uif(UiKeys.guideStepSemantics,
                          {'i': '${i + 1}', 'n': '${steps.length}'}),
                    ),
                  const SizedBox(height: AppSpace.x6),
                  _DoneButton(label: content.ui(UiKeys.guideClose)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Step> _resolveSteps(ContentProvider content) {
    final GuideContent g = content.guide;
    if (g.isEmpty) return _defaultSteps(content);
    return [
      for (final s in g.steps)
        _Step(
          iconName: s.iconId,
          imagePath:
              s.imagePath == null ? null : content.imagePath(s.imagePath!),
          title: content.text(s.title),
          body: content.text(s.body),
        ),
    ];
  }

  /// Bộ bước nhúng sẵn. Ba điều, theo thứ tự khách gặp chúng: đeo tai nghe →
  /// cứ đi → khi hỏng thì làm gì.
  List<_Step> _defaultSteps(ContentProvider content) => [
        _Step(
          iconName: 'headphones',
          title: content.ui(UiKeys.guideDefaultHeadphonesTitle),
          body: content.ui(UiKeys.guideDefaultHeadphonesBody),
        ),
        _Step(
          iconName: 'walk',
          title: content.ui(UiKeys.guideDefaultWalkTitle),
          body: content.ui(UiKeys.guideDefaultWalkBody),
        ),
        _Step(
          iconName: 'help',
          title: content.ui(UiKeys.guideDefaultHelpTitle),
          body: content.ui(UiKeys.guideDefaultHelpBody),
        ),
      ];
}

class _StepCard extends StatelessWidget {
  final _Step step;

  /// "Bước 2 trên 3" — chỉ đọc lên cho screen reader. Trên màn hình, vị trí đã
  /// hiện ra bằng chính thứ tự dọc; in thêm số vào là nói hai lần.
  final String position;

  const _StepCard({required this.step, required this.position});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Semantics(
      label: '$position. ${step.title}. ${step.body}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x3),
        child: Container(
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: t.sharpAll,
          ),
          padding: const EdgeInsets.all(AppSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppSpace.badge,
                    height: AppSpace.badge,
                    decoration: BoxDecoration(
                      color: t.badgeWell,
                      borderRadius: t.sharpAll,
                    ),
                    alignment: Alignment.center,
                    child: Icon(MuseumIcons.byName(step.iconName),
                        size: 18, color: t.ink),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(step.title,
                            style: AppText.cardTitle.copyWith(color: t.ink)),
                        const SizedBox(height: AppSpace.x2),
                        Text(step.body,
                            style: AppText.body.copyWith(color: t.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              if (step.imagePath != null) ...[
                const SizedBox(height: AppSpace.x3),
                ClipRRect(
                  borderRadius: t.sharpAll,
                  child: AspectRatio(
                    // 16:9 cho mọi ảnh hướng dẫn, bất kể server gửi tỉ lệ nào:
                    // các thẻ xếp dọc mà cao thấp lô nhô thì danh sách mất nhịp.
                    aspectRatio: 16 / 9,
                    child: HeroImage(
                      filePath: step.imagePath,
                      cacheWidth:
                          (MediaQuery.sizeOf(context).width * dpr).round(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final String label;
  const _DoneButton({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void done() => Navigator.of(context).maybePop();

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: done,
      child: Material(
        color: t.ctaFill,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: done,
          borderRadius: t.sharpAll,
          child: Container(
            height: AppSpace.ctaHeight,
            alignment: Alignment.center,
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: t.ctaLabel)),
          ),
        ),
      ),
    );
  }
}
