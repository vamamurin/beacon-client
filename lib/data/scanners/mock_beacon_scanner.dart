import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:beacon_client/core/constants.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';

/// Simulates a user walking from ~9 m away to ~0.5 m and back over 60 s.
///
/// Gaussian-ish noise (±3 dBm) is layered on top of the ideal RSSI to
/// replicate indoor multipath fading, exercising the Kalman filter and
/// hysteresis state machine without real hardware.
class MockBeaconScanner implements IBeaconScanner {
  final _controller = StreamController<BeaconReading>.broadcast();
  final _random = Random();
  Timer? _timer;
  bool _active = false;
  double _elapsedSeconds = 0;

  // Sine-wave walk: distance oscillates between 0.5 m and 9.0 m over 60 s.
  static const double _cyclePeriod = 60.0;
  static const double _distanceMid = 4.75;
  static const double _distanceAmp = 4.25;

  // PHASE 2: Measured Power giả lập cho beacon mô phỏng (RSSI hiệu chỉnh @1m).
  // Dùng const cục bộ thay cho AppConstants.txPower để purge hoàn toàn keyword
  // 'txPower'. Beacon ảo này coi như được hiệu chỉnh ở -59 dBm.
  static const int _mockMeasuredPower = -59;

  static final ValueNotifier<double?> manualDistance = ValueNotifier(null);

  @override
  Stream<BeaconReading> get readings => _controller.stream;

  @override
  Future<void> startScan() async {
    _active = true;
    _timer ??= Timer.periodic(AppConstants.mockReadingInterval, _emit);
  }

  @override
  Future<void> stopScan() async => _active = false;

  void _emit(Timer _) {
    if (!_active || _controller.isClosed) return;

    _elapsedSeconds +=
        AppConstants.mockReadingInterval.inMilliseconds / 1000.0;

    final dist = manualDistance.value ??
        (_distanceMid +
            _distanceAmp * sin(2 * pi * _elapsedSeconds / _cyclePeriod));

    // RSSI = MeasuredPower - 10·n·log₁₀(distance)
    final idealRssi = _mockMeasuredPower -
        10.0 * AppConstants.pathLossExponent * log(dist) / log(10);

    // Add uniform noise in [-3, +3] dBm to simulate multipath fading
    final noisyRssi = idealRssi + (_random.nextDouble() * 6.0 - 3.0);

    _controller.add(BeaconReading(
      uuid: AppConstants.museumUUID,
      major: 1,
      minor: 1,
      rssi: noisyRssi.round(),
      measuredPower: _mockMeasuredPower, // PHASE 2: giả lập, giữ build xanh
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}