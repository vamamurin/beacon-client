// Destination: lib/domain/models/zone_signal.dart

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Aggregated radio signal for ONE zone (one iBeacon major) at one instant —
/// the registry's output unit, successor of the per-beacon ActiveBeacon.
///
/// A zone may be served by several physical beacons (per-exhibit beacons all
/// sharing the zone's major). Each keeps its OWN Kalman filter downstream in
/// its own tracker; this type is the roll-up: the zone "sounds as loud as its
/// strongest live beacon".
///
/// Repo-free by design (same SoC rule as ActiveBeacon had): no ZoneInfo, no
/// names — the arbiter and debug radar consume majors and dB only.
@immutable
class ZoneSignal {
  final int major;

  /// Kalman-smoothed RSSI (dBm) of the STRONGEST live beacon of this major.
  /// The arbiter compares zones on this value.
  final double rssiDb;

  /// Smoothed RSSI per live minor. Serves two future consumers without a new
  /// pipeline: infrastructure monitoring (heard minors vs manifest ⇒ dead
  /// battery / stray beacon alerts) and the optional nearestExhibitHint.
  final Map<int, double> rssiByMinor;

  /// Wall-clock of the newest packet from any beacon of this major.
  final DateTime lastSeenAt;

  /// C1 — Measured Power (RSSI hiệu chỉnh @1m) của CHÍNH beacon mạnh nhất
  /// đang đại diện cho zone này (cùng nguồn với [rssiDb]). Mỗi beacon tự khai
  /// giá trị của nó trong gói iBeacon (Phase 2), nên so sánh khoảng cách giữa
  /// các zone dùng đúng hiệu chuẩn của từng phần cứng, không dùng hằng chung.
  /// Default -59 dBm (chuẩn công nghiệp) giữ tương thích cho test/mocks cũ.
  final int measuredPowerDbm;

  const ZoneSignal({
    required this.major,
    required this.rssiDb,
    required this.rssiByMinor,
    required this.lastSeenAt,
    this.measuredPowerDbm = -59,
  });

  /// C1 — Khoảng cách ƯỚC LƯỢNG (mét) theo mô hình log-distance path loss:
  ///   d = 10 ^ ((measuredPower − rssi) / (10 · n))
  /// với n = [pathLossExponent] (≈2.0 không vật cản, 2.5–3.5 trong nhà có tủ
  /// kính/người che). CHỈ dùng để phân TẦNG (engage/release có hysteresis) và
  /// hiển thị debug — sai số trong nhà ±30–50%, KHÔNG được coi là thước đo.
  /// Đầu vào là RSSI đã qua Kalman nên ước lượng ổn định theo thời gian.
  double estimatedDistanceMeters(double pathLossExponent) => math
      .pow(10, (measuredPowerDbm - rssiDb) / (10 * pathLossExponent))
      .toDouble();

  Iterable<int> get minorsHeard => rssiByMinor.keys;

  @override
  String toString() =>
      'ZoneSignal(major: $major, rssi: ${rssiDb.toStringAsFixed(1)} dBm, '
      'minors: ${rssiByMinor.keys.toList()..sort()})';

  // NOTE: no value-equality on purpose. Snapshots are a 1 Hz heartbeat the
  // arbiter consumes as a CLOCK as much as a value; de-duplicating them would
  // starve dwell/lockout timing. Change-gating happens one layer up, on
  // ZonePresence (whose equality intentionally ignores lastBeaconAt).
}