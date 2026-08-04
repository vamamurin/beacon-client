// Destination: lib/presentation/summary/tour_qr.dart
//
// Mã QR "mang chuyến đi về nhà".
//
// Trên máy CHO MƯỢN, mọi thứ khách tạo ra trong phiên đều chết khi trả máy —
// không có tài khoản, không email, không app trên điện thoại họ. QR là đường
// duy nhất đi từ thiết bị của bảo tàng sang thiết bị của khách.
//
// HAI RÀNG BUỘC CỨNG, cả hai đều đã từng làm hỏng QR trong thực tế:
//
//   1. TƯƠNG PHẢN KHÔNG THEO THEME. Mã luôn là đen trên trắng, kể cả ở theme
//      tối. Camera đọc QR bằng ngưỡng sáng-tối; một mã "trắng trên nền mực" cho
//      hợp tông màn hình là một mã ĐẢO NGƯỢC, và nhiều máy quét từ chối đọc.
//      Nên nó ngồi trên một tấm thẻ trắng — trông như một vật được đặt lên màn
//      hình, và đó cũng là ẩn dụ đúng.
//
//   2. NỘI DUNG PHẢI NGẮN. Càng nhiều ký tự, mã càng nhiều ô, ô càng nhỏ —
//      trên màn hình đang bám vân tay, dưới ánh đèn bảo tàng thấp, một mã dày
//      là một mã không quét được. Nên [buildTourUrl] cắt bớt phần chi tiết khi
//      URL vượt [_maxUrlChars] thay vì cố nhồi đủ.
//
// KHÔNG CÓ DỮ LIỆU ĐỊNH DANH trong URL: chỉ id khu / hiện vật, mã ngôn ngữ và
// số phút. Cùng kỷ luật với tầng analytics (xem doc analytics_event.dart).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:beacon_client/domain/models/tour_progress.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Trần độ dài URL. 300 ký tự nằm gọn trong QR phiên bản ~10 ở mức sửa lỗi M —
/// vẫn thưa ô, vẫn quét được ở khoảng cách một cánh tay.
const int _maxUrlChars = 300;

/// Dựng URL mô tả chuyến đi.
///
/// Dạng: `{base}?l=vi&m=47&z=1,2&e=1-1,1-5,2-3`
///   l = ngôn ngữ, m = số phút, z = khu đã ghé, e = hiện vật đã nghe (major-minor)
///
/// `e` là phần bị cắt đầu tiên khi quá dài: danh sách khu đã đủ để trang đích
/// dựng lại một trang "bạn đã đi qua những khu này", còn danh sách hiện vật chỉ
/// làm nó chi tiết hơn.
String buildTourUrl({
  required String baseUrl,
  required TourProgress progress,
  required String language,
  required Duration elapsed,
}) {
  final zones = (progress.visitedMajors.toList()..sort()).join(',');
  final exhibits = (progress.heardExhibits.toList()
        ..sort((a, b) =>
            a.major != b.major ? a.major - b.major : a.minor - b.minor))
      .map((e) => '${e.major}-${e.minor}')
      .join(',');

  final sep = baseUrl.contains('?') ? '&' : '?';
  final head = '$baseUrl${sep}l=$language&m=${elapsed.inMinutes}';
  final withZones = zones.isEmpty ? head : '$head&z=$zones';
  if (exhibits.isEmpty) return withZones;

  final full = '$withZones&e=$exhibits';
  return full.length <= _maxUrlChars ? full : withZones;
}

/// Thẻ QR. Chỉ dựng khi bảo tàng đã bật QR VÀ có địa chỉ hợp lệ — parser đã ép
/// bất biến đó ([SummaryConfig.showQr]), nên ở đây không kiểm lại.
class TourQrCard extends StatelessWidget {
  final TourProgress progress;
  final Duration elapsed;

  const TourQrCard({
    super.key,
    required this.progress,
    required this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final base = content.summary.qrBaseUrl;
    if (base == null) return const SizedBox.shrink();

    final url = buildTourUrl(
      baseUrl: base,
      progress: progress,
      language: content.language,
      elapsed: elapsed,
    );

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: t.sharpAll,
      ),
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tấm thẻ trắng — xem ràng buộc 1 ở đầu file.
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: const EdgeInsets.all(AppSpace.x2),
            child: QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 96,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              // Mã không đọc được thì im lặng biến mất, không dựng cây lỗi đỏ
              // giữa màn tổng kết của khách.
              errorStateBuilder: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: AppSpace.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(content.ui(UiKeys.summaryQrTitle),
                    style: AppText.cardTitle.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.x2),
                Text(content.ui(UiKeys.summaryQrBody),
                    style: AppText.body.copyWith(color: t.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
