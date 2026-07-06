// Destination: lib/presentation/theme/hero_image.dart
//
// The shared "image-as-interface" building block used by every screen: a
// full-bleed image with a gradient veil on top. Replaces the mockup's CSS
// `.ph` gradient placeholders with real bundle images (Image.file), while
// KEEPING a gradient fallback for two cases:
//   • dev before a real bundle exists on device, and
//   • runtime image load failure (corrupt/missing file) — never a broken box.
//
// Performance: pass [cacheWidth] so a large hero image decodes at display size
// instead of full camera resolution (bounded RAM). Bundle images should already
// be sized per spec, but this is a cheap safety net.

import 'dart:io';

import 'package:flutter/material.dart';

import 'museum_palette.dart';

class HeroImage extends StatelessWidget {
  /// Absolute file path from the active bundle (via repository.resolveAsset),
  /// or null to show the fallback gradient.
  final String? filePath;

  /// Gradient veil painted over the image (from AppColors.*Veil).
  final Gradient? veil;

  /// Decode target width in px — set to the on-screen width to cap memory.
  final int? cacheWidth;

  /// Fallback gradient shown when [filePath] is null or the file fails to load.
  /// Defaults to a neutral dark tone consistent with the mockup's `.ph`.
  final Gradient fallback;

  const HeroImage({
    super.key,
    required this.filePath,
    this.veil,
    this.cacheWidth,
    this.fallback = _defaultFallback,
  });

  static const Gradient _defaultFallback = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A2A), Color(0xFF0C0C0C)],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildImage(),
        if (veil != null)
          DecoratedBox(decoration: BoxDecoration(gradient: veil)),
      ],
    );
  }

  Widget _buildImage() {
    final path = filePath;
    if (path == null) return _fallbackBox();

    final file = File(path);
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      // Any decode/IO error -> gradient, never a broken-image box.
      errorBuilder: (_, __, ___) => _fallbackBox(),
      // Smooth in once decoded; show fallback tone underneath meanwhile.
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync || frame != null) return child;
        return _fallbackBox();
      },
    );
  }

  Widget _fallbackBox() =>
      DecoratedBox(decoration: BoxDecoration(gradient: fallback));
}
