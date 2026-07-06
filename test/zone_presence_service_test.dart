// Destination: test/zone_presence_service_test.dart
// Run with: flutter test test/zone_presence_service_test.dart
//
// Verifies the service's real job: turning the arbiter's ZonePresence stream
// into enter/change/standby ZoneEvents, plus enriched ZoneStatus. Drives the
// FULL pipeline (scanner scenario -> registry -> arbiter -> service) on a fake
// clock, reusing the Phase-1 scenarios so this doubles as a cross-phase
// integration check.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/data/scanners/mock_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

const _uuid = '4d6fc88b-be75-6698-da48-6866a36ec78e';
final _t0 = DateTime(2026, 7, 4, 9, 0, 0);

Duration _len(BeaconScenario s) =>
    s.legs.fold(Duration.zero, (a, l) => a + l.duration);

ScenarioLeg? _legAt(BeaconScenario s, Duration t) {
  var off = t;
  for (final leg in s.legs) {
    if (off < leg.duration) return leg;
    off -= leg.duration;
  }
  return null;
}

/// Runs a scenario through the whole pipeline + service; returns collected
/// events and the final status. Repository is pre-warmed synchronously.
({List<ZoneEvent> events, ZoneStatus last}) run(
  BeaconScenario scenario,
  MockZoneRepository repo,
) {
  final events = <ZoneEvent>[];
  late ZoneStatus last;
  last = ZoneStatus.standby;

  fakeAsync((async) {
    DateTime now() => _t0.add(async.elapsed);
    final registry = BeaconTrackerRegistry(now: now);
    final arbiter = ZoneArbiter(
      deskMajor: 99,
      params: ArbitrationParams.defaults(),
      now: now,
    );
    final service = ZonePresenceService(
      scanner: _NullScanner(), // we feed the registry directly below
      repository: repo,
      museumUuidLower: _uuid,
      registry: registry,
      arbiter: arbiter,
    );

    service.events.listen(events.add);
    service.status.listen((s) => last = s);

    // Wire arbiter<-registry and start registry via the service, but replay
    // readings ourselves on the fake clock (NullScanner emits nothing).
    service.start();

    const step = Duration(milliseconds: 100);
    var elapsed = Duration.zero;
    final total = _len(scenario);
    while (elapsed < total) {
      final leg = _legAt(scenario, elapsed);
      if (leg != null) {
        final at = now();
        for (final b in leg.beacons) {
          registry.onReading(BeaconReading(
            uuid: _uuid,
            major: b.major,
            minor: b.minor,
            rssi: b.rssi.round(),
            measuredPower: b.measuredPower,
            timestamp: at,
          ));
        }
      }
      async.elapse(step);
      elapsed += step;
    }
    async.flushMicrotasks();
    service.dispose();
  });

  return (events: events, last: last);
}

void main() {
  late MockZoneRepository repo;

  setUp(() async {
    repo = MockZoneRepository(simulatedLatency: Duration.zero);
    await repo.preWarm();
  });

  test('zoneSwitch -> EnteredZone(1) then ChangedZone(1,2)', () {
    final r = run(MockScenarios.zoneSwitch, repo);

    expect(r.events.whereType<EnteredZone>().first.major, 1);
    final changed = r.events.whereType<ChangedZone>().toList();
    expect(changed, hasLength(1));
    expect(changed.first.fromMajor, 1);
    expect(changed.first.toMajor, 2);
    expect(r.last.zone?.major, 2); // enriched status resolved zone 2
  });

  test('borderStandoff -> only EnteredZone(1), never a ChangedZone', () {
    final r = run(MockScenarios.borderStandoff, repo);

    expect(r.events.whereType<EnteredZone>().single.major, 1);
    expect(r.events.whereType<ChangedZone>(), isEmpty);
    expect(r.last.zone?.major, 1);
  });

  test('returnToDesk -> EnteredZone(1), deskStable surfaces in status', () {
    final r = run(MockScenarios.returnToDesk, repo);

    expect(r.events.whereType<EnteredZone>().first.major, 1);
    // Arbiter never clears the zone; service passes deskStable through.
    expect(r.last.zone?.major, 1);
    expect(r.last.deskStable, isTrue);
    // No audio side effects here — service only reports (Phase-1 boundary).
    expect(r.events.whereType<LeftToStandby>(), isEmpty);
  });

  test('silence -> EnteredZone(1) then LeftToStandby', () {
    final r = run(MockScenarios.silence, repo);

    expect(r.events.whereType<EnteredZone>().first.major, 1);
    expect(r.events.whereType<LeftToStandby>(), hasLength(1));
    expect(r.last.zone, isNull); // standby
    expect(r.last.inZone, isFalse);
  });

  test('event stream carries no duplicate transitions for a steady zone', () {
    // zoneSwitch holds zone 1 for 6 s (many heartbeats) before switching —
    // must yield exactly ONE EnteredZone(1), not one per heartbeat.
    final r = run(MockScenarios.zoneSwitch, repo);
    expect(r.events.whereType<EnteredZone>(), hasLength(1));
  });
}

/// A scanner that never emits — the tests feed the registry directly to stay
/// on the fake clock. start/stop/dispose are no-ops, readings is empty.
class _NullScanner implements IBeaconScanner {
  @override
  Stream<BeaconReading> get readings => const Stream.empty();

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  void dispose() {}
}
