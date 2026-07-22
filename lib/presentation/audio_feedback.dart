// Destination: lib/presentation/audio_feedback.dart

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Phản hồi cho một ý định phát tiếng. Một nút bấm mà "không có gì xảy ra"
/// là dạng lỗi tệ nhất: người dùng không biết là do họ hay do máy.
///
/// Feature B: chuỗi lấy từ ContentProvider.ui() (bundle → default nhúng), KHÔNG
/// hardcode — snackbar này hiện theo đúng ngôn ngữ khách đang chọn.
void showAudioFeedback(BuildContext context, AudioIntentResult r) {
  final String? key = switch (r) {
    AudioIntentResult.blockedNoHeadphones => UiKeys.audioFeedbackNoHeadphones,
    AudioIntentResult.notFound => UiKeys.audioFeedbackNotFound,
    AudioIntentResult.started || AudioIntentResult.noClip => null,
  };
  if (key == null) return;
  final msg = context.read<ContentProvider>().ui(key);
  // Màu, hình dạng, behavior đều đến từ ThemeData.snackBarTheme. Đây chính là
  // lý do chọn ThemeExtension thay vì Provider<MuseumTokens>: widget Material
  // dựng sẵn tự lấy đúng màu.
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}