// Destination: lib/presentation/widgets/signature_screen.dart
//
// KHUÔN CỦA HAI MÀN "KHOẢNH KHẮC" — Poster (cổng vào) và Cảm ơn (tiễn khách).
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO HAI MÀN NÀY DÙNG CHUNG MỘT KHUÔN THAY VÌ MỖI MÀN TỰ DỰNG
// ═══════════════════════════════════════════════════════════════════════════
//
// Chúng là một CẶP ĐỐI XỨNG: một cái mở cửa, một cái tiễn khách. Khách phải
// nhận ra mình đã quay về đúng nơi bắt đầu — và nhận ra được thì cụm chữ phải
// rơi đúng MỘT CHỖ trên cả hai màn, với đúng một khuôn chữ.
//
// Nếu hai màn tự dựng, "đúng một chỗ" trở thành hai con số gõ ở hai file, và
// chúng sẽ lệch nhau ở lần chỉnh đầu tiên. Ở đây chúng đọc chung
// [DesignSize.gateTop], nên sự đối xứng là một TÍNH CHẤT chứ không phải một thoả
// thuận miệng.
//
// Cặp chữ 22/48 ([AppText.posterKicker] / [AppText.posterTitle]) chỉ được dùng
// ở đúng hai chỗ này. Mọi màn ở giữa là trang CÓ NỘI DUNG, không phải khoảnh
// khắc.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI HÒN ĐẢO LUÔN TỐI
// ═══════════════════════════════════════════════════════════════════════════
//
// Cả hai màn giữ bộ token TỐI ở MỌI theme — như bìa một cuốn sách vẫn tối
// trong khi ruột sách vẫn là giấy trắng. Lý do không phải thẩm mỹ: ở đây bức
// ảnh CHÍNH LÀ cái màn, chữ nằm TRONG ảnh chứ không nằm trên trang. Lật chúng
// sang preset sáng thì lớp veil (vốn tan vào `surface`) sẽ LÀM SÁNG đáy ảnh, và
// cụm tiêu đề rơi xuống đúng vùng đó — mất hẳn.
//
// Cách làm khai báo lại token ngay tại khối, KHÔNG viết luật riêng cho từng
// widget — y hệt cách CSS làm với `.gate, .backdrop-screen`. Nhờ vậy mọi thứ
// bên trong (kể cả [AppRow], vốn đọc `context.tokens`) tự chạy đúng mà không
// widget nào phải biết mình đang ở đảo hay ở đất liền.

import 'package:flutter/material.dart';

import 'package:beacon_client/presentation/theme/app_rule.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';

/// Màn nào trong hai màn. Nó chọn CẢ lớp phủ LẪN nhịp dọc, vì hai thứ đó là
/// hai mặt của cùng một câu hỏi: bức ảnh ở đây đang làm việc gì.
///
/// ⚠ HAI MÀN KHÔNG DÙNG CHUNG NHỊP DỌC, và tôi từng cho chúng dùng chung. Bản
/// vẽ ghi rõ hai bộ số khác nhau:
///
///     Poster    tbig ─10─ divider ─34─ hàng
///     Cảm ơn    tbig ─20─ divider ─20─ câu dặn dò
///
/// Poster kéo divider SÁT tiêu đề rồi mở một khoảng rộng trước các hàng: vạch
/// đóng cụm chữ lại, khoảng trống 34 tách "đây là ai" khỏi "đi vào bằng đường
/// nào". Màn Cảm ơn cân đối 20/20 vì cả ba khối là một lời chào liền mạch,
/// không có thao tác nào chen vào.
enum SignatureKind {
  /// Ảnh vẫn là NỘI DUNG. Đỉnh hơi tối để chữ trạng thái của hệ thống đọc được,
  /// rồi MỞ RA gần như trong suốt ở 22% — đó là vùng bức ảnh được nhìn — trước
  /// khi đóng dần xuống đáy nơi cụm chữ và các hàng ngồi.
  poster,

  /// Ảnh chỉ còn làm NỀN cho chữ. Tối đều từ trên xuống, đậm hơn hẳn. Không có
  /// cửa sổ nào để nhìn ảnh, vì lúc này không còn gì để mời chào.
  farewell;

  /// Khe giữa dòng chữ lớn và vạch 92.
  double get titleToDivider => this == poster ? 10 : 20;

  /// Khe dưới vạch 92 — trước hàng thao tác (Poster) hoặc trước câu dặn dò
  /// (Cảm ơn).
  double get dividerToBody => this == poster ? 34 : 20;
}

/// Khung của một màn "khoảnh khắc". Xem chú giải đầu file.
class SignatureScreen extends StatelessWidget {
  /// Đường dẫn ảnh nền đã giải trong bundle. `null` ⇒ gradient dự phòng của
  /// [HeroImage] — vẫn tối, nên chữ trắng vẫn đọc được.
  final String? imagePath;

  final SignatureKind kind;

  /// Dòng nhỏ 22 ("Bảo tàng" / "Cảm ơn").
  final String kicker;

  /// Dòng lớn 48 (tên bảo tàng / "quý khách").
  final String title;

  /// Câu dặn dò dưới divider. Null ⇒ không có (màn Poster).
  final String? lede;

  /// Các hàng thao tác nằm NGAY TRONG cụm chữ, dưới divider. Chúng TRÀN HẾT bề
  /// ngang, nên khối này không có lề ngang — lề đi theo từng khối chữ.
  final List<Widget> rows;

  /// Hàng ghim ở ĐÁY màn (màn Cảm ơn). Poster để trống: ở đó "Tham quan" thuộc
  /// về cụm chữ, vì nó là câu tiếp theo của lời mời chứ không phải một nút kết.
  final Widget? bottom;

  /// Dòng "Powered by" ở chân màn.
  final bool poweredBy;

  const SignatureScreen({
    super.key,
    required this.imagePath,
    required this.kind,
    required this.kicker,
    required this.title,
    this.lede,
    this.rows = const [],
    this.bottom,
    this.poweredBy = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    // HÒN ĐẢO LUÔN TỐI — xem chú giải đầu file. Khai báo lại cả bộ token, không
    // vá từng màu: mọi widget con đọc `context.tokens` sẽ tự đúng.
    return Theme(
      data: base.copyWith(extensions: const <ThemeExtension<dynamic>>[
        MuseumTokens.dark,
      ]),
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ẢNH CHẠM CẢ BỐN MÉP MÁY, kể cả sau thanh trạng thái. Đây là luật
          // chung của app: màn nào có ảnh nền thì ảnh chạm mép trên — nếu để nó
          // rơi xuống dưới vùng an toàn, ảnh thành một dải kẹp giữa hai vùng
          // đen và cả màn thôi là một tấm áp phích.
          HeroImage(
            filePath: imagePath,
            veil: _gradient(t),
            cacheWidth: (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
          ),

          // CỤM CHỮ NEO TUYỆT ĐỐI, không căn giữa bằng flex.
          //
          // Bản trước của màn Cảm ơn dùng hai ô đệm `Spacer()`, tức vị trí cụm
          // chữ do ĐỘ DÀI CÂU DẶN DÒ quyết định: câu một dòng thì nó tụt xuống,
          // câu bốn dòng thì trồi lên. Không ai thiết kế như vậy — đó là tác
          // dụng phụ. Neo tuyệt đối cho cụm chữ đứng im ở một chỗ với mọi độ
          // dài nội dung, và đứng đúng chỗ của màn kia.
          Positioned(
            top: DesignSize.gateTop,
            left: 0,
            right: 0,
            child: _Titles(
              kind: kind,
              kicker: kicker,
              title: title,
              lede: lede,
              rows: rows,
            ),
          ),

          if (bottom != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x12),
                  child: bottom,
                ),
              ),
            ),

          if (poweredBy)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _PoweredBy()),
            ),
        ],
      ),
    );
  }

  /// Veil dựng từ `surface` CỦA CHÍNH PRESET ĐANG DÙNG — ở đây luôn là preset
  /// tối, vì widget này là một hòn đảo.
  ///
  /// Đó chính là ngữ nghĩa của `--veil-rgb` trong bản vẽ: nó *luôn bằng*
  /// `--surface`, để đáy một khối ảnh bao giờ cũng chảy liền vào nền trang.
  /// CSS phải khai báo nó thành một token riêng vì không pha alpha lên biến
  /// được; ở đây `Color.withValues` làm thẳng.
  LinearGradient _gradient(MuseumTokens t) {
    final s = t.surface;
    return switch (kind) {
      SignatureKind.poster => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            s.withValues(alpha: 0.46),
            s.withValues(alpha: 0.04),
            s.withValues(alpha: 0.72),
            s.withValues(alpha: 0.98),
          ],
          stops: const [0.0, 0.22, 0.58, 1.0],
        ),
      SignatureKind.farewell => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            s.withValues(alpha: 0.74),
            s.withValues(alpha: 0.88),
            s.withValues(alpha: 0.97),
          ],
          stops: const [0.0, 0.46, 1.0],
        ),
    };
  }
}

class _Titles extends StatelessWidget {
  final SignatureKind kind;
  final String kicker;
  final String title;
  final String? lede;
  final List<Widget> rows;

  const _Titles({
    required this.kind,
    required this.kicker,
    required this.title,
    required this.lede,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const pad = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // LỀ ĐI THEO TỪNG KHỐI, không theo cả cột — vì các hàng bên dưới phải
        // tràn hết bề ngang. Bản vẽ diễn đạt điều này bằng một lề âm đúng bằng
        // gutter rồi pad lại; ở đây chỉ cần không pad cột.
        Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kicker,
                  style: AppText.posterKicker
                      .copyWith(color: t.ink.withValues(alpha: 0.68))),
              // `.tsmall { margin-bottom: 8px }`
              const SizedBox(height: AppSpace.x2),
              Text(title,
                  style: AppText.posterTitle.copyWith(color: t.ink)),
              SizedBox(height: kind.titleToDivider),
              const AppDivider(),
              if (lede != null) ...[
                SizedBox(height: kind.dividerToBody),
                Text(lede!,
                    style: AppText.lede.copyWith(color: t.inkMuted)),
              ],
            ],
          ),
        ),
        if (rows.isNotEmpty) ...[
          SizedBox(height: kind.dividerToBody),
          ...rows,
        ],
      ],
    );
  }
}

class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Text(
        'Powered by Tapama'.toUpperCase(),
        textAlign: TextAlign.center,
        style: AppText.kicker.copyWith(
          color: t.ink.withValues(alpha: 0.36),
          fontSize: 10,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
