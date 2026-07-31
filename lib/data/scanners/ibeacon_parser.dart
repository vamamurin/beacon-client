// FILE: /lib/data/scanners/ibeacon_parser.dart
//
// Giải mã payload iBeacon từ manufacturer-specific data của Apple, tách khỏi
// [RealBeaconScanner] để [PendingIntentBeaconScanner] dùng chung ĐÚNG bộ luật.
//
// VÌ SAO PHẢI DÙNG CHUNG, KHÔNG COPY: toàn bộ Strict Mode (guard độ dài ≥23,
// subtype 0x02, length 0x15, cửa sổ Measured Power [-100,-20]) là hợp đồng mà
// pipeline phía sau tin tưởng — BeaconReading.measuredPower LUÔN là số âm hợp
// lệ, nên BeaconTracker không phải tự phòng thủ. Hai bản sao của bộ luật này sẽ
// trôi khỏi nhau, và cái trôi sẽ là cái chỉ chạy trên máy thật lúc màn tắt —
// đúng chỗ khó phát hiện nhất.

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/beacon_reading.dart';

/// Apple Inc. Bluetooth SIG company identifier — vỏ chứa iBeacon payload.
const int kAppleCompanyId = 0x004C;

// PHASE 2: cửa sổ Measured Power hợp lệ (dBm). Ngoài vùng này coi như gói rác
// (nhiễu sóng / bit lỗi) → drop thẳng tay theo Strict Mode. Biên bao gồm 2 đầu.
const int kMeasuredPowerMin = -100;
const int kMeasuredPowerMax = -20;

/// Giải mã một gói iBeacon. Trả null nếu không phải iBeacon hợp lệ.
///
/// [appleData] là phần manufacturer-specific data ỨNG VỚI company id Apple, đã
/// bóc vỏ company id — tức byte[0] phải là subtype 0x02.
///
/// [timestamp] là mốc GÓI SÓNG (thời điểm phần cứng nhận), KHÔNG phải lúc parse.
/// Cả staleness 3s, eviction 12s lẫn zoneSilence đều đo tuổi trên mốc này; đưa
/// `DateTime.now()` vào đây là tái phát lỗi P0-2 (beacon chết được "làm tươi"
/// mãi mãi vì danh sách tích lũy liên tục được emit lại).
///
/// Log chi tiết lý do thất bại để dễ debug qua `flutter logs`. Người gọi chịu
/// trách nhiệm dedupe để mỗi gói sóng thật chỉ log đúng một lần.
BeaconReading? parseIBeacon({
  required String deviceId,
  required List<int> appleData,
  required int rssi,
  required DateTime timestamp,
}) {
  // PHASE 2 — STRICT MODE: cần ≥23 byte để đọc Measured Power ở index 22.
  // (Check ≥22 là off-by-one: đủ cho UUID/major/minor nhưng KHÔNG đủ cho byte
  // 23 → appleData[22] sẽ ném RangeError. Guard này bảo vệ toàn bộ các index
  // 0..22 đọc bên dưới.)
  if (appleData.length < 23) {
    if (kDebugMode) {
      debugPrint(
          '[iBeacon] $deviceId — FAIL: data quá ngắn: ${appleData.length} bytes, cần ≥23 (để có Measured Power)');
    }
    return null;
  }

  // Byte 0: iBeacon subtype phải là 0x02
  if (appleData[0] != 0x02) {
    if (kDebugMode) {
      debugPrint(
          '[iBeacon] $deviceId — FAIL: byte[0] sai subtype=0x${appleData[0].toRadixString(16).toUpperCase()} (cần 0x02)');
    }
    return null;
  }

  // Byte 1: payload length phải là 0x15 = 21
  if (appleData[1] != 0x15) {
    if (kDebugMode) {
      debugPrint(
          '[iBeacon] $deviceId — FAIL: byte[1] sai length=0x${appleData[1].toRadixString(16).toUpperCase()} (cần 0x15=21)');
    }
    return null;
  }

  // UUID: bytes [2..17] (16 bytes)
  final uuid = _bytesToUuidString(appleData.sublist(2, 18));

  // Major/Minor: big-endian
  final major = (appleData[18] << 8) | appleData[19];
  final minor = (appleData[20] << 8) | appleData[21];

  // PHASE 2 — MEASURED POWER (byte 23 = index 22):
  // BLE trả uint8 (0..255) nhưng giá trị thực là int8 two's complement (âm).
  // toSigned(8) tái diễn giải đúng dấu, vd 0xC5=197 → -59. Single byte nên
  // không có vấn đề endianness, chỉ cần lo dấu.
  final measuredPower = appleData[22].toSigned(8);

  // PHASE 2 — VALIDATE giá trị: ngoài [-100, -20] dBm là rác → drop (Fail-fast).
  if (measuredPower < kMeasuredPowerMin || measuredPower > kMeasuredPowerMax) {
    if (kDebugMode) {
      debugPrint(
          '[iBeacon] $deviceId — FAIL: MeasuredPower=$measuredPower dBm ngoài vùng hợp lệ [$kMeasuredPowerMin, $kMeasuredPowerMax]');
    }
    return null;
  }

  if (kDebugMode) {
    debugPrint(
        '[iBeacon] $deviceId — OK: uuid=$uuid major=$major minor=$minor measuredPower=$measuredPower rssi=${rssi}dBm');
  }

  return BeaconReading(
    uuid: uuid,
    major: major,
    minor: minor,
    rssi: rssi,
    measuredPower: measuredPower, // PHASE 2: calibration từ chính phần cứng
    timestamp: timestamp,
  );
}

String _bytesToUuidString(List<int> bytes) {
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
