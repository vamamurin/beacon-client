// Destination: lib/services/tour_wiring.dart
//
// Two small adapters that connect the already-built services into a running
// whole (the "hinge" flagged since Phase 2). No new logic — pure wiring.
//
//  • TourAudioSinkAdapter: lets SessionController drive TourAudioController for
//    end-of-session cleanup, via the minimal TourAudioSink surface.
//  • ZoneEventRouter: fans ZonePresenceService's ZoneEvents out to BOTH the
//    audio controller (enter/change/leave) and any other listener. The session
//    controller consumes the SAME event stream directly (it only needs the
//    "first EnteredZone" edge), so it's wired straight in injection.

import 'dart:async';

import 'package:beacon_client/services/session_controller.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

/// Adapts TourAudioController to the TourAudioSink the session needs.
class TourAudioSinkAdapter implements TourAudioSink {
  TourAudioSinkAdapter(this._audio);
  final TourAudioController _audio;

  @override
  void stopAll() => _audio.leaveToStandby(); // stops playback + flushes queue

  @override
  void resetSessionMemory() => _audio.resetVisitedZones();
}

/// Routes zone transition events to the audio controller. Only active while a
/// tour session is running — the session gates whether audio should react
/// (e.g. no audio at the gate). The [isTouring] callback lets the router drop
/// events that arrive outside a tour.
class ZoneEventRouter {
  ZoneEventRouter({
    required Stream<ZoneEvent> events,
    required TourAudioController audio,
    required bool Function() isTouring,
  })  : _audio = audio,
        _isTouring = isTouring {
    _sub = events.listen(_route);
  }

  final TourAudioController _audio;
  final bool Function() _isTouring;
  late final StreamSubscription<ZoneEvent> _sub;

  void _route(ZoneEvent e) {
    if (!_isTouring()) return; // audio reacts only during an active tour
    switch (e) {
      case EnteredZone(:final major):
        _audio.enterZone(major);
      case ChangedZone(:final toMajor):
        _audio.changeZone(toMajor);
      case LeftToStandby():
        _audio.leaveToStandby();
    }
  }

  Future<void> dispose() => _sub.cancel();
}
