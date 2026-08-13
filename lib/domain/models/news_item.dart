// Destination: lib/domain/models/news_item.dart
//
// Một mẩu TIN TỨC của bảo tàng — khối `news` trong manifest.
//
// ═══════════════════════════════════════════════════════════════════════════
// NÓ ĐỨNG VÀO CHỖ MÀ BẢN VẼ DÀNH CHO "THAM QUAN THEO CHỦ ĐỀ"
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ bày các TUYẾN tham quan ở nửa dưới màn Menu. App không có khái niệm
// tuyến: chỉ có một kiểu tham quan duy nhất — khách đi tới đâu máy kể tới đó —
// và đó chính là thứ nút trên hero mở ra. Một lưới "chọn tuyến" bên dưới một
// nút "bắt đầu tham quan" sẽ hứa một lựa chọn không tồn tại.
//
// Nên chỗ ấy đổi NỘI DUNG mà giữ nguyên HÌNH DÁNG: vẫn khối `.tcard`, vẫn lưới
// mosaic ba ảnh, vẫn tiêu đề + mô tả + dòng meta. Hình dáng ấy nói "đây là một
// mục biên tập có ảnh, chạm vào để đọc" — đúng cho một tuyến tham quan, và cũng
// đúng cho một mẩu tin.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO [meta] LÀ LocalizedText CHỨ KHÔNG PHẢI DateTime
// ═══════════════════════════════════════════════════════════════════════════
//
// Nghe như đánh mất kiểu dữ liệu. Nó là một quyết định:
//
//   • Một `DateTime` buộc app phải ĐỊNH DẠNG ngày, mà định dạng ngày là việc
//     phụ thuộc ngôn ngữ — và app này có thể chạy chín thứ tiếng. Kéo theo
//     `intl` cùng dữ liệu locale cho một dòng chữ 12px là cái giá sai.
//   • Dòng meta của bản vẽ không phải lúc nào cũng là ngày: ở thẻ chủ đề nó là
//     "6 hiện vật · tầng 1 · 25 phút". Nó là một DÒNG PHỤ, không phải một ngày.
//
// Bảo tàng viết đúng dòng họ muốn, bằng đúng thứ tiếng họ muốn. Nếu sau này cần
// sắp xếp tin theo thời gian thì đó là lúc thêm một trường `publishedAt` RIÊNG —
// một trường để MÁY đọc, tách khỏi trường để NGƯỜI đọc.

import 'package:flutter/foundation.dart';

import 'localized_text.dart';

@immutable
class NewsItem {
  /// Slug cho log và khoá widget. Null ⇒ dùng vị trí trong mảng.
  final String? id;

  final LocalizedText title;

  /// Câu mô tả dưới tiêu đề. Bản vẽ để nó dài hai dòng.
  final LocalizedText summary;

  /// Dòng phụ mờ dưới cùng (ngày đăng, hoặc bất cứ gì bảo tàng muốn). Null ⇒
  /// không hiện dòng nào.
  final LocalizedText? meta;

  /// Toàn văn. Null ⇒ chạm vào thẻ mở màn "Sắp có" thay vì một trang trống.
  final LocalizedText? body;

  /// Đường dẫn ảnh trong bundle. Bản vẽ dùng ĐÚNG BA ảnh cho lưới mosaic; ít
  /// hơn thì lưới tự co (xem widget), nhiều hơn thì phần thừa bị bỏ qua.
  ///
  /// Rỗng ⇒ thẻ vẫn dựng được, lưới rơi về gradient dự phòng của [HeroImage].
  /// Một mẩu tin không ảnh vẫn là một mẩu tin.
  final List<String> imagePaths;

  const NewsItem({
    this.id,
    required this.title,
    required this.summary,
    this.meta,
    this.body,
    this.imagePaths = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsItem &&
          other.id == id &&
          other.title == title &&
          other.summary == summary &&
          other.meta == meta &&
          other.body == body &&
          listEquals(other.imagePaths, imagePaths));

  @override
  int get hashCode => Object.hash(
        id,
        title,
        summary,
        meta,
        body,
        Object.hashAll(imagePaths),
      );
}

/// Khối `news` của manifest. THỨ TỰ MẢNG LÀ THỨ TỰ HIỂN THỊ — cùng quy ước với
/// `menu.entries` và `zone.exhibits`. Bảo tàng muốn đảo tin nào lên đầu thì đảo
/// trong CMS; app không sắp xếp lại, và vì thế không thể sắp xếp SAI.
@immutable
class NewsFeed {
  final List<NewsItem> items;

  const NewsFeed({required this.items});

  static const NewsFeed empty = NewsFeed(items: <NewsItem>[]);

  bool get isEmpty => items.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsFeed && listEquals(other.items, items));

  @override
  int get hashCode => Object.hashAll(items);
}
