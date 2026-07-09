// Destination: test/tour_audio_controller_test.dart
// Run with: flutter test test/tour_audio_controller_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';

import 'fakes/fake_audio_engine.dart';

// The mock bundle: zone 1 (minors 1,2,5), zone 2 (minors 1,2). Desk 99.
// Policies: allowLoudspeaker=false, autoplayRequiresHeadphones=true,
// revisitPlaysWelcome=false.
//
// NOTE: minor 5 exists ONLY in zone 1. That asymmetry is what lets the
// cross-zone tests below distinguish "resolved against the screen's frozen
// major" from "resolved against the arbiter's active major", without needing
// the fake engine to log source URIs.
//
// NOTE: these tests assume TourAudioController.kDebugAssumeHeadphones is
// false. It is, unless someone passes --dart-define=ASSUME_HEADPHONES=true,
// which must never happen in CI — the flag disables reading mode outright and
// every reading-mode test here would (correctly) fail.

Uri _resolve(String path) => Uri.parse('file:///bundle/$path');

/// Builds a warmed controller + fakes. [headphones] toggles listening route.
Future<
    ({
      TourAudioController ctrl,
      FakeAudioEngine engine,
      FakeHeadphoneMonitor hp,
      MockZoneRepository repo,
    })> harness({bool headphones = true}) async {
  final repo = MockZoneRepository(simulatedLatency: Duration.zero);
  await repo.preWarm();
  final engine = FakeAudioEngine();
  final hp = FakeHeadphoneMonitor(connected: headphones);
  var chimes = 0;
  final ctrl = TourAudioController(
    repository: repo,
    engine: engine,
    headphones: hp,
    uriResolver: _resolve,
    language: () => 'vi',
    onChime: () => chimes++,
  );
  return (ctrl: ctrl, engine: engine, hp: hp, repo: repo);
}

/// Chime-counting variant.
Future<({TourAudioController ctrl, FakeAudioEngine engine, int Function() chimes})>
    harnessWithChimes({bool headphones = true}) async {
  final repo = MockZoneRepository(simulatedLatency: Duration.zero);
  await repo.preWarm();
  final engine = FakeAudioEngine();
  final hp = FakeHeadphoneMonitor(connected: headphones);
  var chimes = 0;
  final ctrl = TourAudioController(
    repository: repo,
    engine: engine,
    headphones: hp,
    uriResolver: _resolve,
    language: () => 'vi',
    onChime: () => chimes++,
  );
  return (ctrl: ctrl, engine: engine, chimes: () => chimes);
}

void main() {
  group('Rule 1 — enter zone, auto-tour with headphones', () {
    test('plays intro then auto-advances through exhibits in order', () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();

      // Intro loaded and playing.
      expect(h.engine.loadLog.first.isIntro, isTrue);
      expect(h.engine.state.isPlaying, isTrue);

      // Intro finishes -> exhibit at index 0 (minor 1).
      h.engine.completeCurrent();
      await pumpEventQueue();
      expect(h.engine.loadLog.last.exhibitMinor, 1);
      expect(h.engine.loadLog.last.clipKind, AudioClipKind.exhibitAuto);

      // Next two exhibits in tour order: minors 2, then 5.
      h.engine.completeCurrent();
      await pumpEventQueue();
      expect(h.engine.loadLog.last.exhibitMinor, 2);
      h.engine.completeCurrent();
      await pumpEventQueue();
      expect(h.engine.loadLog.last.exhibitMinor, 5);

      // Tour of the zone complete -> goes quiet, no further loads.
      final countAtEnd = h.engine.loadLog.length;
      h.engine.completeCurrent();
      await pumpEventQueue();
      expect(h.engine.loadLog.length, countAtEnd);
    });

    test('no chime on first entry from standby', () async {
      final h = await harnessWithChimes();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      expect(h.chimes(), 0);
    });
  });

  group('Rule 1 (reading mode) — no headphones', () {
    test('entering loads intro but plays NO sound', () async {
      final h = await harness(headphones: false);
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      expect(h.engine.loadLog.first.isIntro, isTrue); // loaded for transcript
      expect(h.engine.state.isPlaying, isFalse); // but silent
    });

    test('completing does not auto-advance in reading mode', () async {
      final h = await harness(headphones: false);
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.engine.completeCurrent();
      await pumpEventQueue();
      // Only the intro was ever loaded; no exhibit auto-queued.
      expect(h.engine.loadLog.length, 1);
    });
  });

  group('Rule 2a — manual tap interrupts, resumes after', () {
    test('tap plays that clip, then auto-tour continues from the NEXT', () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.engine.completeCurrent(); // intro -> exhibit minor 1 auto
      await pumpEventQueue();

      // Visitor taps the grenade (minor 5, tour index 2).
      h.ctrl.tapExhibit(major: 1, minor: 5);
      await pumpEventQueue();
      expect(h.engine.loadLog.last.exhibitMinor, 5);
      expect(h.engine.loadLog.last.clipKind, AudioClipKind.exhibitManual);
      expect(h.ctrl.autoIndex, 3); // resume AFTER index 2

      // That clip ends -> resume from index 3, which is past the end (zone 1
      // has 3 exhibits: indices 0,1,2) -> tour quietly completes.
      final count = h.engine.loadLog.length;
      h.engine.completeCurrent();
      await pumpEventQueue();
      expect(h.engine.loadLog.length, count); // nothing after last exhibit
    });

    test('tap mid-tour resumes at the exhibit after the tapped one', () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.engine.completeCurrent(); // playing minor 1 (index 0)
      await pumpEventQueue();

      // Tap minor 1 (index 0) -> resume should be index 1 (minor 2).
      h.ctrl.tapExhibit(major: 1, minor: 1);
      await pumpEventQueue();
      expect(h.ctrl.autoIndex, 1);
      h.engine.completeCurrent(); // manual done -> auto index 1 = minor 2
      await pumpEventQueue();
      expect(h.engine.loadLog.last.exhibitMinor, 2);
      expect(h.engine.loadLog.last.clipKind, AudioClipKind.exhibitAuto);
    });

    test('tap in reading mode loads clip but stays silent (rule a)', () async {
      final h = await harness(headphones: false);
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      final r = h.ctrl.tapExhibit(major: 1, minor: 5);
      await pumpEventQueue();
      expect(r, AudioIntentResult.blockedNoHeadphones);
      expect(h.engine.loadLog.last.exhibitMinor, 5); // loaded for transcript
      expect(h.engine.state.isPlaying, isFalse); // never blasts loudspeaker
    });
  });

  group('Rules 3+4 — zone change: flush + chime, autoplay vs silent', () {
    test('change while PLAYING -> flush old, chime, autoplay new intro', () async {
      final h = await harnessWithChimes();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      // engine playing zone 1 intro
      h.ctrl.changeZone(2);
      await pumpEventQueue();

      expect(h.engine.stopCount, greaterThan(0)); // old queue flushed
      expect(h.chimes(), 1); // zone change chimes
      expect(h.engine.loadLog.last.zoneMajor, 2);
      expect(h.engine.loadLog.last.isIntro, isTrue);
      expect(h.engine.state.isPlaying, isTrue); // autoplayed
    });

    test('change while PAUSED -> flush, chime, load intro but STAY silent',
        () async {
      final h = await harnessWithChimes();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.ctrl.userPause(); // visitor declared "not now"
      await pumpEventQueue();
      h.ctrl.changeZone(2);
      await pumpEventQueue();

      expect(h.chimes(), 1);
      expect(h.engine.loadLog.last.zoneMajor, 2);
      expect(h.engine.loadLog.last.isIntro, isTrue);
      expect(h.engine.state.isPlaying, isFalse); // honoured pause intent
    });
  });

  group('Rule 5 — revisit', () {
    test('returning to a seen zone chimes only, no intro playback', () async {
      final h = await harnessWithChimes();
      h.ctrl.enterZone(1); // visit zone 1
      await pumpEventQueue();
      h.ctrl.changeZone(2); // visit zone 2 (chime 1)
      await pumpEventQueue();
      final loadsBefore = h.engine.loadLog.length;
      h.ctrl.changeZone(1); // REVISIT zone 1 (chime 2)
      await pumpEventQueue();

      expect(h.chimes(), 2);
      // No new intro loaded for the revisit; queue was flushed and left quiet.
      expect(h.engine.loadLog.length, loadsBefore);
      expect(h.engine.state.isPlaying, isFalse);
    });
  });

  group('Rule 6 — headphones', () {
    test('unplug during playback pauses immediately', () async {
      final h = await harness();
      h.ctrl.enterZone(1); // playing
      await pumpEventQueue();
      expect(h.engine.state.isPlaying, isTrue);

      h.hp.setConnected(false); // becoming noisy
      await pumpEventQueue();
      expect(h.engine.state.isPaused, isTrue);
    });

    test('replug does NOT auto-resume', () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.hp.setConnected(false);
      await pumpEventQueue();
      expect(h.engine.state.isPaused, isTrue);

      h.hp.setConnected(true);
      await pumpEventQueue();
      expect(h.engine.state.isPaused, isTrue); // waits for explicit play
    });
  });

  group('leaveToStandby', () {
    test('flushes audio, keeps visited memory (no re-intro on return)',
        () async {
      final h = await harnessWithChimes();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.ctrl.leaveToStandby();
      await pumpEventQueue();
      expect(h.engine.state.current, isNull);

      // Return to zone 1: it was visited, so revisit rule -> chime only.
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      // enterZone from standby doesn't chime, and revisit suppresses intro:
      // no playback should start.
      expect(h.engine.state.isPlaying, isFalse);
    });
  });

  // ==========================================================================
  // Step 1 — the policy gate. Every playback intent must pass through
  // _tryPlay(); none may reach the engine behind reading mode's back.
  // ==========================================================================

  group('Policy gate — no playback intent bypasses reading mode', () {
    test('userPlay in reading mode reports blocked and stays silent', () async {
      final h = await harness(headphones: false);
      h.ctrl.enterZone(1); // intro loaded, silent
      await pumpEventQueue();
      expect(h.engine.state.isPlaying, isFalse);

      final r = h.ctrl.userPlay();
      await pumpEventQueue();

      expect(r, AudioIntentResult.blockedNoHeadphones);
      expect(h.engine.state.isPlaying, isFalse);
    });

    test('userReplay in reading mode seeks to 0 but never plays', () async {
      // This is the exact hole Step 1 closed: AudioProvider.replay() used to
      // call engine.seek + engine.play directly, so "Về đầu" would blast the
      // loudspeaker even though tapExhibit was careful not to.
      final h = await harness(headphones: false);
      h.ctrl.enterZone(1);
      await pumpEventQueue();

      final r = h.ctrl.userReplay();
      await pumpEventQueue();

      expect(r, AudioIntentResult.blockedNoHeadphones);
      expect(h.engine.state.isPlaying, isFalse);
    });

    test('userPlay with nothing loaded reports noClip, not a headphone problem',
        () async {
      // The UI must not show "plug in headphones" when the real reason is
      // "no clip has been loaded yet" — hence an enum rather than a bool.
      final h = await harness(headphones: false);
      final r = h.ctrl.userPlay(); // never entered a zone
      expect(r, AudioIntentResult.noClip);
    });

    test('with headphones, userReplay restarts the clip and plays', () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();

      final r = h.ctrl.userReplay();
      await pumpEventQueue();

      expect(r, AudioIntentResult.started);
      expect(h.engine.state.isPlaying, isTrue);
    });
  });

  // ==========================================================================
  // Step 2 — the screen's zone is frozen; the arbiter's is not. `minor` is
  // only unique within a zone, so a tap must resolve against the major the
  // CALLER is showing, never against _activeZoneMajor.
  //
  // Discriminator: minor 5 exists only in zone 1. Under the old code, tapping
  // it after the arbiter moved to zone 2 would resolve tourIndexOf(5) == -1
  // and silently load nothing.
  // ==========================================================================

  group('Cross-zone tap — screen zone frozen, arbiter zone moved', () {
    test('tap resolves against the SCREEN zone, not the arbiter zone', () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.ctrl.changeZone(2); // arbiter moved underneath the frozen screen
      await pumpEventQueue();
      expect(h.ctrl.activeZoneMajor, 2);

      final r = h.ctrl.tapExhibit(major: 1, minor: 5);
      await pumpEventQueue();

      expect(r, AudioIntentResult.started);
      expect(h.engine.loadLog.last.zoneMajor, 1);
      expect(h.engine.loadLog.last.exhibitMinor, 5);
      expect(h.engine.loadLog.last.clipKind, AudioClipKind.exhibitManual);
    });

    test('cross-zone tap does not hijack the active zone auto-queue', () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.ctrl.changeZone(2);
      await pumpEventQueue();
      final autoIndexBefore = h.ctrl.autoIndex; // zone 2's queue position

      h.ctrl.tapExhibit(major: 1, minor: 5); // index 2 inside zone 1
      await pumpEventQueue();

      // If _autoIndex jumped to 3, zone 2's auto-tour (the zone the visitor is
      // physically standing in) would resume from the wrong place.
      expect(h.ctrl.autoIndex, autoIndexBefore);
    });

    test('cross-zone manual clip goes quiet on completion (no auto-advance)',
        () async {
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();
      h.ctrl.changeZone(2);
      await pumpEventQueue();
      h.ctrl.tapExhibit(major: 1, minor: 5);
      await pumpEventQueue();
      final loadsBefore = h.engine.loadLog.length;

      h.engine.completeCurrent(); // zone 1's clip ends; visitor is in zone 2
      await pumpEventQueue();

      // PRODUCT DECISION, locked in by this test: go quiet and wait for a tap.
      // Advancing inside the stale zone drifts further from physical space
      // ("physical sync is supreme"); jumping into zone 2's queue would be
      // unexplainable to the listener. If someone "fixes" this into an
      // advance, they must delete this test and justify it.
      expect(h.engine.loadLog.length, loadsBefore);
    });

    test('tap into the active zone still advances the queue normally', () async {
      // Guard against over-correcting: the freeze only suppresses advance when
      // the tap is CROSS-zone. A tap inside the active zone behaves as rule 2a.
      final h = await harness();
      h.ctrl.enterZone(1);
      await pumpEventQueue();

      h.ctrl.tapExhibit(major: 1, minor: 1); // index 0, active zone
      await pumpEventQueue();
      expect(h.ctrl.autoIndex, 1);

      h.engine.completeCurrent();
      await pumpEventQueue();
      expect(h.engine.loadLog.last.exhibitMinor, 2);
      expect(h.engine.loadLog.last.clipKind, AudioClipKind.exhibitAuto);
    });
  });
}