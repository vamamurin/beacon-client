// Destination: test/pipeline_integration_test.dart
// Run with: flutter test test/pipeline_integration_test.dart
//
// End-to-end proof of Phase 1: each authored BeaconScenario is replayed
// through the REAL registry (with its 1 Hz sweep Timer) and the REAL arbiter,
// asserting the product-confirmed outcome for all four scenarios.
//
// Determinism: fake_async drives BOTH the registry's periodic sweep Timer AND
// the injected clock (t0 + async.elapsed) that registry and arbiter read. One
// virtual timeline, three components, zero wall-clock. Scenario legs are
// replayed at 100 ms cadence; RSSI noise is disabled here so assertions target
// the arbiter's logic, not luck (the noise path is covered elsewhere).

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/data/scanners/mock_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_presence.dart';

final t0 = DateTime(2026, 7, 4, 9, 0, 0);

/// Total duration of a scenario's legs.
Duration _scenarioLength(BeaconScenario s) =>
    s.legs.fold(Duration.zero, (a, l) => a + l.duration);

/// Which leg covers virtual offset [t] (no loop).
ScenarioLeg? _legAt(BeaconScenario s, Duration t) {
  var off = t;
  for (final leg in s.legs) {
    if (off < leg.duration) return leg;
    off -= leg.duration;
  }
  return null;
}

/// Runs [scenario] through registry + arbiter on a fake-async timeline and
/// returns (final presence, full presence log).
({ZonePresence last, List<ZonePresence> log}) runScenario(
  BeaconScenario scenario,
  ArbitrationParams params,
) {
  late ZonePresence last;
  final log = <ZonePresence>[];

  fakeAsync((async) {
    DateTime now() => t0.add(async.elapsed);
    final registry = BeaconTrackerRegistry(now: now);
    final arbiter = ZoneArbiter(deskMajor: 99, params: params, now: now);

    registry.zoneSignals.listen(arbiter.onSnapshot);
    arbiter.presence.listen((p) {
      last = p;
      log.add(p);
    });
    last = ZonePresence.none;

    registry.start(); // real 1 Hz sweep, driven by fake time

    const step = Duration(milliseconds: 100);
    final total = _scenarioLength(scenario);
    var elapsed = Duration.zero;

    // Replay every 100 ms: push the current leg's beacons, then advance fake
    // time by one step so the registry sweep fires on whole seconds.
    while (elapsed < total) {
      final leg = _legAt(scenario, elapsed);
      if (leg != null) {
        final at = now();
        for (final b in leg.beacons) {
          registry.onReading(BeaconReading(
            uuid: '4d6fc88b-be75-6698-da48-6866a36ec78e',
            major: b.major,
            minor: b.minor,
            rssi: b.rssi.round(), // noise disabled for deterministic assert
            measuredPower: b.measuredPower,
            timestamp: at,
          ));
        }
      }
      async.elapse(step);
      elapsed += step;
    }
    async.flushMicrotasks();

    arbiter.dispose();
    registry.dispose();
  });

  return (last: last, log: log);
}

void main() {
  final params = ArbitrationParams.defaults();

  test('Scenario 1 — zoneSwitch: enters zone 1, then switches to zone 2', () {
    final r = runScenario(MockScenarios.zoneSwitch, params);

    // Must have actually been in zone 1 at some point (entry), then end in 2.
    expect(r.log.any((p) => p.currentMajor == 1), isTrue,
        reason: 'should enter zone 1 first');
    expect(r.last.currentMajor, 2, reason: 'should end switched to zone 2');
    expect(r.last.deskStable, isFalse);
  });

  test('Scenario 2 — borderStandoff: holds the first zone, no ping-pong', () {
    final r = runScenario(MockScenarios.borderStandoff, params);

    // Entered zone 1 (stronger at first), and the sub-delta wobble never
    // flips it to zone 2.
    expect(r.last.currentMajor, 1);
    expect(r.log.every((p) => p.currentMajor != 2), isTrue,
        reason: 'zone 2 never leads by minDeltaDb long enough');
  });

  test('Scenario 3 — returnToDesk: keeps zone, raises deskStable', () {
    final r = runScenario(MockScenarios.returnToDesk, params);

    // Arbiter reports desk presence but MUST NOT clear currentMajor —
    // ending the session belongs to the Session Controller (Phase 3).
    expect(r.last.deskStable, isTrue, reason: 'desk dominant past deskDwell');
    expect(r.last.currentMajor, 1, reason: 'arbiter never clears the zone');
  });

  test('Scenario 4 — silence: drops to standby after zoneSilence', () {
    final r = runScenario(MockScenarios.silence, params);

    expect(r.log.any((p) => p.currentMajor == 1), isTrue,
        reason: 'entered zone 1 before silence');
    expect(r.last.currentMajor, isNull, reason: 'standby after silence');
    expect(r.last.inZone, isFalse);
  });

  test('all four scenarios complete without throwing', () {
    for (final s in MockScenarios.all) {
      expect(() => runScenario(s, params), returnsNormally,
          reason: 'scenario ${s.name}');
    }
  });
}
