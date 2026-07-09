// Destination: lib/presentation/audio_feedback.dart

import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:flutter/material.dart';

import 'theme/museum_palette.dart';

/// Phản hồi cho một ý định phát tiếng. Một nút bấm mà "không có gì xảy ra"
/// là dạng lỗi tệ nhất: người dùng không biết là do họ hay do máy.
void showAudioFeedback(BuildContext context, AudioIntentResult r) {
  final String? msg = switch (r) {
    AudioIntentResult.blockedNoHeadphones =>
      'Cắm tai nghe để nghe thuyết minh.',
    AudioIntentResult.notFound =>
      'Chưa có bản thuyết minh cho hiện vật này.',
    AudioIntentResult.started || AudioIntentResult.noClip => null,
  };
  if (msg == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: AppText.meta.copyWith(color: AppColors.black)),
      backgroundColor: AppColors.white,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}