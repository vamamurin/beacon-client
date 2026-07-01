import 'package:beacon_client/domain/models/beacon_reading.dart';

/// Hardware Abstraction Layer for BLE scanning.
///
/// Implementations:
///   - [MockBeaconScanner]  – simulated walk pattern for desktop dev/demo.
///   - [RealBeaconScanner]  – flutter_blue_plus wrapper for Android / iOS.
abstract class IBeaconScanner {
  /// Continuous stream of raw iBeacon advertisements.
  Stream<BeaconReading> get readings;

  /// Tell the hardware (or mock) to start advertising reads.
  Future<void> startScan();

  /// Pause reading without destroying the stream.
  Future<void> stopScan();

  void dispose();
}
