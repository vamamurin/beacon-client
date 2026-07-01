import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:beacon_client/domain/interfaces/i_bluetooth_gate.dart';
import 'package:beacon_client/domain/models/proximity_info.dart';
import 'package:beacon_client/domain/models/startup_status.dart';
import 'package:beacon_client/services/beacon_service.dart';

/// Bridge giữa [BeaconService] và UI — nay kiêm hai trục mới:
///
///  1. **Gatekeeper**: chạy [IBluetoothGate.ensureReady] trước khi cho pipeline
///     chạy, và lắng nghe adapter để phục hồi runtime (bật/tắt Bluetooth).
///  2. **Lifecycle-aware**: là [WidgetsBindingObserver]; nền/foreground điều
///     khiển start/stop để KHÔNG quét lowLatency ngầm (tiết kiệm pin/CPU).
///
/// Một nguồn sự thật duy nhất quyết định pipeline có chạy hay không — [_reconcile]:
/// chỉ chạy khi `status == ready` VÀ app đang ở foreground. Gate và lifecycle vì
/// thế không "đánh nhau".
class ProximityProvider extends ChangeNotifier with WidgetsBindingObserver {
  final BeaconService _beaconService;
  final IBluetoothGate _gate;
  

  StreamSubscription<List<ProximityInfo>>? _sub;
  StreamSubscription<bool>? _adapterSub;

  List<ProximityInfo> _leaderboard = const [];
  bool _received = false;
  bool _foreground = true;
  bool _serviceRunning = false;
  StartupStatus _status = StartupStatus.checking;
  bool _resolving = false; // chặn các lần kiểm tra gate chồng lên nhau

  ProximityProvider({
    required BeaconService beaconService,
    required IBluetoothGate gate,
  })  : _beaconService = beaconService,
        _gate = gate;

  // ── Reads cho UI ─────────────────────────────────────────────────────
  List<ProximityInfo> get leaderboard => _leaderboard;

  ProximityInfo? get currentInfo =>
      _leaderboard.isEmpty ? null : _leaderboard.first;

  StartupStatus get status => _status;

  bool get isReady => _status == StartupStatus.ready;

  /// "Đang khởi động" chỉ có nghĩa khi đã sẵn sàng quét nhưng chưa có board nào.
  bool get isInitializing => _status == StartupStatus.ready && !_received;

  // ── Lifecycle ────────────────────────────────────────────────────────
  /// Idempotent: chỉ subscribe một lần (chống double-initialize / leak).
  Future<void> initialize() async {
    if (_sub != null) return;

    WidgetsBinding.instance.addObserver(this);
    _sub = _beaconService.proximityStream.listen(_onLeaderboard);
    _adapterSub = _gate.adapterOn.listen(_onAdapterChanged);

    await _resolveGate();
  }

  /// CTA "Thử lại" từ UI lỗi (xin lại quyền / kiểm tra lại adapter).
  Future<void> retry() => _resolveGate();

  /// CTA "Mở cài đặt" cho ca quyền bị cấm vĩnh viễn.
  Future<void> openSettings() => _gate.openSettings();

  // Future<void> _resolveGate() async {
  //   _setStatus(StartupStatus.checking);
  //   final result = await _gate.ensureReady();
  //   _setStatus(result);
  //   await _reconcile();
  // }
  Future<void> _resolveGate() async {
    // Chống spam: nếu một lần kiểm tra gate đang chạy thì bỏ qua lần gọi mới.
    // Đây là chốt chặn "bão" notifyListeners → AnimatedSwitcher churn → crash.
    if (_resolving) return;
    _resolving = true;
    try {
      // KHÔNG nhấp về 'checking' khi retry: giữ nguyên màn hình lỗi hiện tại
      // cho tới khi có kết quả mới (tránh chớp radar). Lúc boot vẫn hiện
      // 'checking' nhờ giá trị khởi tạo của _status ở trên.
      final result = await _gate.ensureReady();
      _setStatus(result);
      await _reconcile();
    } finally {
      _resolving = false;
    }
  }

  /// Phục hồi runtime khi người dùng bật/tắt Bluetooth (không xin lại quyền để
  /// tránh lặp dialog — chỉ chuyển trạng thái giữa ready ↔ bluetoothOff).
  void _onAdapterChanged(bool on) {
    if (!on && _status == StartupStatus.ready) {
      _setStatus(StartupStatus.bluetoothOff);
      _reconcile();
    } else if (on && _status == StartupStatus.bluetoothOff) {
      _setStatus(StartupStatus.ready);
      _reconcile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    _foreground = fg;

    if (fg) {
      // Quay lại foreground sau khi bị chặn vĩnh viễn → có thể vừa cấp ở
      // Settings → resolve lại (đây là nhánh CÓ thể bật hộp thoại, an toàn vì
      // chỉ chạy cho ca permanently-denied).
      if (_status == StartupStatus.permissionPermanentlyDenied) {
        _resolveGate();
        return;
      }
      // Đang ready nhưng one-time permission có thể đã bị OS thu hồi khi chạy
      // nền → kiểm tra CHỈ-ĐỌC (không bật dialog). Nếu mất quyền → hạ trạng
      // thái để UI hiện màn xin quyền thay vì kẹt câm.
      if (_status == StartupStatus.ready) {
        _verifyPermissionsStillHeld();
        return;
      }
    }

    _reconcile();
  }

  /// Soi quyền hiện tại mà không bật hộp thoại; chỉ hạ trạng thái khi đã mất.
  Future<void> _verifyPermissionsStillHeld() async {
    final ok = await _gate.hasPermissions();
    if (ok) {
      _reconcile(); // vẫn đủ quyền → bật lại pipeline cho foreground
    } else {
      _setStatus(StartupStatus.permissionDenied);
      await _reconcile(); // shouldRun=false → dừng pipeline gọn gàng
    }
  }

  /// Nguồn sự thật duy nhất: pipeline sống ⇔ (gate ready) ∧ (foreground).
  Future<void> _reconcile() async {
    final shouldRun = _status == StartupStatus.ready && _foreground;

    if (shouldRun && !_serviceRunning) {
      _serviceRunning = true; // set TRƯỚC await để chặn double-run
      await _beaconService.initialize(); // pre-warm (idempotent) + start
      // Có thể đã đổi ý trong lúc warm-up (app nền / adapter tắt) → undo.
      if (!(_status == StartupStatus.ready && _foreground)) {
        _serviceRunning = false;
        _beaconService.stop();
      }
    } else if (!shouldRun && _serviceRunning) {
      _serviceRunning = false;
      _beaconService.stop();
      // Xả board để UI không hiển thị thẻ cũ khi đang tạm dừng / tắt sóng;
      // reset _received để khi quay lại hiện "Đang khởi động" thay vì "trống".
      _leaderboard = const [];
      _received = false;
      notifyListeners();
    }
  }

  void _onLeaderboard(List<ProximityInfo> board) {
    _received = true;
    _leaderboard = board;
    // Upstream registry đã gate emission theo thay đổi có nghĩa → mỗi emission
    // ở đây xứng đáng một rebuild, không cần throttle thêm.
    notifyListeners();
  }

  void _setStatus(StartupStatus s) {
    if (_status == s) return;
    _status = s;
    if (s != StartupStatus.ready) _received = false;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adapterSub?.cancel();
    _adapterSub = null;
    _sub?.cancel();
    _sub = null;
    _beaconService.dispose();
    _gate.dispose();
    super.dispose();
  }
}