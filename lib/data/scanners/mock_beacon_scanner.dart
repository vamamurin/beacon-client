// Destination: lib/data/scanners/mock_beacon_scanner.dart (REPLACES current file)
//
// Zone-first rewrite. The old scanner simulated ONE beacon walking a sine
// curve (for the distance pipeline). Phase 1 needs multi-zone, multi-beacon
// traffic driven by a SCRIPT so the ZoneArbiter can be exercised end-to-end.
//
// Design: the walk is described as DATA (a BeaconScenario = a list of legs,
// each leg holding a set of beacons for a duration) rather than branching
// code. The four product scenarios (zone switch / border standoff / return to
// desk / silence) are just four scenarios; adding another is data, not code.
//
// Interface (IBeaconScanner) is unchanged, so injection.dart is untouched.
// Noise + emission cadence still exercise the Kalman filter realistically.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

/// One beacon present at an instant, as authored in a scenario (ideal RSSI
/// before noise). measuredPower defaults to a calibrated -59 dBm.
@immutable
class ScannedBeacon {
  final int major;
  final int minor;
  final double rssi;
  final int measuredPower;

  const ScannedBeacon({
    required this.major,
    required this.minor,
    required this.rssi,
    this.measuredPower = -59,
  });
}

/// Hold [beacons] steady for [duration] (noise is layered per emission).
/// An empty [beacons] models radio silence.
@immutable
class ScenarioLeg {
  final Duration duration;
  final List<ScannedBeacon> beacons;
  const ScenarioLeg({required this.duration, required this.beacons});
}

/// An ordered walk through the museum. [loop] repeats it for open-ended demos.
@immutable
class BeaconScenario {
  final String name;
  final List<ScenarioLeg> legs;
  final bool loop;
  const BeaconScenario({
    required this.name,
    required this.legs,
    this.loop = false,
  });
}

class MockBeaconScanner implements IBeaconScanner {
  MockBeaconScanner({
    BeaconScenario? scenario,
    this.emitInterval = const Duration(milliseconds: 100),
    this.noiseAmplitudeDb = 3.0,
    String museumUuid = '4d6fc88b-be75-6698-da48-6866a36ec78e',
    int? randomSeed,
  })  : _scenario = scenario ?? MockScenarios.zoneSwitch,
        _uuid = museumUuid,
        _random = Random(randomSeed);

  final BeaconScenario _scenario;
  final Duration emitInterval;
  final double noiseAmplitudeDb;
  final String _uuid;
  final Random _random;

  final _controller = StreamController<BeaconReading>.broadcast();
  Timer? _timer;
  bool _active = false;
  Duration _elapsed = Duration.zero;

  @override
  Stream<BeaconReading> get readings => _controller.stream;

  @override
  Future<void> startScan() async {
    _active = true;
    _timer ??= Timer.periodic(emitInterval, _tick);
  }

  @override
  Future<void> stopScan() async => _active = false;

  void _tick(Timer _) {
    if (!_active || _controller.isClosed) return;
    _elapsed += emitInterval;

    final leg = _legAt(_elapsed);
    if (leg == null) {
      // Scenario finished (non-looping): go quiet but keep the stream alive.
      return;
    }

    final now = DateTime.now();
    for (final b in leg.beacons) {
      final noisy = b.rssi + (_random.nextDouble() * 2 - 1) * noiseAmplitudeDb;
      _controller.add(BeaconReading(
        uuid: _uuid,
        major: b.major,
        minor: b.minor,
        rssi: noisy.round(),
        measuredPower: b.measuredPower,
        timestamp: now,
      ));
    }
  }

  /// Resolve which leg covers [t], honouring [loop].
  ScenarioLeg? _legAt(Duration t) {
    final total = _scenario.legs.fold<Duration>(
        Duration.zero, (a, l) => a + l.duration);
    if (total == Duration.zero) return null;

    var offset = _scenario.loop
        ? Duration(microseconds: t.inMicroseconds % total.inMicroseconds)
        : t;
    if (offset >= total) return null; // finished

    for (final leg in _scenario.legs) {
      if (offset < leg.duration) return leg;
      offset -= leg.duration;
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (!_controller.isClosed) _controller.close();
  }
}

/// The four product scenarios, authored as data. RSSI values are chosen
/// around the example bundle's arbitration (minDeltaDb 7) so the intended
/// arbiter behaviour is unambiguous.
abstract final class MockScenarios {
  /// Clean walk: 6 s deep in zone 1, then zone 2 dominates by ~15 dB.
  /// Expected: enter 1 → (dwell) → switch to 2.
  static const zoneSwitch = BeaconScenario(
    name: 'zoneSwitch',
    legs: [
      ScenarioLeg(duration: Duration(seconds: 6), beacons: [
        ScannedBeacon(major: 1, minor: 1, rssi: -58),
        ScannedBeacon(major: 1, minor: 5, rssi: -63),
        ScannedBeacon(major: 2, minor: 1, rssi: -82), // faint neighbour
      ]),
      ScenarioLeg(duration: Duration(seconds: 10), beacons: [
        ScannedBeacon(major: 2, minor: 1, rssi: -55),
        ScannedBeacon(major: 1, minor: 1, rssi: -78), // fading behind
      ]),
    ],
  );

  /// Standoff at a doorway: neither zone leads by minDeltaDb for long.
  /// Expected: whichever entered first is HELD (no ping-pong).
  static const borderStandoff = BeaconScenario(
    name: 'borderStandoff',
    legs: [
      ScenarioLeg(duration: Duration(seconds: 4), beacons: [
        ScannedBeacon(major: 1, minor: 1, rssi: -60),
        ScannedBeacon(major: 2, minor: 1, rssi: -80),
      ]),
      // Wobble around equal for a long time; deltas stay under 7 dB.
      ScenarioLeg(duration: Duration(seconds: 20), beacons: [
        ScannedBeacon(major: 1, minor: 1, rssi: -63),
        ScannedBeacon(major: 2, minor: 1, rssi: -61),
      ]),
    ],
  );

  /// Walk back to the front desk (major 99) after touring zone 1.
  /// Expected: currentMajor stays 1; deskStable rises after deskDwell.
  static const returnToDesk = BeaconScenario(
    name: 'returnToDesk',
    legs: [
      ScenarioLeg(duration: Duration(seconds: 5), beacons: [
        ScannedBeacon(major: 1, minor: 1, rssi: -58),
      ]),
      ScenarioLeg(duration: Duration(seconds: 14), beacons: [
        ScannedBeacon(major: 99, minor: 0, rssi: -48), // desk dominates
        ScannedBeacon(major: 1, minor: 1, rssi: -72),
      ]),
    ],
  );

  /// Enter zone 1, then total silence (device pocketed / left the area).
  /// Expected: after zoneSilence, currentMajor → null (standby).
  static const silence = BeaconScenario(
    name: 'silence',
    legs: [
      ScenarioLeg(duration: Duration(seconds: 4), beacons: [
        ScannedBeacon(major: 1, minor: 1, rssi: -58),
      ]),
      ScenarioLeg(duration: Duration(seconds: 12), beacons: []), // silence
    ],
  );

  static const all = [zoneSwitch, borderStandoff, returnToDesk, silence];
}