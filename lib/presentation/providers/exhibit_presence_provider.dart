// Destination: lib/presentation/providers/exhibit_presence_provider.dart (NEW)
//
// Mặt tiền mỏng cho ExhibitPresenceTracker. Chỉ màn 3 dùng.
//
// KHÔNG phải ChangeNotifier, có chủ đích: provider này bán một STREAM, không
// bán snapshot. Nếu nó notifyListeners() mỗi khi tập minor đổi, cả
// ExhibitListScreen (kể cả hero 250px và ảnh nền) sẽ rebuild — đúng thứ mà
// StreamBuilder cục bộ trong danh sách đang tránh. Widget subscribe trực tiếp,
// rebuild đúng phần danh sách.
//
// Nó tồn tại chỉ để widget không phải biết ExhibitPresenceTracker (và qua đó,
// AppGraph) tồn tại — cùng lý do với ContentProvider, khác grain.

import 'package:beacon_client/services/exhibit_presence_tracker.dart';

class ExhibitPresenceProvider {
  const ExhibitPresenceProvider(this._tracker);

  final ExhibitPresenceTracker _tracker;

  /// Tập minor đang nghe thấy tại zone [major], NGAY LÚC NÀY. Dùng làm
  /// initialData cho StreamBuilder để khung hình đầu tiên không rỗng.
  Set<int> currentPresent(int major) => _tracker.currentPresent(major);

  /// Stream đã change-gated: chỉ bắn khi tập minor thực sự thêm/bớt, không
  /// theo nhịp heartbeat 1 Hz của registry.
  Stream<Set<int>> watchMajor(int major) => _tracker.watchMajor(major);
}
