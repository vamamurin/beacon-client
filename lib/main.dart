import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/core/injection.dart';
import 'package:beacon_client/presentation/app/app.dart';
import 'package:beacon_client/presentation/providers/proximity_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Quyền + trạng thái adapter KHÔNG còn xin ở đây nữa: việc đó chuyển vào
  // IBluetoothGate, chạy bên trong ProximityProvider.initialize() để UI có thể
  // hiển thị trạng thái "checking / permissionDenied / bluetoothOff" tường minh.
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final provider = ProximityProvider(
          beaconService: Injection.createBeaconService(),
          gate: Injection.createBluetoothGate(),
        );
        provider.initialize();
        return provider;
      },
      child: const MuseumApp(),
    ),
  );
}