// Destination: lib/presentation/providers/content_provider.dart (NEW)
//
// Cửa DUY NHẤT để tầng UI đọc nội dung tham quan. Trước đây mỗi màn hình tự
// `context.read<AppGraph>()` rồi thò tay vào `graph.repository` — composition
// root rò rỉ xuống tận widget, khiến không màn hình nào widget-test được nếu
// không dựng cả pipeline BLE + audio + power.
//
// Provider này trả lời đúng MỘT loại câu hỏi: "hiển thị chữ nào, ảnh nào?".
// Nó KHÔNG biết gì về beacon, session, hay audio. Nếu bạn thấy mình muốn thêm
// một getter chẳng liên quan gì đến nội dung vào đây, đó là dấu hiệu cần một
// provider khác — không phải một getter khác.
//
// NGÔN NGỮ: đây là nơi duy nhất biết `LocalizedText.resolve()` nhận HAI tham
// số (ngôn ngữ người dùng, ngôn ngữ dự phòng của bảo tàng). Widget gọi
// `content.text(zone.name)` và không cần biết cơ chế fallback tồn tại. Trước
// refactor này, mọi call site đều gọi `resolve(lang, lang)` với cùng một
// nguồn — tức là cơ chế fallback đã được trả tiền nhưng chưa bao giờ chạy.
//
// Là ChangeNotifier dù hôm nay chưa bao giờ notify: khi màn hình Cài đặt cho
// phép đổi ngôn ngữ runtime, chỉ cần `_language = x; notifyListeners()` và mọi
// widget đang `watch` sẽ vẽ lại. Nếu để plain Provider, cả 3 màn hình sẽ phải
// đổi từ `read` sang `watch` ở thời điểm đó — đắt hơn nhiều so với chi phí
// bằng 0 của việc `watch` một notifier không bao giờ bắn.

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/localized_text.dart';
import 'package:beacon_client/domain/models/zone_info.dart';

/// Chuyển đường dẫn tương đối trong bundle (từ manifest) thành đường dẫn file
/// tuyệt đối cho HeroImage, hoặc null khi không resolve được (mock / chưa có
/// bundle). Injected để UI không phải đoán kiểu cụ thể của repository.
typedef ImagePathResolver = String? Function(String bundleRelativePath);

class ContentProvider extends ChangeNotifier {
  ContentProvider({
    required IZoneRepository repository,
    required ImagePathResolver imagePathResolver,
  })  : _repo = repository,
        _imagePath = imagePathResolver;

  final IZoneRepository _repo;
  final ImagePathResolver _imagePath;

  // ── ngôn ngữ ──────────────────────────────────────────────────────────────

  /// Ngôn ngữ mặc định của bảo tàng, đảm bảo luôn có bản dịch trong bundle.
  String get fallbackLanguage => _repo.config?.fallbackLanguage ?? 'vi';

  /// Ngôn ngữ người dùng chọn.
  ///
  /// TODO(settings): hiện trả về fallback, nên [text] vẫn resolve y hệt hành vi
  /// cũ (không đổi gì). Khi màn hình Cài đặt ra đời, đây thành `_userLanguage`
  /// với một setter gọi notifyListeners(). CÙNG LÚC ĐÓ, TourAudioController
  /// phải đọc từ cùng nguồn này — hôm nay cả hai cùng đọc repository.config nên
  /// đồng bộ tự nhiên, nhưng khi tách ra sẽ cần một LanguageStore chung inject
  /// vào cả hai. Đừng để hai nguồn sự thật cùng tồn tại.
  String get language => fallbackLanguage;

  /// Resolve một LocalizedText theo đúng thứ tự ưu tiên. Widget dùng cái này,
  /// KHÔNG gọi `resolve()` trực tiếp — đó là cách giữ quy tắc fallback ở đúng
  /// một chỗ.
  String text(LocalizedText value) => value.resolve(language, fallbackLanguage);

  /// Biến thể cho các trường tuỳ chọn (meaning, museumName...).
  String? textOrNull(LocalizedText? value) =>
      value == null ? null : text(value);

  // ── tra cứu nội dung ──────────────────────────────────────────────────────

  /// O(1). Null cho major không tồn tại HOẶC khi bundle chưa warm.
  ZoneInfo? zoneByMajor(int major) => _repo.zoneByMajor(major);

  /// Tiện ích cho màn 4: một lần tra cứu thay vì zone-rồi-exhibit.
  ExhibitInfo? exhibitAt(int major, int minor) =>
      _repo.zoneByMajor(major)?.exhibitByMinor(minor);

  /// Mọi zone theo thứ tự manifest. Rỗng trước khi warm.
  List<ZoneInfo> get allZones => _repo.allZones;

  /// Tên bảo tàng cho wordmark ở Gate. Null trước khi warm.
  LocalizedText? get museumName => _repo.config?.museumName;

  /// Bundle đã parse thành công chưa. Màn hình nội dung có thể dựa vào đây để
  /// hiện empty state thay vì một danh sách rỗng khó hiểu.
  bool get isWarmed => _repo.isWarmed;

  // ── ảnh ───────────────────────────────────────────────────────────────────

  /// Đường dẫn file tuyệt đối, hoặc null → HeroImage tự vẽ gradient fallback.
  String? imagePath(String bundleRelativePath) => _imagePath(bundleRelativePath);
}
