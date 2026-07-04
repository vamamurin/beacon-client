import 'package:flutter/foundation.dart';

/// Multilingual text value backing every user-facing string in the bundle
/// (`{"vi": "...", "en": "..."}` in manifest.json).
///
/// The bundle validator guarantees the [MuseumConfig.fallbackLanguage] key is
/// always present, but [resolve] is still written defensively (empty-string
/// last resort) so a rogue bundle can never throw in the render path.
///
/// Kept as a wrapper class rather than a raw `Map<String, String>` so the
/// fallback rule lives in exactly ONE place instead of being re-implemented
/// (inconsistently) at every call site.
@immutable
class LocalizedText {
  final Map<String, String> _values;

  const LocalizedText(this._values);

  /// Resolution order: requested [lang] → [fallbackLang] → any available
  /// value → empty string. Never throws, never returns null.
  String resolve(String lang, String fallbackLang) {
    return _values[lang] ??
        _values[fallbackLang] ??
        (_values.isNotEmpty ? _values.values.first : '');
  }

  /// Whether a translation exists for [lang] specifically (no fallback).
  /// Used by the audio resolver to prefer same-language transcripts even
  /// when the audio track itself has to fall back.
  bool has(String lang) => _values.containsKey(lang);

  /// Available language codes — mainly for validation/debug surfaces.
  Iterable<String> get languages => _values.keys;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalizedText && mapEquals(other._values, _values);
  }

  @override
  int get hashCode => Object.hashAllUnordered(
        _values.entries.map((e) => Object.hash(e.key, e.value)),
      );

  @override
  String toString() => 'LocalizedText(${_values.keys.join(", ")})';
}
