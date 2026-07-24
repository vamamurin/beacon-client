// Destination: lib/services/tour_wiring.dart
//
// One small adapter that connects already-built services into a running whole.
//
//  • TourAudioSinkAdapter: lets SessionController drive TourAudioController for
//    end-of-session cleanup, via the minimal TourAudioSink surface.
//
// NOTE (C2): the old ZoneEventRouter that fanned ZoneEvents straight to audio
// is GONE — ZoneChangeCoordinator now owns that path so it can defer a
// ChangedZone behind the confirm banner. The session controller still consumes
// the SAME event stream directly (it only needs the "first EnteredZone" edge),
// wired in injection.

import 'package:beacon_client/services/session_controller.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';

/// Adapts TourAudioController to the TourAudioSink the session needs.
class TourAudioSinkAdapter implements TourAudioSink {
  TourAudioSinkAdapter(this._audio);
  final TourAudioController _audio;

  @override
  void stopAll() => _audio.leaveToStandby(); // stops playback + flushes queue

  @override
  void resetSessionMemory() => _audio.resetSessionMemory();
}