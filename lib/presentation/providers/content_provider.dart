// Destination: lib/presentation/providers/content_provider.dart (REPLACES)
//
// Cửa DUY NHẤT để tầng UI đọc MỌI chữ hiển thị — cả NỘI DUNG (tên khu, hiện
// vật) lẫn CHROME (nhãn giao diện). Widget không bao giờ tự resolve ngôn ngữ.
//
// NGÔN NGỮ (Feature B): nguồn sự thật giờ là [LanguageController] (inject vào
// đây và vào TourAudioController — CÙNG một object). ContentProvider LẮNG NGHE
// nó và relay notifyListeners, nên đổi ngôn ngữ → mọi widget đang `watch`
// content sẽ vẽ lại bằng ngôn ngữ mới. TODO "đừng để hai nguồn sự thật" trong
// bản cũ đã được giải quyết: chỉ còn LanguageController.
//
// CHROME đi cùng bundle (không phải Flutter .arb): [ui] resolve theo
// ui[lang] → ui[fallback] → default nhúng → key. Thêm ngôn ngữ = sửa manifest.

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/feedback_config.dart';
import 'package:beacon_client/domain/models/guide_content.dart';
import 'package:beacon_client/domain/models/localized_text.dart';
import 'package:beacon_client/domain/models/menu_config.dart';
import 'package:beacon_client/domain/models/summary_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/providers/language_controller.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

typedef ImagePathResolver = String? Function(String bundleRelativePath);

class ContentProvider extends ChangeNotifier {
  ContentProvider({
    required IZoneRepository repository,
    required ImagePathResolver imagePathResolver,
    required LanguageController language,
  })  : _repo = repository,
        _imagePath = imagePathResolver,
        _lang = language {
    // Đổi ngôn ngữ → content vẽ lại. Một cầu nối duy nhất, không hai nguồn.
    _lang.addListener(notifyListeners);
  }

  final IZoneRepository _repo;
  final ImagePathResolver _imagePath;
  final LanguageController _lang;

  @override
  void dispose() {
    _lang.removeListener(notifyListeners);
    super.dispose();
  }

  // ── ngôn ngữ ──────────────────────────────────────────────────────────────

  /// Ngôn ngữ mặc định của bảo tàng, đảm bảo luôn có bản dịch trong bundle.
  String get fallbackLanguage => _repo.config?.fallbackLanguage ?? 'vi';

  /// Ngôn ngữ người dùng đang chọn — từ nguồn sự thật duy nhất.
  String get language => _lang.code;

  /// Tên hiển thị của một mã ngôn ngữ cho picker. Ưu tiên tên khai báo trong
  /// manifest (`config.languageNames`) để thêm/sửa tên KHÔNG cần đụng code; lùi
  /// về bảng tên nhúng [languageDisplayName] nếu bundle chưa khai báo mã đó.
  String languageName(String code) {
    final fromBundle = _repo.config?.languageNames[code];
    if (fromBundle != null && fromBundle.isNotEmpty) return fromBundle;
    return languageDisplayName(code);
  }

  /// Resolve một LocalizedText NỘI DUNG theo thứ tự ưu tiên. Widget dùng cái
  /// này, KHÔNG gọi `resolve()` trực tiếp.
  String text(LocalizedText value) => value.resolve(language, fallbackLanguage);

  String? textOrNull(LocalizedText? value) =>
      value == null ? null : text(value);

  /// Resolve một chuỗi CHROME theo khóa [UiKeys]. Thứ tự: ngôn ngữ hiện tại →
  /// fallback bảo tàng → default nhúng → chính khóa (không bao giờ trả rỗng).
  /// Ủy quyền cho [resolveUi] — cùng logic mà composition root dùng cho FGS.
  String ui(String key) =>
      resolveUi(_repo.config?.uiStrings, language, fallbackLanguage, key);

  /// Như [ui] nhưng thay các placeholder `{name}` bằng giá trị trong [params].
  /// Vd: uif(UiKeys.gateSyncUpdated, {'version': '2026.07.10-15'}).
  String uif(String key, Map<String, String> params) {
    var s = ui(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  // ── tra cứu nội dung ──────────────────────────────────────────────────────

  ZoneInfo? zoneByMajor(int major) => _repo.zoneByMajor(major);

  ExhibitInfo? exhibitAt(int major, int minor) =>
      _repo.zoneByMajor(major)?.exhibitByMinor(minor);

  List<ZoneInfo> get allZones => _repo.allZones;

  LocalizedText? get museumName => _repo.config?.museumName;

  bool get isWarmed => _repo.isWarmed;

  // ── cấu hình các màn phụ trợ ───────────────────────────────────────────────
  //
  // Bốn getter này KHÔNG BAO GIỜ trả null, kể cả khi kho chưa nạp xong hay
  // bundle chưa khai báo: mỗi khối có hằng mặc định riêng. Màn Menu và màn
  // Hướng dẫn phải vẽ được ngay cả trên một máy vừa cài xong chưa đồng bộ lần
  // nào — đó là lúc nhân viên cần chúng nhất.

  MenuConfig get menu => _repo.config?.menu ?? MenuConfig.defaults;

  GuideContent get guide => _repo.config?.guide ?? GuideContent.empty;

  SummaryConfig get summary => _repo.config?.summary ?? SummaryConfig.defaults;

  FeedbackConfig get feedback =>
      _repo.config?.feedback ?? FeedbackConfig.defaults;

  // ── ảnh ───────────────────────────────────────────────────────────────────

  String? imagePath(String bundleRelativePath) => _imagePath(bundleRelativePath);

  String? get welcomeImagePath {
    final rel = _repo.config?.welcomeImagePath;
    return rel == null ? null : _imagePath(rel);
  }

  String? get welcomeAccentImagePath {
    final rel = _repo.config?.welcomeAccentImagePath;
    return rel == null ? null : _imagePath(rel);
  }
}