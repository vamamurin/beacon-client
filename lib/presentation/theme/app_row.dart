// Destination: lib/presentation/theme/app_row.dart
//
// HÀNG THAO TÁC — ngữ pháp dùng chung của Poster, ngăn kéo, và màn Cảm ơn.
//
// ═══════════════════════════════════════════════════════════════════════════
// MỘT TRONG BA HÌNH DÁNG CỦA CẢ APP
// ═══════════════════════════════════════════════════════════════════════════
//
// Thiết kế beacon-v6 khép kín bảng phân loại ở đúng ba hình dáng, và chúng phân
// biệt nhau bằng LỀ chứ không bằng một dòng chữ nào:
//
//     ảnh tràn hết mép máy  →  một NƠI CHỐN.  Khách đang Ở TRONG nó.
//     ảnh có lề bao quanh   →  một HIỆN VẬT.  Khách đang NHÌN nó từ ngoài.
//     hàng có dấu ›         →  một THAO TÁC hoặc một lối đi.   ← file này
//
// Nên mỗi lần thêm một widget mới, câu hỏi đúng không phải "trông thế nào" mà
// "nó là cái nào trong ba cái này". Một thao tác mà vẽ thành thẻ có ảnh sẽ đọc
// ra là một nơi chốn, và không dòng chữ nào chữa được.
//
// ═══════════════════════════════════════════════════════════════════════════
// KHÔNG NỀN, KHÔNG VIỀN, KHÔNG BO GÓC — VÀ ĐÓ LÀ THAY ĐỔI SO VỚI BẢN CŨ
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản trước của Menu vẽ mỗi mục thành một thẻ `surfaceRaised` bo góc, có đĩa
// icon 36dp và mũi tên. Hàng ở đây thay toàn bộ thứ đó: tràn hết bề ngang, nền
// trong suốt, không icon, chỉ nhãn và dấu ›. Chiều cao hàng đã đủ tách chúng
// ra — không cần hairline xen giữa, và thiết kế cố ý bỏ hairline đó.
//
// ⚠ ĐÁNH ĐỔI ĐÃ BIẾT, cần nhìn thật trên máy: ghi chú màn Hướng dẫn của thiết
// kế tự nêu rủi ro — ba lựa chọn không có vạch ngăn, mỗi cái hai dòng chữ khác
// cỡ, thì có thể đọc thành ba đoạn văn liền mạch thay vì ba thứ chọn được.
// Cách thử rẻ nhất họ đề xuất: đưa cho người chưa biết app nhìn 5 giây rồi hỏi
// "có mấy mục".
//
// ═══════════════════════════════════════════════════════════════════════════
// MÀU LẤY TỪ THEME, KHÔNG TỪ THAM SỐ
// ═══════════════════════════════════════════════════════════════════════════
//
// Widget này đọc thẳng `context.tokens` và KHÔNG nhận tham số màu, dù nó xuất
// hiện trên hai loại nền rất khác nhau (giấy ở ngăn kéo, ảnh tối ở Poster).
//
// Lý do: hai màn "hòn đảo luôn tối" (Poster, Cảm ơn) giữ tông tối ở MỌI theme
// bằng cách khai báo lại token ngay tại khối — `Theme(data: ...extensions:
// [MuseumTokens.dark])` — đúng như CSS làm với `.gate, .backdrop-screen`. Nhờ
// vậy mọi thứ bên trong tự chạy đúng mà không widget nào phải biết mình đang ở
// đảo hay ở đất liền.
//
// Nếu một ngày cần một hàng màu khác, câu hỏi đúng là "khối này có phải một
// hòn đảo không", không phải "thêm tham số color".

import 'package:flutter/material.dart';

import 'app_space.dart';
import 'app_text.dart';
import 'museum_tokens.dart';

/// Hệ số phóng chiều cao hàng, do MÀN CHA đặt cho cả một cây con.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO LÀ INHERITED WIDGET, KHÔNG PHẢI MỘT THAM SỐ CỦA [AppRow]
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Các hàng của Poster do `gate_screen.dart` dựng, còn thứ BIẾT về hệ số lại là
/// [SignatureScreen] — cái khuôn bọc ngoài. Truyền bằng tham số thì mọi call
/// site phải tự nhớ đọc [DesignSize.verticalScale] rồi nhân đúng thứ tự, và
/// hàng "XONG" của màn Cảm ơn sẽ quên trong lần sửa đầu tiên. Hai màn khoảnh
/// khắc phải phóng BẰNG NHAU, cùng lý do đã đưa `gateTop` thành một hằng chung:
/// sự đối xứng phải là một tính chất, không phải một thoả thuận miệng.
///
/// KHÔNG CÓ TỔ TIÊN NÀO ⇒ 1.0. Đó là đường mặc định và là đường ĐÚNG cho ngăn
/// kéo: ở đó hàng nằm trong một danh sách cuộn, không phải là cả màn, nên nó
/// giữ đúng 58 của bản vẽ.
class RowScale extends InheritedWidget {
  final double scale;

  const RowScale({super.key, required this.scale, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RowScale>()?.scale ?? 1.0;

  @override
  bool updateShouldNotify(RowScale oldWidget) => oldWidget.scale != scale;
}

class AppRow extends StatelessWidget {
  /// Nhãn. Truyền chuỗi THƯỜNG — khi [lead] bật, widget tự viết hoa (luật
  /// "chữ hoa là thuộc tính của vai trò" ở đầu app_text.dart).
  final String label;

  /// Chữ trạng thái ở mép phải, trước dấu › (`.row .st`) — ví dụ hàng "Ngôn
  /// ngữ · Tiếng Việt" trong ngăn kéo. Null ⇒ không có.
  final String? status;

  final VoidCallback? onTap;

  /// Hàng DẪN ĐƯỜNG CHÍNH. Chỉ dùng khi màn có đúng MỘT đường đi tiếp:
  /// "THAM QUAN" ở Poster, "XONG" ở màn Cảm ơn.
  ///
  /// Cao hơn 8dp, chữ lớn hơn 1dp, tracking giãn gấp năm, và viết hoa. Không có
  /// màu nền nào — nó nổi bằng KHÔNG GIAN, đúng luật chung: thứ bậc do kích
  /// thước và khoảng trắng gánh, không do màu.
  ///
  /// ⚠ MỘT MÀN CHỈ ĐƯỢC CÓ MỘT. Hai hàng lead trong một màn là hai đường chính,
  /// tức không có đường nào chính.
  final bool lead;

  /// Ghi đè chuỗi cho screen reader. Mặc định (null) là `label`, cộng `status`
  /// nếu có.
  ///
  /// Tồn tại vì có chỗ mà nhãn nhìn thấy được KHÔNG đủ để phân biệt: hai mục
  /// "Bắt đầu tham quan" và "Chọn tuyến tham quan" nghe gần như nhau khi chỉ
  /// đọc tiêu đề, và câu mô tả — thứ mắt đọc được nhưng đã bị cắt khỏi hàng —
  /// là thứ phân biệt chúng.
  final String? semanticLabel;

  const AppRow({
    super.key,
    required this.label,
    this.status,
    this.onTap,
    this.lead = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // `onTap == null` ⇒ HÀNG TẮT, VÀ PHẢI NHÌN RA ĐƯỢC.
    //
    // Trước đây một hàng không có `onTap` trông y hệt một hàng bấm được: chạm
    // vào không xảy ra gì, và khách không có cách nào biết đó là chủ đích hay
    // là máy hỏng. Một lối đi bị khoá mà không nói ra thì tệ hơn hẳn một lối đi
    // bị ẩn.
    //
    // `ctaDisabled` chứ không phải `ink` pha alpha tự chế: token đó có sàn
    // tương phản 3:1 với `inkMuted`, được test hợp đồng canh — tức nó vẫn ĐỌC
    // ĐƯỢC, chỉ thôi mời gọi.
    final enabled = onTap != null;
    final ink = enabled ? t.ink : t.ctaDisabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? (status == null ? label : '$label. $status'),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          // KHÔNG GỢN SÓNG. Ripple là một vật thể M3 có tâm, có bán kính, có
          // thời gian lan — ba thứ mà ngôn ngữ này không có ở đâu khác (không
          // bo góc, không bóng, không chiều sâu). Thiết kế chỉ định nghĩa một
          // lớp nước phủ khi chạm, nên phản hồi ở đây là ĐỔI NỀN, không phải
          // một hình lan ra.
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          // `ink` @alpha CHÍNH LÀ `--wash-rgb` của bản vẽ: CSS phải khai báo
          // riêng một token wash (đen trên nền sáng, trắng trên nền tối) vì nó
          // không pha alpha lên biến được. Dart pha được, và `ink` đã đúng dấu
          // ở mọi preset theo định nghĩa. Một token ít đi.
          highlightColor: enabled
              ? t.ink.withValues(alpha: lead ? 0.22 : 0.12)
              : Colors.transparent,
          child: SizedBox(
            // CHIỀU CAO HÀNG = VÙNG BẤM. Không có padding nào bên trong nới
            // thêm vùng chạm, nên phóng con số này là phóng đúng thứ ngón tay
            // gặp — xem [RowScale] cho ai đặt hệ số và vì sao ngăn kéo không có.
            height: (lead ? AppSpace.rowLead : AppSpace.row) *
                RowScale.of(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lead ? label.toUpperCase() : label,
                      style: (lead ? AppText.rowLead : AppText.rowLabel)
                          .copyWith(color: ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: AppSpace.x4),
                    Text(status!,
                        style: AppText.meta.copyWith(color: t.inkFaint)),
                  ],
                  const SizedBox(width: AppSpace.x4),
                  AppChevron(
                      color: enabled
                          ? t.ink.withValues(alpha: 0.35)
                          : t.ctaDisabled),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dấu › — "có đường đi tiếp từ đây".
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO VẼ CHỨ KHÔNG DÙNG KÝ TỰ '›' NHƯ BẢN VẼ
/// ═══════════════════════════════════════════════════════════════════════════
///
/// CSS viết `content: "\203A"` vì trong trình duyệt đó là cách rẻ nhất. Ở đây
/// nó sẽ là một glyph của FONT HỆ THỐNG — tức hình dáng, độ dày nét và vị trí
/// trong line box do máy Android của bảo tàng quyết, không do ta. Ba hệ quả:
/// nét chevron sẽ không khớp độ dày 1.6 của bộ icon tab bar; căn dọc lệch theo
/// từng font; và ở `textScaler` 1.6× nó phóng to theo chữ trong khi nó KHÔNG
/// phải chữ — nó là một dấu hệ thống.
///
/// Vẽ tay cho ba thứ đó thành hằng số. Và nó dùng đúng ngữ pháp nét mà thiết kế
/// đã ra luật cho bộ icon: khung 24, nét 1.6, bo tròn hai đầu và góc nối, chỉ
/// nét — không tô đặc.
class AppChevron extends StatelessWidget {
  final Color color;

  /// Cạnh của khung vẽ. 24 là khung chuẩn của mọi icon trong app.
  final double size;

  const AppChevron({super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ChevronPainter(color)),
      );
}

class _ChevronPainter extends CustomPainter {
  final Color color;

  const _ChevronPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Toạ độ trong khung 24, rồi co theo cạnh thật — cùng cách bộ icon tab bar
    // được khai báo, nên đổi cỡ không đổi tỉ lệ nét.
    final k = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(9.4 * k, 5.6 * k)
      ..lineTo(15.8 * k, 12 * k)
      ..lineTo(9.4 * k, 18.4 * k);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
