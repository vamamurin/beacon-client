// Destination: lib/presentation/ui_strings.dart (REPLACES)
//
// Feature B — chuỗi GIAO DIỆN (chrome) đi cùng bundle thay vì Flutter .arb.
// Xem doc gốc ở đầu file: 3 lớp (UiKeys / kUiDefaults / resolve), quy ước tách
// theo widget, {placeholder} + ContentProvider.uif cho chuỗi có biến chạy.
//
// TIẾN ĐỘ STAGE 2 (cập nhật):
//   • Gate (khách + BLE/sync nhân viên): XONG.
//   • zone / exhibit_detail / exhibit_list / banner: XONG.
//   • settings: XONG (đọc ui() 24 chỗ — theme label lấy từ ui, không còn từ
//     enum MuseumThemeId.label).
//   • Nhãn accessibility sub-widget (progress bar, định dạng thời lượng cho
//     screen reader), snackbar phản hồi audio, hint mở cài đặt: XONG (sub-pass
//     này). Duration cho screen reader dùng {m}/{s} qua uif().
//   • CÒN LẠI (ngoài phạm vi manifest): chuỗi notification/FGS ở
//     foreground_task_keep_alive.dart + main.dart chạy TRƯỚC khi có config nên
//     chưa lấy từ bundle — xem ghi chú ở hai file đó.

abstract final class UiKeys {
  // ── ngôn ngữ / picker ──
  static const languageLabel = 'language.label';
  static const languagePickerTitle = 'language.picker.title';

  // ── phản hồi phát tiếng (snackbar) ──
  static const audioFeedbackNoHeadphones = 'audio.feedback.noHeadphones';
  static const audioFeedbackNotFound = 'audio.feedback.notFound';

  // ── keep-alive foreground service (thông báo nền, Feature A) ──
  // channelName/Desc đặt MỘT LẦN lúc init service (Android cache tên kênh sau
  // lần tạo đầu); title/text đặt mỗi lần startService nên đổi theo tour được.
  static const keepAliveChannelName = 'keepAlive.channelName';
  static const keepAliveChannelDesc = 'keepAlive.channelDesc';
  static const keepAliveTitle = 'keepAlive.title';
  static const keepAliveText = 'keepAlive.text';

  /// Nhãn nút TẮT HẲN APP trên thông báo keep-alive. Đây là đường thoát duy
  /// nhất không phụ thuộc hành vi vuốt-tắt của từng ROM — giữ nhãn ngắn, Android
  /// cắt chữ trên notification hẹp.
  static const keepAliveEndButton = 'keepAlive.endButton';

  // ── gate — khách nhìn ──
  static const gateWelcomeTitle = 'gate.welcome.title';
  static const gateWelcomeSubtitle = 'gate.welcome.subtitle';
  static const gateWelcomeGuidance = 'gate.welcome.guidance';
  static const gateStart = 'gate.start';
  static const gateMuseumFallback = 'gate.museum.fallback';
  static const gateSettingsHint = 'gate.settingsHint'; // a11y long-press hint

  // ── gate — đồng bộ (nhân viên) ──
  static const gateSyncUpdated = 'gate.sync.updated'; // {version}
  static const gateSyncUpToDate = 'gate.sync.upToDate'; // {version}
  static const gateSyncNoConnectivity = 'gate.sync.noConnectivity';
  static const gateSyncFailed = 'gate.sync.failed'; // {error}
  static const gateSyncMockMode = 'gate.sync.mockMode';
  static const gateSyncDoneTitle = 'gate.sync.doneTitle';
  static const gateSyncNotReadyTitle = 'gate.sync.notReadyTitle';
  static const gateSyncFreshBody = 'gate.sync.freshBody';
  static const gateSyncRestartCta = 'gate.sync.restartCta';
  static const gateSyncSyncCta = 'gate.sync.syncCta';

  // ── gate — Bluetooth (nhân viên) ──
  static const gateBlePermTitle = 'gate.ble.permTitle';
  static const gateBlePermBody = 'gate.ble.permBody';
  static const gateBlePermCta = 'gate.ble.permCta';
  static const gateBleDeniedTitle = 'gate.ble.deniedTitle';
  static const gateBleDeniedBody = 'gate.ble.deniedBody';
  static const gateBleDeniedCta = 'gate.ble.deniedCta';
  static const gateBleOffTitle = 'gate.ble.offTitle';
  static const gateBleOffBody = 'gate.ble.offBody';
  static const gateBleUnsupportedTitle = 'gate.ble.unsupportedTitle';
  static const gateBleUnsupportedBody = 'gate.ble.unsupportedBody';
  static const gateBleCheckingTitle = 'gate.ble.checkingTitle';
  static const gateBleCheckingBody = 'gate.ble.checkingBody';
  static const gateBleRetryCta = 'gate.ble.retryCta';

  // ── mất Bluetooth GIỮA TOUR (overlay chặn, khách nhìn) ──
  // Khác họ `gate.ble.*`: chuỗi ở đó viết cho NHÂN VIÊN lúc bàn giao máy, còn
  // ở đây là khách đang đi giữa bảo tàng và vừa tự tắt Bluetooth. Giọng phải là
  // trấn an + một hành động rõ ràng, không phải chẩn đoán kỹ thuật.
  static const tourBleLostTitle = 'tour.bleLost.title';
  static const tourBleLostBody = 'tour.bleLost.body';

  /// Mất BLE giữa tour vì lý do KHÔNG phải khách tự tắt (quyền bị thu hồi, máy
  /// không hỗ trợ). Khách không tự xử lý được ⇒ câu chữ chỉ sang nhân viên.
  static const tourBleBlockedTitle = 'tour.bleBlocked.title';
  static const tourBleBlockedBody = 'tour.bleBlocked.body';

  // ── zone (màn 2) ──
  static const zoneNearbyTitle = 'zone.nearbyTitle';
  static const zoneNearbyGuidance = 'zone.nearbyGuidance';
  static const zoneIdentifying = 'zone.identifying';
  static const zoneScanning = 'zone.scanning';
  static const zoneEnterPromptA = 'zone.enterPromptA';
  static const zoneEnterPromptB = 'zone.enterPromptB';
  static const zoneHereBadge = 'zone.hereBadge';
  static const zoneExhibitCount = 'zone.exhibitCount'; // {count}
  static const zoneDistanceSuffix = 'zone.distanceSuffix'; // {d}
  static const zoneRowSemantics = 'zone.rowSemantics'; // {zone} {count}
  static const zoneCurrentSemantics = 'zone.currentSemantics'; // {zone} {count}
  static const zoneIdentifyingSemantics = 'zone.identifyingSemantics';

  // ── exhibit detail (màn 4) ──
  static const exhibitNotFound = 'exhibit.notFound';
  static const exhibitBack = 'exhibit.back';
  static const exhibitRestart = 'exhibit.restart';
  static const exhibitNext = 'exhibit.next';
  static const exhibitPlay = 'exhibit.play';
  static const exhibitPause = 'exhibit.pause';
  static const exhibitSectionIntro = 'exhibit.section.intro';
  static const exhibitSectionMeaning = 'exhibit.section.meaning';
  static const exhibitSectionSpecs = 'exhibit.section.specs';
  // accessibility (screen reader)
  static const exhibitProgressLabel = 'exhibit.progress.label';
  static const exhibitDurationSpoken = 'exhibit.duration.spoken'; // {m} {s}

  // ── exhibit list (màn 3) ──
  static const exhibitListEmptyTitle = 'exhibitList.emptyTitle';
  static const exhibitListEmptyBody = 'exhibitList.emptyBody';
  static const exhibitListZoneNotFound = 'exhibitList.zoneNotFound';
  static const exhibitListHeroKicker = 'exhibitList.heroKicker';
  static const exhibitListHeroSubtitle = 'exhibitList.heroSubtitle';
  static const exhibitListIntroPlay = 'exhibitList.introPlay';
  static const exhibitListIntroPause = 'exhibitList.introPause';
  static const exhibitListNowPlayingSuffix = 'exhibitList.nowPlayingSuffix';
  static const exhibitListNowPlayingMeta = 'exhibitList.nowPlayingMeta';

  // ── banner đổi khu ──
  static const bannerTitle = 'banner.title';
  static const bannerStay = 'banner.stay';
  static const bannerSwitch = 'banner.switch';

  // ── settings (nhân viên) ──
  static const settingsTitle = 'settings.title';
  static const settingsLanguage = 'settings.language';
  static const settingsThemeHeader = 'settings.themeHeader';
  static const settingsThemeDesc = 'settings.themeDesc';
  static const settingsThemeDark = 'settings.theme.dark';
  static const settingsThemeLight = 'settings.theme.light';
  static const settingsThemeHighContrast = 'settings.theme.highContrast';
  static const settingsCaveatLight = 'settings.caveat.light';
  static const settingsCaveatHighContrast = 'settings.caveat.highContrast';
  // ── thiết lập máy (nhân viên, một lần mỗi thiết bị lúc bàn giao) ──
  static const settingsDeviceHeader = 'settings.deviceHeader';
  static const settingsBatteryChecking = 'settings.battery.checking';
  static const settingsBatteryOk = 'settings.battery.ok';
  static const settingsBatteryNeeded = 'settings.battery.needed';
  static const settingsBatteryDesc = 'settings.battery.desc';
  static const settingsBatteryAction = 'settings.battery.action';

  static const settingsDiagnosticsHeader = 'settings.diagnosticsHeader';
  static const settingsDistanceToggle = 'settings.distanceToggle';
  static const settingsDistanceDesc = 'settings.distanceDesc';
  static const settingsServerHeader = 'settings.serverHeader';
  static const settingsServerUrlLabel = 'settings.serverUrlLabel';
  static const settingsServerUrlDesc = 'settings.serverUrlDesc';
  static const settingsSyncNowBtn = 'settings.syncNowBtn';
  static const settingsSyncRunning = 'settings.sync.running';
  static const settingsSyncUpdated = 'settings.sync.updated';
  static const settingsSyncUpToDate = 'settings.sync.upToDate';
  static const settingsSyncNoServer = 'settings.sync.noServer';
  static const settingsSyncFailed = 'settings.sync.failed';
  static const settingsSyncMock = 'settings.sync.mock';
  static const settingsLastSync = 'settings.lastSync'; // {time}

  // STAGE 2 (kế): settings; nhãn accessibility còn lại của progress bar.
}

const Map<String, String> kUiDefaults = <String, String>{
  UiKeys.languageLabel: 'Ngôn ngữ',
  UiKeys.languagePickerTitle: 'Chọn ngôn ngữ',

  UiKeys.audioFeedbackNoHeadphones: 'Cắm tai nghe để nghe thuyết minh.',
  UiKeys.audioFeedbackNotFound: 'Chưa có bản thuyết minh cho hiện vật này.',

  UiKeys.keepAliveChannelName: 'Giữ phiên tham quan',
  UiKeys.keepAliveChannelDesc:
      'Giữ ứng dụng chạy để bắt beacon khi màn hình tắt.',
  UiKeys.keepAliveTitle: 'Đang tham quan',
  UiKeys.keepAliveText: 'Giữ kết nối beacon khi màn hình tắt',
  UiKeys.keepAliveEndButton: 'Kết thúc tham quan',

  UiKeys.gateWelcomeTitle: 'Chào mừng',
  UiKeys.gateWelcomeSubtitle: 'quý khách',
  UiKeys.gateWelcomeGuidance:
      'Ứng dụng tự nhận biết khu trưng bày quanh bạn. '
          'Đeo tai nghe để bắt đầu nghe thuyết minh.',
  UiKeys.gateStart: 'Bắt đầu tham quan',
  UiKeys.gateMuseumFallback: 'Bảo tàng',
  UiKeys.gateSettingsHint: 'Mở cài đặt (dành cho nhân viên)',

  UiKeys.gateSyncUpdated:
      'Đã tải nội dung {version}. Nhấn để khởi động lại và bắt đầu.',
  UiKeys.gateSyncUpToDate:
      'Nội dung đã là bản mới nhất ({version}). Nhấn để khởi động lại.',
  UiKeys.gateSyncNoConnectivity:
      'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
  UiKeys.gateSyncFailed: 'Đồng bộ thất bại: {error}',
  UiKeys.gateSyncMockMode: 'Chế độ mock — không có server.',
  UiKeys.gateSyncDoneTitle: 'Đã tải xong',
  UiKeys.gateSyncNotReadyTitle: 'Chưa sẵn sàng',
  UiKeys.gateSyncFreshBody:
      'Thiết bị chưa có nội dung tham quan. Nhấn Đồng bộ để tải '
          'dữ liệu trước khi bàn giao cho khách.',
  UiKeys.gateSyncRestartCta: 'Khởi động lại ứng dụng',
  UiKeys.gateSyncSyncCta: 'Đồng bộ nội dung',

  UiKeys.gateBlePermTitle: 'Cần quyền Bluetooth',
  UiKeys.gateBlePermBody:
      'Ứng dụng cần quyền Bluetooth để nhận diện khu trưng bày. '
          'Nhấn để cấp quyền.',
  UiKeys.gateBlePermCta: 'Cấp quyền',
  UiKeys.gateBleDeniedTitle: 'Quyền bị từ chối',
  UiKeys.gateBleDeniedBody:
      'Quyền Bluetooth đã bị tắt. Mở Cài đặt để bật, rồi quay lại — '
          'ứng dụng sẽ tự nhận.',
  UiKeys.gateBleDeniedCta: 'Mở cài đặt',
  UiKeys.gateBleOffTitle: 'Bluetooth đang tắt',
  UiKeys.gateBleOffBody: 'Vui lòng bật Bluetooth để tiếp tục.',
  UiKeys.gateBleUnsupportedTitle: 'Thiết bị không hỗ trợ',
  UiKeys.gateBleUnsupportedBody:
      'Thiết bị này không hỗ trợ Bluetooth Low Energy.',
  UiKeys.gateBleCheckingTitle: 'Đang kiểm tra',
  UiKeys.gateBleCheckingBody: 'Đang kiểm tra Bluetooth…',
  UiKeys.gateBleRetryCta: 'Thử lại',

  UiKeys.tourBleLostTitle: 'Đã tắt Bluetooth',
  UiKeys.tourBleLostBody:
      'Máy cần Bluetooth để biết bạn đang đứng trước hiện vật nào. '
          'Thuyết minh đã tạm dừng. Vui lòng bật lại Bluetooth — '
          'màn hình này sẽ tự tắt và chuyến tham quan tiếp tục.',
  UiKeys.tourBleBlockedTitle: 'Không dùng được Bluetooth',
  UiKeys.tourBleBlockedBody:
      'Thuyết minh đã tạm dừng vì máy không truy cập được Bluetooth. '
          'Vui lòng mang máy tới quầy để nhân viên hỗ trợ.',

  UiKeys.zoneNearbyTitle: 'Khu vực quanh bạn',
  UiKeys.zoneNearbyGuidance:
      'Ứng dụng nhận diện các khu trưng bày gần bạn qua sóng beacon.',
  UiKeys.zoneIdentifying: 'Đang xác định',
  UiKeys.zoneScanning: 'Đang quét không gian',
  UiKeys.zoneEnterPromptA:
      'Hãy tiến vào một khu trưng bày để bắt đầu nghe thuyết minh.',
  UiKeys.zoneEnterPromptB:
      'Hãy tiến vào khu trưng bày để bắt đầu nghe thuyết minh.',
  UiKeys.zoneHereBadge: 'Đang ở đây',
  UiKeys.zoneExhibitCount: '{count} hiện vật',
  UiKeys.zoneDistanceSuffix: ' · ~{d} m',
  UiKeys.zoneRowSemantics: 'Khu {zone}, {count} hiện vật',
  UiKeys.zoneCurrentSemantics: 'Bạn đang ở khu {zone}, {count} hiện vật',
  UiKeys.zoneIdentifyingSemantics: 'Đang xác định khu trưng bày quanh bạn',

  UiKeys.exhibitNotFound: 'Không tìm thấy hiện vật',
  UiKeys.exhibitBack: 'Quay lại',
  UiKeys.exhibitRestart: 'Về đầu',
  UiKeys.exhibitNext: 'Tiếp',
  UiKeys.exhibitPlay: 'Phát',
  UiKeys.exhibitPause: 'Tạm dừng',
  UiKeys.exhibitSectionIntro: 'Giới thiệu',
  UiKeys.exhibitSectionMeaning: 'Ý nghĩa',
  UiKeys.exhibitSectionSpecs: 'Thông số',
  UiKeys.exhibitProgressLabel: 'Tiến trình thuyết minh',
  UiKeys.exhibitDurationSpoken: '{m} phút {s} giây',

  UiKeys.exhibitListEmptyTitle: 'Khu này chưa có hiện vật',
  UiKeys.exhibitListEmptyBody:
      'Khu trưng bày này hiện chưa có hiện vật nào trong nội dung. '
          'Vui lòng quay lại sau khi nội dung được cập nhật.',
  UiKeys.exhibitListZoneNotFound: 'Không tìm thấy khu trưng bày',
  UiKeys.exhibitListHeroKicker: 'Khu trưng bày',
  UiKeys.exhibitListHeroSubtitle: 'Chọn một hiện vật để nghe thuyết minh',
  UiKeys.exhibitListIntroPlay: 'Nghe giới thiệu khu trưng bày',
  UiKeys.exhibitListIntroPause: 'Tạm dừng giới thiệu khu trưng bày',
  UiKeys.exhibitListNowPlayingSuffix: ', đang phát',
  UiKeys.exhibitListNowPlayingMeta: 'Đang phát thuyết minh',

  UiKeys.bannerTitle: 'Bạn đã sang khu vực mới',
  UiKeys.bannerStay: 'Ở lại',
  UiKeys.bannerSwitch: 'Chuyển',

  UiKeys.settingsLanguage: 'Ngôn ngữ',
  UiKeys.settingsTitle: 'Cài đặt',
  UiKeys.settingsThemeHeader: 'Giao diện',
  UiKeys.settingsThemeDesc:
      'Giao diện được lưu trên thiết bị và giữ nguyên cho khách tiếp theo.',
  UiKeys.settingsThemeDark: 'Tối',
  UiKeys.settingsThemeLight: 'Sáng',
  UiKeys.settingsThemeHighContrast: 'Tương phản cao',
  UiKeys.settingsCaveatLight:
      'Màn hình sáng gây chói trong phòng trưng bày tối và có thể làm phiền '
          'khách đứng cạnh.',
  UiKeys.settingsCaveatHighContrast:
      'Tăng độ tương phản cho khách lớn tuổi hoặc thị lực kém.',
  UiKeys.settingsDeviceHeader: 'Thiết lập máy',
  UiKeys.settingsBatteryChecking: 'Đang kiểm tra tối ưu hoá pin…',
  UiKeys.settingsBatteryOk: 'Đã tắt tối ưu hoá pin cho ứng dụng',
  UiKeys.settingsBatteryNeeded: 'Cần tắt tối ưu hoá pin cho ứng dụng',
  UiKeys.settingsBatteryDesc:
      'Không tắt, hệ điều hành có thể đóng băng ứng dụng khi màn hình tắt và '
      'khách sẽ không nghe thuyết minh khi bước vào khu. Trên máy Xiaomi cần '
      'bật thêm "Tự khởi động" và đặt Tiết kiệm pin thành "Không hạn chế".',
  UiKeys.settingsBatteryAction: 'Tắt tối ưu hoá pin',

  UiKeys.settingsDiagnosticsHeader: 'Chẩn đoán',
  UiKeys.settingsDistanceToggle: 'Hiện khoảng cách ước lượng',
  UiKeys.settingsDistanceDesc:
      'Chỉ dùng khi tinh chỉnh khoảng cách tại hiện trường. Hiện số mét ước '
          'lượng trên màn khu vực. Tắt trước khi giao máy cho khách.',
  UiKeys.settingsServerHeader: 'Máy chủ nội dung',
  UiKeys.settingsServerUrlLabel: 'Địa chỉ máy chủ',
  UiKeys.settingsServerUrlDesc:
      'Để trống để dùng địa chỉ mặc định của bản cài. Đổi tại đây có hiệu '
          'lực ngay lần đồng bộ kế tiếp, không cần cài lại app.',
  UiKeys.settingsSyncNowBtn: 'Đồng bộ ngay',
  UiKeys.settingsSyncRunning: 'Đang đồng bộ…',
  UiKeys.settingsSyncUpdated: 'Đã cập nhật nội dung mới',
  UiKeys.settingsSyncUpToDate: 'Đã là bản mới nhất',
  UiKeys.settingsSyncNoServer: 'Không gọi được máy chủ',
  UiKeys.settingsSyncFailed: 'Đồng bộ thất bại',
  UiKeys.settingsSyncMock: 'Chế độ thử — không có máy chủ',
  UiKeys.settingsLastSync: 'Lần đồng bộ gần nhất: {time}',
};

/// Resolve một chuỗi CHROME theo khóa [UiKeys]:
///   table[lang] → table[fallback] → [kUiDefaults] → chính khóa (không rỗng).
///
/// NGUỒN SỰ THẬT DUY NHẤT cho thứ tự này. Dùng chung bởi:
///   • [ContentProvider.ui] ở tầng UI (table = config.uiStrings), và
///   • composition root khi cần chuỗi TRƯỚC lúc có ContentProvider — vd nhãn
///     thông báo của foreground keep-alive service (Feature A).
/// Để logic ở MỘT chỗ, tránh hai nơi resolve lệch nhau như từng xảy ra với
/// LocalizedText trước khi gom vào một hàm.
String resolveUi(
  Map<String, Map<String, String>>? table,
  String lang,
  String fallback,
  String key,
) {
  return table?[lang]?[key] ??
      table?[fallback]?[key] ??
      kUiDefaults[key] ??
      key;
}