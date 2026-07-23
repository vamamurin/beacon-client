// Destination: lib/services/analytics_recorder.dart
//
// Turns the pipeline's EXISTING streams into analytics events. This is a pure
// listener wired in the composition root — exactly like NearbyZonesTracker
// (listens to presence.signals) and AutoSyncScheduler (listens to
// session.state). It touches nothing it observes, so SessionController, the
// ZoneArbiter and TourAudioController stay byte-for-byte unchanged.
//
// Sources (all already exposed on AppGraph):
//   • session.state            (Stream<SessionState>)  -> tour start/end + duration
//   • presence.events          (Stream<ZoneEvent>)     -> zone dwell (enter/change/standby)
//   • engine.onStateChanged    (Stream<AudioQueueState>) -> clip start + "cut short"
//   • engine.onCompleted       (Stream<AudioTrackRef>)  -> clip heard to the end
//
// Derivations that matter (and their edge cases):
//   ZONE DWELL — open a span on Entered/Changed, close it (emit the elapsed
//     span) on the NEXT Entered/Changed, on LeftToStandby, and on tour end.
//     The tour-start resync replays EnteredZone for the zone the visitor is
//     already standing in, so a dwell opens at Start as intended.
//   CLIP FINISHED — natural end arrives as onCompleted; a cut arrives as
//     onStateChanged carrying a DIFFERENT current ref (or null) while a clip
//     was still open. Completion order from JustAudioEngine is (state: paused,
//     same ref) THEN (completed: ref); we key off the ref identity + an
//     "accounted" flag so neither path double-counts.
//
// Everything is stamped from the injected [now], and a new sessionId per tour
// is injectable too, so a scripted stream sequence produces a byte-stable event
// log under test (see test/services/analytics_recorder_test.dart).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_analytics_sink.dart';
import 'package:beacon_client/domain/models/analytics_event.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

class AnalyticsRecorder {
  AnalyticsRecorder({
    required Stream<SessionState> sessionState,
    required Stream<ZoneEvent> zoneEvents,
    required Stream<AudioQueueState> audioState,
    required Stream<AudioTrackRef> audioCompleted,
    required IAnalyticsSink sink,
    required String Function() languageCode,
    required bool Function() headphonesConnected,
    String Function()? newSessionId,
    DateTime Function()? now,
  })  : _sink = sink,
        _language = languageCode,
        _headphones = headphonesConnected,
        _newSessionId = newSessionId ?? _defaultSessionId,
        _now = now ?? DateTime.now {
    _sessionSub = sessionState.listen(_onSession);
    _zoneSub = zoneEvents.listen(_onZone);
    _audioSub = audioState.listen(_onAudioState);
    _completedSub = audioCompleted.listen(_onAudioCompleted);
  }

  final IAnalyticsSink _sink;
  final String Function() _language;
  final bool Function() _headphones;
  final String Function() _newSessionId;
  final DateTime Function() _now;

  late final StreamSubscription<SessionState> _sessionSub;
  late final StreamSubscription<ZoneEvent> _zoneSub;
  late final StreamSubscription<AudioQueueState> _audioSub;
  late final StreamSubscription<AudioTrackRef> _completedSub;

  // ---- tour state ----
  bool _inTour = false;
  String? _sid; // current tour's analytics session id (null outside a tour)
  DateTime? _tourStart;

  // ---- open zone dwell ----
  int? _zoneMajor;
  DateTime? _zoneSince;
  ZoneEntryKind? _zoneEntry;

  // ---- open clip ----
  AudioTrackRef? _clip;
  DateTime? _clipStart;
  Duration? _clipTotal;
  bool _clipAccounted = true; // true = no open clip needing a Finished event

  // ============================================================ session
  void _onSession(SessionState s) {
    final touring = s.phase == SessionPhase.touring;

    if (touring && !_inTour) {
      _inTour = true;
      _sid = _newSessionId();
      _tourStart = _now();
      _resetTrackers();
      _emit(TourStarted(
        sessionId: _sid!,
        at: _now(),
        language: _language(),
        headphones: _headphones(),
      ));
      return;
    }

    if (!touring && _inTour) {
      // Close any open spans BEFORE we drop the session id (they need it).
      _closeZone();
      if (!_clipAccounted) _accountClip(completed: false);

      final started = _tourStart ?? _now();
      _emit(TourEnded(
        sessionId: _sid!,
        at: _now(),
        reason: s.endReason,
        duration: _now().difference(started),
      ));

      _inTour = false;
      _sid = null;
      _tourStart = null;
      _resetTrackers();

      // Persist this tour's events at the boundary; upload happens later when
      // docked (drain), never here.
      unawaited(_sink.flush());
    }
  }

  // ============================================================ zone dwell
  void _onZone(ZoneEvent e) {
    if (_sid == null) return; // ignore radio traffic outside a tour
    switch (e) {
      case EnteredZone(:final major):
        _closeZone(); // normally none open; defensive
        _openZone(major, ZoneEntryKind.entered);
      case ChangedZone(:final fromMajor, :final toMajor):
        _closeZone(fallbackMajor: fromMajor);
        _openZone(toMajor, ZoneEntryKind.changed);
      case LeftToStandby():
        _closeZone();
    }
  }

  void _openZone(int major, ZoneEntryKind entry) {
    _zoneMajor = major;
    _zoneSince = _now();
    _zoneEntry = entry;
  }

  void _closeZone({int? fallbackMajor}) {
    final major = _zoneMajor ?? fallbackMajor;
    final since = _zoneSince;
    if (major == null || since == null || _sid == null) {
      _clearZone();
      return;
    }
    _emit(ZoneDwell(
      sessionId: _sid!,
      at: _now(),
      major: major,
      duration: _now().difference(since),
      entry: _zoneEntry ?? ZoneEntryKind.entered,
    ));
    _clearZone();
  }

  void _clearZone() {
    _zoneMajor = null;
    _zoneSince = null;
    _zoneEntry = null;
  }

  // ============================================================ clip
  void _onAudioState(AudioQueueState s) {
    // Audio only plays during a tour; open clips are closed by the session
    // handler BEFORE the id is cleared, so outside a tour there is nothing to
    // account and no valid session id to stamp.
    if (_sid == null) return;
    final ref = s.current;

    // A clip we were tracking got replaced/unloaded before its end.
    if (!_clipAccounted && ref != _clip) {
      _accountClip(completed: false);
    }

    if (ref == null) return; // nothing loaded now

    if (s.status == PlaybackStatus.playing && ref != _clip) {
      // A (new) clip started producing sound.
      _clip = ref;
      _clipStart = _now();
      _clipTotal = s.duration;
      _clipAccounted = false;
      _emit(ExhibitPlayed(
        sessionId: _sid!,
        at: _now(),
        major: ref.zoneMajor,
        minor: ref.exhibitMinor,
        kind: ref.clipKind,
      ));
    }
  }

  void _onAudioCompleted(AudioTrackRef ref) {
    if (_clip == ref && !_clipAccounted) _accountClip(completed: true);
  }

  void _accountClip({required bool completed}) {
    final ref = _clip;
    final start = _clipStart;
    if (ref == null || start == null || _sid == null) {
      _clipAccounted = true;
      return;
    }
    _emit(ExhibitFinished(
      sessionId: _sid!,
      at: _now(),
      major: ref.zoneMajor,
      minor: ref.exhibitMinor,
      kind: ref.clipKind,
      listened: _now().difference(start),
      total: _clipTotal,
      completed: completed,
    ));
    _clipAccounted = true;
  }

  // ============================================================ helpers
  void _resetTrackers() {
    _clearZone();
    _clip = null;
    _clipStart = null;
    _clipTotal = null;
    _clipAccounted = true;
  }

  void _emit(AnalyticsEvent e) {
    _sink.record(e);
    if (kDebugMode) debugPrint('[Analytics] ${e.name} ${e.payload()}');
  }

  Future<void> dispose() async {
    await _sessionSub.cancel();
    await _zoneSub.cancel();
    await _audioSub.cancel();
    await _completedSub.cancel();
  }

  static final math.Random _rand = math.Random();

  /// Opaque, non-identifying id: microsecond clock + random suffix. Not a UUID
  /// (no extra dependency); collision-safe enough for grouping one device's
  /// tours.
  static String _defaultSessionId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final r = _rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$t-$r';
  }
}