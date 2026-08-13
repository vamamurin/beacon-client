// Destination: lib/presentation/app/shell_controller.dart
//
// TAY CẦM ĐỂ NGƯỜI NGOÀI ĐIỀU KHIỂN SHELL — và cách nó tránh một cái bẫy.
//
// ═══════════════════════════════════════════════════════════════════════════
// VÌ SAO KHÔNG PHẢI MỘT TÚI ĐỰNG GlobalKey<NavigatorState>
// ═══════════════════════════════════════════════════════════════════════════
//
// Cách hiển nhiên là để controller giữ năm `GlobalKey<NavigatorState>` rồi ai
// cần thì `key.currentState!.pushNamed(...)`. Cách đó HỎNG ở đúng chỗ shell
// này bị dựng lại: `_syncNavigation` gọi `pushNamedAndRemoveUntil(shellRoute)`
// mỗi lần phase đổi, nên trong MỘT frame có thể tồn tại cùng lúc shell cũ (đang
// bị gỡ) và shell mới (đang gắn). Hai cây cùng mang một GlobalKey ⇒ Flutter ném
// "Duplicate GlobalKey detected in widget tree" và cả app trắng màn.
//
// Nên các key nằm trong `State` của shell — nơi chúng sinh ra và chết cùng cây —
// còn controller chỉ giữ một CON TRỎ HÀM tới shell đang sống. Shell tự đăng ký
// lúc mount và tự rút lúc unmount.
//
// Hệ quả cần biết: mọi lệnh ở đây là NO-OP KHI KHÔNG CÓ SHELL NÀO ĐANG SỐNG
// (khách đang ở màn Cài đặt toàn màn hình, hoặc app vừa khởi động). Đó là hành
// vi đúng — một lệnh điều hướng gửi tới một cái khung không tồn tại thì không
// có gì để làm — nhưng nó nghĩa là ĐỪNG dùng chỗ này cho việc phải chắc chắn
// xảy ra. Việc phải chắc chắn xảy ra thì thuộc về máy trạng thái phiên.

import 'package:flutter/foundation.dart';

import 'package:beacon_client/presentation/theme/tab_icons.dart' show ShellTab;

/// Những gì shell làm được khi có người ngoài yêu cầu. Shell's State cài đặt.
abstract interface class ShellCommands {
  void selectTab(ShellTab tab);

  /// Khách đã XÁC NHẬN chuyển sang khu khác (banner "Chuyển"). Đưa họ tới danh
  /// sách hiện vật của khu mới — nhưng CHỈ KHI họ đang ở sâu trong tab Tham
  /// quan.
  ///
  /// Ở màn khu vực (gốc của tab đó) thì KHÔNG làm gì: `ZoneProvider` đã phản
  /// ánh khu mới ngay tại chỗ, và kéo khách đi tiếp một bước họ không yêu cầu
  /// là hành vi thù địch. Điều kiện này trước đây được kiểm bằng cách so tên
  /// route trên navigator gốc; giờ nó là câu hỏi về ngăn xếp của một tab, nên
  /// nó thuộc về shell.
  void followZoneChange(int major);

  void openDrawer();
  void closeDrawer();
}

class ShellController extends ChangeNotifier {
  ShellCommands? _target;

  bool get hasShell => _target != null;

  /// Shell gọi lúc mount.
  void attach(ShellCommands target) {
    _target = target;
    notifyListeners();
  }

  /// Shell gọi lúc unmount. So sánh `identical` để một shell CŨ đang bị gỡ
  /// không xoá mất đăng ký của shell MỚI vừa gắn — thứ tự attach/detach giữa
  /// hai cây không được đảm bảo trong một frame dựng lại.
  void detach(ShellCommands target) {
    if (identical(_target, target)) {
      _target = null;
      notifyListeners();
    }
  }

  void selectTab(ShellTab tab) => _target?.selectTab(tab);
  void followZoneChange(int major) => _target?.followZoneChange(major);
  void openDrawer() => _target?.openDrawer();
  void closeDrawer() => _target?.closeDrawer();
}

/// CHIỀU CAO CỦA VỎ MÁY Ở ĐÁY MÀN — hai con số, và chúng ăn vào mọi màn.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO CHÚNG PHẢI ĐƯỢC CHỐT TRƯỚC KHI DỰNG THÊM MÀN NÀO
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Ghi chú thiết kế của màn chi tiết hiện vật nói thẳng: thanh "đang phát" cộng
/// tab bar ăn ~134dp đáy của MỌI màn, *"nên phải chốt trước khi dựng thêm màn
/// mới nào"*. Dựng mười màn rồi mới thêm thanh này là phải đo lại cả mười.
///
/// ĐÃ CHỐT: thanh "đang phát" CHỈ HIỆN KHI CÓ TIẾNG. Nên đáy không phải một
/// hằng số mà là một HÀM của trạng thái audio:
///
///     im       70dp   (tab bar)
///     có tiếng 134dp  (tab bar + thanh đang phát)
///
/// Đổi lại: nội dung dịch lên 64dp đúng lúc tiếng bắt đầu. Chấp nhận được vì
/// nó xảy ra khi khách vừa bước vào một khu — họ đang nhìn quanh phòng, không
/// nhìn màn — và vì hai màn không bao giờ có tiếng (Hướng dẫn, Tổng kết) không
/// phải hy sinh 64dp vĩnh viễn cho một thanh không bao giờ hiện.
///
/// ⚠ SHELL TỰ ÁP KHOẢNG NÀY QUA `MediaQuery.padding.bottom`, nên màn nào đã
/// dùng `SafeArea` là tự tránh được tab bar, KHÔNG cần sửa gì. Chỉ những màn
/// tự tính padding đáy (danh sách cuộn có `EdgeInsets` cứng) mới phải đọc thẳng
/// hai hằng dưới đây.
abstract final class ShellInsets {
  /// Tab bar. Bằng `--tabbar-h` của bản vẽ.
  static const double tabBar = 70;

  /// Thanh "đang phát". CHƯA CÓ NỘI DUNG — Đợt C dựng. Con số đã chốt từ bây
  /// giờ để bố cục của mọi màn dựng trong Đợt A không phải đo lại lần hai.
  static const double nowPlaying = 64;

  /// Tổng chiều cao vỏ đáy, KHÔNG kể vùng an toàn của hệ thống.
  static double chrome({required bool audioLoaded}) =>
      tabBar + (audioLoaded ? nowPlaying : 0);
}
