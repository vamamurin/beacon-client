// Destination: lib/presentation/menu/menu_topics.dart
//
// KHỐI TUYẾN THEO CHỦ ĐỀ — nửa dưới màn Menu, dựng bằng `.tsec` + `.tcard` của
// bản vẽ. Thay `menu_news.dart` đã xoá.
//
// ═══════════════════════════════════════════════════════════════════════════
// LƯỚI MOSAIC MANG SẴN MỘT NGHĨA, VÀ Ở ĐÂY NÓ ĐÚNG NGHĨA ĐÓ
// ═══════════════════════════════════════════════════════════════════════════
//
// Ba ảnh ghép thành một khối = MỘT MỤC BIÊN TẬP CÓ NHIỀU MẶT. Bản vẽ ghi rõ
// điều này khi bác một bản dựng khác: mượn lưới mosaic sang màn danh sách hiện
// vật là mượn luôn cái nghĩa ấy, và khách đọc ra "ba ảnh của một thứ" thay vì
// "ba thứ khác nhau". Một tuyến tham quan CHÍNH LÀ một thứ có nhiều mặt.
//
// ═══════════════════════════════════════════════════════════════════════════
// THẺ CHƯA BẤM ĐƯỢC — CÓ CHỦ ĐÍCH, VÀ ĐÂY LÀ MỘT MÓN NỢ CÓ TÊN
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ cho `.tcard { cursor: pointer }`, nhưng trong 11 màn của `screens/`
// KHÔNG có màn nào là đích của một tuyến. Dựng đại một màn đích là bịa ra một
// phần thiết kế chưa ai vẽ, nên khối này hiện chỉ trưng bày.
//
// ⚠ HỆ QUẢ PHẢI BIẾT: một cái thẻ có ảnh và tiêu đề thì TRÔNG như bấm được, và
// khách sẽ thử. Đây là món nợ được chấp nhận có ý thức, không phải một chỗ bị
// quên. Khi có màn đích, chỗ cần sửa là widget này (bọc `InkWell`) — dữ liệu đã
// sẵn sàng: [TourTopic.exhibits] đã trỏ đúng cặp major/minor.
//
// KHÔNG khai `Semantics(button: true)` để "chuẩn bị sẵn": khai là nút mà chạm
// không xảy ra gì là nói dối với người dùng screen reader, và họ không có cách
// nào thấy được rằng cái thẻ chỉ để nhìn.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/tour_topic.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class MenuTopics extends StatelessWidget {
  const MenuTopics({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final items = content.topics.items;

    // ═══════════════════════════════════════════════════════════════════════
    // KHÔNG CÓ TUYẾN ⇒ KHÔNG CÓ KHỐI. Không tiêu đề, không "Sắp có", không gì.
    // ═══════════════════════════════════════════════════════════════════════
    //
    // ⚠ ĐÂY LÀ NGOẠI LỆ CÓ LÝ của luật "không bỏ chức năng vì CMS chưa có dữ
    // liệu" (D16②), và ranh giới nằm ở D18:
    //
    //     "Sắp có" là một LỜI HỨA. Nó chỉ được dùng khi thứ đó SẼ tới.
    //
    // Màn Giới thiệu và FAQ chắc chắn sẽ có nội dung, nên ở đó lối đi phải
    // hiện kèm lời hứa. Tuyến theo chủ đề thì KHÁC: chức năng đã chạy đúng, và
    // một bảo tàng KHÔNG SOẠN tuyến nào là trạng thái hợp lệ, có thể vĩnh viễn
    // — hero vẫn mở đúng kiểu tham quan mà app có. Một tiêu đề "Tham quan theo
    // chủ đề" treo trên khoảng trống thì đọc ra là app hỏng.
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
            child: Text(content.ui(UiKeys.menuTopicsTitle),
                style: AppText.sheetTitle.copyWith(color: t.ink)),
          ),
          // `.tcard { margin-top: x8 }`, riêng thẻ đầu `x6` — trong CSS con số
          // x6 đến từ việc margin của `.sheet-title` gộp với margin của thẻ.
          for (var i = 0; i < items.length; i++)
            Padding(
              padding:
                  EdgeInsets.only(top: i == 0 ? AppSpace.x6 : AppSpace.x8),
              child: _TopicCard(topic: items[i]),
            ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final TourTopic topic;

  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final title = content.text(topic.title);
    final summary = content.text(topic.summary);
    final meta = _metaLine(content, topic);

    // `Semantics(container: true)` để screen reader đọc cả thẻ thành MỘT khối
    // thay vì ba mẩu chữ rời. KHÔNG khai là nút — xem doc đầu file.
    return Semantics(
      container: true,
      label: meta == null ? '$title. $summary' : '$title. $summary. $meta',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // `.tgrid { height: 215px }`, quy theo chiều cao máy CÙNG HỆ SỐ với
          // hero — xem doc [DesignSize.cardGrid] cho quan hệ 215:580.
          SizedBox(
            height: DesignSize.cardGrid * DesignSize.verticalScale(context),
            child: _Mosaic(paths: topic.imagePaths),
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
                Text(title, style: AppText.listTitle.copyWith(color: t.ink)),
                // `.tcard-d { margin-top: 5px }`
                const SizedBox(height: 5),
                Text(summary, style: AppText.lede.copyWith(color: t.inkMuted)),
                if (meta != null) ...[
                  // `.tcard .meta { margin-top: var(--x2) }`
                  const SizedBox(height: AppSpace.x2),
                  Text(meta, style: AppText.meta.copyWith(color: t.inkFaint)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dòng `"6 hiện vật · tầng 1 · 25 phút"`, DỰNG TỪ DỮ LIỆU chứ không đọc từ
  /// một trường — xem doc [UiKeys.menuTopicMeta] cho lý do.
  ///
  /// `floor` và `durationMinutes` đều tuỳ chọn, nên hàm này CẮT cả mảnh thiếu
  /// LẪN dấu phân cách của nó: nối chuỗi thẳng tay sẽ cho ra "6 hiện vật ·  ·
  /// 25 phút". Cắt theo dấu `·` của chính khuôn, nên bản dịch nào giữ dấu ấy
  /// thì tự chạy đúng — kể cả bản tiếng Trung, nơi mọi thứ quanh nó đều khác.
  String? _metaLine(ContentProvider content, TourTopic topic) {
    final floor = content.textOrNull(topic.floor);
    final minutes = topic.durationMinutes;

    final kept = content
        .ui(UiKeys.menuTopicMeta)
        .split('·')
        .map((s) => s.trim())
        .where((s) {
          if (s.contains('{floor}')) return floor != null && floor.isNotEmpty;
          if (s.contains('{minutes}')) return minutes != null;
          return s.isNotEmpty;
        })
        .toList();

    if (kept.isEmpty) return null;

    return kept
        .join(' · ')
        .replaceAll('{count}', '${topic.exhibits.length}')
        .replaceAll('{floor}', floor ?? '')
        .replaceAll('{minutes}', '${minutes ?? ''}');
  }
}

/// Lưới mosaic: ô lớn chiếm 2/3 bên trái, hai ô nhỏ chồng nhau bên phải.
///
/// Khe 3dp để lọt màu `surface` — đủ để đọc thành ba ảnh, không đủ để chúng rời
/// nhau ra thành ba thứ không liên quan.
///
/// SỐ ẢNH ÍT HƠN BA THÌ LƯỚI TỰ CO, không để lại ô trống: một tuyến có một ảnh
/// vẫn phải trông như một tuyến, không như một tuyến hỏng.
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
