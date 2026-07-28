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
// with one action: turn Bluetooth back on.
//
// Placed as the TOP child of MuseumApp's builder Stack, above ZoneChangeBanner,
// because "the radio is gone" outranks "you may have changed zone" — and the
// zone-change question is meaningless without a radio anyway.
//
// ONLY WHILE TOURING. At the gate, the Gate screen already owns BLE messaging
// with staff-facing copy and a retry (that path was verified working); a second
// modal on top of it would be noise. Being on the dock with Bluetooth off is a
// staff situation, not a visitor emergency.

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
  static const cta = ValueKey('ble.lost.cta');
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
    final startup = context.read<StartupProvider>();

    // The adapter being off is the case the visitor caused and can undo. Every
    // other non-ready reason mid-tour (permission revoked from the tray,
    // unsupported) is a staff problem, so it routes to system settings rather
    // than promising a retry that cannot succeed.
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.ui(adapterOff
                          ? UiKeys.tourBleLostTitle
                          : UiKeys.gateBleDeniedTitle),
                      style: AppText.sheetTitle.copyWith(color: t.inkOnImage),
                    ),
                    const SizedBox(height: AppSpace.x3),
                    Text(
                      content.ui(adapterOff
                          ? UiKeys.tourBleLostBody
                          : UiKeys.gateBleDeniedBody),
                      style: AppText.body.copyWith(color: t.mutedOnImage),
                    ),
                    const SizedBox(height: AppSpace.x6),
                    SizedBox(
                      width: double.infinity,
                      height: AppSpace.tap, // a11y floor, same as _StaffButton
                      child: FilledButton(
                        key: BluetoothLostKeys.cta,
                        style: FilledButton.styleFrom(
                          backgroundColor: t.ctaOnImageFill,
                          foregroundColor: t.ctaOnImageInk,
                          shape: const RoundedRectangleBorder(),
                        ),
                        // Both paths are safe to press repeatedly. retryBluetooth
                        // re-derives readiness and restarts the pipeline if the
                        // adapter came back; it does not fabricate a state.
                        onPressed: () => adapterOff
                            ? startup.retryBluetooth()
                            : startup.openBluetoothSettings(),
                        child: Text(
                          content.ui(adapterOff
                              ? UiKeys.tourBleLostCta
                              : UiKeys.gateBleDeniedCta),
                          style: AppText.button,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
