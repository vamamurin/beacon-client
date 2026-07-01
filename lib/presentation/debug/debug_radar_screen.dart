import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:beacon_client/domain/models/beacon_reading.dart';

class DebugRadarScreen extends StatefulWidget {
  const DebugRadarScreen({super.key});

  @override
  State<DebugRadarScreen> createState() => _DebugRadarScreenState();
}

class _DebugRadarScreenState extends State<DebugRadarScreen> {
  StreamSubscription<List<ScanResult>>? _sub;
  Timer? _uiTimer;
  final Map<String, _DeviceEntry> _devices = {};

  // PHASE 2 ALIGN: cùng cửa sổ Measured Power hợp lệ với RealBeaconScanner để
  // màn debug phản ánh ĐÚNG luật validate của production (không còn lệch chuẩn).
  static const int _kMeasuredPowerMin = -100;
  static const int _kMeasuredPowerMax = -20;

  @override
  void initState() {
    super.initState();
    _startScan();
    // Render UI tối đa 2 lần/giây thay vì mỗi lần có kết quả BLE.
    // lowLatency+continuousUpdates có thể trả kết quả hàng chục lần/giây,
    // gọi setState() mỗi lần sẽ queue đầy UI thread → ANR.
    _uiTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _startScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    await FlutterBluePlus.startScan(
      continuousUpdates: true,
      androidScanMode: AndroidScanMode.lowLatency,
    );
    _sub = FlutterBluePlus.scanResults.listen(_onResults);
  }

  void _onResults(List<ScanResult> results) {
    // Chỉ cập nhật data map, KHÔNG gọi setState.
    // UI timer định kỳ 500ms mới trigger rebuild.
    for (final r in results) {
      final (beacon, failReason) = _parseIBeaconWithReason(r);
      _devices[r.device.remoteId.str] =
          _DeviceEntry(result: r, beacon: beacon, failReason: failReason);
    }
  }

  /// Parse iBeacon và trả về lý do fail chi tiết nếu không thành công.
  /// failReason = null nếu thiết bị hoàn toàn không có manufacturer data (không phải iBeacon candidate).
  ///
  /// PHASE 2 ALIGN: áp dụng đúng Strict Mode của RealBeaconScanner
  /// (length ≥23 + toSigned(8) + window [-100, -20]). Gói thiếu byte 23 hoặc
  /// có Measured Power rác giờ hiện FAIL kèm lý do, thay vì "OK" gây hiểu nhầm.
  (BeaconReading?, String?) _parseIBeaconWithReason(ScanResult r) {
    final mfg = r.advertisementData.manufacturerData;
    if (mfg.isEmpty) return (null, null);

    final appleData = mfg[0x004C];
    if (appleData == null) {
      final ids = mfg.keys
          .map((k) => '0x${k.toRadixString(16).padLeft(4, '0').toUpperCase()}')
          .join(', ');
      return (null, 'No Apple ID. Found: $ids');
    }

    // PHASE 2 ALIGN: ≥23 byte (was ≥22) để đọc Measured Power ở index 22.
    if (appleData.length < 23) {
      return (
        null,
        'Apple data too short: ${appleData.length}b (need ≥23 for Measured Power)'
      );
    }
    if (appleData[0] != 0x02) {
      return (null, 'byte[0]=0x${appleData[0].toRadixString(16).toUpperCase()} ≠ 0x02');
    }
    if (appleData[1] != 0x15) {
      return (null, 'byte[1]=0x${appleData[1].toRadixString(16).toUpperCase()} ≠ 0x15');
    }

    final h = Uint8List.fromList(appleData.sublist(2, 18))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final uuid = '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    final major = (appleData[18] << 8) | appleData[19];
    final minor = (appleData[20] << 8) | appleData[21];

    // PHASE 2 ALIGN: byte 23 (index 22), ép dấu int8 two's complement (0xC5 → -59).
    final measuredPower = appleData[22].toSigned(8);

    // PHASE 2 ALIGN: validate cửa sổ giá trị; ngoài [-100, -20] dBm → FAIL.
    if (measuredPower < _kMeasuredPowerMin ||
        measuredPower > _kMeasuredPowerMax) {
      return (
        null,
        'MeasuredPower=$measuredPower dBm out of range [$_kMeasuredPowerMin, $_kMeasuredPowerMax]'
      );
    }

    return (
      BeaconReading(
        uuid: uuid,
        major: major,
        minor: minor,
        rssi: r.rssi,
        // PHASE 2 ALIGN: bơm giá trị thật đã parse, bỏ placeholder -59.
        measuredPower: measuredPower,
        timestamp: DateTime.now(),
      ),
      null,
    );
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _sub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _clear() => setState(() => _devices.clear());

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return Colors.greenAccent;
    if (rssi >= -80) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _devices.values.toList()
      ..sort((a, b) => b.result.rssi.compareTo(a.result.rssi));

    final beaconCount = sorted.where((e) => e.beacon != null).length;
    final failCount =
        sorted.where((e) => e.beacon == null && e.failReason != null).length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        title: Text(
          'RADAR DEBUG  •  ${sorted.length} dev  •  $beaconCount iBeacon  •  $failCount fail',
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear',
            onPressed: _clear,
          ),
        ],
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00FF41)),
                  SizedBox(height: 16),
                  Text(
                    'Scanning...',
                    style: TextStyle(color: Color(0xFF00FF41), fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, i) =>
                  _DeviceCard(entry: sorted[i], rssiColor: _rssiColor),
            ),
    );
  }
}

// ─── Data model ────────────────────────────────────────────────────────────────

class _DeviceEntry {
  final ScanResult result;
  final BeaconReading? beacon;

  /// Non-null only if device has Apple manufacturer data but failed iBeacon parse.
  final String? failReason;

  const _DeviceEntry({
    required this.result,
    this.beacon,
    this.failReason,
  });
}

// ─── Row widget ────────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final _DeviceEntry entry;
  final Color Function(int) rssiColor;

  const _DeviceCard({required this.entry, required this.rssiColor});

  @override
  Widget build(BuildContext context) {
    final r = entry.result;
    final beacon = entry.beacon;
    final isBeacon = beacon != null;
    final hasFail = entry.failReason != null;

    final displayName = r.advertisementData.advName.isNotEmpty
        ? r.advertisementData.advName
        : r.device.remoteId.str;

    return Card(
      color: isBeacon
          ? const Color(0xFF0D2B0D)
          : hasFail
              ? const Color(0xFF2B1A00)
              : const Color(0xFF181818),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──
                  Row(
                    children: [
                      if (isBeacon) _tag('iBEACON', Colors.green),
                      if (hasFail) _tag('FAIL', Colors.orange),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isBeacon ? beacon.uuid : displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: isBeacon
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isBeacon
                                ? const Color(0xFF00FF41)
                                : hasFail
                                    ? Colors.orange
                                    : Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // ── Detail row ──
                  if (isBeacon)
                    Text(
                      'Major: ${beacon.major}   Minor: ${beacon.minor}   MP: ${beacon.measuredPower}dBm',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    )
                  else if (hasFail)
                    Text(
                      entry.failReason!,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    )
                  else
                    Text(
                      r.device.remoteId.str,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 10),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${r.rssi} dBm',
              style: TextStyle(
                color: rssiColor(r.rssi),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold),
        ),
      );
}