// Destination: test/services/analytics_recorder_test.dart
//
// Golden-style test for AnalyticsRecorder: drive the four source streams with a
// scripted walkthrough and an injected clock, and assert the EXACT derived
// event log. This is the payoff of the codebase's injectable-clock discipline —
// no real time, no plugins, byte-stable output.
//
// Scenario (clock in seconds from a fixed base):
//   t0  session -> touring                         => TourStarted
//   t1  EnteredZone(1)                             (opens zone-1 dwell)
//   t2  audio playing zone-1 intro (30s)           => ExhibitPlayed intro/z1
//   t10 audio paused (same clip) then completed    => ExhibitFinished intro/z1 (completed)
//   t11 audio playing z1 exhibit 5 auto (20s)      => ExhibitPlayed auto/z1#5
//   t15 ChangedZone(1 -> 2)                         => ZoneDwell z1 (14s, entered)
//   t15 audio idle (zone change stopped the clip)  => ExhibitFinished auto/z1#5 (cut, 4s)
//   t16 audio playing zone-2 intro (25s)           => ExhibitPlayed intro/z2
//   t40 session -> ending(silence)                  => ZoneDwell z2 (25s, changed),
//                                                       ExhibitFinished intro/z2 (cut, 24s),
//                                                       TourEnded(silence, 40s)
//   t40 session -> atDesk(silence)                  (dedup: no second TourEnded)
//   t41 EnteredZone(9) after the tour               (ignored: no active session)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/domain/interfaces/i_analytics_sink.dart';
import 'package:beacon_client/domain/models/analytics_event.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/analytics_recorder.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

class _RecordingSink implements IAnalyticsSink {
  final List<AnalyticsEvent> events = [];
  int flushCount = 0;
  int drainCount = 0;

  @override
  void record(AnalyticsEvent event) => events.add(event);
  @override
  Future<void> flush() async => flushCount++;
  @override
  Future<void> drain() async => drainCount++;
  @override
  Future<void> dispose() async {}
}

void main() {
  test('derives the expected event log for one walkthrough', () async {
    final base = DateTime.utc(2026, 1, 1, 10, 0, 0);
    var clock = base;
    DateTime now() => clock;
    void at(int sec) => clock = base.add(Duration(seconds: sec));

    final session = StreamController<SessionState>.broadcast();
    final zones = StreamController<ZoneEvent>.broadcast();
    final audio = StreamController<AudioQueueState>.broadcast();
    final completed = StreamController<AudioTrackRef>.broadcast();
    final sink = _RecordingSink();

    final recorder = AnalyticsRecorder(
      sessionState: session.stream,
      zoneEvents: zones.stream,
      audioState: audio.stream,
      audioCompleted: completed.stream,
      sink: sink,
      languageCode: () => 'en',
      headphonesConnected: () => true,
      newSessionId: () => 'S1',
      now: now,
    );

    Future<void> pump() => pumpEventQueue();

    const introZ1 = AudioTrackRef.zoneIntro(1);
    const autoZ1e5 = AudioTrackRef(
        zoneMajor: 1, exhibitMinor: 5, clipKind: AudioClipKind.exhibitAuto);
    const introZ2 = AudioTrackRef.zoneIntro(2);

    at(0);
    session.add(const SessionState(phase: SessionPhase.touring));
    await pump();

    at(1);
    zones.add(const EnteredZone(1));
    await pump();

    at(2);
    audio.add(const AudioQueueState(
        current: introZ1,
        status: PlaybackStatus.playing,
        duration: Duration(seconds: 30)));
    await pump();

    at(10);
    audio.add(const AudioQueueState(
        current: introZ1,
        status: PlaybackStatus.paused,
        duration: Duration(seconds: 30)));
    completed.add(introZ1);
    await pump();

    at(11);
    audio.add(const AudioQueueState(
        current: autoZ1e5,
        status: PlaybackStatus.playing,
        duration: Duration(seconds: 20)));
    await pump();

    at(15);
    zones.add(const ChangedZone(1, 2));
    audio.add(AudioQueueState.idle); // zone change stops the old clip
    await pump();

    at(16);
    audio.add(const AudioQueueState(
        current: introZ2,
        status: PlaybackStatus.playing,
        duration: Duration(seconds: 25)));
    await pump();

    at(40);
    session.add(const SessionState(
        phase: SessionPhase.ending, endReason: SessionEndReason.silence));
    await pump();
    session.add(const SessionState(
        phase: SessionPhase.atDesk, endReason: SessionEndReason.silence));
    await pump();

    at(41);
    zones.add(const EnteredZone(9)); // after tour: must be ignored
    await pump();

    final e = sink.events;
    expect(e.length, 10, reason: 'unexpected event count: ${e.map((x) => x.name).toList()}');

    // 1. TourStarted
    expect(e[0], isA<TourStarted>());
    final started = e[0] as TourStarted;
    expect(started.sessionId, 'S1');
    expect(started.language, 'en');
    expect(started.headphones, true);

    // 2. intro z1 played
    expect(e[1], isA<ExhibitPlayed>());
    expect((e[1] as ExhibitPlayed).major, 1);
    expect((e[1] as ExhibitPlayed).minor, isNull);
    expect((e[1] as ExhibitPlayed).kind, AudioClipKind.zoneIntro);

    // 3. intro z1 finished (completed)
    expect(e[2], isA<ExhibitFinished>());
    final introFin = e[2] as ExhibitFinished;
    expect(introFin.completed, true);
    expect(introFin.listened, const Duration(seconds: 8));
    expect(introFin.total, const Duration(seconds: 30));

    // 4. auto exhibit 5 played
    expect(e[3], isA<ExhibitPlayed>());
    expect((e[3] as ExhibitPlayed).minor, 5);
    expect((e[3] as ExhibitPlayed).kind, AudioClipKind.exhibitAuto);

    // 5. zone 1 dwell (14s, entered)
    expect(e[4], isA<ZoneDwell>());
    final dwell1 = e[4] as ZoneDwell;
    expect(dwell1.major, 1);
    expect(dwell1.duration, const Duration(seconds: 14));
    expect(dwell1.entry, ZoneEntryKind.entered);

    // 6. auto exhibit 5 finished (cut short, 4s)
    expect(e[5], isA<ExhibitFinished>());
    final autoFin = e[5] as ExhibitFinished;
    expect(autoFin.completed, false);
    expect(autoFin.listened, const Duration(seconds: 4));
    expect(autoFin.total, const Duration(seconds: 20));

    // 7. intro z2 played
    expect(e[6], isA<ExhibitPlayed>());
    expect((e[6] as ExhibitPlayed).major, 2);

    // 8. zone 2 dwell (25s, changed)
    expect(e[7], isA<ZoneDwell>());
    final dwell2 = e[7] as ZoneDwell;
    expect(dwell2.major, 2);
    expect(dwell2.duration, const Duration(seconds: 25));
    expect(dwell2.entry, ZoneEntryKind.changed);

    // 9. intro z2 finished (cut short at tour end, 24s)
    expect(e[8], isA<ExhibitFinished>());
    final introZ2Fin = e[8] as ExhibitFinished;
    expect(introZ2Fin.completed, false);
    expect(introZ2Fin.listened, const Duration(seconds: 24));

    // 10. TourEnded (silence, 40s)
    expect(e[9], isA<TourEnded>());
    final ended = e[9] as TourEnded;
    expect(ended.reason, SessionEndReason.silence);
    expect(ended.duration, const Duration(seconds: 40));

    // Every event shares the tour's session id.
    expect(e.every((x) => x.sessionId == 'S1'), true);

    // Flushed at the tour boundary.
    expect(sink.flushCount, greaterThanOrEqualTo(1));

    await recorder.dispose();
    await session.close();
    await zones.close();
    await audio.close();
    await completed.close();
  });
}