// Destination: test/beacon_tracker_registry_test.dart
// Run with: flutter test test/beacon_tracker_registry_test.dart

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/zone_signal.dart';

/// Fixed epoch so tests are fully deterministic under FakeAsync.
final t0 = DateTime(2026, 7, 4, 9, 0, 0);

BeaconReading reading(int major, int minor, int rssi, DateTime at) =>
    BeaconReading(
      uuid: '4d6fc88b-be75-6698-da48-6866a36ec78e',
      major: major,
      minor: minor,
      rssi: rssi,
      measuredPower: -59,
      timestamp: at,
    );

/// Builds a registry whose clock follows FakeAsync's elapsed time from [t0].
BeaconTrackerRegistry registryOn(FakeAsync async) =>
    BeaconTrackerRegistry(now: () => t0.add(async.elapsed));

void main() {
  test('aggregates by major: zone rssi = strongest live minor', () {
    fakeAsync((async) {
      final reg = registryOn(async);
      final emits = <List<ZoneSignal>>[];
      reg.zoneSignals.listen(emits.add);
      reg.start();

      // Two beacons of zone 1 (minors 1 & 5), one beacon of zone 2.
      final now = t0.add(async.elapsed);
      reg.onReading(reading(1, 1, -70, now));
      reg.onReading(reading(1, 5, -55, now)); // stronger sibling
      reg.onReading(reading(2, 1, -80, now));
      async.elapse(const Duration(seconds: 1)); // one heartbeat
      async.flushMicrotasks();

      final snap = emits.last;
      expect(snap.map((z) => z.major), [1, 2]); // strongest zone first
      expect(snap.first.rssiDb, closeTo(-55, 3)); // max of minors, Kalman-near
      expect(snap.first.minorsHeard.toSet(), {1, 5});
      expect(snap.first.rssiByMinor[1], lessThan(snap.first.rssiByMinor[5]!));

      reg.dispose();
    });
  });

  test('new-beacon sighting emits IMMEDIATELY (entry latency)', () {
    fakeAsync((async) {
      final reg = registryOn(async);
      final emits = <List<ZoneSignal>>[];
      reg.zoneSignals.listen(emits.add);
      reg.start();
      async.flushMicrotasks();
      final before = emits.length;

      reg.onReading(reading(3, 1, -60, t0.add(async.elapsed)));
      async.flushMicrotasks(); // NO time elapse — must not wait for a tick

      expect(emits.length, before + 1);
      expect(emits.last.single.major, 3);
      reg.dispose();
    });
  });

  test('heartbeat: emits every sweep even with zero change and when empty',
      () {
    fakeAsync((async) {
      final reg = registryOn(async);
      final emits = <List<ZoneSignal>>[];
      reg.zoneSignals.listen(emits.add);
      reg.start();

      async.elapse(const Duration(seconds: 3)); // 3 empty heartbeats
      async.flushMicrotasks();
      expect(emits.length, 3);
      expect(emits.every((s) => s.isEmpty), isTrue);

      // Steady signal (identical packets) — old registry would gate these;
      // the new contract must keep the arbiter's clock ticking.
      reg.onReading(reading(1, 1, -60, t0.add(async.elapsed)));
      final countAfterSighting = emits.length;
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(emits.length, countAfterSighting + 3);

      reg.dispose();
    });
  });

  test('stale beacon stops voting; sibling minor carries the zone', () {
    fakeAsync((async) {
      final reg = registryOn(async);
      final emits = <List<ZoneSignal>>[];
      reg.zoneSignals.listen(emits.add);
      reg.start();

      // Minor 5 goes silent after t0; minor 1 keeps advertising.
      reg.onReading(reading(1, 5, -50, t0));
      var elapsedTick = 0;
      // 4 seconds pass; minor 1 refreshed every second, minor 5 never again.
      while (elapsedTick < 4) {
        reg.onReading(reading(1, 1, -70, t0.add(async.elapsed)));
        async.elapse(const Duration(seconds: 1));
        elapsedTick++;
      }
      async.flushMicrotasks();

      final snap = emits.last;
      expect(snap.single.major, 1); // zone still audible…
      expect(snap.single.minorsHeard.toSet(), {1}); // …but only via minor 1
      expect(snap.single.rssiDb, closeTo(-70, 3)); // max no longer counts -50
      expect(reg.trackerCount, 2); // stale ≠ evicted yet (warm Kalman kept)

      reg.dispose();
    });
  });

  test('eviction: tracker GCed after evictionThreshold of silence', () {
    fakeAsync((async) {
      final reg = registryOn(async);
      reg.zoneSignals.listen((_) {});
      reg.start();

      reg.onReading(reading(1, 1, -60, t0));
      expect(reg.trackerCount, 1);

      async.elapse(const Duration(seconds: 13)); // > 12 s eviction default
      async.flushMicrotasks();
      expect(reg.trackerCount, 0);

      reg.dispose();
    });
  });

  test('stop() clears state; start() after stop resumes cleanly', () {
    fakeAsync((async) {
      final reg = registryOn(async);
      final emits = <List<ZoneSignal>>[];
      reg.zoneSignals.listen(emits.add);
      reg.start();
      reg.onReading(reading(1, 1, -60, t0.add(async.elapsed)));
      async.elapse(const Duration(seconds: 1));

      reg.stop();
      expect(reg.trackerCount, 0);
      final afterStop = emits.length;
      async.elapse(const Duration(seconds: 3));
      expect(emits.length, afterStop); // no heartbeats while stopped

      reg.start();
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(emits.length, afterStop + 2); // heartbeats resumed (empty)

      reg.dispose();
    });
  });
}
