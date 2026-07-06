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
import 'package:beacon_client/domain/models/audio_clip_info.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_info.dart';

/// Resolves a bundle-relative audio path to a playable Uri. Injected so the
/// same controller works over MockZoneRepository (asset/file) and the real
/// LocalBundleZoneRepository (file on disk) without knowing which.
typedef AudioUriResolver = Uri Function(String bundleRelativePath);

class TourAudioController {
  TourAudioController({
    required IZoneRepository repository,
    required IAudioEngine engine,
    required IHeadphoneMonitor headphones,
    required AudioUriResolver uriResolver,
    required String language,
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
  final String _language;
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

  bool get _autoplayAllowed {
    final cfg = _config;
    if (cfg == null) return false;
    // Reading mode is a PHYSICAL fact (no way to make sound without breaking
    // policy) and overrides everything: if we can't emit sound legitimately,
    // we never autoplay, regardless of the autoplayRequiresHeadphones setting.
    if (_readingMode) return false;
    // Otherwise honour the headphone-preference policy.
    if (cfg.policies.autoplayRequiresHeadphones && !_headphones.isConnected) {
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
    final noRoute = !_headphones.isConnected;
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
    _onChime(); // zone change always chimes

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

    if (chime && !alreadyChimed) _onChime();

    // Rule 5: revisiting a seen zone -> chime only (chime already handled by
    // caller for change; enterZone passes chime:false), no intro, wait for tap.
    if (revisit && !(_config?.policies.revisitPlaysWelcome ?? false)) {
      // Nothing loaded/played; the grid awaits a manual tap.
      return;
    }

    _visitedZones.add(zone.major);

    // Decide whether to actually START sound.
    final bool shouldPlay = forcePlay ?? _autoplayAllowed;

    // Load the intro either way (so a paused visitor can press play, and so
    // reading mode has a "current" ref to show the transcript for).
    _loadIntro(zone, play: shouldPlay && _autoplayAllowed);
  }

  void _loadIntro(ZoneInfo zone, {required bool play}) {
    final resolved = zone.introAudio.resolve(_language, _fallback);
    if (resolved == null) return;
    _autoIndex = 0; // exhibits start after the intro
    _engine.load(
      AudioTrackRef.zoneIntro(zone.major),
      _resolveUri(resolved.track.filePath),
      durationHint: Duration(
          milliseconds: (resolved.track.durationSec * 1000).round()),
    );
    if (play) _engine.play();
  }

  // ========================================================================
  // User commands
  // ========================================================================

  /// Visitor tapped an exhibit tile. Rule 2a: interrupt, play it, then resume
  /// auto-tour from the NEXT exhibit.
  void tapExhibit(int minor) {
    final major = _activeZoneMajor;
    if (major == null) return;
    final zone = _repo.zoneByMajor(major);
    if (zone == null) return;
    final idx = zone.tourIndexOf(minor);
    if (idx < 0) return;

    final exhibit = zone.exhibits[idx];
    final resolved = exhibit.audio.resolve(_language, _fallback);
    if (resolved == null) return;

    // Resume point: the exhibit AFTER the tapped one.
    _autoIndex = idx + 1;

    _engine.load(
      AudioTrackRef(
        zoneMajor: major,
        exhibitMinor: minor,
        clipKind: AudioClipKind.exhibitManual,
      ),
      _resolveUri(resolved.track.filePath),
      durationHint: Duration(
          milliseconds: (resolved.track.durationSec * 1000).round()),
    );
    // Rule (a): in reading mode a tap loads the clip (so the UI can show its
    // transcript) but plays NO sound — a tap must never blast the loudspeaker.
    // With headphones, a tap is an explicit request and always plays.
    if (!_readingMode) _engine.play();
  }

  /// Visitor pressed play (resume, or start a queued-but-silent intro).
  void userPlay() => _engine.play();

  /// Visitor pressed pause. Recorded implicitly via engine status; the
  /// zone-change logic reads that status to honour intent.
  void userPause() => _engine.pause();

  // ========================================================================
  // Reactions
  // ========================================================================

  /// A clip finished naturally -> advance the queue.
  void _onClipCompleted(AudioTrackRef ref) {
    final major = _activeZoneMajor;
    if (major == null) return;
    final zone = _repo.zoneByMajor(major);
    if (zone == null) return;

    // Only auto-advance when autoplay is allowed (headphones etc). In reading
    // mode a completed manual clip simply stops.
    if (!_autoplayAllowed) return;

    // Intro finished, or an exhibit (auto or manual) finished: play exhibit at
    // _autoIndex, which was set to idx+1 for a manual tap (rule 2a) or
    // incremented for the auto sequence.
    _playExhibitAt(zone, _autoIndex);
  }

  void _playExhibitAt(ZoneInfo zone, int index) {
    if (index < 0 || index >= zone.exhibits.length) {
      return; // tour of this zone complete; go quiet, await tap or zone change
    }
    final exhibit = zone.exhibits[index];
    final resolved = exhibit.audio.resolve(_language, _fallback);
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
    _engine.play();
  }

  /// Headphone connection changed. Rule 6.
  void _onHeadphoneChanged(bool connected) {
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
  
  String get _fallback => _config?.fallbackLanguage ?? _language;

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
