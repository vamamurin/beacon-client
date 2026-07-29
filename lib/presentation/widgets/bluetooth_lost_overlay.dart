// Destination: lib/presentation/widgets/bluetooth_lost_overlay.dart
//
// A BLOCKING notice shown when the radio dies mid-tour.
//
// Why this exists, and why it blocks. Field test of the adapter-watch fix:
// swiping down and switching Bluetooth off during a tour left the app looking
// completely normal — exhibits still listed, narration still playing. The
// visitor's reasonable conclusion is "Bluetooth isn't needed", and they leave it
// off for the rest of their visit while the guide silently does nothing useful.
// A passive banner would teach the same lesson more quietly. So this is a scrim
// the tour cannot continue behind.
//
// ─────────────────────────────────────────────────────────────────────────────
// NO ACTION BUTTON — DELIBERATE
//
// The first version had a "Turn on Bluetooth" button wired to retryBluetooth().
// It could not work, and field testing said so: an app cannot switch the
// adapter on. BluetoothAdapter.enable() has been a no-op for third-party apps
// since Android 13, and retryBluetooth() only RE-READS state — against a
// switched-off adapter it returns bluetoothOff again and nothing visibly
// happens. A button that cannot keep its promise is worse than no button.
//
// So this states the fact and gets out of the way. The visitor turns Bluetooth
// back on from the same quick-settings tile they just used, and the overlay
// dismisses ITSELF: AppGraph._watchAdapter sees the adapter return, re-derives
// readiness, publishes `ready`, and this renders nothing again. No tap needed.
//
// A real "enable" affordance would be a system-settings intent — a later, and
// separate, decision.
//
// ─────────────────────────────────────────────────────────────────────────────
// ⚠ MUST SIT UNDER A Material.
//
// This is a direct child of MuseumApp's builder Stack, which is ABOVE the
// Navigator — there is no Scaffold or Material overhead. Text rendered there
// falls back to MaterialApp's error style: red, double-underlined in yellow.
// That is exactly what the first version shipped. ZoneChangeBanner (same
// position in the same Stack) avoids it by wrapping in Material; so does this.
//
// Placed ABOVE ZoneChangeBanner in that Stack, because "the radio is gone"
// outranks "you may have changed zone" — and the zone question is meaningless
// without a radio anyway.
//
// ONLY WHILE TOURING. At the gate the Gate screen already owns BLE messaging
// with staff-facing copy and a retry that CAN work (permission prompts); a
// second modal over it would be noise.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/providers/startup_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

/// Test anchor. Same discipline as GateKeys: one key per relationship that has
/// to hold, not decoration.
@visibleForTesting
abstract final class BluetoothLostKeys {
  static const scrim = ValueKey('ble.lost.scrim');
  static const card = ValueKey('ble.lost.card');
}

class BluetoothLostOverlay extends StatelessWidget {
  const BluetoothLostOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // Only a live tour gets the blocking treatment — see header.
    final phase = context.watch<SessionProvider>().phase;
    if (phase != SessionPhase.touring) return const SizedBox.shrink();

    return ValueListenableBuilder<StartupStatus>(
      valueListenable: context.read<StartupProvider>().bleStatus,
      builder: (context, status, _) {
        // `checking` is transient (a re-derive in flight). Flashing a modal for
        // it would strobe the screen every time we re-check.
        if (status == StartupStatus.ready ||
            status == StartupStatus.checking) {
          return const SizedBox.shrink();
        }
        return _Notice(status: status);
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.status});
  final StartupStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.read<ContentProvider>();

    // The adapter being off is the case the visitor caused and can undo from
    // quick settings. Any other non-ready reason mid-tour (permission revoked,
    // unsupported hardware) is a staff problem, and the copy says so instead of
    // telling a visitor to do something they cannot.
    final bool adapterOff = status == StartupStatus.bluetoothOff;

    return Positioned.fill(
      child: Semantics(
        // A modal barrier for screen readers too: nothing behind this is
        // actionable while it is up.
        scopesRoute: true,
        explicitChildNodes: true,
        child: ColoredBox(
          key: BluetoothLostKeys.scrim,
          color: t.scrimBack,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                // Material, not a bare Container: see the ⚠ note in the header.
                // Card surface + outline mirror ZoneChangeBanner so the two
                // overlays read as the same system.
                child: Material(
                  key: BluetoothLostKeys.card,
                  color: t.surface,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      // t.outline (control border), NOT t.line — the hairline is
                      // tuned for `surface` and reads as no border at all here.
                      border: Border.all(color: t.outline),
                    ),
                    padding: const EdgeInsets.all(AppSpace.x5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.bluetooth_disabled,
                            size: 28, color: t.inkMuted),
                        const SizedBox(height: AppSpace.x3),
                        Text(
                          content.ui(adapterOff
                              ? UiKeys.tourBleLostTitle
                              : UiKeys.tourBleBlockedTitle),
                          style: AppText.sheetTitle.copyWith(color: t.ink),
                        ),
                        const SizedBox(height: AppSpace.x2),
                        Text(
                          content.ui(adapterOff
                              ? UiKeys.tourBleLostBody
                              : UiKeys.tourBleBlockedBody),
                          style: AppText.body.copyWith(color: t.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
