// Destination: lib/presentation/providers/startup_provider.dart (NEW)
//
// Mọi thứ Gate cần để trả lời "đã sẵn sàng bàn giao máy cho khách chưa?".
// Trước đây Gate chạm năm mặt khác nhau của AppGraph: repository.lastError,
// bleStatus, runSync, retryBluetooth, bluetoothGate.openSettings,
// refreshBluetoothOnResume.
//
// Nhận CALLBACK chứ không nhận AppGraph, nên fake được trong widget test bằng
// vài closure — không cần Bluetooth thật, không cần server thật.
//
// Cũng là nơi SyncResult (tầng data) được dịch sang SyncReport (tầng UI). Gate
// không cần biết ContentSyncService tồn tại, và quan trọng hơn: việc so sánh
// kết quả không còn dựa vào `outcome.name == 'updated'` — đổi tên một hằng
// enum sẽ không còn âm thầm làm nút "Khởi động lại" biến mất.
//
// TODO(domain): SyncOutcome/SyncResult đúng ra thuộc domain/models, không phải
// data/repositories. Khi chuyển, import bên dưới biến mất và provider này sạch
// hoàn toàn khỏi tầng data.

import 'package:flutter/foundation.dart';

import 'package:beacon_client/data/repositories/content_sync_service.dart';
import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/startup_status.dart';

/// Kết quả một lần đồng bộ, đã dịch sang ngôn ngữ của UI.
@immutable
class SyncReport {
  const SyncReport._(this.status, {this.version, this.error});

  final SyncStatus status;
  final String? version;
  final String? error;

  /// Chỉ hai kết quả này cho phép bàn giao máy: nội dung đã có trên thiết bị.
  /// Cả hai đều CẦN restart graph, vì pipeline đã được dựng khi chưa có config
  /// (UUID beacon, tham số arbiter, ngôn ngữ đều là mặc định/rỗng).
  bool get readyToRestart =>
      status == SyncStatus.updated || status == SyncStatus.upToDate;
}

enum SyncStatus {
  /// Đã tải nội dung mới.
  updated,

  /// Nội dung trên máy đã là bản mới nhất.
  upToDate,

  /// Không gọi được máy chủ.
  noConnectivity,

  /// Lỗi mạng / checksum / validation.
  failed,

  /// Chế độ mock — không có server để đồng bộ.
  mockMode,
}

class StartupProvider {
  StartupProvider({
    required IZoneRepository repository,
    required ValueListenable<StartupStatus> bleStatus,
    required Future<void> Function() retryBluetooth,
    required Future<void> Function() refreshBluetoothOnResume,
    required Future<bool> Function() openBluetoothSettings,
    required Future<SyncResult?> Function({void Function(double)? onProgress})
        runSync,
  })  : _repo = repository,
        _bleStatus = bleStatus,
        _retryBluetooth = retryBluetooth,
        _refreshOnResume = refreshBluetoothOnResume,
        _openSettings = openBluetoothSettings,
        _runSync = runSync;

  final IZoneRepository _repo;
  final ValueListenable<StartupStatus> _bleStatus;
  final Future<void> Function() _retryBluetooth;
  final Future<void> Function() _refreshOnResume;
  final Future<bool> Function() _openSettings;
  final Future<SyncResult?> Function({void Function(double)? onProgress})
      _runSync;

  // ── Bluetooth ─────────────────────────────────────────────────────────────

  /// Trạng thái BLE, phản ứng: cấp quyền / bật Bluetooth sẽ lật nó sang ready
  /// mà không cần khởi động lại app. Gate lắng nghe qua ValueListenableBuilder.
  ValueListenable<StartupStatus> get bleStatus => _bleStatus;

  /// Retry tường minh do người dùng bấm ("Cấp quyền" / "Thử lại"). CÓ THỂ hiện
  /// hộp thoại xin quyền.
  Future<void> retryBluetooth() => _retryBluetooth();

  /// App quay lại foreground (ví dụ từ Settings). PROMPT-SAFE: không bao giờ
  /// bật lại hộp thoại xin quyền, chỉ đọc lại trạng thái nếu quyền đã có.
  Future<void> refreshBluetoothOnResume() => _refreshOnResume();

  Future<bool> openBluetoothSettings() => _openSettings();

  // ── nội dung ──────────────────────────────────────────────────────────────

  /// Thiết bị mới toanh: bundle chưa có / hỏng. Đây là màn STAFF, không phải
  /// khách — thông báo được viết cho người bàn giao máy.
  bool get needsSync => _repo.lastError != null;

  /// Lý do kỹ thuật, cho staff. Null khi không có lỗi.
  String? get syncError => _repo.lastError;

  /// Chạy đồng bộ. [onProgress] nhận 0..1.
  Future<SyncReport> runSync({void Function(double)? onProgress}) async {
    final res = await _runSync(onProgress: onProgress);
    if (res == null) return const SyncReport._(SyncStatus.mockMode);

    // So sánh trên enum, KHÔNG trên `outcome.name` — đổi tên một hằng enum
    // không được phép âm thầm đổi hành vi nút "Khởi động lại".
    return switch (res.outcome) {
      SyncOutcome.updated =>
        SyncReport._(SyncStatus.updated, version: res.version),
      SyncOutcome.upToDate =>
        SyncReport._(SyncStatus.upToDate, version: res.version),
      SyncOutcome.noConnectivity =>
        SyncReport._(SyncStatus.noConnectivity, error: res.error),
      SyncOutcome.failed => SyncReport._(SyncStatus.failed, error: res.error),
    };
  }
}
