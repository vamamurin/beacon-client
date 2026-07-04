// Destination: test/zone_arbiter_test.dart
// Run with: flutter test test/zone_arbiter_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_presence.dart';
import 'package:beacon_client/domain/models/zone_signal.dart';

/// Manually-driven clock so each snapshot lands at a controlled instant —
/// the arbiter reads time via the injected `now`, never a real Timer.
class ManualClock {
  DateTime t = DateTime(2026, 7, 4, 9, 0, 0);
  DateTime call() => t;
  void advance(Duration d) => t = t.add(d);
}

ZoneSignal sig(int major, double rssi, DateTime at) => ZoneSignal(
      major: major,
      rssiDb: rssi,
      rssiByMinor: {0: rssi},
      lastSeenAt: at,
    );

/// Test params: delta 7 dB, dwell 3 s, lockout 12 s, zoneSilence 8 s,
/// deskDwell 10 s, sessionSilence 10 min (== manifest.example.json).
ArbitrationParams testParams() => ArbitrationParams.defaults();

void main() {
  late ManualClock clock;
  late ZoneArbiter arb;
  late List<ZonePresence> emitted;

  setUp(() {
    clock = ManualClock();
    arb = ZoneArbiter(deskMajor: 99, params: testParams(), now: clock);
    emitted = [];
    arb.presence.listen(emitted.add);
  });

  tearDown(() => arb.dispose());

  /// Push a snapshot at the current clock instant.
  void push(List<ZoneSignal> zones) => arb.onSnapshot(zones);

  group('Rule 1 — instant entry', () {
    test('first zone becomes current immediately, no dwell', () async {
      push([sig(1, -60, clock())]);
      await Future.microtask(() {});
      expect(arb.current.currentMajor, 1);
      expect(emitted.last.currentMajor, 1);
    });

    test('strongest of several becomes current on entry', () async {
      push([sig(2, -50, clock()), sig(1, -70, clock())]);
      await Future.microtask(() {});
      expect(arb.current.currentMajor, 2);
    });
  });

  group('Rule 2 — takeover needs delta AND dwell', () {
    test('challenger below delta never takes over', () {
      push([sig(1, -60, clock())]); // enter zone 1
      // Zone 2 stronger but only by 5 dB (< 7). Hold a long time.
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(2, -55, clock()), sig(1, -60, clock())]);
      }
      expect(arb.current.currentMajor, 1);
    });

    test('challenger with delta but insufficient dwell does not switch', () {
      push([sig(1, -60, clock())]);
      // Zone 2 leads by 10 dB, but only for 2 s (< 3 s dwell).
      clock.advance(const Duration(seconds: 1));
      push([sig(2, -50, clock()), sig(1, -60, clock())]);
      clock.advance(const Duration(seconds: 1));
      push([sig(2, -50, clock()), sig(1, -60, clock())]);
      expect(arb.current.currentMajor, 1);
    });

    test('challenger with delta held for full dwell takes over', () {
      push([sig(1, -60, clock())]);
      // Lead by 10 dB continuously for >= 3 s.
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(2, -50, clock()), sig(1, -60, clock())]);
      }
      expect(arb.current.currentMajor, 2);
    });

    test('losing the lead for one snapshot resets dwell', () {
      push([sig(1, -60, clock())]);
      clock.advance(const Duration(seconds: 1));
      push([sig(2, -50, clock()), sig(1, -60, clock())]); // leading (1s)
      clock.advance(const Duration(seconds: 1));
      push([sig(2, -50, clock()), sig(1, -60, clock())]); // leading (2s)
      clock.advance(const Duration(seconds: 1));
      push([sig(2, -58, clock()), sig(1, -60, clock())]); // lead lost! reset
      clock.advance(const Duration(seconds: 1));
      push([sig(2, -50, clock()), sig(1, -60, clock())]); // leading again (1s)
      expect(arb.current.currentMajor, 1); // not enough continuous dwell
    });
  });

  group('Rule 3 — lockout freezes after a switch', () {
    // Drive zone 1 -> zone 2 (opens lockout), then probe.
    void switchTo2() {
      push([sig(1, -60, clock())]);
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(2, -50, clock()), sig(1, -60, clock())]);
      }
      expect(arb.current.currentMajor, 2); // switched at ~3s, lockout open 12s
    }

    test('no second takeover during lockout even with huge delta', () {
      switchTo2();
      // Zone 3 screams louder immediately, but we are locked out.
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(3, -30, clock()), sig(2, -60, clock())]);
      }
      expect(arb.current.currentMajor, 2);
    });

    test('silence during lockout does NOT drop to standby', () {
      switchTo2();
      // Total radio silence for 6 s while still inside the 12 s lockout.
      for (var i = 0; i < 6; i++) {
        clock.advance(const Duration(seconds: 1));
        push(const []);
      }
      expect(arb.current.currentMajor, 2); // frozen, not standby
    });

    test('takeover works again once lockout expires', () {
      switchTo2(); // switched around t=3s, lockout until ~t=15s
      // Idle to let lockout expire (stay in zone 2 so no standby).
      for (var i = 0; i < 13; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(2, -60, clock())]);
      }
      // Now zone 3 challenges with delta + dwell.
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(3, -50, clock()), sig(2, -60, clock())]);
      }
      expect(arb.current.currentMajor, 3);
    });
  });

  group('Rule 4 — standby on silence, only after lockout', () {
    test('current zone silent past zoneSilence -> standby', () {
      push([sig(1, -60, clock())]); // instant entry, NO lockout
      // Silence for 9 s (> 8 s zoneSilence).
      for (var i = 0; i < 9; i++) {
        clock.advance(const Duration(seconds: 1));
        push(const []);
      }
      expect(arb.current.currentMajor, isNull); // radar/standby
    });

    test('brief silence under zoneSilence keeps the zone', () {
      push([sig(1, -60, clock())]);
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 1));
        push(const []);
      }
      expect(arb.current.currentMajor, 1);
    });
  });

  group('Rule 5 — desk stability, reported not acted on', () {
    test('desk leading for deskDwell raises deskStable, keeps currentMajor',
        () {
      push([sig(1, -60, clock())]); // in a zone
      // Desk (99) beats zone 1 by 15 dB, held 11 s (>= 10 s deskDwell).
      for (var i = 0; i < 11; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(99, -45, clock()), sig(1, -60, clock())]);
      }
      expect(arb.current.deskStable, isTrue);
      // Arbiter must NOT clear currentMajor — that is the session's job.
      expect(arb.current.currentMajor, 1);
    });

    test('desk heard but not dominant does not raise deskStable', () {
      push([sig(1, -60, clock())]);
      // Desk only 3 dB above zone 1 (< 7). Walking past the desk.
      for (var i = 0; i < 11; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(99, -57, clock()), sig(1, -60, clock())]);
      }
      expect(arb.current.deskStable, isFalse);
    });

    test('desk dominant but too briefly does not raise deskStable', () {
      push([sig(1, -60, clock())]);
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(99, -45, clock()), sig(1, -60, clock())]);
      }
      expect(arb.current.deskStable, isFalse); // only 5 s < 10 s
    });
  });

  group('emission gating', () {
    test('steady presence does not re-emit on every heartbeat', () {
      push([sig(1, -60, clock())]);
      final afterEntry = emitted.length;
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(1, -60, clock())]); // identical presence
      }
      expect(emitted.length, afterEntry); // no churn
    });

    test('lastBeaconAt advances on steady signal even without an emit', () {
      push([sig(1, -60, clock())]);
      final entryTime = clock();
      // Five steady heartbeats: presence unchanged (no emit), but the
      // freshness timestamp must track the latest packet for the Session
      // Controller's silence detection.
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 1));
        push([sig(1, -60, clock())]);
      }
      expect(arb.current.lastBeaconAt, clock());
      expect(arb.current.lastBeaconAt!.isAfter(entryTime), isTrue);
    });

    test('lastBeaconAt is carried forward (not advanced) on empty snapshot',
        () {
      push([sig(1, -60, clock())]);
      final lastHeard = clock();
      clock.advance(const Duration(seconds: 2));
      push(const []); // silence: timestamp must NOT jump to now
      expect(arb.current.lastBeaconAt, lastHeard);
    });
  });
}
