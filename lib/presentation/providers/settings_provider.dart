// Destination: lib/presentation/providers/settings_provider.dart
//
// C3 — reactive access to staff-facing device settings that aren't the theme.
// Today just the "show estimated distance" debug toggle. Same shape as
// ThemeController: seeded from ISettingsStore at construction, writes through on
// change, notifies listeners so the toggle and the zone screen update in place.
//
// Kept separate from ThemeController because theme is a visitor-visible choice
// with its own lerp/animation concerns, while this is a staff diagnostic flag.

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_settings_store.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({required ISettingsStore store})
      : _store = store,
        _showDistance = store.showDistanceDebug;

  final ISettingsStore _store;

  bool _showDistance;
  bool get showDistanceDebug => _showDistance;

  void setShowDistanceDebug(bool value) {
    if (value == _showDistance) return;
    _showDistance = value;
    _store.setShowDistanceDebug(value); // persist (fire-and-forget)
    notifyListeners();
  }
}