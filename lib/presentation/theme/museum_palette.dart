import 'package:flutter/material.dart';

/// Centralised museum palette — the single source of truth for every brand
/// colour that was previously copy-pasted as private `_kXxx` constants across
/// the widget layer (home, carousel, near view, out-of-range, video overlay).
///
/// Reference semantically: `AppColors.gold`, `AppColors.background`, etc.
///
/// `abstract final` ⇒ cannot be instantiated or extended, mirroring the
/// `AppConstants` idiom in `core/constants.dart`.
abstract final class AppColors {
  // ── Surfaces (darkest → lightest) ───────────────────────────────────
  /// Scaffold background (was `_kBg`).
  static const Color background = Color(0xFF0B0905);

  /// Elevated surface: app bars, headers (was `_kSurface`).
  static const Color surface = Color(0xFF140F0A);

  /// Card fill (was `_kCard`).
  static const Color card = Color(0xFF1C1510);

  /// Hairline dividers, inactive signal bars, unfocused borders (`_kBorder`).
  static const Color border = Color(0xFF2C2318);

  // ── Brand / gold ────────────────────────────────────────────────────
  /// Primary brand gold — accents, eyebrow labels, focus borders (`_kGold`).
  static const Color gold = Color(0xFFC8973A);

  /// Lighter gold for emphasis text and highlights (was `_kGoldLight`).
  static const Color goldLight = Color(0xFFE8C570);

  // ── Text ────────────────────────────────────────────────────────────
  /// Primary text on dark surfaces (was `_kText`).
  static const Color text = Color(0xFFEDE5D5);

  /// Secondary / muted text and captions (was `_kMuted`).
  static const Color muted = Color(0xFF7A6E5E);

  // ── Status accents ──────────────────────────────────────────────────
  /// "Very near" / live signal — zone near2m, status dot (was `_kGreen`).
  static const Color green = Color(0xFF4A8F6A);

  /// "Approaching" — zone near5m accent (was `_kAmber`).
  static const Color amber = Color(0xFFD98A3D);

  /// Idle / scanning radar accent — out-of-range view (was `_kBlue`).
  static const Color blue = Color(0xFF4FA3E0);
}
