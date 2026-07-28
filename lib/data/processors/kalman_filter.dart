import 'package:flutter/foundation.dart';

/// Bộ lọc Kalman 1 chiều (1D Kalman Filter) chuyên dụng cho sóng RSSI (BLE)
///
/// Thay vì chỉ tính trung bình, bộ lọc này tự động điều chỉnh độ tin cậy
/// dựa trên độ nhiễu thực tế của môi trường.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// BỘ LỌC NHẬN THỨC THỜI GIAN — vì sao [update] cần [elapsed]
///
/// Bản trước cộng [processNoise] vào hiệp phương sai MỖI LẦN GỌI, không phải
/// mỗi đơn vị thời gian. Nghe thì vô hại, nhưng nó khiến độ nhạy của bộ lọc phụ
/// thuộc vào TỐC ĐỘ GÓI TIN — thứ hoàn toàn không nằm trong tay app.
///
/// Với Q = 0.008 và R = 4.0, hiệp phương sai hội tụ về nghiệm của
///   P² − QP − QR = 0  ⇒  P ≈ 0.183  ⇒  K = P/(P+R) ≈ 0.044
/// tức một EWMA có hằng số thời gian ~23 MẪU. Ở 10 Hz (chu kỳ quảng bá iBeacon
/// tiêu chuẩn 100 ms) đó là ~2,3 giây: đúng như mong muốn. Nhưng Android gộp và
/// giảm nhịp scan callback khi Doze, khi màn tắt, và sau ngưỡng quét liên tục
/// 30 phút. Ở 1 Hz, CÙNG bộ lọc đó có hằng số thời gian ~23 GIÂY — và toàn bộ
/// cổng engage/release theo mét ở ZoneArbiter được xây trên ước lượng này.
///
/// Hậu quả thực địa: cùng một bản build, cùng một bảo tàng, nhưng độ trễ nhận
/// khu thay đổi theo thiết bị, theo trạng thái nguồn, theo thời gian đã quét.
/// Không test đơn vị nào bắt được, vì bộ lọc cũ không hề biết thời gian tồn tại.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// TƯƠNG THÍCH NGƯỢC — vì sao chia cho [nominalInterval] thay vì đổi Q sang /giây
///
/// [processNoise] được SHIP TRONG MANIFEST (`kalmanProcessNoise`) và đã được
/// hiệu chỉnh tại hiện trường theo ngữ nghĩa "mỗi lần cập nhật". Diễn giải lại
/// nó thành "mỗi giây" sẽ âm thầm làm mọi bundle đang chạy chậm đi ~10 lần.
///
/// Nên đơn vị của Q GIỮ NGUYÊN, và thời gian được quy về số nhịp danh định:
///   P += Q · (elapsed / nominalInterval)
/// Ở đúng 10 Hz, tỉ số bằng 1 và hành vi TRÙNG KHÍT bản cũ — mọi giá trị đã
/// hiệu chỉnh vẫn đúng. Lệch khỏi 10 Hz thì bộ lọc tự bù, thay vì trôi.
class KalmanFilter {
  // Q: Nhiễu hệ thống (Process Noise). Tốc độ người dùng đi bộ thực tế.
  // Đặt thấp (vd 0.008) vì người dùng đi trong bảo tàng khá chậm.
  //
  // ĐƠN VỊ: mỗi [nominalInterval] (KHÔNG phải mỗi giây) — xem ghi chú tương
  // thích ngược ở đầu lớp trước khi tinh chỉnh giá trị này.
  final double processNoise;

  // R: Nhiễu đo lường (Measurement Noise). Sóng Bluetooth dởm đến mức nào?
  // Đặt cao (vd 4.0 -> 8.0) vì sóng BLE indoor nhảy loạn xạ.
  final double measurementNoise;

  /// Chu kỳ quảng bá iBeacon mà [processNoise] được hiệu chỉnh theo. Đây là
  /// MẪU SỐ QUY ĐỔI, không phải một giả định về tốc độ gói thật: bộ lọc đo
  /// khoảng cách thật giữa hai gói và quy về bội số của hằng số này.
  final Duration nominalInterval;

  /// Trần cho một bước thời gian. Beacon im lâu rồi phát lại thì tin vào phép
  /// đo mới là ĐÚNG (K → 1 tương đương một lần reset mềm), nhưng vẫn cần chặn
  /// trên để hiệp phương sai không phình theo một mốc thời gian rác (đồng hồ
  /// nhảy, gói lỗi thứ tự). 12 s khớp ngưỡng eviction của registry — quá đó thì
  /// tracker đã bị thu hồi và một bộ lọc mới được dựng.
  static const Duration maxStep = Duration(seconds: 12);

  double? _estimatedRssi; // x: Vị trí (RSSI) ước tính hiện tại
  double _errorCovariance; // P: Sai số ước tính

  KalmanFilter({
    this.processNoise = 0.008,
    this.measurementNoise = 4.0,
    this.nominalInterval = const Duration(milliseconds: 100),
  }) : _errorCovariance = 1.0;

  /// Nạp một phép đo. [elapsed] là thời gian THẬT trôi qua kể từ phép đo trước
  /// của CHÍNH beacon này (lấy từ timestamp của gói tin, không phải giờ lúc
  /// parse). Bỏ trống ⇒ coi như đúng một nhịp danh định.
  double update(double measurement, {Duration? elapsed}) {
    if (_estimatedRssi == null) {
      _estimatedRssi = measurement;
      return _estimatedRssi!;
    }

    // --- BƯỚC 1: DỰ ĐOÁN (PREDICT) ---
    // Vì người dùng đi bộ không bay nhảy dịch chuyển tức thời,
    // ta đoán RSSI tiếp theo bằng RSSI hiện tại.
    double predictedRssi = _estimatedRssi!;

    // Sai số dự đoán tăng lên do nhiễu hệ thống — TỈ LỆ VỚI THỜI GIAN TRÔI QUA.
    // Gói tới dồn dập ⇒ độ bất định tăng ít giữa hai gói; gói thưa ⇒ tăng
    // nhiều, nên phép đo kế tiếp được tin hơn. Đó chính là điều bản cũ bỏ sót.
    _errorCovariance += processNoise * _steps(elapsed);

    // --- BƯỚC 2: CẬP NHẬT (UPDATE) ---
    // Tính Hệ số Kalman (Kalman Gain) - Trái tim của thuật toán
    double kalmanGain = _errorCovariance / (_errorCovariance + measurementNoise);

    // Cập nhật lại RSSI ước tính dựa trên độ tin cậy
    _estimatedRssi = predictedRssi + kalmanGain * (measurement - predictedRssi);

    // Cập nhật lại sai số cho chu kỳ tiếp theo
    _errorCovariance = (1.0 - kalmanGain) * _errorCovariance;

    return _estimatedRssi!;
  }

  /// [elapsed] quy về số nhịp danh định, đã chặn hai đầu.
  ///
  /// Âm (gói tới sai thứ tự, đồng hồ hệ thống lùi) ⇒ 0: thời gian không chạy
  /// ngược, và một P âm sẽ làm hỏng bộ lọc vĩnh viễn.
  /// Null ⇒ 1 nhịp, giữ nguyên hành vi cho mọi call site chưa truyền thời gian.
  double _steps(Duration? elapsed) {
    if (elapsed == null) return 1.0;
    if (elapsed <= Duration.zero) return 0.0;
    final capped = elapsed > maxStep ? maxStep : elapsed;
    return capped.inMicroseconds / nominalInterval.inMicroseconds;
  }

  void reset() {
    _estimatedRssi = null;
    _errorCovariance = 1.0;
  }

  bool get hasData => _estimatedRssi != null;

  /// Hiệp phương sai hiện tại (P). Chỉ để test khẳng định được rằng độ bất định
  /// thực sự lớn lên theo thời gian im lặng.
  @visibleForTesting
  double get errorCovariance => _errorCovariance;
}
