// Destination: lib/presentation/widgets/language_picker.dart (NEW)
//
// Widget chọn ngôn ngữ DÙNG CHUNG cho Gate và Settings. Dựng từ
// LanguageController.available (= manifest.languages), nên thêm ngôn ngữ nội
// dung vào manifest là picker tự có thêm lựa chọn — không đụng widget này.
//
// Chip đơn giản, chạm để chọn ngay. Đủ cho 2–8 ngôn ngữ; nếu sau này có rất
// nhiều ngôn ngữ, đổi sang danh sách cuộn cũng chỉ sửa trong file này.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/language_controller.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageController>();
    final content = context.read<ContentProvider>();
    final codes = lang.available;

    // Một ngôn ngữ thì không cần picker.
    if (codes.length < 2) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpace.x2,
      runSpacing: AppSpace.x2,
      children: [
        for (final code in codes)
          _LangChip(
            // Tên ưu tiên từ manifest (config.languageNames), lùi về bảng nhúng.
            label: content.languageName(code),
            selected: code == lang.code,
            onTap: () => lang.setCode(code),
          ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.ink : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? t.ink : t.inkFaint),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x4,
            vertical: AppSpace.x2,
          ),
          child: Text(
            label,
            style: AppText.meta.copyWith(
              color: selected ? t.surface : t.ink,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}