// Destination: lib/data/audio/audio_session_headphone_monitor.dart
//
// Real IHeadphoneMonitor over audio_session. Covers BOTH wired and Bluetooth
// routes (devicesChangedEventStream reports either), and treats the plugin's
// becomingNoisyEventStream as the authoritative "unplugged" edge that the
// controller pauses on (rule 6).
//
// Why audio_session and not a dedicated headphone plugin: we already depend on
// audio_session for the speech configuration, it gives both the noisy edge and
// device enumeration, and using one source avoids two plugins fighting over the
// single shared audio session.
//
// NOT unit-tested (plugin/hardware). Verified via the on-device checklist.

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_headphone_monitor.dart';

class AudioSessionHeadphoneMonitor implements IHeadphoneMonitor {
  AudioSession? _session;
  bool _connected = false;

  final _ctrl = StreamController<bool>.broadcast();
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioDevicesChangedEvent>? _devicesSub;

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get onConnectionChanged => _ctrl.stream;

  @override
  Future<void> start() async {
    _session ??= await AudioSession.instance;
    final session = _session!;

    // Seed initial state from currently connected output devices.
    _connected = await _hasPrivateRoute(session);

    // becomingNoisy == a route that was carrying audio was removed. This is
    // the reliable "unplugged" signal (rule 6): pause immediately.
    _noisySub ??= session.becomingNoisyEventStream.listen((_) {
      _update(false);
    });

    // devicesChanged fills in the POSITIVE edge (a route was added) and also
    // catches Bluetooth (dis)connects that don't always raise becomingNoisy.
    _devicesSub ??= session.devicesChangedEventStream.listen((_) async {
      _update(await _hasPrivateRoute(session));
    });
  }

  /// True if any private-listening output (wired headset/headphones or a
  /// Bluetooth audio sink) is currently available.
  Future<bool> _hasPrivateRoute(AudioSession session) async {
    try {
      final devices = await session.getDevices(includeInputs: false);
      return devices.any((d) => _isPrivateOutput(d.type));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HeadphoneMonitor] getDevices failed: $e');
      }
      return _connected; // keep last known on transient failure
    }
  }

  bool _isPrivateOutput(AudioDeviceType type) {
    switch (type) {
      case AudioDeviceType.wiredHeadset:
      case AudioDeviceType.wiredHeadphones:
      case AudioDeviceType.bluetoothA2dp:
      case AudioDeviceType.bluetoothSco:
      case AudioDeviceType.usbAudio:
      // case AudioDeviceType.headphones: // iOS generic headphones
        return true;
      default:
        return false;
    }
  }

  void _update(bool connected) {
    if (connected == _connected) return;
    _connected = connected;
    if (!_ctrl.isClosed) _ctrl.add(connected);
    if (kDebugMode) {
      debugPrint('[HeadphoneMonitor] route ${connected ? "connected" : "removed"}');
    }
  }

  @override
  Future<void> dispose() async {
    await _noisySub?.cancel();
    await _devicesSub?.cancel();
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
