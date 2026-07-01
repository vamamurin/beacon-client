abstract final class AppConstants {
  // Museum-wide iBeacon UUID shared by all ESP32 beacons
  static const String museumUUID = '4d6fc88b-be75-6698-da48-6866a36ec78e';

  // iBeacon path-loss model parameters
  static const int txPower = -59; // Calibrated RSSI at 1 metre (dBm)
  static const double pathLossExponent = 2.5; // Indoor environment

  // Moving-average filter window (Dùng cho bản cũ, nếu xài EMA thì ko quan trọng lắm)
  static const int filterWindowSize = 8;

  // Duty-cycle timing (SỬA LẠI THÀNH THẾ NÀY ĐỂ BẮT SÓNG REAL-TIME)
  static const Duration scanDuration = Duration(milliseconds: 6000); // Quét 2.5s
  static const Duration pauseDuration = Duration(milliseconds: 6000); // Tắt anten nửa giây thôi cho đỡ nóng máy

  // Mock scanner emits one reading every N ms
  static const Duration mockReadingInterval = Duration(milliseconds: 300);

  // ---------- SỬA LẠI NGƯỠNG HYSTERESIS THỰC TẾ ---------- //
  // Zone ENTRY thresholds (metres) - Khoảng cách chui vào vùng
  static const double zone2Entry = 6.0; 
  static const double zone3Entry = 3.5; 
  static const double zone4Entry = 1.5; 

  // Zone EXIT thresholds (metres) - Khoảng cách thoát khỏi vùng
  // Khoảng đệm (Exit - Entry) bây giờ ít nhất là 1.5 mét để chống nhiễu
  static const double zone2Exit = 8.0; // Phải lùi ra tận 8 mét mới thoát hẳn
  static const double zone3Exit = 5.0; // Phải lùi ra 5 mét mới rớt về zone 2
  static const double zone4Exit = 3.0; // Đang xem video, lùi ra 3 mét mới tắt video
}