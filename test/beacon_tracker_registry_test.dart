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

      // A NEW beacon appears: by contract that publishes ONE immediate
      // snapshot (entry latency) — see the previous test. Capture the count
      // AFTER that immediate emit so we isolate just the heartbeats below.
      reg.onReading(reading(1, 1, -60, t0.add(async.elapsed)));
      async.flushMicrotasks();
      expect(emits.length, 4); // 3 heartbeats + 1 sighting
      final countAfterSighting = emits.length;

      // Steady signal (identical packets) — the old registry would gate
      // these; the new contract must keep the arbiter's clock ticking.
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

      final beforeStop = emits.length;
      reg.stop();
      expect(reg.trackerCount, 0);
      async.flushMicrotasks();

      // stop() publishes ONE final empty snapshot. Downstream expiry clocks
      // (NearbyZonesTracker's hold, the arbiter's silence timers) are driven by
      // this heartbeat, so without it they would hold the pre-stop world
      // forever — that is what froze the exhibit list on Bluetooth-off.
      expect(emits.length, beforeStop + 1);
      expect(emits.last, isEmpty, reason: 'a stopped registry knows nothing');

      final afterStop = emits.length;
      async.elapse(const Duration(seconds: 3));
      expect(emits.length, afterStop); // ...and then genuinely goes quiet

      reg.start();
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(emits.length, afterStop + 2); // heartbeats resumed (empty)

      reg.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // The tracker ceiling bounds MEMORY. It must not become a first-come-first-
  // served lock-in, because incumbents keep advertising and so never age out —
  // that would make a beacon the visitor is standing next to permanently
  // invisible. The occupant set must converge on the NEAREST beacons.
  // ───────────────────────────────────────────────────────────────────────────
  group('at the tracker ceiling', () {
    BeaconTrackerRegistry smallRegistry(FakeAsync async) =>
        BeaconTrackerRegistry(
          maxTrackers: 3,
          now: () => t0.add(async.elapsed),
        );

    test('a STRONGER newcomer displaces the weakest incumbent', () {
      fakeAsync((async) {
        final reg = smallRegistry(async);
        final emits = <List<ZoneSignal>>[];
        reg.zoneSignals.listen(emits.add);
        reg.start();

        final now = t0.add(async.elapsed);
        reg.onReading(reading(1, 1, -60, now));
        reg.onReading(reading(2, 1, -70, now));
        reg.onReading(reading(3, 1, -85, now)); // weakest — the one to lose
        expect(reg.trackerCount, 3);

        // Visitor walks up to zone 4's exhibit. Under the old drop-the-newcomer
        // policy this beacon was invisible forever.
        reg.onReading(reading(4, 1, -50, now));

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(reg.trackerCount, 3); // ceiling still honoured
        final majors = emits.last.map((z) => z.major).toSet();
        expect(majors, contains(4), reason: 'the near beacon must be tracked');
        expect(majors, isNot(contains(3)), reason: 'the far one was evicted');
      });
    });

    test('a WEAKER newcomer cannot evict a beacon we are standing next to', () {
      fakeAsync((async) {
        final reg = smallRegistry(async);
        final emits = <List<ZoneSignal>>[];
        reg.zoneSignals.listen(emits.add);
        reg.start();

        final now = t0.add(async.elapsed);
        reg.onReading(reading(1, 1, -55, now));
        reg.onReading(reading(2, 1, -58, now));
        reg.onReading(reading(3, 1, -61, now));

        // A distant stray from across the hall. It must stay out — otherwise a
        // crowded room could churn the table and evict the nearest beacon.
        reg.onReading(reading(9, 9, -95, now));

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(reg.trackerCount, 3);
        final majors = emits.last.map((z) => z.major).toSet();
        expect(majors, {1, 2, 3});
        expect(majors, isNot(contains(9)));
      });
    });

    test('repeated pressure converges on the nearest set, not the first set',
        () {
      fakeAsync((async) {
        final reg = smallRegistry(async);
        final emits = <List<ZoneSignal>>[];
        reg.zoneSignals.listen(emits.add);
        reg.start();

        final now = t0.add(async.elapsed);
        // Seed with three far beacons (arrival order would lock these in).
        for (var m = 1; m <= 3; m++) {
          reg.onReading(reading(m, 1, -90, now));
        }
        // Then hear three near ones, one at a time.
        for (var m = 4; m <= 6; m++) {
          reg.onReading(reading(m, 1, -55, now));
        }

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(reg.trackerCount, 3);
        expect(emits.last.map((z) => z.major).toSet(), {4, 5, 6});
      });
    });

    test('an existing tracker is still updated in place, never re-admitted', () {
      fakeAsync((async) {
        final reg = smallRegistry(async);
        reg.start();

        var now = t0.add(async.elapsed);
        reg.onReading(reading(1, 1, -60, now));
        reg.onReading(reading(2, 1, -70, now));
        reg.onReading(reading(3, 1, -80, now));

        // A full table must not stop known beacons from being fed.
        async.elapse(const Duration(milliseconds: 500));
        now = t0.add(async.elapsed);
        reg.onReading(reading(3, 1, -75, now));

        expect(reg.trackerCount, 3);
      });
    });
  });
}