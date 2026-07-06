// Destination: lib/presentation/theme/app_text.dart
//
// Typography matching giaodien.html: Playfair Display (serif) for titles,
// Inter (sans) for body. Font files are bundled as assets (see pubspec block in
// the Step 1 notes) rather than fetched, so there is no network dependency and
// the tour works fully offline.
//
// Sizes/weights mirror the mockup's CSS rules so the Flutter build reads 1:1.

import 'package:flutter/material.dart';

import 'museum_palette.dart';

abstract final class AppFonts {
  static const String serif = 'PlayfairDisplay';
  static const String sans = 'Inter';
}

abstract final class AppText {
  // ── serif titles (Playfair Display) ──

  /// wordmark / big welcome (h2 in tour-hero, 28px 600)
  static const TextStyle heroTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.02,
    color: AppColors.white,
  );

  /// zone card title (h3, 20px 600)
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    color: AppColors.white,
  );

  /// sheet title (26px 600)
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    color: AppColors.white,
  );

  /// player exhibit name (26px 600)
  static const TextStyle playerTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.05,
    color: AppColors.white,
  );

  /// exhibit-list row name (15px 600 serif)
  static const TextStyle stopName = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.white,
  );

  /// numeric badges / wordmark (30px 700)
  static const TextStyle wordmark = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 0.92,
    color: AppColors.white,
  );

  // ── sans body (Inter) ──

  /// uppercase kicker (8.5px, .22em tracking)
  static const TextStyle kicker = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w500,
    fontSize: 8.5,
    letterSpacing: 1.87, // ~.22em at 8.5px
    color: AppColors.kicker,
  );

  /// card / hero meta line (11px 300)
  static const TextStyle meta = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 11,
    color: AppColors.subText,
  );

  /// exhibit-list row sub (9.5px 300 grey)
  static const TextStyle stopMeta = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 9.5,
    color: AppColors.grey,
  );

  /// player artist line (11px 300 italic)
  static const TextStyle artist = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    fontSize: 11,
    color: Color(0xFFC8C8C8),
  );

  /// start button label (12px 600 uppercase, .08em)
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 0.96,
    color: AppColors.black,
  );

  /// player time codes (9px grey)
  static const TextStyle timeCode = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w400,
    fontSize: 9,
    color: AppColors.grey,
  );
}
