// Destination: lib/domain/interfaces/i_headphone_monitor.dart

/// Reports headphone availability and the "audio became noisy" event.
///
/// "Headphones" here means ANY private-listening route — wired jack OR
/// Bluetooth audio (the client-device future case) — not just a 3.5 mm plug.
/// The tour controller consumes this for two confirmed policies:
///   • autoplayRequiresHeadphones: no route ⇒ reading mode, never autoplay
///     out loud;
///   • becomingNoisy: route removed mid-playback ⇒ pause immediately (the
///     Spotify/Apple Music gold standard), and DO NOT auto-resume on replug —
///     wait for an explicit play.
abstract interface class IHeadphoneMonitor {
  /// Whether a private-listening route is currently connected. Synchronous
  /// read for the gate screen's initial autoplay decision.
  bool get isConnected;

  /// Connection changes: true = a route became available, false = removed.
  /// The false edge is the "becoming noisy" signal the controller pauses on.
  Stream<bool> get onConnectionChanged;

  /// Begin monitoring. Idempotent.
  Future<void> start();

  Future<void> dispose();
}
