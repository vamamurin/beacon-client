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

/// Một phần tử trong dải tư liệu của hiện vật.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO MỘT DANH SÁCH THAY VÌ `image` + `thumbnail` + `images[]`
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Bản trước tách ảnh đại diện thành trường riêng, có lý do rõ ràng: gộp thành
/// list sẽ biến "ảnh đại diện" thành "phần tử [0]", và một bundle xếp sai thứ
/// tự sẽ âm thầm đổi bộ mặt của hiện vật. Lý do đó vẫn đúng — nó được bù bằng
/// một phép kiểm ở khâu đóng gói, không phải bằng cách bỏ qua.
///
/// Cái mua về là hai quy tắc bố cục **thu về một**:
///
///     sân khấu   media[0]      (mô hình, hoặc cả dải ảnh nếu không có mô hình)
///     lưới đáy   media[1..]    ← MỘT quy tắc, không còn nhánh
///
/// Trước đó lưới cần hai nhánh: không có mô hình thì bày ảnh phụ, có mô hình
/// thì bày cả ảnh chính. Với danh sách thì cả hai đều là "mọi thứ sau phần tử
/// đầu" — vì khi có mô hình, chính mô hình mới là phần tử đầu.
///
/// VÀ nó mở đường cho video mà không phải sửa schema lần nữa: `type: "video"`
/// là một nhánh mới của [ExhibitMedia], không phải một trường mới ở khắp nơi.
sealed class ExhibitMedia {
  /// Ảnh nhỏ cho ô lưới. MỌI loại đều phải có — kể cả mô hình, vì lưới 04b
  /// được vẽ trước khi bất kỳ model nào được tải về.
  final String thumb;

  const ExhibitMedia({required this.thumb});
}

/// Một tấm ảnh.
class ImageMedia extends ExhibitMedia {
  final String file;

  const ImageMedia({required this.file, required super.thumb});

  @override
  bool operator ==(Object other) =>
      other is ImageMedia && other.file == file && other.thumb == thumb;

  @override
  int get hashCode => Object.hash(file, thumb);
}

/// Mô hình 3D. CHỈ được đứng ở vị trí [0] — xem [ExhibitInfo.media].
class ModelMedia extends ExhibitMedia {
  /// Khoá vào `models.json` trên máy chủ. KHÔNG phải đường dẫn.
  final String id;

  /// Ảnh giữ chỗ ở khung đầu sân khấu, trong bundle. Dải ảnh xoay phủ lên nó
  /// khi tải xong, nên hai thứ phải khớp khung — poster được render từ chính
  /// file `.glb`, không phải một tấm ảnh chụp.
  final String poster;

  const ModelMedia({
    required this.id,
    required this.poster,
    required super.thumb,
  });

  @override
  bool operator ==(Object other) =>
      other is ModelMedia &&
      other.id == id &&
      other.poster == poster &&
      other.thumb == thumb;

  @override
  int get hashCode => Object.hash(id, poster, thumb);
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

  /// Dải tư liệu của hiện vật, ĐÚNG THỨ TỰ CMS xếp. Luôn có ít nhất một phần tử.
  ///
  /// ⚠ RÀNG BUỘC VỊ TRÍ: mô hình 3D chỉ được đứng ở `media[0]`. Parser loại bỏ
  /// một [ModelMedia] nằm ở chỗ khác kèm warning, vì cả bố cục dựa trên việc
  /// phần tử đầu LÀ sân khấu — một mô hình ở giữa dải sẽ là một trang mà không
  /// ngón tay nào tới được (vuốt ngang trên mô hình là xoay nó, không lật trang).
  final List<ExhibitMedia> media;

  /// Per-exhibit narration clip — one playlist item in the zone tour.
  final AudioClipInfo audio;

  const ExhibitInfo({
    required this.minor,
    this.id,
    required this.name,
    required this.summary,
    this.meaning,
    this.specs = const [],
    required this.media,
    required this.audio,
  });

  // ── ba quy tắc quyết định hiện vật này TRÔNG NHƯ THẾ NÀO ─────────────────
  //
  // Sống ở đây chứ không ở màn hình, vì hai màn (04b và 04c) cùng phải tuân
  // theo và chúng không được phép nghĩ khác nhau.

  /// Mô hình 3D, hoặc null. Chỉ `media[0]` mới có thể là mô hình.
  ModelMedia? get model {
    final first = media.first;
    return first is ModelMedia ? first : null;
  }

  bool get hasModel => model != null;

  /// Những gì CUỘN PHIM ở nửa trên màn 04c bày ra.
  ///
  /// Có mô hình ⇒ **đúng một khung**. Không phải để tiết kiệm, mà vì cử chỉ đã
  /// bị chiếm: vuốt ngang trên mô hình là XOAY nó, nên cuộn phim không lật
  /// trang được nữa. Thêm ảnh vào dải là dựng những trang không ai tới được —
  /// chúng đi xuống [documentPaths], nơi ngón tay còn tới.
  List<String> get stagePaths => model != null
      ? [model!.poster]
      : [for (final m in media) if (m is ImageMedia) m.file];

  /// Những gì LƯỚI TƯ LIỆU ở đáy màn 04c bày ra: **mọi thứ sau phần tử đầu**.
  ///
  /// MỘT quy tắc cho cả hai trường hợp, và đó chính là thứ danh sách mua về.
  /// Không có mô hình ⇒ phần tử đầu là ảnh chính (đang đứng ở cuộn phim) nên
  /// lưới bày ảnh phụ. Có mô hình ⇒ phần tử đầu là mô hình, nên lưới bày TẤT CẢ
  /// ảnh kể cả ảnh chính — đúng như cần, vì cuộn phim không còn chỗ cho chúng.
  List<String> get documentPaths =>
      [for (final m in media.skip(1)) if (m is ImageMedia) m.file];

  /// Ảnh cho ô lưới ở màn danh sách hiện vật (04b) — thumb của phần tử đầu.
  /// Có mô hình thì đó là ảnh render của mô hình: ô lưới hứa đúng thứ khách sẽ
  /// thấy khi mở ra.
  String get gridThumbnailPath => media.first.thumb;

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
        listEquals(other.media, media) &&
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
        Object.hashAll(media),
        audio,
      );
}
