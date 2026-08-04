// Destination: lib/domain/models/guide_content.dart
//
// Nội dung MÀN HƯỚNG DẪN SỬ DỤNG — khối `guide` trong manifest.
//
// Đây là màn hình mà nội dung thay đổi nhiều nhất theo thực địa: sau vài tuần
// đứng quầy, nhân viên biết chính xác ba câu hỏi khách hay hỏi nhất, và nó khác
// nhau giữa các bảo tàng. Nên toàn bộ danh sách bước nằm ở bundle, app không
// hardcode bước nào — trừ bộ mặc định nhúng sẵn (xem [GuideContent.isEmpty] và
// `UiKeys.guideDefault*`) để máy chưa kịp đồng bộ vẫn có gì đó để đọc.

import 'package:flutter/foundation.dart';

import 'localized_text.dart';

/// Một bước trong hướng dẫn.
@immutable
class GuideStep {
  /// Tên biểu tượng dạng CHUỖI, ánh xạ qua một bảng whitelist ở tầng
  /// presentation (`guideIcon()`), KHÔNG phải asset.
  ///
  /// Lý do phải là whitelist: Flutter tree-shake bộ icon lúc build, một
  /// `IconData` dựng động từ codepoint sẽ ra ô vuông rỗng trên bản release.
  /// Tên lạ ⇒ icon mặc định, không bao giờ là lỗi.
  final String? iconId;

  /// Ảnh minh họa tùy chọn, đường dẫn tương đối trong bundle.
  final String? imagePath;

  final LocalizedText title;
  final LocalizedText body;

  const GuideStep({
    required this.title,
    required this.body,
    this.iconId,
    this.imagePath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuideStep &&
          other.iconId == iconId &&
          other.imagePath == imagePath &&
          other.title == title &&
          other.body == body);

  @override
  int get hashCode => Object.hash(iconId, imagePath, title, body);
}

/// Khối `guide` của manifest. Thứ tự mảng là thứ tự đọc.
@immutable
class GuideContent {
  final List<GuideStep> steps;

  const GuideContent({required this.steps});

  /// Bundle không khai báo `guide` (hoặc mọi bước đều hỏng) ⇒ rỗng ⇒ màn hướng
  /// dẫn vẽ bộ bước mặc định lấy từ [kUiDefaults]. Màn hình này KHÔNG BAO GIỜ
  /// được để trống: nó là thứ nhân viên chỉ vào khi khách hỏi.
  static const GuideContent empty = GuideContent(steps: <GuideStep>[]);

  bool get isEmpty => steps.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuideContent && listEquals(other.steps, steps));

  @override
  int get hashCode => Object.hashAll(steps);
}
