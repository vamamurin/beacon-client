// Destination: lib/presentation/theme/tab_icons.dart
//
// NĂM ICON CỦA TAB BAR — vẽ tay, không dùng Material Icons.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO VẼ CHỨ KHÔNG LẤY TỪ BỘ CÓ SẴN
// ═══════════════════════════════════════════════════════════════════════════
//
// Không phải vì Material Icons xấu. Vì hai trong năm icon có sẵn đều SAI NGHĨA,
// và thiết kế đã bác chúng bằng tên:
//
//   "Sơ đồ"  từng vẽ một người đang đi bộ  → đó là "đi bộ", không phải "sơ đồ"
//   "Gợi ý"  từng vẽ một trái tim          → trái tim là "yêu thích", không
//                                            phải "chọn riêng cho bạn"
//
// Và một lý do thứ hai, mạnh hơn: bộ Material tô đặc/nét-mảnh trộn lẫn, trong
// khi app này có một ngữ pháp nét duy nhất mà `AppChevron` và nút ☰ đã theo.
// Lấy năm icon từ một hệ khác vào là để năm vật thể nói một giọng khác.
//
// ═══════════════════════════════════════════════════════════════════════════
// LUẬT VẼ — để sau này thêm tab mới không bị lạc đàn
// ═══════════════════════════════════════════════════════════════════════════
//
//   · khung 24, nét 1.6, bo tròn hai đầu VÀ các góc nối;
//   · CHỈ NÉT, không tô đặc — cùng ngữ pháp với ‹ và ☰;
//   · mỗi icon là một VẬT nhìn ra được ở 22px, không phải một khái niệm;
//   · năm bóng dáng phải khác nhau KHI NHEO MẮT:
//       tam giác · vòng cung · hình chữ nhật gấp · ngôi sao · hai trang sách.
//
// Điều kiện cuối là điều kiện khó nhất và là điều kiện đáng giữ nhất: khách
// bảo tàng liếc thanh này trong nửa giây, dưới ánh sáng kém, thường là người
// lớn tuổi. Họ nhận ra BÓNG, không đọc CHI TIẾT.
//
// Toạ độ chép thẳng từ `parts/tabbar.html`. Giữ nguyên con số để còn so được
// với bản vẽ; mọi phép co giãn đi qua hệ số `k`.

import 'package:flutter/material.dart';

/// Năm đích cấp một của app. Thứ tự ở đây LÀ thứ tự trên thanh.
enum ShellTab {
  /// Hub — dẫn tới gần như mọi nơi. Icon: mặt tiền bảo tàng (trán tường + ba
  /// cột). KHÔNG dùng hình ngôi nhà (nói "nhà ở") và KHÔNG dùng ba vạch ngang
  /// (đã là nút ☰ ở thanh trên — trùng nghĩa ngay trong cùng một màn).
  home,

  /// Màn khu vực — nơi tiếng đang phát, một chạm là về. Icon: tai nghe, vì cả
  /// app xoay quanh việc nghe.
  tour,

  /// Sơ đồ tầng. Icon: tờ bản đồ gấp ba, hai nếp gấp.
  map,

  /// Khu gần bạn mà chưa ghé. Icon: một tia lớn và một tia nhỏ — ngôi sao BỐN
  /// cánh là quy ước cho "chọn riêng cho bạn"; ngôi sao NĂM cánh sẽ đọc thành
  /// đánh giá, mà màn Tổng kết đã dùng sao cho đúng việc đó rồi.
  foryou,

  /// Cách dùng máy. Icon: sách mở. Dấu `?` nói "trợ giúp" — nghĩa rộng hơn, bao
  /// cả việc gọi người, mà việc đó thuộc quầy lễ tân chứ không thuộc cái máy.
  guide,
}

/// Icon của một tab. Cỡ mặc định 22 là cỡ trên thanh.
class TabIcon extends StatelessWidget {
  final ShellTab tab;
  final Color color;
  final double size;

  const TabIcon({
    super.key,
    required this.tab,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _TabIconPainter(tab, color)),
      );
}

class _TabIconPainter extends CustomPainter {
  final ShellTab tab;
  final Color color;

  const _TabIconPainter(this.tab, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * k, y * k);

    switch (tab) {
      case ShellTab.home:
        // Trán tường + ba cột + bệ.
        canvas.drawPath(
          Path()
            ..moveTo(3.2 * k, 10.2 * k)
            ..lineTo(12 * k, 4.6 * k)
            ..lineTo(20.8 * k, 10.2 * k)
            ..close(),
          paint,
        );
        for (final x in <double>[7, 12, 17]) {
          canvas.drawLine(p(x, 12.6), p(x, 18.2), paint);
        }
        canvas.drawLine(p(4.4, 18.8), p(19.6, 18.8), paint);

      case ShellTab.tour:
        // Vòng cung + hai chụp tai.
        canvas.drawPath(
          Path()
            ..moveTo(4.4 * k, 15.2 * k)
            ..lineTo(4.4 * k, 12.4 * k)
            ..arcToPoint(p(19.6, 12.4),
                radius: Radius.circular(7.6 * k), clockwise: true)
            ..lineTo(19.6 * k, 15.2 * k),
          paint,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(2.6 * k, 14.2 * k, 7.2 * k, 20.8 * k,
              Radius.circular(2.1 * k)),
          paint,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(16.8 * k, 14.2 * k, 21.4 * k, 20.8 * k,
              Radius.circular(2.1 * k)),
          paint,
        );

      case ShellTab.map:
        // Tờ bản đồ gấp ba.
        canvas.drawPath(
          Path()
            ..moveTo(9.2 * k, 4.4 * k)
            ..lineTo(3.4 * k, 6.8 * k)
            ..lineTo(3.4 * k, 19.6 * k)
            ..lineTo(9.2 * k, 17.2 * k)
            ..lineTo(14.8 * k, 19.6 * k)
            ..lineTo(20.6 * k, 17.2 * k)
            ..lineTo(20.6 * k, 4.4 * k)
            ..lineTo(14.8 * k, 6.8 * k)
            ..close(),
          paint,
        );
        canvas.drawLine(p(9.2, 4.4), p(9.2, 17.2), paint);
        canvas.drawLine(p(14.8, 6.8), p(14.8, 19.6), paint);

      case ShellTab.foryou:
        // Tia lớn + tia nhỏ, bốn cánh.
        canvas.drawPath(
          Path()
            ..moveTo(13.4 * k, 3.4 * k)
            ..lineTo(15.1 * k, 8.1 * k)
            ..lineTo(19.8 * k, 9.8 * k)
            ..lineTo(15.1 * k, 11.5 * k)
            ..lineTo(13.4 * k, 16.2 * k)
            ..lineTo(11.7 * k, 11.5 * k)
            ..lineTo(7 * k, 9.8 * k)
            ..lineTo(11.7 * k, 8.1 * k)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6.5 * k, 14.2 * k)
            ..lineTo(7.5 * k, 16.9 * k)
            ..lineTo(10.2 * k, 17.9 * k)
            ..lineTo(7.5 * k, 18.9 * k)
            ..lineTo(6.5 * k, 21.6 * k)
            ..lineTo(5.5 * k, 18.9 * k)
            ..lineTo(2.8 * k, 17.9 * k)
            ..lineTo(5.5 * k, 16.9 * k)
            ..close(),
          paint,
        );

      case ShellTab.guide:
        // Sách mở: hai trang cong, gáy ở giữa.
        canvas.drawPath(
          Path()
            ..moveTo(12 * k, 7.6 * k)
            ..cubicTo(10.1 * k, 6 * k, 7.3 * k, 5.4 * k, 3.8 * k, 5.4 * k)
            ..lineTo(3.8 * k, 17.4 * k)
            ..cubicTo(7.3 * k, 17.4 * k, 10.1 * k, 18 * k, 12 * k, 19.6 * k)
            ..cubicTo(13.9 * k, 18 * k, 16.7 * k, 17.4 * k, 20.2 * k, 17.4 * k)
            ..lineTo(20.2 * k, 5.4 * k)
            ..cubicTo(16.7 * k, 5.4 * k, 13.9 * k, 6 * k, 12 * k, 7.6 * k)
            ..close(),
          paint,
        );
        canvas.drawLine(p(12, 7.6), p(12, 19.6), paint);
    }
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.tab != tab || old.color != color;
}
