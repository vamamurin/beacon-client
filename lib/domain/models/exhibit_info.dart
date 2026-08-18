import 'package:flutter/foundation.dart';

import 'audio_clip_info.dart';
import 'localized_text.dart';

/// One label/value row in the exhibit spec table ("Năm sản xuất: 1965").
///
/// Free-form label/value pairs instead of fixed fields (era/material) because
/// a bronze drum and a rifle need different attributes — the CMS editor owns
/// the vocabulary, the app just renders rows in array order.
@immutable
class SpecEntry {
  final LocalizedText label;
  final LocalizedText value;

  const SpecEntry({required this.label, required this.value});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpecEntry && other.label == label && other.value == value;
  }

  @override
  int get hashCode => Object.hash(label, value);
}

/// Mô hình 3D của một hiện vật.
///
/// KHÔNG MANG ĐƯỜNG DẪN TỚI FILE `.glb`. Đó là điểm khác quan trọng nhất so với
/// mọi tài sản khác của hiện vật (ảnh, audio) và nó có lý do:
///
/// Ảnh và audio đi TRONG bundle nội dung — tải nguyên khối, thay nguyên khối.
/// Mô hình 3D thì không: chúng nặng gấp hàng chục lần, và nếu nhét vào bundle
/// thì sửa một dấu phẩy trong manifest là cả đội máy tải lại hàng trăm MB. Nên
/// model đi đường riêng, từng file, đánh địa chỉ bằng sha256 (xem [ModelStore]).
///
/// Vì thế manifest chỉ trỏ một KHOÁ [id] vào danh mục `models.json` của máy chủ,
/// còn nội dung thì `ModelStore` tự đối chiếu và tải. Hệ quả kéo theo: quy tắc
/// đường dẫn của `ManifestParser` KHÔNG cần biết tới `.glb` — bundle không bao
/// giờ chứa file 3D, nên bề mặt của nó giữ nguyên như trước tính năng này.
///
/// [poster] thì NGƯỢC LẠI, nằm trong bundle và BẮT BUỘC. Nó là bảo hiểm: model
/// có thể chưa tải xong, có thể tải hỏng, có thể máy quá yếu để dựng — nhưng
/// khung hình đầu của sân khấu 04c thì luôn phải có gì đó để hiện. Một hiện vật
/// khai `model` mà thiếu `poster` là một hiện vật có thể hiện ra khung trống,
/// nên nó bị bỏ cả khối `model` (kèm warning) thay vì được nhận một nửa.
@immutable
class ExhibitModel {
  /// Khoá vào `models.json` trên máy chủ ("tuong-phat"). KHÔNG phải đường dẫn.
  final String id;

  /// Ảnh giữ chỗ, đường dẫn tương đối trong bundle. Luôn có.
  final String poster;

  const ExhibitModel({required this.id, required this.poster});

  @override
  bool operator ==(Object other) =>
      other is ExhibitModel && other.id == id && other.poster == poster;

  @override
  int get hashCode => Object.hash(id, poster);
}

/// Immutable exhibit metadata (successor of ArtifactInfo, zone-first model).
///
/// Keyed by [minor] — the iBeacon minor value shared with beacon firmware and
/// the CMS. IMPORTANT boundary (Phase-0 decision): minor is a CONTENT key and
/// an infrastructure-monitoring hook only. It is never a ranging target, and
/// the exhibit list of a zone comes from the manifest (editorial truth), never
/// from which minors happen to be heard over the air (a dead beacon battery
/// must not make an exhibit vanish from the app).
@immutable
class ExhibitInfo {
  /// iBeacon minor — unique within its zone, matches CMS/firmware.
  final int minor;

  /// Optional human-readable slug ("sung-ak-47") for logs and asset naming.
  final String? id;

  final LocalizedText name;

  /// Short intro paragraph — "Thông tin" tab.
  final LocalizedText summary;

  /// Long-form cultural significance — "Ý nghĩa" tab. Null ⇒ hide the tab
  /// entirely (never show a "content updating" placeholder).
  final LocalizedText? meaning;

  /// Ordered spec rows. Empty list ⇒ hide the spec table.
  final List<SpecEntry> specs;

  /// Bundle-relative image paths. [thumbnailPath] feeds the 2-column grid so
  /// the grid never loads full-resolution images.
  final String imagePath;
  final String thumbnailPath;

  /// Ảnh PHỤ của hiện vật (góc chụp khác, chi tiết hoa văn, mặt sau…), theo
  /// đúng thứ tự CMS xếp. Rỗng ⇒ hiện vật chỉ có một ảnh, đúng như mọi bundle
  /// đã phát hành trước tính năng này.
  ///
  /// VÌ SAO KHÔNG GỘP THẲNG ẢNH CHÍNH VÀO ĐÂY: [imagePath] là một hợp đồng
  /// riêng — nó là ảnh ĐẠI DIỆN, thứ duy nhất được phép xuất hiện ở nơi chỉ có
  /// chỗ cho một ảnh. Một list gộp sẽ biến "ảnh đại diện" thành "phần tử [0]",
  /// và một bundle xếp sai thứ tự sẽ âm thầm đổi bộ mặt của hiện vật ở màn 3.
  /// Giữ hai trường ⇒ ảnh đại diện KHÔNG THỂ trôi.
  ///
  /// Dải để xem là [imagePaths] — luôn có ảnh chính đứng đầu.
  final List<String> extraImagePaths;

  /// Toàn bộ dải ảnh xem được, ảnh chính đứng đầu. Luôn có ít nhất 1 phần tử.
  List<String> get imagePaths => [imagePath, ...extraImagePaths];

  /// Per-exhibit narration clip — one playlist item in the zone tour.
  final AudioClipInfo audio;

  /// Mô hình 3D, hoặc null nếu hiện vật này không có. TUỲ CHỌN theo đúng nghĩa:
  /// phần lớn hiện vật sẽ không bao giờ có model, và bundle nào không khai khối
  /// này vẫn hợp lệ y như trước.
  final ExhibitModel? model;

  const ExhibitInfo({
    required this.minor,
    this.id,
    required this.name,
    required this.summary,
    this.meaning,
    this.specs = const [],
    required this.imagePath,
    required this.thumbnailPath,
    this.extraImagePaths = const [],
    required this.audio,
    this.model,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExhibitInfo &&
        other.minor == minor &&
        other.id == id &&
        other.name == name &&
        other.summary == summary &&
        other.meaning == meaning &&
        listEquals(other.specs, specs) &&
        other.imagePath == imagePath &&
        other.thumbnailPath == thumbnailPath &&
        listEquals(other.extraImagePaths, extraImagePaths) &&
        other.audio == audio &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(
        minor,
        id,
        name,
        summary,
        meaning,
        Object.hashAll(specs),
        imagePath,
        thumbnailPath,
        Object.hashAll(extraImagePaths),
        audio,
        model,
      );
}
