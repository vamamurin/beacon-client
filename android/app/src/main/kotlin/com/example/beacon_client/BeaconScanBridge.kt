package com.example.beacon_client

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Điểm hẹn giữa [BeaconScanReceiver] (chạy độc lập với Activity, có thể chạy
 * khi engine chưa gắn) và EventChannel bên Dart.
 *
 * VÌ SAO CẦN BỘ ĐỆM CHỨ KHÔNG BẮN THẲNG VÀO SINK:
 * điểm mấu chốt của PendingIntent scan là hệ thống giữ phiên quét hộ ta, nên
 * broadcast có thể tới lúc EventChannel CHƯA có listener — ngay sau khi tiến
 * trình được hệ thống dựng dậy, hoặc trong khoảng engine đang được gắn lại.
 * Bắn thẳng vào một sink null là mất gói im lặng, đúng loại lỗi mà cả nhánh
 * này sinh ra để chữa. Nên gói được xếp hàng và xả khi có listener.
 *
 * TRẦN [MAX_BUFFERED] là bắt buộc, không phải phòng xa: nếu Dart không bao giờ
 * lắng nghe (engine chết hẳn), hàng đợi này là rò rỉ bộ nhớ trong một tiến
 * trình mà cả tính năng chạy ngầm đang cố giữ sống. Vượt trần thì bỏ gói CŨ
 * NHẤT — dữ liệu proximity chỉ có giá trị khi còn tươi, gói 30 giây trước
 * không giúp được gì cho việc quyết định khách đang đứng ở khu nào.
 */
object BeaconScanBridge {

    private const val MAX_BUFFERED = 256

    private val main = Handler(Looper.getMainLooper())
    private val buffered = ArrayDeque<Map<String, Any?>>()

    @Volatile
    private var sink: EventChannel.EventSink? = null

    /** Gắn sink từ isolate chính và xả ngay những gì đã xếp hàng. */
    fun attach(newSink: EventChannel.EventSink?) {
        main.post {
            sink = newSink
            if (newSink == null) return@post
            while (buffered.isNotEmpty()) {
                newSink.success(buffered.removeFirst())
            }
        }
    }

    /**
     * Nhận một lô kết quả từ receiver. Gọi được từ bất kỳ thread nào — mọi thứ
     * được đẩy về main looper, vì EventSink KHÔNG an toàn đa luồng.
     */
    fun emit(batch: Map<String, Any?>) {
        main.post {
            val s = sink
            if (s != null) {
                s.success(batch)
                return@post
            }
            if (buffered.size >= MAX_BUFFERED) buffered.removeFirst()
            buffered.addLast(batch)
        }
    }

    /** Xoá hàng đợi khi dừng quét, để phiên sau không thấy gói của phiên trước. */
    fun clearBuffer() {
        main.post { buffered.clear() }
    }
}
