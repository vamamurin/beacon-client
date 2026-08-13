// Destination: lib/presentation/menu/menu_news.dart
//
// KHỐI TIN TỨC — nửa dưới màn Menu, dựng bằng `.tsec` + `.tcard` của bản vẽ.
//
// ═══════════════════════════════════════════════════════════════════════════
// GIỮ HÌNH DÁNG CỦA BẢN VẼ, ĐỔI NỘI DUNG
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ bày các TUYẾN tham quan ở đây ("Tham quan theo chủ đề"). App không có
// khái niệm tuyến — chỉ có một kiểu tham quan, và nút trên hero đã mở nó ra.
// Một lưới "chọn tuyến" đặt ngay dưới nút "Bắt đầu tham quan" sẽ hứa một lựa
// chọn không tồn tại.
//
// Nên chỗ ấy nhận TIN TỨC, và giữ nguyên mọi số đo: lưới mosaic 2fr/1fr cao
// 215dp, khe 3dp để lọt màu nền, chữ trong lề trong khi ảnh chạm hai mép.
//
// ═══════════════════════════════════════════════════════════════════════════
// LƯỚI MOSAIC MANG SẴN MỘT NGHĨA — đừng mượn nó đi chỗ khác
// ═══════════════════════════════════════════════════════════════════════════
//
// Ba ảnh ghép thành một khối = MỘT MỤC BIÊN TẬP có nhiều mặt. Bản vẽ ghi rõ
// điều này khi bác một bản dựng khác: mượn lưới mosaic sang màn danh sách hiện
// vật là mượn luôn cái nghĩa ấy, và khách đọc ra "ba ảnh của một thứ" thay vì
// "ba thứ khác nhau".
//
// Ở đây nghĩa đó ĐÚNG: ba ảnh của một mẩu tin.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/news_item.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class MenuNews extends StatelessWidget {
  const MenuNews({super.key});

  /// Chiều cao lưới ảnh của một thẻ — `.tgrid { height: 215px }`.
  static const double _gridHeight = DesignSize.cardGrid;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final items = content.news.items;

    // ═══════════════════════════════════════════════════════════════════════
    // KHÔNG CÓ TIN ⇒ KHÔNG CÓ KHỐI. Không tiêu đề, không "Sắp có", không gì.
    // ═══════════════════════════════════════════════════════════════════════
    //
    // ⚠ ĐÂY LÀ NGOẠI LỆ CÓ LÝ CỦA LUẬT "không bỏ chức năng vì CMS chưa có dữ
    // liệu", và ranh giới nằm ở chỗ này:
    //
    //     "Sắp có" là một LỜI HỨA. Nó chỉ được dùng khi thứ đó SẼ tới.
    //
    // Màn Giới thiệu và FAQ chưa có nội dung vì CMS chưa kịp, và chúng chắc
    // chắn sẽ có — nên ở đó lối đi phải hiện, kèm lời hứa.
    //
    // Tin tức KHÁC VỀ BẢN CHẤT: chức năng đã chạy đúng, và một bảo tàng KHÔNG
    // CÓ TIN NÀO là một trạng thái hợp lệ, có thể vĩnh viễn. Hứa "sắp có" ở đó
    // là hứa một thứ có thể không bao giờ đến — và một tiêu đề "Tin tức" treo
    // trên khoảng trống thì đọc ra là app hỏng.
    //
    // Câu hỏi để phân biệt, cho lần sau: *thiếu cái này là app CHƯA XONG, hay
    // là bảo tàng đang không có gì để nói?*
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x10, bottom: AppSpace.x10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Text(content.ui(UiKeys.menuNewsTitle),
                style: AppText.sheetTitle.copyWith(color: t.ink)),
          ),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding:
                  EdgeInsets.only(top: i == 0 ? AppSpace.x6 : AppSpace.x8),
              child: _NewsCard(item: items[i]),
            ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final title = content.text(item.title);

    // THẺ TIN KHÔNG BẤM ĐƯỢC — chỉ làm đúng những gì bản vẽ chỉ định.
    //
    // Bản vẽ bày thẻ ở đây và KHÔNG chỉ ra màn đích nào cho nó. Tôi từng cho nó
    // mở một màn bài đọc, tức tự thêm một chức năng không có trong thiết kế.
    // Tin tức ở đây là thứ để ĐỌC LƯỚT: tiêu đề, câu tóm tắt, dòng ngày — đủ để
    // biết bảo tàng đang có gì mới.
    //
    // `Semantics(container: true)` để screen reader đọc cả thẻ thành MỘT khối
    // thay vì ba mẩu chữ rời, nhưng KHÔNG khai là nút.
    return Semantics(
      container: true,
      label: '$title. ${content.text(item.summary)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: MenuNews._gridHeight,
            child: _Mosaic(paths: item.imagePaths),
          ),
          // ẢNH CHẠM HAI MÉP, CHỮ Ở TRONG LỀ. Luật chung của app, và nó là thứ
          // phân biệt "một mục biên tập" với "một cái thẻ nổi trên nền".
          // `.tcard .txt { padding: var(--x4) var(--gutter) 0 }`
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.x4, AppSpace.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppText.listTitle.copyWith(color: t.ink)),
                // `.tcard-d { margin-top: 5px }`
                const SizedBox(height: 5),
                Text(content.text(item.summary),
                    style: AppText.lede.copyWith(color: t.inkMuted)),
                if (item.meta != null) ...[
                  // `.tcard .meta { margin-top: var(--x2) }`
                  const SizedBox(height: AppSpace.x2),
                  Text(content.text(item.meta!),
                      style: AppText.meta.copyWith(color: t.inkFaint)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lưới mosaic: ô lớn chiếm 2/3 bên trái, hai ô nhỏ chồng nhau bên phải.
///
/// Khe 3dp để lọt màu `surface` — đủ để đọc thành ba ảnh, không đủ để chúng rời
/// nhau ra thành ba thứ không liên quan.
///
/// SỐ ẢNH ÍT HƠN BA THÌ LƯỚI TỰ CO, không để lại ô trống: một mẩu tin có một
/// ảnh vẫn phải trông như một mẩu tin, không như một mẩu tin hỏng.
class _Mosaic extends StatelessWidget {
  final List<String> paths;

  const _Mosaic({required this.paths});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentProvider>();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;

    Widget cell(int i, double widthFraction) => HeroImage(
          filePath: i < paths.length ? content.imagePath(paths[i]) : null,
          cacheWidth: (width * widthFraction * dpr).round(),
        );

    if (paths.length < 2) {
      return cell(0, 1.0);
    }

    return Row(
      children: [
        Expanded(flex: 2, child: cell(0, 0.66)),
        const SizedBox(width: 3),
        Expanded(
          child: paths.length == 2
              ? cell(1, 0.34)
              : Column(
                  children: [
                    Expanded(child: cell(1, 0.34)),
                    const SizedBox(height: 3),
                    Expanded(child: cell(2, 0.34)),
                  ],
                ),
        ),
      ],
    );
  }
}
