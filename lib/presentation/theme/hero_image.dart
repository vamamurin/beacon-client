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

import 'museum_tokens.dart';

class HeroImage extends StatelessWidget {
  /// Absolute file path from the active bundle (via repository.resolveAsset),
  /// or null to show the fallback gradient.
  final String? filePath;

  /// Gradient veil painted over the image (from AppColors.*Veil).
  final Gradient? veil;

  /// Decode target width in px — set to the on-screen width to cap memory.
  final int? cacheWidth;

  /// Ghi đè gradient fallback. `null` (mặc định) ⇒ lấy
  /// [MuseumTokens.imageFallback] từ theme — đó là đường đúng; tham số này chỉ
  /// dành cho trường hợp một màn thật sự cần khác, và tới giờ chưa có màn nào.
  ///
  /// TRƯỚC 1.5 ĐÂY LÀ MỘT `static const` #2A2A2A→#0C0C0C nằm ngay trong file
  /// này — ngoài hệ token, trong khối dựng chung của CẢ BỐN màn.
  ///
  /// ⚠ GIÁ TRỊ KHÔNG ĐỔI, CHỖ Ở CỦA NÓ THÌ ĐỔI. Nó vẫn tối ở mọi preset, và
  /// đó KHÔNG phải "chưa sửa xong": bốn trên năm call site có chữ TRẮNG (họ
  /// on-image) nằm trên. Làm fallback sáng lên ở preset giấy là để chữ trắng
  /// biến mất đúng lúc ảnh hỏng — tức đúng lúc màn hình cần nói rằng có gì đó
  /// sai. Xem doc [MuseumTokens.imageFallback].
  final Gradient? fallback;

  const HeroImage({
    super.key,
    required this.filePath,
    this.veil,
    this.cacheWidth,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  /// Cách ảnh lấp khung.
  ///
  /// `cover` (mặc định) khi ảnh là một BỀ MẶT — nền tường chào, hero khu, thẻ,
  /// thumbnail. Ở đó ảnh phải lấp trọn, và cắt mép là chấp nhận được vì thứ
  /// đang xem không phải bản thân tấm ảnh.
  ///
  /// `contain` khi ảnh là CHỦ THỂ — màn 4, nơi khách đang nhìn CHÍNH hiện vật
  /// đó. Cắt một cái bình gốm cho vừa khung vuông là thứ bảo tàng không làm.
  /// Dải trống hai bên KHÔNG phải lỗi bố cục: nó là tấm BO (passe-partout), và
  /// nó nên mang màu [MuseumTokens.surfaceRaised] để đọc ra là một tấm ảnh
  /// được đóng khung, không phải một tấm ảnh bị hụt.
  final BoxFit fit;


  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildImage(context),
        if (veil != null)
          DecoratedBox(decoration: BoxDecoration(gradient: veil)),
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    final path = filePath;
    if (path == null) return _fallbackBox(context);

    final file = File(path);
    return Image.file(
      file,
      fit: fit,
      cacheWidth: cacheWidth,
      // Any decode/IO error -> gradient, never a broken-image box.
      errorBuilder: (_, __, ___) => _fallbackBox(context),
      // Smooth in once decoded; show fallback tone underneath meanwhile.
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync || frame != null) return child;
        return _fallbackBox(context);
      },
    );
  }

  Widget _fallbackBox(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: fallback ?? context.tokens.imageFallback,
        ),
      );
}