// Destination: lib/presentation/theme/on_image_text.dart
//
// CHỮ NẰM TRÊN ẢNH TRẦN — ba cách làm nó đọc được, để so bằng mắt trên máy.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO FILE NÀY TỒN TẠI
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản thiết kế giải bài toán "chữ trên ảnh" bằng một lớp veil phủ kín ảnh. Cách
// đó có một lỗi mà chính bản vẽ không thấy, vì nó được cân khi app còn MỘT
// preset tối duy nhất:
//
//     phủ TỐI  → tạo chiều sâu, ảnh vẫn là ảnh, chữ nổi lên
//     phủ SÁNG → chỉ là sương mù, ảnh bạc màu, mà chữ trắng còn khó đọc hơn
//
// Từ khi giấy thành preset mặc định, `veil` tan vào `surface` nghĩa là nó RÓT
// MÀU GIẤY lên ảnh. Nên veil đã bị gỡ ở màn Khu vực, màn 4b và hero Menu.
//
// Bỏ veil thì bài toán quay lại: một tấm ảnh tư liệu SÁNG MÀU sẽ nuốt chữ
// trắng. File này là cách giải thay thế — xử lý ở CHỮ chứ không ở ẢNH. Ưu điểm
// quyết định: nó chỉ tốn diện tích đúng bằng mấy con chữ, thay vì phủ lên toàn
// bộ bức ảnh mà bảo tàng vất vả chọn.
//
// ═══════════════════════════════════════════════════════════════════════════
// BA CÁCH, VÀ CHỈ MẮT MỚI CHỌN ĐƯỢC
// ═══════════════════════════════════════════════════════════════════════════
//
//   halo    Bóng đổ mềm, TỐI, toả đều quanh nét chữ. Trên vùng ảnh tối thì bóng
//           vô hình; trên vùng sáng thì nó tách nét chữ ra khỏi nền. Đây chính
//           là cách [PlayMark] đã dùng cho dấu phát từ trước — tức nó ĐÃ nằm
//           trong từ vựng của app, không phải một vật liệu mới.
//
//   outline Viền nét mảnh ôm sát chữ. Đọc được ở mọi nền, kể cả ảnh rối. Cái
//           giá: nó là một ĐƯỜNG KẺ, và một đường kẻ quanh chữ serif làm chữ
//           nặng và cứng hơn — dễ đọc ra "chữ dán lên ảnh" thay vì "chữ thuộc
//           về bức ảnh".
//
//   none    Không xử lý. Đúng khi bên dưới đã có nền đặc (thanh trên có màn
//           chắn riêng, hai màn khoảnh khắc có veil tối).
//
// ⚠ KHÔNG CHỌN BẰNG SUY LUẬN. Cả ba phụ thuộc vào ẢNH THẬT của bảo tàng, và ảnh
// đó thay đổi. Đổi [OnImageText.mode] rồi nhìn trên máy với ít nhất một ảnh
// TỐI và một ảnh SÁNG.

import 'package:flutter/material.dart';

enum OnImageMode { none, halo, outline }

/// Chữ đặt trên ảnh chưa bị phủ.
///
/// Dùng thay `Text` ở những chỗ chữ ngồi thẳng trên ảnh: tiêu đề hero Menu, tên
/// khu, tên khu bên cạnh. KHÔNG dùng ở chỗ chữ ngồi trên nền trang.
class OnImageText extends StatelessWidget {
  /// CÔNG TẮC DUY NHẤT ĐỂ THỬ. Đổi một chỗ này là đổi mọi chữ-trên-ảnh của cả
  /// app cùng lúc, nên hai lần chạy thử so được với nhau — chỉnh lẻ từng màn
  /// thì mỗi màn thành một biến thể và không kết luận được gì.
  static const OnImageMode mode = OnImageMode.halo;

  /// Độ toả của lớp bóng RỘNG NHẤT. Ba lớp còn lại suy ra từ nó.
  ///
  /// ⚠ ĐÃ SIẾT TỪ 12 XUỐNG 10 (16/08/2026) sau khi nhìn trên máy: trên ảnh có
  /// nhiều đốm trắng nhỏ, một quầng rộng và nhạt bị chính các đốm ấy xuyên qua
  /// nên nét chữ vẫn lẫn. Thứ cứu được chỗ đó không phải toả RỘNG hơn mà là
  /// đậm hơn và SÁT hơn — xem [haloAlpha].
  static const double haloBlur = 10;

  /// Độ đậm của lớp trong cùng. Đây là con số quyết định "nét" hay "mờ".
  static const double haloAlpha = 0.88;

  /// Bề dày viền. 1.6 là độ dày nét của cả bộ icon trong app — dùng lại để viền
  /// chữ không thành một độ dày thứ hai không ai đo.
  static const double outlineWidth = 1.6;

  final String data;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  const OnImageText(
    this.data, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case OnImageMode.none:
        return _text(style);

      case OnImageMode.halo:
        // BA lớp bóng chồng nhau, không phải một. Một bóng đơn phải chọn giữa
        // "toả đủ xa để tách khỏi nền" và "sát đủ đậm để giữ mép chữ", và không
        // giá trị nào làm được cả hai:
        //
        //   rộng + nhạt   dựng một vùng tối quanh cụm chữ, tách nó khỏi ảnh
        //   vừa           lấp khoảng giữa, để không thấy hai vòng rời nhau
        //   sát + đậm     ôm lấy mép nét — đây là lớp làm chữ NÉT
        //
        // Lớp thứ ba là lớp vừa được thêm: trên ảnh có đốm trắng nhỏ, hai lớp
        // ngoài bị các đốm ấy xuyên qua, và chỉ một vòng tối sát mép mới giữ
        // được nét chữ.
        return _text(style.copyWith(shadows: [
          Shadow(
            color: const Color(0xFF000000).withValues(alpha: haloAlpha * 0.6),
            blurRadius: haloBlur,
          ),
          Shadow(
            color: const Color(0xFF000000).withValues(alpha: haloAlpha * 0.8),
            blurRadius: haloBlur * 0.4,
          ),
          Shadow(
            color: const Color(0xFF000000).withValues(alpha: haloAlpha),
            blurRadius: haloBlur * 0.15,
          ),
        ]));

      case OnImageMode.outline:
        // Viền vẽ TRƯỚC, ruột vẽ SAU — hai `Text` chồng nhau, không phải một
        // `Text` có `foreground` stroke: stroke một mình cho ra chữ RỖNG RUỘT.
        //
        // Hai lớp phải dùng CÙNG maxLines/overflow, nếu không lớp dưới xuống
        // dòng khác lớp trên và viền lệch khỏi ruột.
        return Stack(
          children: [
            _text(style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = outlineWidth
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF000000).withValues(alpha: 0.72),
            )),
            _text(style),
          ],
        );
    }
  }

  Widget _text(TextStyle s) =>
      Text(data, style: s, maxLines: maxLines, overflow: overflow);
}
