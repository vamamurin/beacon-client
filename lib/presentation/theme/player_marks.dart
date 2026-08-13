// Destination: lib/presentation/theme/player_marks.dart
//
// HAI VẬT LIỆU CỦA VIỆC NGHE: dấu phát và thanh tiến độ.
//
// Chúng ở chung một file vì thiết kế dùng chúng thành CẶP ở hai chỗ khác nhau —
// phần dẫn của khu (màn danh sách hiện vật) và trình phát (màn chi tiết) — và
// cả hai lần đều là cùng hai vật liệu ấy, chỉ khác cỡ.
//
// ═══════════════════════════════════════════════════════════════════════════
// DẤU PHÁT LÀ MỘT NÉT, KHÔNG PHẢI MỘT CÁI NÚT
// ═══════════════════════════════════════════════════════════════════════════
//
// Đây là chỗ thiết kế đã sai ba lần rồi sửa, và lý lẽ đáng giữ nguyên văn: bản
// trước dán một nút có viền lên ảnh hiện vật, và nó sai ba lần cùng lúc —
//
//   · nút có VIỀN, mà ô kia vốn đã là một khung ảnh ⇒ khung trong khung;
//   · nút có MÀN CHẮN tối, tức đục một lỗ đen vào chính hiện vật cần xem;
//   · nút nặng ngang một hành động chính, trong khi hành động chính của ô là
//     chạm vào ảnh để MỞ hiện vật, không phải để nghe.
//
// Nên ở đây không có hộp nào. Chỉ một tam giác trần.
//
// THỨ BẬC DO CỠ GÁNH, KHÔNG DO HỘP — và con số này là một ràng buộc thật, không
// phải một thang trang trí. `10-menu.css` ghi rõ `.mcta` là *"ngoại lệ duy nhất
// còn nút có viền"* trong cả app; thêm một cái nút thứ hai là làm câu đó thành
// sai. Ba cỡ, một hình dáng:
//
//     [PlayMark.grid]   20  một hiện vật trong bảng ảnh
//     [PlayMark.zone]   28  phần dẫn của cả khu
//     [PlayMark.main]   34  hành động chính ở trình phát
//
// ═══════════════════════════════════════════════════════════════════════════
// TƯƠNG PHẢN LẤY TỪ BÓNG ĐỔ, KHÔNG LẤY TỪ MÀN CHẮN — GIỮ, ĐỪNG BỎ
// ═══════════════════════════════════════════════════════════════════════════
//
// Ảnh do bảo tàng nạp vào, sáng tối không đoán trước được. Một nét trắng mảnh
// biến mất trên ảnh sáng; cách chữa quen thuộc là đặt nó lên một khối tối, và
// khối tối đó lại đục một lỗ vào hiện vật.
//
// Bóng đổ giải được cả hai: trên vùng ảnh tối thì bóng vô hình, trên vùng ảnh
// sáng thì bóng tách nét ra khỏi nền. Nó chịu được cả hai đầu mà không trả giá
// bằng một khối tối cố định.
//
// ⚠ ĐÂY LÀ NGOẠI LỆ CÓ CHỦ ĐÍCH của quyết định D2 ("hiệu ứng phụ được phép
// bỏ"). Bóng ở đây KHÔNG phải trang trí — bỏ nó là mất khả năng nhìn thấy dấu
// phát trên một nửa số ảnh. Nó mang thông tin, nên nó ở lại.
//
// VÙNG CHẠM 44dp lấy bằng padding rồi ép nét về đúng vị trí: ngón tay có chỗ,
// mắt không thấy cái hộp nào.

import 'package:flutter/material.dart';

import 'museum_tokens.dart';

/// Hình của dấu — tam giác phát hay hai gạch tạm dừng.
enum PlayGlyph { play, pause }

/// Dấu phát/tạm dừng. Một nét trần, không hộp, không viền, không nền.
///
/// MÀU DO CALL SITE CHỌN, và đó không phải sự lười: dấu này xuất hiện trên hai
/// loại nền hoàn toàn khác nhau, và hai họ token khác nhau —
///
///   trên ẢNH TRẦN (ô lưới hiện vật)      `inkOnImage` @62%, đang phát thì
///                                        `accentOnImage`
///   trên NỀN TRANG (phần dẫn của khu, ở  `ink`, đang phát thì `accent`
///   đáy khối ảnh nơi veil đã kéo gần hết
///   về màu trang)
///
/// Chỗ dễ trượt nhất là cái thứ hai: cụm đó NẰM TRÊN một khối ảnh, nhưng ở
/// đúng vùng mà lớp veil đã tan gần hết về màu trang — nên nó dùng mực của
/// trang, không dùng họ on-image. Xem doc hai họ ở đầu museum_tokens.dart.
class PlayMark extends StatelessWidget {
  /// Một hiện vật trong bảng ảnh.
  static const double grid = 20;

  /// Phần dẫn của cả khu.
  static const double zone = 28;

  /// Hành động chính ở trình phát.
  static const double main = 34;

  /// Sàn vùng chạm. Nét được ép về giữa, phần còn lại là padding trong suốt.
  static const double _touch = 44;

  final PlayGlyph glyph;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  /// Nhãn cho screen reader ("Nghe phần dẫn của khu" / "Tạm dừng"). Bắt buộc:
  /// một tam giác trần không có chữ nào bên cạnh thì TalkBack không có gì để
  /// đọc, và đây là hành động chính của cả app.
  final String semanticLabel;

  const PlayMark({
    super.key,
    required this.glyph,
    required this.size,
    required this.color,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = size > _touch ? size : _touch;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: box,
          height: box,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(painter: _PlayMarkPainter(glyph, color)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayMarkPainter extends CustomPainter {
  final PlayGlyph glyph;
  final Color color;

  const _PlayMarkPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Toạ độ gốc trong khung 24 — chép thẳng từ path SVG của bản vẽ, rồi co
    // theo cạnh thật. Giữ nguyên con số để hai bên còn so được với nhau.
    final k = size.width / 24.0;
    final path = Path();

    switch (glyph) {
      case PlayGlyph.play:
        path
          ..moveTo(6.4 * k, 3.8 * k)
          ..lineTo(19.6 * k, 12 * k)
          ..lineTo(6.4 * k, 20.2 * k)
          ..close();
      case PlayGlyph.pause:
        final r = Radius.circular(1 * k);
        path
          ..addRRect(RRect.fromLTRBR(
              5.4 * k, 3.8 * k, 10.2 * k, 20.2 * k, r))
          ..addRRect(RRect.fromLTRBR(
              13.8 * k, 3.8 * k, 18.6 * k, 20.2 * k, r));
    }

    // Bóng TRƯỚC, nét SAU — xem khối doc "tương phản lấy từ bóng đổ" ở đầu
    // file. drop-shadow(0 1px 3px rgba(0,0,0,.6)) của bản vẽ.
    canvas.save();
    canvas.translate(0, 1 * k);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * k),
    );
    canvas.restore();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlayMarkPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// Thanh tiến độ — `.ptrack`.
///
/// KHÔNG HỘP, KHÔNG BO GÓC, KHÔNG NỀN NỔI. Một vạch 2dp, một vệt đã nghe, và
/// một đầu đọc 2×14. Ở màn chi tiết nó CHẠM HAI MÉP MÁY, không nằm trong lề:
/// nó là một đường kẻ của cái máy, không phải một dòng nội dung.
///
/// ⚠ HIỆU NĂNG — đọc trước khi đặt widget này vào cây.
/// Vạch này nhích vài lần mỗi giây. `AudioProvider.position` là một stream
/// RIÊNG, cố ý không đi qua `notifyListeners()`, đúng để chỉ một `StreamBuilder`
/// nhỏ quanh đây rebuild chứ không phải cả màn. Bọc widget này trong
/// StreamBuilder đó — đừng đọc vị trí ở tầng trên rồi truyền xuống, vì như thế
/// là kéo cả cây vào nhịp 1/10 giây.
///
/// Ở màn danh sách hiện vật, `--line` quá tối để nhìn ra khi nằm trên ảnh, nên
/// call site đó truyền [trackColor] khác. Đó là lý do tham số này tồn tại.
class ProgressTrack extends StatelessWidget {
  /// 0..1. Ngoài khoảng sẽ bị kẹp — một clip lỗi độ dài 0 không được phép làm
  /// vệt fill tràn ra ngoài vạch.
  final double value;

  /// Nền của vạch. Null ⇒ `line` (vạch trang trí trên nền trang).
  final Color? trackColor;

  /// Vệt đã nghe + đầu đọc. Null ⇒ `accent`.
  final Color? fillColor;

  /// Đầu đọc 2×14. Tắt ở những chỗ vạch chỉ báo cáo tiến độ mà không mời tua.
  final bool showHead;

  const ProgressTrack({
    super.key,
    required this.value,
    this.trackColor,
    this.fillColor,
    this.showHead = true,
  });

  /// Chiều cao của phần NHÌN THẤY. Đầu đọc cao 14 nên khối này cao 14 để nó
  /// không bị cắt; vạch nằm giữa.
  static const double height = 14;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // `.toDouble()` KHÔNG thừa: `num.clamp` trả về `num`, và `num` không lọt
    // vào `width:` được. Bỏ nó ra là lỗi biên dịch, không phải cảnh báo.
    final v = value.clamp(0.0, 1.0).toDouble();
    final track = trackColor ?? t.line;
    final fill = fillColor ?? t.accent;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(height: 2, width: w, color: track),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(height: 2, width: w * v, color: fill),
              ),
              if (showHead)
                Positioned(
                  // -1 để tâm đầu đọc rơi đúng vào mốc, không phải mép trái
                  // của nó — vạch rộng 2dp nên lệch nửa vạch là 1dp.
                  left: (w * v) - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: fill),
                ),
            ],
          );
        },
      ),
    );
  }
}
