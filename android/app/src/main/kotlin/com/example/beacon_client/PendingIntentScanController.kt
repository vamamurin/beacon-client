package com.example.beacon_client

import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bật/tắt phiên quét kiểu PendingIntent và nối kết quả về Dart.
 *
 * Xem [BeaconScanReceiver] để biết vì sao chọn cơ chế này.
 */
class PendingIntentScanController(context: Context, messenger: BinaryMessenger) {

    private val app = context.applicationContext

    private val methodChannel =
        MethodChannel(messenger, "beacon_client/pending_scan").apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            start(
                                scanModeName = call.argument<String>("scanMode") ?: "lowLatency",
                                useFilter = call.argument<Boolean>("useFilter") ?: true,
                                companyId = call.argument<Int>("companyId")
                                    ?: BeaconScanReceiver.APPLE_COMPANY_ID,
                                reportDelayMillis =
                                    (call.argument<Number>("reportDelayMillis") ?: 0).toLong(),
                            )
                            result.success(true)
                        }
                        "stop" -> {
                            stop()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: SecurityException) {
                    // Thiếu BLUETOOTH_SCAN. Trả lỗi có mã để Dart fallback sang
                    // RealBeaconScanner thay vì tour chạy câm.
                    result.error("permission", e.message, null)
                } catch (e: Exception) {
                    result.error("start_failed", e.message, null)
                }
            }
        }

    private val eventChannel =
        EventChannel(messenger, "beacon_client/pending_scan_events").apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    BeaconScanBridge.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    BeaconScanBridge.attach(null)
                }
            })
        }

    private fun scanner() = (app.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)
        ?.adapter
        ?.takeIf { it.isEnabled }
        ?.bluetoothLeScanner

    /**
     * PendingIntent phải BẰNG NHAU giữa lúc start và lúc stop thì
     * `stopScan(PendingIntent)` mới huỷ đúng phiên. Đẳng thức của PendingIntent
     * xét trên requestCode + Intent (component/action/data), KHÔNG xét extras và
     * KHÔNG xét flags — nên dựng lại y hệt ở cả hai đầu là đủ, không cần giữ
     * tham chiếu qua vòng đời tiến trình (mà cũng không giữ được: cả điểm của
     * cơ chế này là tiến trình có thể đã chết giữa chừng).
     */
    private fun pendingIntent(): PendingIntent {
        val intent = Intent(app, BeaconScanReceiver::class.java)
            .setAction(ACTION_SCAN_RESULT)

        // FLAG_MUTABLE là BẮT BUỘC từ API 31: hệ thống phải ghi được
        // EXTRA_LIST_SCAN_RESULT vào intent. Dùng FLAG_IMMUTABLE ở đây là phiên
        // quét chạy mà không bao giờ giao kết quả — hỏng câm, không có lỗi nào.
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE

        return PendingIntent.getBroadcast(app, REQUEST_CODE, intent, flags)
    }

    private fun start(
        scanModeName: String,
        useFilter: Boolean,
        companyId: Int,
        reportDelayMillis: Long,
    ) {
        val le = scanner() ?: throw IllegalStateException("Bluetooth chưa bật")

        // Dừng phiên cũ trước: startScan hai lần với PendingIntent BẰNG NHAU sẽ
        // thay thế phiên cũ trên hầu hết ROM, nhưng "hầu hết" không phải hợp
        // đồng — dừng tường minh cho tất định.
        runCatching { le.stopScan(pendingIntent()) }
        BeaconScanBridge.clearBuffer()

        // Gọi tường minh từng dòng thay vì nối chuỗi: bản Kotlin ở đây không suy
        // luận được kiểu qua chuỗi builder này, và dạng tường minh cũng dễ đọc
        // hơn khi mỗi tham số đều là một cần gạt đang được đối chứng.
        val builder = ScanSettings.Builder()
        builder.setScanMode(toScanMode(scanModeName))
        builder.setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
        // reportDelay > 0 = quét theo LÔ, do controller gom rồi trả một lần.
        // Đây là cần gạt THỨ HAI của file này: batch scan đi nhánh mBatchClients
        // trong stack, khác nhánh regular scan — cần thử nếu riêng PendingIntent
        // vẫn thua governor. Mặc định 0 = như thường.
        // Setter tên `setReportDelay`, getter tên `getReportDelayMillis` — bất
        // đối xứng có thật trong API, không phải nhầm.
        builder.setReportDelay(reportDelayMillis)
        if (Build.VERSION.SDK_INT >= 26) {
            // iBeacon là quảng bá LEGACY. Để setLegacy(false) là loại sạch
            // beacon khỏi kết quả.
            builder.setLegacy(true)
            builder.setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
        }
        val settings = builder.build()

        val filters = if (!useFilter) {
            emptyList()
        } else {
            listOf(
                ScanFilter.Builder()
                    .setManufacturerData(
                        companyId,
                        byteArrayOf(0x02, 0x15),      // prefix iBeacon
                        byteArrayOf(0xFF.toByte(), 0xFF.toByte()),
                    )
                    .build()
            )
        }

        le.startScan(filters, settings, pendingIntent())
        Log.i(
            TAG,
            "PendingIntent scan bật: mode=$scanModeName filter=$useFilter " +
                "reportDelay=${reportDelayMillis}ms"
        )
    }

    /**
     * Huỷ phiên quét. Public vì [MainActivity] PHẢI gọi được lúc khách vuốt tắt:
     * phiên quét này do hệ thống giữ nên nó SỐNG QUA cái chết của tiến trình —
     * không huỷ là để lại một đường đánh thức app sau khi tour đã kết thúc.
     */
    fun stop() {
        BeaconScanBridge.clearBuffer()
        val le = scanner() ?: return
        runCatching { le.stopScan(pendingIntent()) }
            .onFailure { Log.w(TAG, "stopScan thất bại: ${it.message}") }
        // Huỷ luôn PendingIntent: để lại một cái sống là để lại đường cho hệ
        // thống đánh thức tiến trình sau khi tour đã kết thúc.
        runCatching { pendingIntent().cancel() }
        Log.i(TAG, "PendingIntent scan tắt")
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        BeaconScanBridge.attach(null)
    }

    private fun toScanMode(name: String): Int = when (name) {
        "lowPower" -> ScanSettings.SCAN_MODE_LOW_POWER
        "balanced" -> ScanSettings.SCAN_MODE_BALANCED
        "opportunistic" -> ScanSettings.SCAN_MODE_OPPORTUNISTIC
        else -> ScanSettings.SCAN_MODE_LOW_LATENCY
    }

    private companion object {
        const val TAG = "PendingIntentScan"

        /** Bất kỳ, chỉ cần ổn định — nó tham gia vào đẳng thức PendingIntent. */
        const val REQUEST_CODE = 4718

        const val ACTION_SCAN_RESULT = "com.example.beacon_client.SCAN_RESULT"
    }
}
