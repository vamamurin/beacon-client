// Destination: test/presentation/app/tour_navigation_target_test.dart
//
// Ánh xạ phase → route.
//
// Điều file này thật sự canh giữ là một RÀNG BUỘC KIẾN TRÚC, không phải một
// bảng tra: bộ định tuyến không được có trạng thái của riêng nó. Mọi sự thật về
// vòng đời phiên — kể cả "khách chủ động kết thúc" — phải tới từ
// [SessionPhase]. Chữ ký của [tourNavigationTarget] là chỗ ràng buộc đó lộ ra:
// thêm được một tham số nào khác vào đây nghĩa là bộ định tuyến vừa mọc thêm
// một máy trạng thái thứ hai chạy song song với SessionController.

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/presentation/app/app.dart';
import 'package:beacon_client/presentation/app/app_router.dart';

String? target(SessionPhase? prev, SessionPhase next) =>
    tourNavigationTarget(prev: prev, next: next);

void main() {
  test('vào tour ⇒ màn khu vực', () {
    expect(target(SessionPhase.gate, SessionPhase.touring), AppRouter.zoneRoute);
  });

  group('kết thúc TỰ ĐỘNG (sạc / về bàn / im lặng / nút trên notification)', () {
    // `ending` bị `atDesk` thay thế trong cùng một lần gọi đồng bộ nên không
    // frame nào được bơm; điều hướng ở cạnh đó chỉ tốn một lần dựng lại stack.
    test('touring → ending KHÔNG điều hướng', () {
      expect(target(SessionPhase.touring, SessionPhase.ending), isNull);
    });

    test('ending → atDesk về màn nghỉ', () {
      expect(target(SessionPhase.ending, SessionPhase.atDesk),
          AppRouter.restRoute);
    });
  });

  group('kết thúc do KHÁCH xác nhận ở màn tổng kết', () {
    test('touring → farewell mở màn Cảm ơn', () {
      expect(target(SessionPhase.touring, SessionPhase.farewell),
          AppRouter.farewellRoute);
    });

    // Ba đường rời màn Cảm ơn (hết giờ giữ / bấm "Xong" / máy lên dock) đều là
    // cùng một bước phase, nên chỉ có một nhánh phải đúng.
    test('farewell → atDesk về màn nghỉ', () {
      expect(target(SessionPhase.farewell, SessionPhase.atDesk),
          AppRouter.restRoute);
    });

    test('cả chuỗi điều hướng đúng hai lần, đúng thứ tự', () {
      const steps = <SessionPhase>[
        SessionPhase.touring,
        SessionPhase.farewell,
        SessionPhase.atDesk,
      ];
      expect(
        [for (var i = 1; i < steps.length; i++) target(steps[i - 1], steps[i])],
        [AppRouter.farewellRoute, AppRouter.restRoute],
      );
    });
  });

  group('máy về dock / khách kế tiếp rút máy', () {
    test('gate → atDesk (cắm lại lúc đang ở Menu) về màn nghỉ', () {
      expect(
          target(SessionPhase.gate, SessionPhase.atDesk), AppRouter.restRoute);
    });

    test('atDesk → gate (khách kế tiếp rút máy) về màn nghỉ', () {
      expect(
          target(SessionPhase.atDesk, SessionPhase.gate), AppRouter.restRoute);
    });
  });

  group('không phải chuyển động', () {
    test('quan sát đầu tiên không điều hướng — initialRoute lo', () {
      for (final p in SessionPhase.values) {
        expect(target(null, p), isNull, reason: 'với $p');
      }
    });

    test('phase không đổi không điều hướng', () {
      for (final p in SessionPhase.values) {
        expect(target(p, p), isNull, reason: 'với $p');
      }
    });
  });

  // Canh chừng chính vòng lặp trên: thêm một phase mới mà quên xử lý ở
  // tourNavigationTarget sẽ bị `switch` vét cạn của Dart bắt lúc biên dịch,
  // nhưng một phase mới trả về giá trị VÔ NGHĨA thì không. Đây là lưới thứ hai.
  test('mọi phase đều có đích đến xác định khi tới từ atDesk', () {
    for (final p in SessionPhase.values) {
      if (p == SessionPhase.atDesk) continue;
      final t = target(SessionPhase.atDesk, p);
      expect(
        t,
        anyOf(isNull, isIn(const [
          AppRouter.zoneRoute,
          AppRouter.farewellRoute,
          AppRouter.restRoute,
        ])),
        reason: 'phase $p trả về route lạ: $t',
      );
    }
  });
}
