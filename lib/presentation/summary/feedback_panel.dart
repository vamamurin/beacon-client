// Destination: lib/presentation/summary/feedback_panel.dart
//
// Khối ĐÁNH GIÁ trên màn tổng kết.
//
// VÌ SAO NÓ Ở ĐÂY MÀ KHÔNG PHẢI TRÊN MÀN CẢM ƠN — đây là ràng buộc kỹ thuật,
// không phải khẩu vị bố cục: `AnalyticsRecorder` xoá session id ngay khi phiên
// rời `touring`, nên một đánh giá gửi sau `endTour()` sẽ không nối được với
// tour nào. Màn tổng kết nằm TRONG phiên; màn cảm ơn thì không.
//
// Gửi MỘT LẦN, không có nút hoàn tác: khách chạm sao → gửi ngay → khối đổi
// thành lời cảm ơn. Không bắt bấm thêm "Gửi" sau khi đã chọn sao, vì mỗi bước
// thêm ở đây là một phần trăm người bỏ giữa chừng. Nhãn lý do (nếu bảo tàng có
// khai báo) hiện SAU khi đã chấm điểm — chúng là phần tuỳ chọn, và hỏi trước
// khi biết khách thấy thế nào là hỏi sai thứ tự.
//
// VÀ CÓ NÚT BỎ QUA. Phần lớn khách không muốn đánh giá, và một câu hỏi không
// đóng lại được sẽ nằm chắn giữa họ với nút "Kết thúc chuyến đi" — biến lời mời
// góp ý thành trạm thu phí. Bỏ qua CHỈ ẩn khối đi, không ghi sự kiện nào: đây
// là lời mời, và từ chối một lời mời thì không cần phải giải trình.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/feedback_config.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/services/analytics_recorder.dart';

class FeedbackPanel extends StatefulWidget {
  const FeedbackPanel({super.key});

  @override
  State<FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<FeedbackPanel> {
  int? _rating;
  final Set<String> _tags = <String>{};

  /// Đã gửi ít nhất một lần. Chấm lại điểm hoặc chọn thêm nhãn sẽ gửi lại —
  /// server thấy hai bản ghi cùng sessionId và lấy bản cuối. Rẻ hơn nhiều so
  /// với việc dựng cơ chế sửa/huỷ ở client cho một thao tác một lần.
  bool _sent = false;

  /// Khách bấm "Bỏ qua". Chỉ là trạng thái của widget — không có sự kiện nào
  /// được ghi, và nó cũng không sống qua lần mở màn tổng kết kế tiếp.
  bool _skipped = false;

  void _send(FeedbackConfig cfg) {
    final r = _rating;
    if (r == null) return;
    context.read<AnalyticsRecorder>().recordFeedback(
          scale: cfg.scale.id,
          rating: r.clamp(cfg.scale.min, cfg.scale.max),
          tags: _tags.toList(growable: false),
        );
    if (!_sent) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final cfg = content.feedback;
    final question =
        content.textOrNull(cfg.question) ?? content.ui(UiKeys.feedbackQuestion);

    // Bỏ qua ⇒ khối biến mất hẳn, không để lại một dòng "bạn đã bỏ qua". Nhắc
    // lại một lời từ chối là một cách hỏi lại.
    if (_skipped) return const SizedBox.shrink();

    return Container(
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
              Expanded(
                child:
                    Text(question, style: AppText.cardTitle.copyWith(color: t.ink)),
              ),
              // Chỉ hiện khi CHƯA chấm điểm: đã góp ý rồi thì không còn gì để
              // bỏ qua, và một nút "Bỏ qua" cạnh lời cảm ơn đọc như đang mời
              // khách rút lại điều vừa nói.
              if (!_sent) ...[
                const SizedBox(width: AppSpace.x3),
                _SkipButton(
                  label: content.ui(UiKeys.feedbackSkip),
                  onTap: () => setState(() => _skipped = true),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.x3),
          _Scale(
            scale: cfg.scale,
            value: _rating,
            onPick: (v) {
              setState(() => _rating = v);
              _send(cfg);
            },
          ),
          if (_rating != null && cfg.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x4),
            Text(content.ui(UiKeys.feedbackTagsHint),
                style: AppText.meta.copyWith(color: t.inkMuted)),
            const SizedBox(height: AppSpace.x3),
            Wrap(
              spacing: AppSpace.x2,
              runSpacing: AppSpace.x2,
              children: [
                for (final tag in cfg.tags)
                  _TagChip(
                    label: content.text(tag.label),
                    selected: _tags.contains(tag.id),
                    onTap: () {
                      setState(() {
                        if (!_tags.remove(tag.id)) _tags.add(tag.id);
                      });
                      _send(cfg);
                    },
                  ),
              ],
            ),
          ],
          if (_sent) ...[
            const SizedBox(height: AppSpace.x3),
            Text(content.ui(UiKeys.feedbackThanks),
                style: AppText.meta.copyWith(color: t.accentInk)),
          ],
        ],
      ),
    );
  }
}

/// "Bỏ qua" — nhẹ nhất có thể mà vẫn đủ sàn vùng chạm.
///
/// Cố tình KHÔNG dùng biểu tượng dấu × : dấu × đọc là "đóng cái gì đó lại", và
/// khách sẽ ngần ngại vì không biết mình đang đóng khối đánh giá hay đóng cả
/// bản tổng kết. Chữ thì không mơ hồ.
class _SkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SkipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.sharpAll,
          child: Container(
            height: AppSpace.tap,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
            alignment: Alignment.center,
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: t.inkFaint)),
          ),
        ),
      ),
    );
  }
}

/// Ba thang đo, một widget. Chúng khác nhau ở HÌNH, không khác ở hành vi —
/// tách thành ba widget sẽ nhân ba phần semantics và phần trạng thái chọn.
class _Scale extends StatelessWidget {
  final FeedbackScale scale;
  final int? value;
  final void Function(int) onPick;

  const _Scale({required this.scale, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();

    switch (scale) {
      case FeedbackScale.stars5:
        return Row(
          children: [
            for (var i = 1; i <= 5; i++)
              _PickTarget(
                selected: value != null && i <= value!,
                semanticsLabel: content.uif(
                    UiKeys.feedbackStarSemantics, {'i': '$i', 'n': '5'}),
                onTap: () => onPick(i),
                child: (t, on) => Icon(on ? Icons.star : Icons.star_border,
                    size: 28, color: on ? t.accent : t.inkFaint),
              ),
          ],
        );

      case FeedbackScale.emoji3:
        const icons = [
          Icons.sentiment_dissatisfied_outlined,
          Icons.sentiment_neutral_outlined,
          Icons.sentiment_satisfied_outlined,
        ];
        final labels = [
          content.ui(UiKeys.feedbackEmojiBad),
          content.ui(UiKeys.feedbackEmojiOk),
          content.ui(UiKeys.feedbackEmojiGood),
        ];
        return Row(
          children: [
            for (var i = 0; i < 3; i++)
              _PickTarget(
                // Emoji KHÔNG tích luỹ như sao: "ổn" không bao hàm "tệ".
                selected: value == i + 1,
                semanticsLabel: labels[i],
                onTap: () => onPick(i + 1),
                child: (t, on) => Icon(icons[i],
                    size: 32, color: on ? t.accent : t.inkFaint),
              ),
          ],
        );

      case FeedbackScale.nps:
        return Wrap(
          spacing: AppSpace.x1,
          runSpacing: AppSpace.x1,
          children: [
            for (var i = 0; i <= 10; i++)
              _NpsCell(
                value: i,
                selected: value == i,
                semanticsLabel:
                    content.uif(UiKeys.feedbackNpsSemantics, {'i': '$i'}),
                onTap: () => onPick(i),
              ),
          ],
        );
    }
  }
}

/// Vùng chạm đủ sàn a11y quanh một glyph nhỏ. Glyph 28dp không phải vùng chạm;
/// [AppSpace.tap] mới là.
class _PickTarget extends StatelessWidget {
  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget Function(MuseumTokens t, bool selected) child;

  const _PickTarget({
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: AppSpace.tap / 2,
        child: SizedBox(
          width: AppSpace.tap,
          height: AppSpace.tap,
          child: Center(child: child(t, selected)),
        ),
      ),
    );
  }
}

class _NpsCell extends StatelessWidget {
  final int value;
  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _NpsCell({
    required this.value,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? t.accent : t.badgeWell,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.sharpAll,
          child: SizedBox(
            width: AppSpace.badge,
            height: AppSpace.badge,
            child: Center(
              child: Text('$value',
                  style: AppText.meta
                      .copyWith(color: selected ? t.accentInk : t.inkMuted)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? t.accent : t.badgeWell,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.sharpAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.x3,
              vertical: AppSpace.x2,
            ),
            child: Text(label,
                style: AppText.meta
                    .copyWith(color: selected ? t.accentInk : t.inkMuted)),
          ),
        ),
      ),
    );
  }
}
