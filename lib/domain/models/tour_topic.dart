// Destination: lib/domain/models/tour_topic.dart
//
// Một TUYẾN THAM QUAN THEO CHỦ ĐỀ — khối `topics` trong manifest.
//
// ═══════════════════════════════════════════════════════════════════════════
// NÓ THAY CHO `news`, VÀ ĐÓ LÀ MỘT LẦN QUAY VỀ BẢN VẼ
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ bày các tuyến theo chủ đề ở nửa dưới màn Menu, và ghi chú thiết kế nói
// rõ màn ấy trả lời đúng một câu hỏi: *hôm nay đi đường nào.* Có một thời khối
// này nhận TIN TỨC thay vì tuyến, với lý lẽ "app chỉ có một kiểu tham quan nên
// một lưới chọn tuyến sẽ hứa một lựa chọn không tồn tại" (D17). Quyết định đó
// đã bị đảo: bản vẽ là chuẩn, và dữ liệu để dựng nó thì bảo tàng viết được.
//
// ═══════════════════════════════════════════════════════════════════════════
// DÒNG META KHÔNG PHẢI MỘT TRƯỜNG — ĐÂY LÀ ĐIỂM QUAN TRỌNG NHẤT CỦA FILE
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ in "6 hiện vật · tầng 1 · 25 phút". Cách rẻ nhất là cho CMS gõ đúng
// chuỗi đó bằng ba thứ tiếng — và đó là cách SAI, vì con số 6 sẽ trôi khỏi
// [exhibits] ngay lần đầu ai đó thêm một hiện vật, rồi màn hình nói dối mà
// không có gì kêu lên.
//
// Nên bảo tàng khai [exhibits], [floor], [durationMinutes]; app dựng dòng chữ
// từ khuôn `menu.topic.meta`. Đúng ranh giới D9: CMS sở hữu *cái gì được nói*,
// app sở hữu *cách nói*. Hệ quả kèm theo: đổi thứ tự ba mảnh đó, hay đổi dấu
// phân cách, là việc của một khoá ui — không phải một lần sửa dữ liệu ở CMS.
//
// So sánh với `NewsItem` đã bị gỡ, nơi `meta` LÀ một trường tự do: ở đó nó
// đúng, vì "12 tháng 8, 2026" không phải thứ app suy ra được từ dữ liệu nào.
// Ở đây thì có — và một trường suy ra được mà vẫn cho nhập tay là một lời mời
// hai nguồn sự thật.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO [exhibits] TRỎ BẰNG CẶP major/minor
// ═══════════════════════════════════════════════════════════════════════════
//
// Đó đúng là khoá mà `zones[].exhibits[]` đang dùng, nên một tuyến vắt qua
// nhiều khu được mà không phải nhân bản một dòng nội dung nào. Tuyến là một
// CÁCH ĐỌC bộ sưu tập, không phải một bản sao của nó.

import 'package:flutter/foundation.dart';

import 'localized_text.dart';

/// Một chặng của tuyến: trỏ tới hiện vật đã khai trong `zones`.
///
/// KHÔNG kiểm tra tại chỗ rằng cặp này có thật — parser cũng không. Manifest là
/// dữ liệu ngoài, và việc đối chiếu chéo thuộc về khâu đóng bundle ở server,
/// nơi có cả hai bảng trong tay. App chỉ giữ đúng cái nó đọc được.
@immutable
class TopicStop {
  final int major;
  final int minor;

  const TopicStop({required this.major, required this.minor});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicStop && other.major == major && other.minor == minor);

  @override
  int get hashCode => Object.hash(major, minor);
}

@immutable
class TourTopic {
  /// Slug cho log và khoá widget. Null ⇒ dùng vị trí trong mảng.
  final String? id;

  final LocalizedText title;

  /// Câu mô tả dưới tiêu đề. Bản vẽ để nó dài một tới hai dòng.
  final LocalizedText summary;

  /// "tầng 1", "lầu 2", "khu B" — CHUỖI, không phải số.
  ///
  /// Mỗi bảo tàng đánh tầng một kiểu, và một số nguyên buộc app phải tự chọn
  /// cách gọi hộ. Null ⇒ dòng meta bỏ mảnh đó, không để lại dấu phân cách mồ
  /// côi.
  final LocalizedText? floor;

  /// Thời lượng ước tính. Null ⇒ dòng meta bỏ mảnh đó.
  ///
  /// SỐ chứ không phải chuỗi: nó là thứ app định dạng (và có thể đổi cách nói ở
  /// ui), không phải thứ bảo tàng viết ra.
  final int? durationMinutes;

  /// Ảnh cho lưới mosaic. Bản vẽ dùng ĐÚNG BA; ít hơn thì lưới tự co, nhiều hơn
  /// thì phần thừa bị bỏ qua.
  final List<String> imagePaths;

  /// Các chặng, THEO THỨ TỰ BẢO TÀNG KHAI. Số chặng là thứ dựng nên "N hiện
  /// vật" của dòng meta, nên mảng này không bao giờ được sắp xếp lại trong app.
  final List<TopicStop> exhibits;

  const TourTopic({
    this.id,
    required this.title,
    required this.summary,
    this.floor,
    this.durationMinutes,
    this.imagePaths = const [],
    this.exhibits = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TourTopic &&
          other.id == id &&
          other.title == title &&
          other.summary == summary &&
          other.floor == floor &&
          other.durationMinutes == durationMinutes &&
          listEquals(other.imagePaths, imagePaths) &&
          listEquals(other.exhibits, exhibits));

  @override
  int get hashCode => Object.hash(
        id,
        title,
        summary,
        floor,
        durationMinutes,
        Object.hashAll(imagePaths),
        Object.hashAll(exhibits),
      );
}

/// Khối `topics` của manifest. THỨ TỰ MẢNG LÀ THỨ TỰ HIỂN THỊ — cùng quy ước
/// với `menu.entries` và `zone.exhibits`. Bảo tàng muốn đảo tuyến nào lên đầu
/// thì đảo trong CMS; app không sắp xếp lại, và vì thế không thể sắp xếp SAI.
@immutable
class TopicSet {
  final List<TourTopic> items;

  const TopicSet({required this.items});

  static const TopicSet empty = TopicSet(items: <TourTopic>[]);

  bool get isEmpty => items.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicSet && listEquals(other.items, items));

  @override
  int get hashCode => Object.hashAll(items);
}
