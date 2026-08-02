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
        other.audio == audio;
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
      );
}
