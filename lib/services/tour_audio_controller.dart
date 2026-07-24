// Destination: lib/services/tour_audio_controller.dart
//
// The heart of Phase 2. Owns ALL audio POLICY; the engine owns none.
// Consumes zone events (from ZonePresenceService in Step 5; called directly in
// tests) + user commands + headphone signals, and drives IAudioEngine.
//
// Confirmed rule set:
//  (1) ENTER zone + headphones present -> play intro, then auto-advance the
//      exhibit queue in tour order. No headphones -> reading mode (never
//      autoplay out loud); nothing is played, UI shows transcript.
//  (2a) TAP exhibit -> interrupt immediately, flush pending auto-queue, play
//      that clip; when it ends, resume auto-tour FROM THE NEXT exhibit.
//  (3+4) CHANGE zone -> ALWAYS interrupt + flush old queue + chime. Then judge
//      the visitor's INTENT (not the engine's mechanical state): if they have
//      not deliberately paused, the new zone's intro plays; if they paused
//      (button or unplug), the intro loads but stays silent until they press
//      play. Physical-space sync is supreme; the paused visitor's intent is
//      still honoured for "start new sound or not".
//  (5) REVISIT a zone already seen this tour (revisitPlaysWelcome=false)
//      -> chime only, no intro, wait for a tap. EXCEPTION: an explicit
//      "Chuyển sang B" tap beats rule 5 — the banner promised a switch, so
//      silence would read as a broken button.
//  (6) UNPLUG headphones -> pause now; REPLUG -> wait for explicit play.
//
// Chime policy (confirmed): chime fires on zone CHANGE and REVISIT, not on the
// first entry from standby (there the intro itself is the arrival cue).
//
// ─────────────────────────────────────────────────────────────────────────────
// FIX B8 — KHÔNG CÒN stop() + load() KHÔNG-AWAIT CẠNH NHAU.
//
// Bản trước gọi `_flushQueue()` (→ `_engine.stop()`) ngay trước `_loadIntro`
// (→ `_engine.load()`), cả hai đều async và cả hai đều KHÔNG await, trên CÙNG
// một AudioPlayer. Hai coroutine interleave và sinh ra hai hỏng hóc, tuỳ thứ
// tự tiếp đất của plugin:
//
//   • Phần đuôi của stop() đặt lại `_completedSignalled = false` trong khi
//     player còn nằm ở ProcessingState.completed của clip CŨ ⇒ engine bắn
//     onCompleted mang ref của clip MỚI (chưa hề phát) ⇒ controller tưởng intro
//     vừa nghe xong và nhảy thẳng sang hiện vật kế tiếp. Triệu chứng thực địa:
//     đổi khu thì bỏ qua intro và phát hiện vật thứ hai của khu mới.
//   • Ngược lại, nếu đuôi của stop() tiếp đất SAU setAudioSource thì nó gỡ
//     luôn nguồn vừa nạp ⇒ player về idle, play() thành no-op, UI kẹt ở
//     "loading". Cùng một cửa sổ, hai kết cục khác nhau.
//
// Sửa ở ĐÂY (nguyên nhân), song song với cờ `_sourceReady` bên
// just_audio_engine.dart (hậu quả):
//   `load()` VỐN ĐÃ thay nguồn — một AudioPlayer chỉ giữ một nguồn tại một
//   thời điểm — nên `stop()` trước nó là thừa. Bỏ đi là cửa sổ đóng kín.
//   Nhưng vẫn PHẢI stop tường minh ở nhánh KHÔNG có clip mới nào thế chỗ
//   (khu đã ghé theo luật 5, hoặc intro không resolve được ngôn ngữ hiện tại),
//   nếu không thuyết minh khu CŨ sẽ phát tiếp sau khi khách đã sang khu mới.
//   Vì thế [_beginZoneAudio] và [_loadIntro] trả về bool "đã giao clip mới cho
//   engine hay chưa", và người gọi tự quyết định có cần stop hay không.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_audio_engine.dart';
import 'package:beacon_client/domain/interfaces/i_headphone_monitor.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
// import 'package:beacon_client/domain/models/audio_clip_info.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';

/// Kết quả của một ý định phát tiếng do người dùng khởi xướng. Trả về enum
/// thay vì bool để UI phân biệt được "bị chặn vì không có tai nghe" với
/// "chưa có clip nào" — hai trường hợp cần phản hồi khác nhau.
enum AudioIntentResult {
  /// Đã bắt đầu phát.
  started,

  /// Reading mode: không có đường nghe riêng và bảo tàng cấm loa ngoài.
  /// Clip VẪN được load (để hiện transcript), chỉ không phát tiếng.
  blockedNoHeadphones,

  /// Chưa có clip nào được load — nút play không có gì để phát.
  noClip,

  /// Không resolve được zone/exhibit/audio track.
  notFound,
}

/// Resolves a bundle-relative audio path to a playable Uri. Injected so the
/// same controller works over MockZoneRepository (asset/file) and the real
/// LocalBundleZoneRepository (file on disk) without knowing which.
typedef AudioUriResolver = Uri Function(String bundleRelativePath);
typedef LanguageResolver = String Function();

class TourAudioController {
  // Bench-test / demo qua loa ngoài, không cần tai nghe:
  //   flutter run   --dart-define=ASSUME_HEADPHONES=true
  //   flutter build apk --dart-define=ASSUME_HEADPHONES=true   (bản demo)
  // FIX A4: defaultValue PHẢI là false — bản release chính thức (build không
  // truyền define) mà nhận true sẽ vô hiệu toàn bộ chính sách tai nghe
  // (reading mode chết, rút tai nghe không pause). Muốn demo loa ngoài thì
  // truyền define tường minh như trên, không sửa hằng số này.
  static const bool kDebugAssumeHeadphones =
      bool.fromEnvironment('ASSUME_HEADPHONES', defaultValue: false);

  TourAudioController({
    required IZoneRepository repository,
    required IAudioEngine engine,
    required IHeadphoneMonitor headphones,
    required AudioUriResolver uriResolver,
    required LanguageResolver language,
    required void Function() onChime,
  })  : _repo = repository,
        _engine = engine,
        _headphones = headphones,
        _resolveUri = uriResolver,
        _language = language,
        _onChime = onChime {
    _completedSub = _engine.onCompleted.listen(_onClipCompleted);
    _headphoneSub =
        _headphones.onConnectionChanged.listen(_onHeadphoneChanged);
  }

  final IZoneRepository _repo;
  final IAudioEngine _engine;
  final IHeadphoneMonitor _headphones;
  final AudioUriResolver _resolveUri;
  final LanguageResolver _language;
  final void Function() _onChime;

  late final StreamSubscription<AudioTrackRef> _completedSub;
  late final StreamSubscription<bool> _headphoneSub;

  // ---- tour position state ----
  int? _activeZoneMajor;

  /// Index into the active zone's exhibit list for the AUTO tour. Points at
  /// the exhibit that will play NEXT when the current clip completes.
  int _autoIndex = 0;

  /// Zones whose intro has been heard THIS TOUR (rule 5). RAM-only.
  /// LƯU Ý: controller sống suốt vòng đời app (Injection dựng một lần), KHÔNG
  /// dựng lại mỗi phiên. Bộ nhớ này được SessionController.userStartedTour()
  /// dọn ở đầu mỗi tour — đừng giả định nó tự chết theo phiên.
  final Set<int> _visitedZones = {};

  /// Ý ĐỊNH của khách, không phải trạng thái cơ học của engine.
  ///
  /// Vì sao cần cờ này thay vì đọc `_engine.state.status == playing`: một clip
  /// vừa nghe HẾT được engine map thành `paused` (ProcessingState.completed →
  /// PlaybackStatus.paused). Nên khách nghe trọn vẹn khu A rồi sang khu B sẽ bị
  /// đánh giá nhầm là "đang tạm dừng" và khu B im lặng một cách khó hiểu.
  /// "Nghe xong" KHÔNG phải "muốn dừng".
  bool _userPaused = false;

  MuseumConfig? get _config => _repo.config;

  /// Whether there is a legitimate private-listening route right now. Single
  /// source of truth for every headphone gate below, so the debug override
  /// only has to be applied in ONE place. In production this is exactly
  /// "headphones connected"; under [kDebugAssumeHeadphones] it's forced true.
  bool get _hasAudioRoute =>
      kDebugAssumeHeadphones || _headphones.isConnected;

  bool get _autoplayAllowed {
    final cfg = _config;
    if (cfg == null) return false;
    // Reading mode is a PHYSICAL fact (no way to make sound without breaking
    // policy) and overrides everything: if we can't emit sound legitimately,
    // we never autoplay, regardless of the autoplayRequiresHeadphones setting.
    if (_readingMode) return false;
    // Otherwise honour the headphone-preference policy.
    if (cfg.policies.autoplayRequiresHeadphones && !_hasAudioRoute) {
      return false;
    }
    return true;
  }

  /// Reading mode: no private-listening route AND the museum forbids the
  /// loudspeaker. In this mode NOTHING plays sound — not autoplay, not a
  /// manual tap (rule (a)): the difference between listening and reading is
  /// solely whether headphones are present. A tap still loads the clip so the
  /// UI can show that exhibit's transcript.
  bool get _readingMode {
    final cfg = _config;
    if (cfg == null) return true;
    final noRoute = !_hasAudioRoute;
    return noRoute && !cfg.policies.allowLoudspeaker;
  }

  // ========================================================================
  // Zone events (from ZonePresenceService / tests)
  // ========================================================================

  /// Visitor entered a zone from standby (no previous zone). Rule 1 / 5.
  void enterZone(int major) {
    final zone = _repo.zoneByMajor(major);
    if (zone == null) return;
    _activeZoneMajor = major;
    _autoIndex = 0;

    // First entry from standby: NO chime (intro is the arrival cue).
    final bool tookOver = _beginZoneAudio(zone, chime: false);

    // B8 — chỉ stop khi KHÔNG có clip mới nào thế chỗ (khu đã ghé, luật 5).
    // Bình thường engine đã idle sẵn ở đây (leaveToStandby / kết thúc phiên đã
    // dọn), nên đây là dây an toàn chứ không phải đường chính.
    if (!tookOver) _flushQueue();
  }

  /// Visitor moved from one zone to another. Rules 3+4 (+5 for revisits).
  ///
  /// [forcePlay]: null (mặc định — đường auto-switch khi banner hết giờ) →
  /// phát-hay-im theo Ý ĐỊNH của khách ([_userPaused]). true (khách BẤM
  /// "Chuyển" trên banner) → luôn phát intro B: bấm nút là mệnh lệnh phát, chỉ
  /// reading-mode mới chặn được, và nó THẮNG cả luật 5. false thì để dành.
  void changeZone(int major, {bool? forcePlay}) {
    final zone = _repo.zoneByMajor(major);
    if (zone == null) return;

    // ⚠ HAI CỜ NÀY KHÁC NHAU — đừng suy cái sau ra từ cái trước.
    //
    // `explicit` = "khách có thực sự BẤM nút không". CHỈ nó mới được phép
    // thắng luật 5 (khu đã ghé thì không chào lại).
    //
    // `shouldPlayIntro` = "có phát tiếng ngay không". Trên đường auto nó bằng
    // `!_userPaused`, tức THƯỜNG LÀ true.
    //
    // Một bản trước suy `explicitCommand = forcePlay == true` từ BÊN TRONG
    // [_beginZoneAudio], SAU khi `shouldPlayIntro` đã được truyền vào chính
    // tham số `forcePlay`. Vì `shouldPlayIntro` là bool đặc (không bao giờ
    // null), cờ "khách đã bấm" hoá thành true trên CẢ đường auto ⇒ luật 5 bị
    // vô hiệu ⇒ đi A → B → A và để banner hết giờ sẽ nghe lại toàn bộ lời chào
    // khu A. Giữ hai cờ tách bạch, tính ở ĐÂY, truyền xuống riêng.
    final bool explicit = forcePlay == true;
    final bool shouldPlayIntro = forcePlay ?? !_userPaused;

    // B8 — KHÔNG _flushQueue() ở đây nữa (xem ghi chú đầu file). load() bên
    // dưới đã thay nguồn; thêm một stop() không-await vào đó chính là cửa sổ
    // race đã sinh ra lỗi "đổi khu bỏ qua intro".
    _activeZoneMajor = major;
    _autoIndex = 0;
    _chime(); // zone change always chimes (trừ reading mode — cấm mọi tiếng)

    final bool tookOver = _beginZoneAudio(
      zone,
      chime: false,
      forcePlay: shouldPlayIntro,
      explicitCommand: explicit,
      alreadyChimed: true,
    );

    // Không có clip mới nào thế chỗ → phải cắt thuyết minh khu CŨ tường minh,
    // nếu không nó sẽ phát tiếp trong khi khách đã sang khu mới.
    if (!tookOver) _flushQueue();
  }

  /// Radio dropped to standby (Phase 1 rule 4). Stop audio; keep visited memory.
  void leaveToStandby() {
    _flushQueue();
    _activeZoneMajor = null;
    _autoIndex = 0;
  }

  /// Shared entry/change audio logic.
  ///
  /// [forcePlay]: khi có giá trị (đường đổi khu), ghi đè quyết định autoplay.
  /// [explicitCommand]: khách BẤM nút tường minh — CHỈ cờ này mới thắng luật 5.
  ///
  /// Trả về TRUE khi một clip mới đã được giao cho engine (người gọi KHÔNG cần
  /// stop nữa), FALSE khi không có gì được nạp (khu đã ghé theo luật 5, hoặc
  /// intro không resolve được ở ngôn ngữ hiện tại). Giá trị trả về này là thứ
  /// cho phép [changeZone] bỏ được lệnh stop() không-await — xem B8 đầu file.
  bool _beginZoneAudio(
    ZoneInfo zone, {
    required bool chime,
    bool? forcePlay,
    bool explicitCommand = false,
    bool alreadyChimed = false,
  }) {
    final bool revisit = _visitedZones.contains(zone.major);

    if (chime && !alreadyChimed) _chime();

    // Luật 5: khu đã ghé thì chỉ chime, chờ tap. NGOẠI LỆ: khách bấm "Chuyển"
    // trên banner — banner đã hứa chuyển khu, im lặng sẽ đọc thành nút hỏng.
    if (revisit &&
        !explicitCommand &&
        !(_config?.policies.revisitPlaysWelcome ?? false)) {
      // Nothing loaded/played; the grid awaits a manual tap.
      return false;
    }

    _visitedZones.add(zone.major);

    // Decide whether to actually START sound.
    //
    // FIX B5: forcePlay là mệnh lệnh "khách ĐANG muốn nghe khi đổi zone → intro
    // mới phát tiếp" (rule 3+4). Bản cũ AND thêm _autoplayAllowed nên forcePlay
    // chỉ phủ quyết được, không ép được — khách nghe qua loa (bảo tàng cho
    // phép) sang zone mới bị im lặng khó hiểu. Giờ forcePlay đi thẳng vào
    // _loadIntro; cổng cuối cùng vẫn là _tryPlay (reading mode phủ quyết
    // TUYỆT ĐỐI mọi đường phát tiếng — bất khả kháng vật lý, không phải
    // preference).
    final bool shouldPlay = forcePlay ?? _autoplayAllowed;

    // Load the intro either way (so a paused visitor can press play, and so
    // reading mode has a "current" ref to show the transcript for).
    return _loadIntro(zone, play: shouldPlay);
  }

  /// Trả về TRUE khi intro đã được giao cho engine; FALSE khi khu này không có
  /// track intro dùng được ở ngôn ngữ hiện tại (người gọi phải tự stop).
  bool _loadIntro(ZoneInfo zone, {required bool play}) {
    final resolved = zone.introAudio.resolve(_language(), _fallback);
    if (resolved == null) return false;
    _autoIndex = 0; // exhibits start after the intro
    _engine.load(
      AudioTrackRef.zoneIntro(zone.major),
      _resolveUri(resolved.track.filePath),
      durationHint: Duration(
          milliseconds: (resolved.track.durationSec * 1000).round()),
    );
    if (play) _tryPlay();
    return true;
  }

  // ========================================================================
  // Cổng chính sách phát tiếng
  // ========================================================================

  /// CHỖ DUY NHẤT trong toàn bộ codebase được phép gọi `_engine.play()`.
  /// Mọi đường phát tiếng — autoplay, tap, play, replay, auto-advance — đều
  /// phải đi qua đây. Nếu bạn thấy `_engine.play()` ở chỗ khác, đó là bug.
  bool _tryPlay() {
    if (_readingMode) return false;
    _engine.play();
    return true;
  }

  /// B6: chime cũng là ÂM THANH — reading mode cấm mọi tiếng ra loa, kể cả
  /// tiếng "ting" đổi zone. Mọi call site dùng wrapper này, không gọi thẳng
  /// _onChime. (Cổng riêng thay vì gộp vào _tryPlay vì chime không đi qua
  /// engine thuyết minh — nó có player riêng.)
  void _chime() {
    if (_readingMode) return;
    _onChime();
  }

  // ========================================================================
  // User commands
  // ========================================================================

  /// Visitor tapped an exhibit tile. Rule 2a: interrupt, play it, then resume
  /// auto-tour from the NEXT exhibit.
  ///
  /// [major] là zone MÀ MÀN HÌNH ĐANG HIỂN THỊ (frozen theo route args), KHÔNG
  /// phải zone của arbiter. Hai giá trị này lệch nhau khi visitor đứng ở biên
  /// và arbiter chuyển zone dưới nền trong lúc họ đang đọc danh sách. `minor`
  /// chỉ unique trong một zone, nên resolve theo _activeZoneMajor sẽ phát nhầm
  /// hiện vật cùng số của zone khác.
  AudioIntentResult tapExhibit({required int major, required int minor}) {
    _userPaused = false; // Bấm chọn bài tức là muốn nghe
    final zone = _repo.zoneByMajor(major);
    if (zone == null) return AudioIntentResult.notFound;
    final idx = zone.tourIndexOf(minor);
    if (idx < 0) return AudioIntentResult.notFound;

    final exhibit = zone.exhibits[idx];
    final resolved = exhibit.audio.resolve(_language(), _fallback);
    if (resolved == null) return AudioIntentResult.notFound;

    // Chỉ nối tiếp auto-tour khi tap nằm TRONG zone vật lý hiện tại. Tap vào
    // một zone đã rời đi thì phát đúng clip được yêu cầu, nhưng không cướp
    // quyền auto-queue của zone visitor đang thực sự đứng.
    if (major == _activeZoneMajor) {
      _autoIndex = idx + 1;
    }

    // B8: load() thay nguồn trực tiếp — KHÔNG stop() trước. Đây cũng từng là
    // một ổ của cùng lỗi: chạm hiện vật đúng lúc clip trước vừa kết thúc sẽ
    // khiến engine bắn onCompleted cho clip mới và nhảy dư một hiện vật.
    _engine.load(
      AudioTrackRef(
        zoneMajor: major, // ref mang major ĐÚNG -> `isThis` ở màn 4 khớp
        exhibitMinor: minor,
        clipKind: AudioClipKind.exhibitManual,
      ),
      _resolveUri(resolved.track.filePath),
      durationHint: Duration(
          milliseconds: (resolved.track.durationSec * 1000).round()),
    );

    return _tryPlay()
        ? AudioIntentResult.started
        : AudioIntentResult.blockedNoHeadphones;
  }

  /// Visitor bấm nút play trên hero của màn 3: PHÁT LẠI intro của khu đó.
  /// Yêu cầu tường minh như [tapExhibit] — interrupt clip đang phát, load
  /// intro, phát qua cổng [_tryPlay] (reading mode: vẫn load để màn 4 hiện
  /// transcript, chỉ không ra tiếng).
  ///
  /// [major] là zone ĐÓNG BĂNG của màn hình (route args), không phải zone của
  /// arbiter — cùng kỷ luật với [tapExhibit].
  ///
  /// KHÔNG tái dụng [_loadIntro]: hàm đó reset `_autoIndex = 0` vô điều kiện,
  /// đúng cho đường enter/change zone nhưng SAI ở đây khi tap intro của một
  /// zone đã rời đi — nó sẽ cướp auto-queue của zone visitor đang thực sự
  /// đứng. Quy tắc giữ nguyên từ tapExhibit: chỉ đụng `_autoIndex` khi major
  /// trùng zone vật lý hiện tại; khi đó reset về 0 để intro phát xong,
  /// auto-tour đi lại từ hiện vật đầu tiên — y hệt lần vào zone (rule 1).
  /// Intro của zone khác: phát xong thì im, chờ tap — [_onClipCompleted] đã
  /// chặn advance cho ref lệch zone.
  AudioIntentResult tapZoneIntro({required int major}) {
    _userPaused = false; // Bấm chọn khu tức là muốn nghe
    final zone = _repo.zoneByMajor(major);
    if (zone == null) return AudioIntentResult.notFound;
    final resolved = zone.introAudio.resolve(_language(), _fallback);
    if (resolved == null) return AudioIntentResult.notFound;

    if (major == _activeZoneMajor) {
      _autoIndex = 0;
    }

    _engine.load(
      AudioTrackRef.zoneIntro(major),
      _resolveUri(resolved.track.filePath),
      durationHint: Duration(
          milliseconds: (resolved.track.durationSec * 1000).round()),
    );

    return _tryPlay()
        ? AudioIntentResult.started
        : AudioIntentResult.blockedNoHeadphones;
  }

  /// Visitor bấm play (resume, hoặc khởi động một intro đã load nhưng im).
  AudioIntentResult userPlay() {
    _userPaused = false; // Ghi nhận: Khách muốn tiếp tục nghe
    if (_engine.state.current == null) return AudioIntentResult.noClip;
    return _tryPlay()
        ? AudioIntentResult.started
        : AudioIntentResult.blockedNoHeadphones;
  }

  /// Visitor bấm pause.
  void userPause() {
    _userPaused = true; // Ghi nhận: Khách không muốn ồn ào lúc này
    _engine.pause();
  }

  /// Visitor bấm "Về đầu". Tua về 0 LUÔN được phép (đây là thao tác vị trí,
  /// không phải phát tiếng); chỉ việc phát mới đi qua cổng chính sách.
  AudioIntentResult userReplay() {
    _userPaused = false; // Đã tua lại tức là muốn nghe
    if (_engine.state.current == null) return AudioIntentResult.noClip;
    _engine.seek(Duration.zero);
    return _tryPlay()
        ? AudioIntentResult.started
        : AudioIntentResult.blockedNoHeadphones;
  }

  /// Visitor kéo thanh progress. Không phát tiếng ⇒ không qua cổng.
  /// (Chưa có UI dùng — chuẩn bị cho seek ở bước 6.)
  void userSeek(Duration position) => _engine.seek(position);

  // ========================================================================
  // Reactions
  // ========================================================================

  /// A clip finished naturally -> advance the queue.
  void _onClipCompleted(AudioTrackRef ref) {
    final major = _activeZoneMajor;
    if (major == null) return;

    // Clip vừa phát thuộc một zone khác zone vật lý hiện tại (visitor tap một
    // hiện vật của zone họ đã rời đi). Phát xong thì im, chờ tap tiếp — KHÔNG
    // auto-advance. Advance trong zone cũ sẽ trôi ngày càng xa không gian thật;
    // nhảy sang queue zone mới thì đột ngột không giải thích được.
    if (ref.zoneMajor != major) return;

    final zone = _repo.zoneByMajor(major);
    if (zone == null) return;
    if (!_autoplayAllowed) return;
    _playNextFrom(zone, _autoIndex);
  }

  /// Auto-tour phát LẦN LƯỢT MỌI hiện vật của khu theo THỨ TỰ MANIFEST từ
  /// [startIndex], KHÔNG phụ thuộc việc có nghe thấy sóng minor hay không. Khu
  /// là một mạch thuyết minh liền: chỉ cần bắt được major (đang trong khu) là
  /// phát hết hiện vật, đồng nhất với danh sách màn 3 (cũng hiện hết manifest).
  ///
  /// Chỉ bỏ qua hiện vật KHÔNG resolve được audio ở ngôn ngữ hiện tại (thiếu
  /// track) — đi tiếp hiện vật sau. Hết danh sách → dừng auto-tour, chờ tap
  /// hoặc đổi zone.
  ///
  /// (Trước đây bản này lọc theo ExhibitPresenceTracker — "chỉ phát hiện vật
  /// đang có sóng". Đã gỡ theo quyết định sản phẩm: hiển thị và audio đều dựa
  /// trọn vào manifest, chỉ cần major.)
  void _playNextFrom(ZoneInfo zone, int startIndex) {
    for (int i = startIndex; i < zone.exhibits.length; i++) {
      final exhibit = zone.exhibits[i];
      final resolved = exhibit.audio.resolve(_language(), _fallback);
      if (resolved == null) continue; // thiếu audio ngôn ngữ này → bỏ qua, đi tiếp
      _autoIndex = i + 1; // lần sau bắt đầu SAU hiện vật này
      _engine.load(
        AudioTrackRef(
          zoneMajor: zone.major,
          exhibitMinor: exhibit.minor,
          clipKind: AudioClipKind.exhibitAuto,
        ),
        _resolveUri(resolved.track.filePath),
        durationHint: Duration(
            milliseconds: (resolved.track.durationSec * 1000).round()),
      );
      _tryPlay();
      return;
    }
    // Hết hiện vật trong khu → dừng auto-tour ở đây.
    _autoIndex = zone.exhibits.length;
  }

  /// Headphone connection changed. Rule 6.
  void _onHeadphoneChanged(bool connected) {
    // Debug override: ignore unplug entirely so bench testing over the speaker
    // isn't cut short. Revert kDebugAssumeHeadphones to restore rule 6.
    if (kDebugAssumeHeadphones) return;

    if (!connected) {
      // Rút tai nghe = khách muốn dừng.
      //
      // ⚠ LƯU Ý PHẠM VI: cờ này SỐNG TIẾP sau khi cắm lại, nên nó không chỉ
      // dừng clip hiện tại mà còn khiến MỌI khu tiếp theo im lặng cho tới khi
      // khách bấm play / chạm một hiện vật. Đó là luật 6 được mở rộng, và trên
      // máy bỏ túi màn tắt khách có thể không hiểu vì sao tour "chết". Nếu thực
      // địa báo lỗi này, chỗ sửa là ở ĐÂY (ví dụ: cắm lại trong ~10 giây thì
      // coi như cùng một thao tác vật lý và hạ cờ), không phải ở tầng engine.
      _userPaused = true;
      // Becoming noisy -> pause immediately (never blast the loudspeaker).
      if (_engine.state.status == PlaybackStatus.playing) {
        _engine.pause();
      }
    }
    // Replug: do NOTHING — wait for an explicit play (gold standard).
  }

  // ========================================================================

  void _flushQueue() {
    _engine.stop();
  }

  /// Dọn TOÀN BỘ trí nhớ thuộc về một tour. Gọi ở ĐÚNG MỘT chỗ —
  /// SessionController, ở đầu mỗi tour — và phải chạy kể cả khi tour trước kết
  /// thúc bất thường (sạc / về bàn / im lặng / staff).
  ///
  /// ⚠ Tên này đã đổi từ `resetVisitedZones()`: kiểm tra `tour_wiring.dart`
  /// (TourAudioSinkAdapter.resetSessionMemory) đang gọi đúng tên mới.
  void resetSessionMemory() {
    _visitedZones.clear();
    _userPaused = false; // Khách mới vào mặc định là muốn nghe
  }

  String get _fallback => _config?.fallbackLanguage ?? _language();

  Future<void> dispose() async {
    await _completedSub.cancel();
    await _headphoneSub.cancel();
  }

  // ---- test visibility ----
  @visibleForTesting
  int get autoIndex => _autoIndex;
  @visibleForTesting
  Set<int> get visitedZones => Set.unmodifiable(_visitedZones);
  @visibleForTesting
  int? get activeZoneMajor => _activeZoneMajor;
  @visibleForTesting
  bool get userPaused => _userPaused;
}