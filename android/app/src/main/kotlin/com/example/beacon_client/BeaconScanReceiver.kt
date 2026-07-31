package com.example.beacon_client

import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanResult
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

/**
 * Đầu nhận của PendingIntent scan.
 *
 * VÌ SAO ĐI ĐƯỜNG NÀY THAY VÌ ScanCallback (RealBeaconScanner):
 * `BluetoothLeScanner.startScan(filters, settings, PendingIntent)` (API 26+)
 * đăng ký phiên quét cho HỆ THỐNG giữ, không phải cho tiến trình app giữ. Đó là
 * khác biệt CẤU TRÚC, không phải khác biệt tham số: `dumpsys` trên Redmi Note 12
 * đã cho thấy ba hình dạng filter và một vòng restart 15 giây đều thua, tất cả
 * đều là client kiểu callback. Đây là loại client khác trong stack.
 *
 * ⚠ CHƯA ĐƯỢC KIỂM CHỨNG trên máy có governor của HyperOS. Đây là hướng còn lại
 * đáng thử, không phải bản vá đã biết là chạy. Mặc định TẮT — bật bằng
 * `--dart-define=BLE_PENDING_INTENT=true`.
 */
class BeaconScanReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val errorCode = intent.getIntExtra(BluetoothLeScanner.EXTRA_ERROR_CODE, -1)
        if (errorCode != -1) {
            // Lỗi được giao qua CHÍNH kênh này, không qua giá trị trả về của
            // startScan — nên không log ở đây là mù hẳn khi hệ thống từ chối.
            Log.w(TAG, "PendingIntent scan lỗi: errorCode=$errorCode")
            BeaconScanBridge.emit(mapOf("error" to errorCode))
            return
        }

        val results = extractResults(intent)

        // Log CẢ đường thành công, không bọc BuildConfig.DEBUG. Bản đầu chỉ log
        // lúc lỗi, và hệ quả là lần test đầu tiên trên máy thật không kết luận
        // được gì: logcat im lặng có thể là "receiver không hề nổ" mà cũng có
        // thể là "nổ bình thường, không có gói nào" — hai chẩn đoán trái ngược,
        // cùng một dòng trống. Cơ chế này chỉ tồn tại để được đo, nên nó phải
        // tự nói được là mình có sống hay không.
        Log.i(TAG, "broadcast: ${results.size} kết quả thô")
        if (results.isEmpty()) return

        // elapsedRealtimeNanos của ScanResult đếm từ lúc BOOT, còn cả pipeline
        // (staleness/eviction/zoneSilence) đo tuổi gói bằng đồng hồ TƯỜNG. Quy
        // đổi qua mốc boot đọc MỘT lần cho cả lô: đọc lại giữa chừng sẽ cho hai
        // gói cùng lô lệch nhau vài ms mà không có lý do vật lý nào.
        val bootWallClockMs = System.currentTimeMillis() - SystemClock.elapsedRealtime()

        val payload = ArrayList<Map<String, Any?>>(results.size)
        for (r in results) {
            val record = r.scanRecord ?: continue
            val msd = record.manufacturerSpecificData
            if (msd == null || msd.size() == 0) continue

            // Chỉ chuyển qua channel phần Apple: guard UUID bảo tàng và toàn bộ
            // Strict Mode nằm ở Dart (ibeacon_parser), nên đây chỉ bóc vỏ.
            val appleData = msd.get(APPLE_COMPANY_ID) ?: continue

            payload.add(
                mapOf(
                    "id" to r.device.address,
                    "rssi" to r.rssi,
                    "tsMs" to bootWallClockMs + (r.timestampNanos / 1_000_000L),
                    "data" to appleData,
                )
            )
        }
        if (payload.isEmpty()) {
            Log.i(TAG, "  → 0 gói mang Apple MSD, bỏ lô")
            return
        }
        Log.i(TAG, "  → ${payload.size} gói Apple MSD đẩy sang Dart")

        BeaconScanBridge.emit(mapOf("results" to payload))
    }

    @Suppress("DEPRECATION")
    private fun extractResults(intent: Intent): List<ScanResult> {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(
                BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT, ScanResult::class.java
            ) ?: emptyList()
        } else {
            intent.getParcelableArrayListExtra<ScanResult>(
                BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT
            ) ?: emptyList()
        }
    }

    companion object {
        private const val TAG = "BeaconScanReceiver"

        /** Apple Inc. Bluetooth SIG company identifier — vỏ chứa iBeacon payload. */
        const val APPLE_COMPANY_ID = 0x004C
    }
}
