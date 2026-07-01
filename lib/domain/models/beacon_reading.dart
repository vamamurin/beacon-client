/// A single iBeacon advertisement received from an ESP32.
class BeaconReading {
  final String uuid;
  final int major; // Museum zone / floor ID
  final int minor; // Specific artifact ID
  final int rssi; // Raw signal strength in dBm

  /// PHASE 2 — Measured Power: byte 23 của gói iBeacon (RSSI hiệu chỉnh @1m do
  /// CHÍNH beacon phát ra). Đã được ép dấu int8 (toSigned(8)) và validate cửa sổ
  /// [-100, -20] dBm ngay tại tầng Scanner → tới đây luôn là số âm hợp lệ.
  /// Thay thế hằng số tĩnh AppConstants.txPower: nguồn sự thật giờ là phần cứng.
  final int measuredPower;

  final DateTime timestamp;

  const BeaconReading({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
    required this.measuredPower,
    required this.timestamp,
  });
}