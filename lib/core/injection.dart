import 'package:beacon_client/data/gateways/mock_bluetooth_gate.dart';
import 'package:beacon_client/data/gateways/real_bluetooth_gate.dart';
import 'package:beacon_client/data/repositories/remote_artifact_repository.dart';
import 'package:beacon_client/data/scanners/mock_beacon_scanner.dart';
import 'package:beacon_client/data/scanners/real_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_artifact_repository.dart';
import 'package:beacon_client/domain/interfaces/i_beacon_scanner.dart';
import 'package:beacon_client/domain/interfaces/i_bluetooth_gate.dart';
import 'package:beacon_client/services/beacon_service.dart';

enum ScannerMode { mock, real }

/// Composition root. Ráp đồ thị phụ thuộc tại một nơi; mọi phụ thuộc đi xuống
/// qua constructor (không phơi singleton ra ngoài → tránh anti-pattern
/// Service Locator).
///
/// Đổi [_mode] sang [ScannerMode.real] trước khi build cho mobile. Repository
/// được giữ làm singleton app-wide để cache được warm một lần và dùng chung.
abstract final class Injection {
  static const ScannerMode _mode = ScannerMode.real;

  /// App-wide singleton. `static final` ⇒ lazy, dựng một lần ở lần truy cập đầu.
  // static final IArtifactRepository _artifactRepository =
  //     MockArtifactRepository();
  static final IArtifactRepository _artifactRepository =
      RemoteArtifactRepository(
    // TODO(config): tách endpoint ra --dart-define / AppEnvironment; production
    // phải là HTTPS thay vì IP LAN cleartext.
    apiUrl: 'http://172.20.10.4:8000/data.json',
  );

  static BeaconService createBeaconService() {
    final IBeaconScanner scanner = switch (_mode) {
      ScannerMode.mock => MockBeaconScanner(),
      ScannerMode.real => RealBeaconScanner(),
    };

    return BeaconService(
      scanner: scanner,
      artifactRepository: _artifactRepository,
    );
  }

  /// Gate quyền/adapter, song hành với scanner theo cùng [_mode].
  static IBluetoothGate createBluetoothGate() {
    return switch (_mode) {
      ScannerMode.mock => MockBluetoothGate(),
      ScannerMode.real => RealBluetoothGate(),
    };
  }
}