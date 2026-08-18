// Destination: lib/main_spike.dart
//
// ⚠ ENTRYPOINT CỦA SPIKE M0 — KHÔNG PHẢI BẢN GIAO CHO KHÁCH.
//
//     flutter run -t lib/main_spike.dart --profile
//
// Chạy y hệt app thật — cùng `main()`, cùng foreground service, cùng BLE, cùng
// tour — rồi ĐĂNG KÝ THÊM màn Model Lab. Nhờ vậy phép đo diễn ra trong đúng
// hoàn cảnh cần đo: một chuyến tham quan đang chạy thật, không phải một app
// rỗng chỉ có mỗi khối 3D.
//
// ─────────────────────────────────────────────────────────────────────────────
// VÌ SAO PHẢI LÀ MỘT ENTRYPOINT RIÊNG
//
// `flutter_scene` dựa trên `flutter_gpu`, một thư viện do ENGINE cung cấp và
// KHÔNG tồn tại trong môi trường `flutter test`. Chỉ cần một file trong đồ thị
// import của app chạm tới nó là **toàn bộ widget test** hết biên dịch được:
//
//     ../flutter_scene-0.20.0/lib/src/geometry/geometry.dart:157:7:
//     Error: Type 'gpu.VertexFormat' not found.
//
// Đã xảy ra thật: ba test đỏ cùng lúc chỉ vì `app_router.dart` import màn Lab.
// Đây là một CHI PHÍ CÓ THẬT của `flutter_scene` và nó được ghi vào
// docs/M0-baseline.md, không phải một trở ngại vặt cần lách cho xong.
//
// Cách ly bằng entrypoint giữ được cả hai: đồ thị của `lib/main.dart` không bao
// giờ biết tới `flutter_scene`, nên 289 test vẫn xanh; còn bản đo thì có đủ mọi
// thứ nó cần.
//
// KHI M0 KẾT THÚC, xoá đúng bốn thứ và không còn dấu vết nào:
//   1. file này
//   2. lib/presentation/debug/model_lab_screen.dart
//   3. hai dependency `model_viewer_plus` + `flutter_scene` trong pubspec
//   4. khối loopback trong android/.../network_security_config.xml
// (`AppRouter.extraRoutes` và `ModelStore` Ở LẠI — chúng là hạ tầng thật.)

import 'package:beacon_client/main.dart' as app;
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/debug/model_lab_screen.dart';

Future<void> main() {
  // Phải đặt TRƯỚC app.main(): màn Cài đặt hỏi map này lúc dựng để quyết định
  // có hiện hàng "Model Lab" hay không, và bảng route tra nó khi điều hướng.
  AppRouter.extraRoutes = {
    AppRouter.modelLabRoute: (_) => const ModelLabScreen(),
  };
  return app.main();
}
