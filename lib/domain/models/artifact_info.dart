import 'package:flutter/foundation.dart';

/// Immutable artifact metadata.
///
/// Phase 6: expanded with API-ready presentation fields ([era], [material],
/// [meaning], [imageUrl]) on top of the original [videoUrl]. Every added field
/// is **nullable** so a partial remote payload (REST/GraphQL) deserializes
/// cleanly and each surface can fall back per-field rather than per-record.
///
/// Value equality + [copyWith] are hand-written (no `equatable` / `freezed`) to
/// keep the domain layer dependency-free. Equality is what lets upstream diffing
/// (and any future value-based change detection) treat two fetched records as
/// the same artifact.
@immutable
class ArtifactInfo {
  /// Matches the iBeacon minor value.
  final int id;
  final String name;
  final String summary;

  /// Historical period, e.g. "Khoảng thế kỷ I TCN – I SCN".
  final String? era;

  /// Primary material, e.g. "Đồng".
  final String? material;

  /// Long-form cultural significance — backs the "Ý nghĩa" detail tab.
  final String? meaning;

  /// Remote hero image (CMS/CDN). Null ⇒ UI uses the gold/glyph fallback.
  final String? imageUrl;

  /// Narration / video asset (remote URL or bundled asset path).
  final String? videoUrl;

  const ArtifactInfo({
    required this.id,
    required this.name,
    required this.summary,
    this.era,
    this.material,
    this.meaning,
    this.imageUrl,
    this.videoUrl,
  });

  /// Standard `??`-merge semantics: omitted args keep the current value.
  /// (To clear a field to null, construct directly rather than via copyWith.)
  ArtifactInfo copyWith({
    int? id,
    String? name,
    String? summary,
    String? era,
    String? material,
    String? meaning,
    String? imageUrl,
    String? videoUrl,
  }) {
    return ArtifactInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      era: era ?? this.era,
      material: material ?? this.material,
      meaning: meaning ?? this.meaning,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArtifactInfo &&
        other.runtimeType == runtimeType &&
        other.id == id &&
        other.name == name &&
        other.summary == summary &&
        other.era == era &&
        other.material == material &&
        other.meaning == meaning &&
        other.imageUrl == imageUrl &&
        other.videoUrl == videoUrl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        summary,
        era,
        material,
        meaning,
        imageUrl,
        videoUrl,
      );
}