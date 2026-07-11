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
//      the engine's status AT THAT INSTANT: was playing -> autoplay new intro;
//      was paused (user or unplug) -> load new intro but stay silent until the
//      visitor presses play. Physical-space sync is supreme; the paused
//      visitor's intent is still honoured for "start new sound or not".
//  (5) REVISIT a zone already seen this session (revisitPlaysWelcome=false)
//      -> chime only, no intro, wait for a tap.
//  (6) UNPLUG headphones -> pause now; REPLUG -> wait for explicit play.
//
// Chime policy (confirmed): chime fires on zone CHANGE and REVISIT, not on the
// first entry from standby (there the intro itself is the arrival cue).

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

  /// Zones whose intro has been heard this session (rule 5). RAM-only — the
  /// session boundary (Phase 3) constructs a fresh controller, so revisit
  /// memory dies with the session exactly as intended.
  final Set<int> _visitedZones = {};

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
    _beginZoneAudio(zone, chime: false);
  }

  /// Visitor moved from one zone to another. Rules 3+4 (+5 for revisits).
  /// ALWAYS interrupt + flush + chime; autoplay-vs-silent depends on the
  /// engine's status at THIS instant.
  void changeZone(int major) {
    final zone = _repo.zoneByMajor(major);
    if (zone == null) return;

    // Judge intent BEFORE we tear anything down (confirmed: state at the
    // instant the change event arrives).
    final bool wasPlaying = _engine.state.status == PlaybackStatus.playing;

    _flushQueue(); // stop + unload old zone's queue (supreme physical sync)
    _activeZoneMajor = major;
    _autoIndex = 0;
    _chime(); // zone change always chimes (trừ reading mode — cấm mọi tiếng)

    _beginZoneAudio(zone, chime: false, forcePlay: wasPlaying, alreadyChimed: true);
  }

  /// Radio dropped to standby (Phase 1 rule 4). Stop audio; keep visited memory.
  void leaveToStandby() {
    _flushQueue();
    _activeZoneMajor = null;
    _autoIndex = 0;
  }

  /// Shared entry/change audio logic.
  ///
  /// [forcePlay]: when set (zone change), overrides the autoplay decision with
  /// the pre-change playing state (honours a paused visitor).
  void _beginZoneAudio(
    ZoneInfo zone, {
    required bool chime,
    bool? forcePlay,
    bool alreadyChimed = false,
  }) {
    final bool revisit = _visitedZones.contains(zone.major);

    if (chime && !alreadyChimed) _chime();

    // Rule 5: revisiting a seen zone -> chime only (chime already handled by
    // caller for change; enterZone passes chime:false), no intro, wait for tap.
    if (revisit && !(_config?.policies.revisitPlaysWelcome ?? false)) {
      // Nothing loaded/played; the grid awaits a manual tap.
      return;
    }

    _visitedZones.add(zone.major);

    // Decide whether to actually START sound.
    //
    // FIX B5: forcePlay là mệnh lệnh "khách ĐANG nghe khi đổi zone → intro mới
    // phát tiếp" (rule 3+4). Bản cũ AND thêm _autoplayAllowed nên forcePlay
    // chỉ phủ quyết được, không ép được — khách nghe qua loa (bảo tàng cho
    // phép) sang zone mới bị im lặng khó hiểu. Giờ forcePlay đi thẳng vào
    // _loadIntro; cổng cuối cùng vẫn là _tryPlay (reading mode phủ quyết
    // TUYỆT ĐỐI mọi đường phát tiếng — bất khả kháng vật lý, không phải
    // preference).
    final bool shouldPlay = forcePlay ?? _autoplayAllowed;

    // Load the intro either way (so a paused visitor can press play, and so
    // reading mode has a "current" ref to show the transcript for).
    _loadIntro(zone, play: shouldPlay);
  }

  void _loadIntro(ZoneInfo zone, {required bool play}) {
    final resolved = zone.introAudio.resolve(_language(), _fallback);
    if (resolved == null) return;
    _autoIndex = 0; // exhibits start after the intro
    _engine.load(
      AudioTrackRef.zoneIntro(zone.major),
      _resolveUri(resolved.track.filePath),
      durationHint: Duration(
          milliseconds: (resolved.track.durationSec * 1000).round()),
    );
    if (play) _tryPlay();
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

  /// Visitor bấm play (resume, hoặc khởi động một intro đã load nhưng im).
  AudioIntentResult userPlay() {
    if (_engine.state.current == null) return AudioIntentResult.noClip;
    return _tryPlay()
        ? AudioIntentResult.started
        : AudioIntentResult.blockedNoHeadphones;
  }

  /// Visitor bấm pause.
  void userPause() => _engine.pause();

  /// Visitor bấm "Về đầu". Tua về 0 LUÔN được phép (đây là thao tác vị trí,
  /// không phải phát tiếng); chỉ việc phát mới đi qua cổng chính sách.
  AudioIntentResult userReplay() {
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
    _playExhibitAt(zone, _autoIndex);
  }

  void _playExhibitAt(ZoneInfo zone, int index) {
    if (index < 0 || index >= zone.exhibits.length) {
      return; // tour of this zone complete; go quiet, await tap or zone change
    }
    final exhibit = zone.exhibits[index];
    final resolved = exhibit.audio.resolve(_language(), _fallback);
    if (resolved == null) {
      // Skip a clip that failed to resolve; keep the tour moving.
      _autoIndex = index + 1;
      _playExhibitAt(zone, _autoIndex);
      return;
    }
    _autoIndex = index + 1; // next up
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
  }

  /// Headphone connection changed. Rule 6.
  void _onHeadphoneChanged(bool connected) {
    // Debug override: ignore unplug entirely so bench testing over the speaker
    // isn't cut short. Revert kDebugAssumeHeadphones to restore rule 6.
    if (kDebugAssumeHeadphones) return;

    if (!connected) {
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

  void resetVisitedZones() => _visitedZones.clear();

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
}