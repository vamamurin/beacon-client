// Destination: lib/domain/models/feedback_config.dart
//
// Cấu hình KHỐI ĐÁNH GIÁ trên màn tổng kết — khối `feedback` trong manifest.
//
// Thang đo để server chọn vì mỗi bảo tàng đã có sẵn hệ đo riêng và muốn số liệu
// nối được với báo cáo cũ của họ: nơi dùng 5 sao, nơi dùng NPS 0–10, nơi chỉ
// cần ba mặt cười cho khách lớn tuổi. Đổi thang đo không đáng phải build lại
// app cho cả đội máy.

import 'package:flutter/foundation.dart';

import 'localized_text.dart';

/// Thang đo hiển thị. [id] là chuỗi trong manifest — KHÔNG đổi sau khi phát
/// hành bundle.
enum FeedbackScale {
  /// 5 sao. Giá trị ghi nhận: 1–5.
  stars5('stars5', min: 1, max: 5),

  /// Net Promoter Score. Giá trị ghi nhận: 0–10.
  nps('nps', min: 0, max: 10),

  /// Ba mặt: tệ / ổn / tốt. Giá trị ghi nhận: 1–3.
  emoji3('emoji3', min: 1, max: 3);

  const FeedbackScale(this.id, {required this.min, required this.max});

  final String id;

  /// Biên của giá trị ghi nhận — dùng để kẹp trước khi đẩy vào analytics, để
  /// một lỗi ở tầng UI không sinh ra số nằm ngoài thang trong báo cáo.
  final int min;
  final int max;

  static FeedbackScale? byId(String id) {
    for (final s in FeedbackScale.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Một nhãn lý do chọn thêm được (tùy chọn, nhiều lựa chọn).
@immutable
class FeedbackTag {
  /// Khóa ổn định đi vào analytics. Nhãn hiển thị đổi thoải mái, khóa thì không.
  final String id;
  final LocalizedText label;

  const FeedbackTag({required this.id, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedbackTag && other.id == id && other.label == label);

  @override
  int get hashCode => Object.hash(id, label);
}

@immutable
class FeedbackConfig {
  final FeedbackScale scale;

  /// Câu hỏi. Thiếu ⇒ chuỗi mặc định `feedback.question` trong [kUiDefaults].
  final LocalizedText? question;

  /// Nhãn lý do. Rỗng ⇒ chỉ hiện thang đo, không hiện hàng nhãn.
  final List<FeedbackTag> tags;

  const FeedbackConfig({
    this.scale = FeedbackScale.stars5,
    this.question,
    this.tags = const <FeedbackTag>[],
  });

  static const FeedbackConfig defaults = FeedbackConfig();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedbackConfig &&
          other.scale == scale &&
          other.question == question &&
          listEquals(other.tags, tags));

  @override
  int get hashCode => Object.hash(scale, question, Object.hashAll(tags));
}
