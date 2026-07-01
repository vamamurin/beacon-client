/// Bộ lọc Kalman 1 chiều (1D Kalman Filter) chuyên dụng cho sóng RSSI (BLE)
/// 
/// Thay vì chỉ tính trung bình, bộ lọc này tự động điều chỉnh độ tin cậy
/// dựa trên độ nhiễu thực tế của môi trường.
class KalmanFilter {
  // Q: Nhiễu hệ thống (Process Noise). Tốc độ người dùng đi bộ thực tế.
  // Đặt thấp (vd 0.008) vì người dùng đi trong bảo tàng khá chậm.
  final double processNoise; 

  // R: Nhiễu đo lường (Measurement Noise). Sóng Bluetooth dởm đến mức nào?
  // Đặt cao (vd 4.0 -> 8.0) vì sóng BLE indoor nhảy loạn xạ.
  final double measurementNoise; 

  double? _estimatedRssi; // x: Vị trí (RSSI) ước tính hiện tại
  double _errorCovariance; // P: Sai số ước tính

  KalmanFilter({
    this.processNoise = 0.008, 
    this.measurementNoise = 4.0,
  }) : _errorCovariance = 1.0;

  double update(double measurement) {
    if (_estimatedRssi == null) {
      _estimatedRssi = measurement;
      return _estimatedRssi!;
    }

    // --- BƯỚC 1: DỰ ĐOÁN (PREDICT) ---
    // Vì người dùng đi bộ không bay nhảy dịch chuyển tức thời, 
    // ta đoán RSSI tiếp theo bằng RSSI hiện tại.
    double predictedRssi = _estimatedRssi!;
    // Sai số dự đoán tăng lên do nhiễu hệ thống
    _errorCovariance = _errorCovariance + processNoise; 

    // --- BƯỚC 2: CẬP NHẬT (UPDATE) ---
    // Tính Hệ số Kalman (Kalman Gain) - Trái tim của thuật toán
    double kalmanGain = _errorCovariance / (_errorCovariance + measurementNoise);

    // Cập nhật lại RSSI ước tính dựa trên độ tin cậy
    _estimatedRssi = predictedRssi + kalmanGain * (measurement - predictedRssi);

    // Cập nhật lại sai số cho chu kỳ tiếp theo
    _errorCovariance = (1.0 - kalmanGain) * _errorCovariance;

    return _estimatedRssi!;
  }

  void reset() {
    _estimatedRssi = null;
    _errorCovariance = 1.0;
  }

  bool get hasData => _estimatedRssi != null;
}