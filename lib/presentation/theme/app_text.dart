// Destination: lib/presentation/theme/app_text.dart (REPLACES current)
//
// ═══════════════════════════════════════════════════════════════════════════
// KHÔNG STYLE NÀO KHAI BÁO `color`
// ═══════════════════════════════════════════════════════════════════════════
//
// Màu đến từ MuseumTokens, và mỗi call site phải tự chọn giữa hai họ:
//
//   Text(name, style: AppText.cardTitle.copyWith(color: t.inkOnImage))  // trên ảnh
//   Text(title, style: AppText.sheetTitle.copyWith(color: t.ink))       // trên nền
//
// Trông ồn hơn `AppText.cardTitle`, nhưng đó là ý đồ: light theme làm cho hai
// trường hợp trên KHÁC nhau, và compiler không thể chọn hộ. Một style mang sẵn
// màu sẽ âm thầm sai ở một trong hai chỗ.
//
// Với `Text` không copyWith, màu chảy xuống từ ThemeData.textTheme qua
// TextStyle.inherit — đó là màu `ink` mặc định của theme.
//
// ═══════════════════════════════════════════════════════════════════════════
// CHỮ HOA LÀ THUỘC TÍNH CỦA VAI TRÒ, KHÔNG PHẢI CỦA CHUỖI
// ═══════════════════════════════════════════════════════════════════════════
//
// Chỉ HAI style được viết hoa, và chúng là NHÃN HỆ THỐNG:
//
//     AppText.kicker    — nhãn mục / nhãn trạng thái
//     AppText.button    — nhãn nút
//
// Mọi thứ khác là NỘI DUNG và giữ nguyên chữ của bảo tàng: tên bảo tàng, tên
// khu, tên hiện vật, câu dẫn, chỉ dẫn.
//
// ── Vì sao có luật này ────────────────────────────────────────────────────
// Gate từng có kicker "HƯỚNG DẪN THAM QUAN TỰ ĐỘNG" và nó bị khai tử với lý
// do: "chữ hoa tiếng Việt có dấu + tracking rộng đọc lởm chởm". Lý do đó
// đúng — nhưng lúc đó nó chỉ được áp cho MỘT dòng, trong khi bốn chỗ khác
// vẫn viết hoa y hệt (kicker hero màn 3, _StaffCard, _NoneNearby, và
// museumName.toUpperCase()). Một lý lẽ chỉ áp cho một call site thì nó không
// phải lý lẽ, nó là khẩu vị của hôm đó.
//
// Đường phân đúng không phải "hoa hay không hoa" mà là NHÃN hay NỘI DUNG.
// "BẮT ĐẦU THAM QUAN" là app đang nói. "Bảo tàng Lịch sử Quốc gia" là bảo
// tàng đang nói — và ta không viết hoa tên riêng của người khác.
//
// ── Cách thi hành ─────────────────────────────────────────────────────────
// Widget SỞ HỮU VAI TRÒ tự gọi `.toUpperCase()`; call site truyền chuỗi
// thường. ĐỪNG viết hoa sẵn trong string literal.
//
// Trước luật này đã có hai lối làm song song, ngay trong cùng một file:
//     _BleNotReady:  title: 'CẦN QUYỀN BLUETOOTH'          // hoa sẵn
//     _SyncNotice:   title: 'Đã tải xong'.toUpperCase()    // hoa ở call site
// Hai lối làm = không có luật nào. Chuỗi hoa sẵn còn phá cả Semantics (screen
// reader có thể đánh vần từng chữ cái) và không dịch được sang ngôn ngữ không
// có khái niệm chữ hoa.
//
// ── Hệ quả ────────────────────────────────────────────────────────────────
// Chữ hoa SERIF không còn tồn tại ⇒ vấn đề "serif hoa tracking 0 vs sans hoa
// tracking .22em" tự biến mất, không cần token nào.
//
// ⚠ CÒN NỢ: `height: 1.32` của [museumName] được đo TRÊN chữ hoa ("BẢO TÀNG"),
// vì "chữ HOA có dấu là tệ nhất". Tiền đề đó vừa mất. GIỮ NGUYÊN 1.32 cho tới
// khi có người nhìn bằng mắt trên máy thật — đổi một con số hình học vì suy
// luận, không vì đo, là đúng cái bug file này đã dính ba lần.
//
// ═══════════════════════════════════════════════════════════════════════════
// CỠ CHỮ — đã sửa (xem commit "fix(a11y)")
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản trước lấy px từ mockup HTML nguyên xi: kicker 8.5, timeCode 9, stopMeta
// 9.5, zone-card meta 10. CSS px trên màn hình desktop cách mắt 60cm KHÔNG
// tương đương logical px trên điện thoại cầm cách mắt 30cm. Ngưỡng khuyến nghị
// cho chữ phụ là ~12sp, và khách bảo tàng có tỉ trọng người lớn tuổi cao.
//
// `height` của các tiêu đề serif đã nới HAI LẦN, và lần thứ hai xoá kết luận
// của lần thứ nhất:
//   • lần 1 (thời Playfair): 1.02 -> 1.10. Ở textScaler 1.3x, Playfair 28px
//     với height 1.02 cắt mất phần trên của dấu tiếng Việt (ấ, ầ, ế).
//   • lần 2 (sau khi đổi sang Cormorant): 1.10–1.15 -> 1.28–1.32. Con số của
//     lần 1 chết cùng Playfair — xem doc của AppFonts ngay dưới.
// Cả hai đều là bug thật, chỉ lộ khi bật cỡ chữ lớn của hệ thống.

import 'package:flutter/material.dart';

/// ⚠ FONT SERIF ĐÃ ĐỔI PLAYFAIR DISPLAY -> CORMORANT GARAMOND. Mọi comment
/// trong file này từng nhắc "Playfair" đều đã được sửa — nhưng quan trọng hơn
/// cái tên: TOÀN BỘ các con số fontSize/height dưới đây được ĐO trên Playfair,
/// nên kết luận của chúng không tự động còn đúng.
///
/// Hai font khác nhau ở đúng chỗ giết ta:
///   • x-height: Playfair rất cao, Cormorant rất thấp ⇒ cùng fontSize thì
///     Cormorant TRÔNG nhỏ hơn hẳn. (đã giết `stopName: 15`)
///   • extenders: Cormorant có ascender/descender dài kiểu Garamond ⇒ natural
///     line height lớn hơn Playfair ⇒ mọi `height` cũ đều quá chật.
///     (đã giết `height: 1.10–1.15` ở mọi style serif)
///
/// Bài học: đổi font KHÔNG phải đổi một dòng string. Nó vô hiệu hoá mọi con số
/// đã tinh chỉnh quanh font cũ. Lần sau đổi font, soát lại cả file này.
abstract final class AppFonts {
  static const String serif = 'CormorantGaramond';
  static const String sans = 'Inter';
}

abstract final class AppText {
  // ── serif titles (Cormorant Garamond) ────────────────────────────────────
  //
  // MỌI `height` DƯỚI ĐÂY VỪA ĐƯỢC NÂNG 1.10–1.15 -> 1.28–1.32.
  //
  // Vì sao: các giá trị cũ được đo trên Playfair Display. Cormorant Garamond
  // có extenders dài hơn, và tiếng Việt là trường hợp xấu nhất của chữ Latin —
  // dấu CHỒNG trên dấu (Ầ, Ế, Ộ, Ẫ) vượt lên trên cả cap-height. Chữ HOA có
  // dấu (`museumName` -> "BẢO TÀNG") là tệ nhất, nên nó được 1.32.
  //
  // RỦI RO THẬT KHÔNG PHẢI LÀ "CẮT CHỮ": Flutter không clip, nó để glyph tràn
  // khỏi line box. Hai hậu quả thật:
  //   1. CHỒNG CHỮ ở khối "Chào mừng / quý khách" — hai Text xếp cách nhau 0.
  //      Đuôi `g` của "mừng" và dấu sắc của `ý` trong "quý" đang lao vào nhau.
  //   2. KHE QUANG HỌC SAI: nếu line box không chứa nổi glyph, dấu mũ chọc lên
  //      trên nó ⇒ khe 12dp dưới vạch accent TRÔNG hẹp hơn 12. Mọi công căn
  //      lưới ở gate_screen được đo trên một hộp chữ nói dối.
  //
  // ⚠ ĐÁNH ĐỔI PHẢI NHÌN BẰNG MẮT: nâng height làm khối "Chào mừng / quý
  // khách" GIÃN RA ~5dp. Khối đó tight vì leading đang KHÔNG an toàn — không
  // thể vừa tight vừa an toàn từ cùng một con số. Nhìn rồi chọn; nếu vẫn muốn
  // tight, cách duy nhất là gộp hai dòng vào MỘT Text hai style (TextSpan) và
  // chỉnh height ở span, đừng hạ height về mức chật.

  /// Hero title của KHU TRƯNG BÀY — call site DUY NHẤT còn lại là `_ZoneHeroBar`
  /// (màn 3), sau khi Gate chuyển sang [welcomeTitle].
  ///
  /// (Doc cũ ở đây có ba comment chồng lên nhau, hai trong số đó mô tả
  /// [welcomeTitle], và comment thắng cuộc nói "32 vì hero giờ cao 80% màn
  /// hình" trong khi giá trị là 28. Đã gỡ hai comment mồ côi và sửa con số —
  /// 28 là giá trị thật, chưa từng có ai đo lại cho hero 80%.)
  ///
  /// ⚠ GIỐNG [welcomeSubTitle] TỪNG BYTE (serif/w600/28/1.28), VÀ ĐỪNG GỘP.
  ///
  /// Bản trước ghi ở đây: "nếu tới lần sửa sau chúng vẫn bằng nhau thì chúng là
  /// một." Câu đó SAI, và tiền lệ nằm ngay trong file này: [welcomeTitle] đã
  /// được CỐ Ý tách khỏi style này với lý do —
  ///
  ///     "Gate là màn duy nhất có ~55% không gian trống nên chịu được cỡ 34;
  ///      màn 3 dùng heroTitle 28 trên hero thì không. Đổi cỡ ở đây không được
  ///      ảnh hưởng màn 3."
  ///
  /// Dự án này đã chọn: MÀN KHÁC NHAU THÌ STYLE KHÁC NHAU, kể cả khi giá trị
  /// trùng. Hai style trùng byte nhưng có HAI LÝ DO ĐỔI khác nhau là HAI thứ —
  /// gộp chúng không phải khử trùng lặp, mà là tạo ra một khớp nối giả: sửa
  /// phụ đề của Gate sẽ âm thầm sửa tên khu ở màn 3.
  ///
  /// DRY nói về TRI THỨC, không nói về ký tự. Hai con số bằng nhau vì tình cờ
  /// thì không phải một tri thức bị lặp.
  ///
  /// (Ràng buộc thật của [welcomeSubTitle] nằm ở chỗ khác: nó phải nhỏ hơn
  /// [welcomeTitle] 34 để phân vai trong một câu bị bẻ hai dòng. Style NÀY
  /// không có ràng buộc đó — nó đứng một mình trên hero màn 3.)
  ///
  /// height 1.28 nới từ 1.02: xem khối doc "CỠ CHỮ" ở đầu file.
  static const TextStyle heroTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.28,
  );

  /// Tiêu đề màn chào (Gate) — CỐ Ý tách khỏi [heroTitle]: Gate là màn duy
  /// nhất có ~55% không gian trống nên chịu được cỡ 34; màn 3 dùng [heroTitle]
  /// 28 trên hero 250px thì không. Đổi cỡ ở đây không được ảnh hưởng màn 3.
  static const TextStyle welcomeTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.28,
  );

  /// Tên bảo tàng, góc trên-trái Gate.
  ///
  /// KHÔNG CÒN VIẾT HOA (luật ở đầu file): tên riêng của một tổ chức là NỘI
  /// DUNG, không phải nhãn giao diện. `.toUpperCase()` đã gỡ khỏi call site.
  ///
  /// ⚠ height 1.32 GIỮ NGUYÊN dù tiền đề của nó đã mất. Nó được chọn vì "chữ
  /// HOA có dấu (BẢO TÀNG) là tệ nhất, nên nó được 1.32". Giờ chuỗi là chữ
  /// thường, và 1.32 nhiều khả năng rộng hơn cần thiết. ĐỪNG hạ nó bằng suy
  /// luận: hạ height là đúng loại thao tác đã cắt dấu tiếng Việt hai lần
  /// trước. Đo trên máy, ở textScaler 1.6×, với một tên bảo tàng thật, rồi
  /// mới đổi.
  static const TextStyle museumName = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.32,
  );

  /// Dòng thứ hai của lời chào Gate ("quý khách"). MỘT câu, hai dòng, hai cỡ.
  ///
  /// Style DUY NHẤT trong file này từng không có doc — và điều đó đã đẻ ra một
  /// lỗi review: khi rà soát, người ta so 34/28 với một "phân cấp editorial hai
  /// vai, hai trọng lượng" mà không doc nào tuyên bố, rồi gọi khoảng cách giữa
  /// code và tài liệu-tưởng-tượng-đó là lỗi. Không có tài liệu thì phê bình chỉ
  /// còn là khẩu vị đội lốt phát hiện. Đây là tài liệu.
  ///
  /// RÀNG BUỘC THẬT, và chỉ có một: PHẢI NHỎ HƠN [welcomeTitle] (34). Hai dòng
  /// là một câu bị bẻ; cỡ giảm là thứ nói cho mắt biết dòng hai là phần TIẾP,
  /// không phải một tiêu đề mới. Bằng nhau thì thành hai tiêu đề; lớn hơn thì
  /// thành đảo ngữ.
  ///
  /// 34/28 (tỉ lệ 1.21) là con số ĐÃ ĐƯỢC NHÌN BẰNG MẮT trên máy thật với
  /// Cormorant. Đừng đổi nó bằng suy luận từ một thang tỉ lệ nào đó — thang tỉ
  /// lệ không biết x-height của font này.
  ///
  /// ⚠ KHÔNG PHẢI [heroTitle], dù trùng byte (serif/w600/28/1.28). Xem doc ở
  /// đó: trùng giá trị nhưng khác lý do đổi ⇒ khác thứ.
  static const TextStyle welcomeSubTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.28,
  );

  /// Tiêu đề cỡ vừa. HAI call site, cố ý dùng chung:
  ///   • thẻ zone (màn 2)
  ///   • tiêu đề trạng thái rỗng (màn 3) — xem `_NoneNearby`
  ///
  /// Không tách làm hai style: thang chữ của app đã có bảy style ở cỡ 12, và
  /// thêm một nấc serif-20 thứ hai chỉ vì tên khác nhau là cách một thang chết.
  ///
  /// ⚠ RÀNG BUỘC LIÊN MÀN: màn 2 CHƯA qua tái cấu trúc thị giác. Khi nó được
  /// làm, đổi style này sẽ đổi luôn trạng thái rỗng của màn 3 — mà ở đó nó
  /// đang giữ một quan hệ cụ thể (phải NHỎ HƠN heroTitle 28 để không tranh vai
  /// với tên khu). Soát cả hai chỗ, hoặc lúc đó mới tách.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.30,
  );

  /// Sheet title ("Khu vực của bạn").
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.28,
  );

  /// Player exhibit name.
  static const TextStyle playerTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.28,
  );

  /// Exhibit-list row name.
  /// Tên hiện vật trên hàng danh sách (màn 3).
  ///
  /// 15 -> 18: ĐÂY LÀ SÀN CỦA FONT, KHÔNG PHẢI SỞ THÍCH. Cormorant Garamond
  /// là một Garamond hiển thị: x-height rất thấp, nét rất mảnh, dựng cho cỡ
  /// >= 20. Ở 15px nó thôi là chữ đọc được và thành hoa văn — và đối tượng
  /// của app này lệch về khách lớn tuổi, đúng nhóm chịu thiệt nhất.
  ///
  /// 15 KHÔNG SAI KHI NÓ ĐƯỢC VIẾT RA — nó được đo trên Playfair Display
  /// (x-height cao, nét dày). Nó chết trong lần đổi font sang Cormorant mà
  /// không ai soát lại. Cùng con bug với `height: 1.12` bên dưới.
  ///
  /// Nếu buộc phải giữ 15 (hàng quá cao): PHẢI đổi sang AppFonts.sans w500.
  /// Không có phương án thứ ba — serif 15 ở font này là không đọc được.
  ///
  /// Hệ quả bố cục: hàng cao thêm ~6dp khi tên xuống 2 dòng. Chấp nhận —
  /// thumb 56 vẫn là mỏ neo, và tên hiện vật LÀ nội dung của hàng.
  static const TextStyle stopName = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.30,
  );


  // ── sans body (Inter) ────────────────────────────────────────────────────

  /// Nhãn mục / nhãn trạng thái. VAI TRÒ CHỮ HOA — widget sở hữu tự gọi
  /// `.toUpperCase()`, call site truyền chuỗi thường (xem luật ở đầu file).
  ///
  /// 8.5 -> 11. letterSpacing 2.42 = .22em CỦA CỠ 11.
  ///
  /// ⚠ ĐỪNG "SỬA" letterSpacing CHO CO THEO textScaler. Nó đã bị báo là bug
  /// một lần, và báo sai — giữ đoạn này để không ai tốn công báo lại.
  ///
  /// Flutter KHÔNG nhân letterSpacing với textScaler, chỉ nhân fontSize. Nên ở
  /// 1.6× cỡ chữ thành 17.6 mà tracking vẫn 2.42dp — tức .1375em thay vì .22em.
  /// Nghe như một tỉ lệ bị trôi. Nó không phải.
  ///
  /// OPTICAL SIZING: cỡ càng LỚN thì tracking càng phải HẸP. Chữ hoa 11px cần
  /// ~.22em để không dính; cùng chữ đó ở 17.6px mà vẫn .22em thì rời rạc — các
  /// chữ cái thôi đọc thành từ. Giá trị quang học nên có ở 17.6px là khoảng
  /// .12–.14em, và 2.42dp cố định cho ra đúng .1375em.
  ///
  /// Tức hành vi "không co" của Flutter TÌNH CỜ làm đúng optical sizing. Ép nó
  /// co theo textScaler là giữ .22em ở mọi cỡ — tức làm hỏng chữ ở cỡ lớn, cho
  /// đúng một tỉ lệ mà bản thân tỉ lệ đó không phải mục tiêu.
  ///
  /// Bài học của lần báo sai: `em` là cách VIẾT một quyết định typographic,
  /// không phải bản thân quyết định. Kiểm "em có giữ nguyên không" là đo bằng
  /// nhầm thước; câu hỏi đúng là "em có GIẢM theo cỡ không".
  static const TextStyle kicker = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 2.42,
  );

  /// Meta line trên card/hero. 11 -> 12.
  static const TextStyle meta = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.3,
  );

  /// Mô tả phụ dưới tiêu đề màn hình. Gom từ 3 TextStyle inline giống nhau.
  static const TextStyle sheetSub = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.4,
  );

  /// Đoạn hướng dẫn / trạng thái nhiều dòng (empty state, sync notice).
  static const TextStyle guidance = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.5,
  );

  /// Đoạn dẫn nhập của màn chào — chỉ dẫn quan trọng nhất khách sẽ đọc, nên
  /// KHÔNG dùng [guidance] (12/w300 đọc như chữ in nhỏ). w400 vì chữ sáng
  /// trên nền tối render mảnh hơn thực tế (halation).
  static const TextStyle lede = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.55,
  );

  /// Thân bài các mục dưới fold. Gom từ _bodyStyle private ở màn 4.
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 13,
    height: 1.7,
  );

  /// Exhibit-list row sub. 9.5 -> 12.
  static const TextStyle stopMeta = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.3,
  );

  /// Player artist line.  11 -> 12.
  static const TextStyle artist = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    fontSize: 12,
    height: 1.3,
  );

  /// Nhãn nút. VAI TRÒ CHỮ HOA — widget sở hữu tự gọi `.toUpperCase()`,
  /// call site truyền chuỗi thường (xem luật ở đầu file).
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 0.96,
  );

  /// Player time codes. 9 -> 12. Chúng là chữ số dày đặc, cỡ 9 gần như không
  /// đọc nổi khi cầm máy đi bộ.
  static const TextStyle timeCode = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}