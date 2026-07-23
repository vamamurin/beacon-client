// Destination: test/data/processors/zone_arbiter_test.dart
//
// Golden suite for ZoneArbiter — the most intricate deterministic component in
// the pipeline. The arbiter owns no Timer and reads its clock from an injected
// `now`, so a scripted sequence of snapshots at controlled times produces a
// byte-stable presence log. Each test names the rule it pins (see the rule list
// at the top of zone_arbiter.dart).
//
// RSSI cheat-sheet (measuredPower = -59 dBm, pathLossExponent n = 2.5):
//   d = 10 ^ ((measuredPower - rssi) / (10 n))     [log-distance path loss]
//     rssi -70  -> ~2.8 m   (WITHIN engage 5 m)      "close, engageable"
//     rssi -75  -> ~4.4 m   (WITHIN engage 5 m)
//     rssi -79  -> ~6.3 m   (dead band: > engage, <= release 8 m) "display only"
//     rssi -85  -> ~11.0 m  (BEYOND release 8 m)     "far, releasable"
//   engage < release is a hysteresis dead band that swallows indoor RSSI error.
//
// Defaults used (ArbitrationParams.defaults):
//   minDeltaDb 7 | dwell 3 s | lockout 12 s | zoneSilence 8 s | deskDwell 10 s

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_presence.dart';
import 'package:beacon_client/domain/models/zone_signal.dart';

void main() {
  const deskMajor = 99;

  late DateTime clock;
  late ZoneArbiter arbiter;

  setUp(() {
    clock = DateTime.utc(2026, 1, 1, 12, 0, 0);
    arbiter = ZoneArbiter(
      deskMajor: deskMajor,
      params: ArbitrationParams.defaults(),
      now: () => clock,
    );
  });

  tearDown(() => arbiter.dispose());

  // ---- helpers -------------------------------------------------------------

  void advance(int seconds) => clock = clock.add(Duration(seconds: seconds));

  ZoneSignal sig(int major, double rssi) => ZoneSignal(
        major: major,
        rssiDb: rssi,
        rssiByMinor: {0: rssi},
        lastSeenAt: clock,
        // -59 is also the default, spelled out so the distance math is explicit.
        measuredPowerDbm: -59,
      );

  void feed(List<ZoneSignal> snapshot) => arbiter.onSnapshot(snapshot);

  void expectState(int? current, {int? candidate, bool desk = false}) {
    final p = arbiter.current;
    expect(p.currentMajor, current, reason: 'currentMajor');
    expect(p.candidateMajor, candidate, reason: 'candidateMajor');
    expect(p.deskStable, desk, reason: 'deskStable');
  }

  // ---- rule 1: instant entry ----------------------------------------------

  test('rule 1 — first engageable zone becomes current with no dwell', () {
    feed([sig(1, -70)]); // ~2.8 m, within engage
    expectState(1);
  });

  // ---- rule 4b: engage gate ------------------------------------------------

  test('rule 4b — a zone heard beyond engage does NOT become current', () {
    feed([sig(1, -79)]); // ~6.3 m, in the dead band -> display tier only
    expectState(null);

    advance(1);
    feed([sig(1, -70)]); // now within engage
    expectState(1);
  });

  // ---- rule 2: takeover needs the delta lead held for dwell ----------------

  test('rule 2 — takeover only after holding the dB lead for dwell', () {
    feed([sig(1, -70)]); // current = 1
    expectState(1);

    // B leads A by 9 dB (>= 7) and is engageable -> becomes candidate, no switch.
    advance(1);
    feed([sig(1, -75), sig(2, -66)]);
    expectState(1, candidate: 2);

    // Held 2 s (< dwell 3 s): still candidate.
    advance(2);
    feed([sig(1, -75), sig(2, -66)]);
    expectState(1, candidate: 2);

    // Held 3 s total: switch to 2, candidate cleared, lockout opens.
    advance(1);
    feed([sig(1, -75), sig(2, -66)]);
    expectState(2);
  });

  test('rule 2 — losing the lead for even one snapshot resets the dwell', () {
    feed([sig(1, -70)]);
    advance(1);
    feed([sig(1, -75), sig(2, -66)]); // candidate 2 since here
    expectState(1, candidate: 2);

    // Lead collapses to 1 dB (< 7): candidate cleared.
    advance(1);
    feed([sig(1, -75), sig(2, -74)]);
    expectState(1, candidate: null);

    // Lead returns: dwell restarts from now, so 2 s later it's still candidate.
    advance(1);
    feed([sig(1, -75), sig(2, -66)]); // candidate 2 restarts here
    advance(2);
    feed([sig(1, -75), sig(2, -66)]);
    expectState(1, candidate: 2); // only 2 s held since restart, no switch
  });

  // ---- rule 3: lockout freezes takeover AND standby ------------------------

  test('rule 3 — during lockout no takeover and no standby', () {
    // Drive a takeover to open the lockout window.
    feed([sig(1, -70)]);
    advance(1);
    feed([sig(1, -75), sig(2, -66)]); // candidate 2
    advance(3);
    feed([sig(1, -75), sig(2, -66)]); // switch -> 2, lockout for 12 s
    expectState(2);

    // A much stronger challenger is IGNORED while locked out.
    advance(1);
    feed([sig(2, -75), sig(3, -60)]); // C very close, huge lead
    expectState(2, candidate: null);

    // Silence does NOT drop to standby while locked out.
    advance(1);
    feed(const []); // nothing heard
    expectState(2);
  });

  // ---- rule 4: standby on radio silence (no lockout on first entry) --------

  test('rule 4 — silence past zoneSilence drops to standby', () {
    feed([sig(1, -70)]); // instant entry has NO lockout
    expectState(1);

    // 8 s of silence is the boundary (strictly greater triggers): still 1.
    advance(8);
    feed(const []);
    expectState(1);

    // 9 s: standby.
    advance(1);
    feed(const []);
    expectState(null);
  });

  // ---- rule 4 (C1): standby on sustained-far, with dip-back reset ----------

  test('rule 4 (C1) — heard but beyond release for dwell drops to standby', () {
    feed([sig(1, -70)]); // current 1
    advance(1);
    feed([sig(1, -85)]); // ~11 m, beyond release -> far clock starts here
    expectState(1);

    advance(2); // 2 s far (< dwell 3): still current
    feed([sig(1, -85)]);
    expectState(1);

    advance(1); // 3 s far: standby
    feed([sig(1, -85)]);
    expectState(null);
  });

  test('rule 4 (C1) — dipping back inside release resets the far clock', () {
    feed([sig(1, -70)]);
    advance(1);
    feed([sig(1, -85)]); // far clock starts
    advance(1);
    feed([sig(1, -70)]); // back within release -> far clock resets
    advance(1);
    feed([sig(1, -85)]); // far clock restarts here
    advance(2); // only 2 s since restart
    feed([sig(1, -85)]);
    expectState(1); // not yet standby thanks to the reset
  });

  // ---- rule 5: desk raises deskStable, never touches currentMajor ----------

  test('rule 5 — desk stability is independent of the current zone', () {
    // Desk dominates by 15 dB, but zone 1 is also engageable.
    feed([sig(deskMajor, -60), sig(1, -75)]);
    expectState(1); // zone still current; desk not yet stable

    // Desk held for deskDwell (10 s): deskStable rises, current UNCHANGED.
    advance(10);
    feed([sig(deskMajor, -60), sig(1, -75)]);
    expectState(1, desk: true);

    // Leaving the desk drops the flag immediately.
    advance(1);
    feed([sig(1, -70)]);
    expectState(1, desk: false);
  });

  // ---- emission contract: change-gated, not a per-snapshot spam ------------

  test('presence stream is change-gated (identical snapshots do not re-emit)',
      () async {
    final seen = <ZonePresence>[];
    final sub = arbiter.presence.listen(seen.add);

    feed([sig(1, -70)]); // null -> 1 : one emission
    advance(1);
    feed([sig(1, -70)]); // unchanged (lastBeaconAt ignored in equality)
    advance(1);
    feed([sig(1, -70)]); // unchanged

    await pumpEventQueue();
    expect(seen.length, 1);
    expect(seen.single.currentMajor, 1);

    await sub.cancel();
  });
}