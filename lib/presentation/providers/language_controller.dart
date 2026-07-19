// Destination: lib/presentation/providers/language_controller.dart (NEW)
//
// Feature B — NGUỒN SỰ THẬT DUY NHẤT cho ngôn ngữ đang chọn. Chính là thứ mà
// TODO trong ContentProvider chờ đợi ("đừng để hai nguồn sự thật cùng tồn tại").
//
// - ContentProvider đọc `.code` để resolve chữ (nội dung + chrome).
// - TourAudioController đọc `.code` (qua callback) để chọn track audio.
// Cả hai trỏ về CÙNG một object này (truyền bằng tham chiếu, không copy — một
// con trỏ, không tốn RAM đáng kể).
//
// PER-SESSION (theo quyết định sản phẩm): khách chọn ngôn ngữ ở Gate mỗi phiên;
// hết phiên (rời `touring`) reset về `fallback` của bảo tàng cho khách kế. Việc
// reset do injection gọi ở đúng cạnh phase. Controller sống TRONG graph (dựng
// lại theo bundle qua AppRestarter), nên nó luôn seed từ config mới nhất.
//
// Danh sách ngôn ngữ khả dụng = `config.languages` (từ manifest). Thêm ngôn ngữ
// nội dung = sửa manifest, KHÔNG đụng code — picker tự dựng từ danh sách này.

import 'package:flutter/foundation.dart';

class LanguageController extends ChangeNotifier {
  LanguageController({
    required List<String> available,
    required String fallback,
    String? initial,
  })  : _available = available.isEmpty ? <String>[fallback] : List.of(available),
        _fallback = fallback,
        _code = (initial != null && available.contains(initial))
            ? initial
            : fallback;

  List<String> _available;
  String _fallback;
  String _code;

  /// Mã ngôn ngữ đang chọn (vd 'vi', 'en', 'zh').
  String get code => _code;

  /// Ngôn ngữ mặc định của bảo tàng — luôn có bản dịch trong bundle.
  String get fallback => _fallback;

  /// Các ngôn ngữ khả dụng (từ manifest.languages), theo thứ tự manifest.
  List<String> get available => List.unmodifiable(_available);

  /// Khách chọn ngôn ngữ (ở Gate hoặc Settings). No-op nếu mã không hợp lệ hoặc
  /// trùng mã hiện tại (tránh notify thừa).
  void setCode(String code) {
    if (code == _code || !_available.contains(code)) return;
    _code = code;
    notifyListeners();
  }

  /// Hết phiên → về mặc định bảo tàng cho khách kế.
  void resetToFallback() {
    if (_code == _fallback) return;
    _code = _fallback;
    notifyListeners();
  }
}

/// Tên hiển thị của mã ngôn ngữ, dùng cho picker. Fallback về mã in hoa nếu
/// chưa có (thêm ngôn ngữ nội dung mới mà chưa kịp thêm tên vào đây vẫn hiện
/// được, chỉ là hiển thị mã thô — không vỡ). Thêm một dòng ở đây là đủ để có
/// tên đẹp; không cần build lại logic.
String languageDisplayName(String code) {
  const names = <String, String>{
    'vi': 'Tiếng Việt',
    'en': 'English',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'ru': 'Русский',
    'th': 'ไทย',
    'km': 'ភាសាខ្មែរ',
    'lo': 'ລາວ',
  };
  return names[code] ?? code.toUpperCase();
}