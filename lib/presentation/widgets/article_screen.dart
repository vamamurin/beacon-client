// Destination: lib/presentation/widgets/article_screen.dart
//
// MÀN BÀI ĐỌC — một tiêu đề, vài đoạn văn, không gì khác.
//
// Dùng cho "Giới thiệu bảo tàng" và "Câu hỏi thường gặp" ở màn Poster, và sẵn
// sàng cho trang chi tiết của màn Hướng dẫn.
//
// ═══════════════════════════════════════════════════════════════════════════
// MỘT MÀN CHO BA KHỐI NỘI DUNG — vì chúng CÙNG MỘT HÌNH DẠNG
// ═══════════════════════════════════════════════════════════════════════════
//
// `guide`, `about`, `faq` trong manifest đều là "một danh sách mục có tiêu đề
// và thân bài". Chúng khác nhau ở NỘI DUNG và ở CHỖ ĐỨNG, không ở cấu trúc —
// nên chúng dùng chung một bộ phân tích (`_optArticle`) và chung một màn.
//
// Dựng ba màn gần giống nhau là cách chắc chắn nhất để có ba nhịp dọc khác nhau
// sau vài lần sửa.
//
// ═══════════════════════════════════════════════════════════════════════════
// CỠ CHỮ 15/1.75 — chỗ DUY NHẤT trong app phá thang chữ chuẩn
// ═══════════════════════════════════════════════════════════════════════════
//
// Thân bài thường của app là 13/1.7. Ở đây là [AppText.readingBody] 15/1.75, và
// lý do là hoàn cảnh đọc chứ không phải sở thích: khách đang vừa đọc vừa làm
// việc khác — loay hoay với dây tai nghe, hoặc đứng giữa sảnh với cái máy vừa
// mượn. Mắt không ở yên trên màn.
//
// Đây cũng là chỗ duy nhất `w300` còn được dùng, vì nó đứng đúng ở sàn 15px.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/guide_content.dart';
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Đối số route: khối nội dung nào, và tên hiện trên thanh trên.
///
/// Truyền NỘI DUNG chứ không truyền một khoá để màn tự đi lấy: nhờ vậy màn này
/// không biết `about` và `faq` tồn tại, và thêm khối thứ tư không phải sửa nó.
class ArticleArgs {
  final String titleKey;
  final GuideContent content;

  const ArticleArgs({required this.titleKey, required this.content});
}

class ArticleScreen extends StatelessWidget {
  final ArticleArgs args;

  const ArticleScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final sections = args.content.steps;

    return Scaffold(
      backgroundColor: t.surface,
      body: Column(
        children: [
          // Thanh ĐỤC: màn này không có ảnh hero nào, nên nội dung cuộn sẽ lộn
          // thẳng qua một thanh trong suốt.
          MuseumTopBar(
            title: content.ui(args.titleKey),
            leading: TopBarLeading.back,
          ),
          Expanded(
            // KHỐI RỖNG ⇒ MÀN "SẮP CÓ", KHÔNG PHẢI MỘT HÀNG BIẾN MẤT.
            //
            // Đây là luật của dự án, không phải một giải pháp tạm: một lối đi
            // có trong bản vẽ thì phải có mặt, kể cả khi CMS chưa kịp viết nội
            // dung cho nó. Ẩn nó đi là âm thầm sửa bản thiết kế bằng một quyết
            // định kỹ thuật — người thiết kế không bao giờ biết, và khách thì
            // thấy một màn hình nghèo hơn bản đã được duyệt.
            child: sections.isEmpty
                ? const ComingSoon()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x6,
                AppSpace.gutter,
                AppSpace.x12,
              ),
              itemCount: sections.length,
              // Khe giữa hai mục lớn hơn hẳn khe trong một mục (x5): mắt phải
              // đọc ra "hết mục này sang mục khác" mà không cần một đường kẻ.
              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.x10),
              itemBuilder: (context, i) => _Section(step: sections[i]),
              ),
          ),
        ],
      ),
    );
  }
}

/// Trạng thái "chức năng đã có lối vào nhưng chưa có nội dung".
///
/// Tách thành widget công khai vì nó dùng ở nhiều chỗ: bài đọc rỗng, tin tức
/// rỗng, và các màn của bản vẽ chưa dựng xong (Sơ đồ, Gợi ý, Danh mục).
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.ui(UiKeys.comingSoonTitle),
                style: AppText.sheetTitle.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.x4),
            Text(content.ui(UiKeys.comingSoonBody),
                style: AppText.readingBody.copyWith(color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final GuideStep step;

  const _Section({required this.step});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(content.text(step.title),
            style: AppText.sheetTitle.copyWith(color: t.ink)),
        // Mỗi đoạn trống trong bundle thành một đoạn văn. Bảo tàng viết nội
        // dung trong một ô textarea của CMS, và cách duy nhất họ diễn đạt "sang
        // đoạn mới" ở đó là gõ hai lần Enter.
        for (final para in content.text(step.body).split('\n\n'))
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.x5),
            child: Text(para.trim(),
                style: AppText.readingBody.copyWith(color: t.inkMuted)),
          ),
      ],
    );
  }
}
