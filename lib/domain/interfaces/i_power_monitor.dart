// Destination: lib/domain/interfaces/i_power_monitor.dart

/// Reports charging state — the dock signal at the heart of the session
/// lifecycle. Same shape as IHeadphoneMonitor: a synchronous read plus a
/// change stream.
///
/// Two lifecycle roles (confirmed):
///   • charging rises while touring  -> device docked -> end session (P1, 0ms).
///   • charging falls while atDesk   -> device lifted off the dock -> wake to
///     the gate. Unplug is the ONLY way out of atDesk (the physical lock).
abstract interface class IPowerMonitor {
  /// Whether the device is currently charging (on the dock).
  bool get isCharging;

  /// Emits on every charging-state change: true = plugged, false = unplugged.
  Stream<bool> get onChargingChanged;

  /// Begin monitoring. Idempotent.
  Future<void> start();

  Future<void> dispose();
}
