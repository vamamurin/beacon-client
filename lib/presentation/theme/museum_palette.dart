// Destination: lib/presentation/theme/museum_palette.dart (REPLACES current)
//
// Colours lifted verbatim from giaodien.html :root, so the Flutter build
// matches the mockup 1:1. The old gold/brown museum_palette is replaced by this
// Rijksmuseum-style dark palette (black ground, white ink, grey supporting).

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── from :root in giaodien.html ──
  static const Color black = Color(0xFF000000); // --black
  static const Color ink = Color(0xFF0A0A0A); // --ink
  static const Color white = Color(0xFFFFFFFF); // --white
  static const Color grey = Color(0xFF9B9B9B); // --grey
  static const Color greyDark = Color(0xFF3A3A3A); // --grey-d
  static const Color line = Color(0xFF222222); // --line

  /// body background (#141414)
  static const Color background = Color(0xFF141414);

  // ── derived tones used across the mockup ──
  static const Color surface = black; // phone/tabbar/player use pure black
  static const Color text = white;
  static const Color muted = Color(0xFF8A8A8A); // page-note / meta grey
  static const Color kicker = Color(0xFFD8D8D8); // uppercase kicker text
  static const Color subText = Color(0xFFCFCFCF); // card subtitles

  // ── veils (gradient overlays over hero images) ──
  /// Standard bottom-up veil on cards/heroes.
  static const LinearGradient cardVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xC7000000), Color(0x1A000000)], // rgba(0,0,0,.78) -> .1
    stops: [0.0, 0.55],
  );

  /// Stronger veil for the tour list cards.
  static const LinearGradient tourCardVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xD1000000), Color(0x14000000)], // .82 -> .08
    stops: [0.0, 0.60],
  );

  /// Player screen veil: dark top + dark bottom, clear middle.
  static const LinearGradient playerVeil = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x8C000000), // .55
      Color(0x00000000), // transparent
      Color(0x00000000),
      Color(0xE6000000), // .9
      Color(0xFF000000),
    ],
    stops: [0.0, 0.22, 0.45, 0.78, 1.0],
  );

  /// Hero veil on the exhibit-list top image.
  static const LinearGradient heroVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF000000), Color(0x26000000)], // #000 4% -> .15 60%
    stops: [0.04, 0.60],
  );

  // ── vai trò, không phải sắc độ ────────────────────────────────────────────
  // Đặt tên theo VIỆC chúng làm. `subText` đổi từ #CFCFCF sang #D0D0D0 sẽ đổi
  // đúng một dòng; `Color(0xFFCFCFCF)` rải rác thì không.

  /// Chữ phụ đặt trên ảnh hero/card. Trước đây tồn tại hai giá trị chênh nhau
  /// 1 đơn vị (#D0D0D0 và #CFCFCF) cho cùng vai trò này — không ai phân biệt
  /// được, và cả hai đều không phải AppColors.subText vốn đã có sẵn.
  static const Color onImageText = subText;

  /// Nền tròn của nút back trên ảnh (đen 40%).
  static const Color scrimBack = Color(0x66000000);

  /// Nút CTA khi chưa đủ điều kiện bấm.
  static const Color buttonDisabled = Color(0xFF6E6E6E);

  /// Dòng nghệ sĩ / niên đại, in nghiêng dưới tên hiện vật.
  static const Color artistText = Color(0xFFC8C8C8);

  /// Veil màn hình chào (gate). Tối ở đáy VÀ đỉnh, nhạt ở giữa — khác cardVeil
  /// vì wordmark nằm ở trên cùng và cần nền tối để đọc được.
  static const LinearGradient welcomeVeil = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF000000), Color(0x59000000), Color(0x8C000000)],
    stops: [0.10, 0.55, 1.0],
  );
}
