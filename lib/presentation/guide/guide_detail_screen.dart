// Destination: lib/presentation/guide/guide_detail_screen.dart
//
// MÀN 03b · HƯỚNG DẪN CHI TIẾT — một mục, một trang.
//
// ═══════════════════════════════════════════════════════════════════════════
// TRANG NÀY CUỘN ĐƯỢC, VÀ ĐÓ LÀ MỘT LUẬT CHUNG
// ═══════════════════════════════════════════════════════════════════════════
//
// Luật của dự án (chốt 14/08/2026): MỌI MÀN TRỪ POSTER đều phải cuộn được. Bản
// vẽ dựng trên khung 844 cố định nên nhiều trang của nó trông như vừa khít; đó
// là tính chất của một bản vẽ, không phải của một cái máy. Trên máy thấp hơn,
// ở `textScaler` lớn, hoặc với một bài viết dài hơn bản mẫu, một trang không
// cuộn được sẽ CẮT IM LẶNG phần cuối — không sọc vàng-đen, không exception,
// chỉ mất chữ.
//
// Poster là ngoại lệ DUY NHẤT vì nó không có nội dung nào để mất: cụm chữ của
// nó là một hằng số, và nó là một tấm áp phích chứ không phải một trang.
//
// ═══════════════════════════════════════════════════════════════════════════
// NÚT "NGHE THỬ" CHƯA CÓ, VÀ ĐÓ LÀ CHỦ ĐÍCH
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ đặt một nút `.btn-sm` "Nghe thử" ở cuối trang. Chưa bảo tàng nào thu
// tiếng cho mục hướng dẫn, và một cái nút bấm vào không ra gì là một lời hứa
// suông — tệ hơn hẳn việc không có nút. Chỗ của nó trong manifest đã được giữ
// (`guide.steps[].audio`, xem `manifest_parser.dart`); ngày có dữ liệu thì nút
// hiện ra khi và chỉ khi mục đó có clip.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/guide/guide_screen.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class GuideDetailScreen extends StatelessWidget {
  final GuideEntry entry;

  const GuideDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Scaffold(
      backgroundColor: t.surface,
      body: Column(
        children: [
          // Tiêu đề thanh vẫn là "Hướng dẫn", KHÔNG phải tên mục: tên mục nằm
          // ngay dưới ở cỡ 26, và thanh trên trả lời câu "tôi đang ở phần nào
          // của app" chứ không lặp lại câu "tôi đang đọc gì".
          MuseumTopBar(
            title: content.ui(UiKeys.guideTitle),
            leading: TopBarLeading.back,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x8,
                AppSpace.gutter,
                AppSpace.x12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // `.gtitle` — 26, cùng cỡ với mọi tiêu đề khối khác của app.
                  // Nó là NỘI DUNG chứ không phải nhãn màn, nên nó không cần to
                  // hơn bất cứ tiêu đề nào khác.
                  Text(entry.title,
                      style: AppText.sheetTitle.copyWith(color: t.ink)),
                  // `.gbody` — 15/1.75 thay cho 13/1.7 của thân bài thường:
                  // khách đang vừa đọc vừa loay hoay với dây tai nghe, mắt
                  // không ở yên trên màn.
                  for (final p in _paragraphs(entry.body))
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.x5),
                      child: Text(p,
                          style: AppText.readingBody
                              .copyWith(color: t.inkMuted)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tách đoạn ở dòng trống — cùng quy ước với mọi trường thân bài khác của
  /// manifest, và cùng cách màn Chi tiết hiện vật đang làm.
  List<String> _paragraphs(String body) => [
        for (final p in body.split(RegExp(r'\n\s*\n')))
          if (p.trim().isNotEmpty) p.trim(),
      ];
}
