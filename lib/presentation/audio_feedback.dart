// Destination: lib/presentation/audio_feedback.dart

import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:flutter/material.dart';

/// Phản hồi cho một ý định phát tiếng. Một nút bấm mà "không có gì xảy ra"
/// là dạng lỗi tệ nhất: người dùng không biết là do họ hay do máy.
void showAudioFeedback(BuildContext context, AudioIntentResult r) {
  final String? msg = switch (r) {
    AudioIntentResult.blockedNoHeadphones => 'Cắm tai nghe để nghe thuyết minh.',
    AudioIntentResult.notFound => 'Chưa có bản thuyết minh cho hiện vật này.',
    AudioIntentResult.started || AudioIntentResult.noClip => null,
  };
  if (msg == null) return;
  // Màu, hình dạng, behavior đều đến từ ThemeData.snackBarTheme. Đây chính là
  // lý do chọn ThemeExtension thay vì Provider<MuseumTokens>: widget Material
  // dựng sẵn tự lấy đúng màu.
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}