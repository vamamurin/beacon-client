import 'package:beacon_client/domain/models/floor_info.dart';

class FloorRepository {
  static const Map<int, FloorInfo> _catalog = {
    1: FloorInfo(
      id: 1,
      name: 'Tầng 3 - Thời Niên Thiếu',
      description:
          'Trưng bày các hiện vật và tư liệu về giai đoạn thời niên thiếu '
          'và những năm tháng hoạt động cách mạng đầu tiên của Chủ tịch Hồ Chí Minh.',
    ),
    2: FloorInfo(
      id: 2,
      name: 'Tầng 4 - Chủ Tịch Nước',
      description:
          'Trưng bày các hiện vật gắn liền với giai đoạn Chủ tịch Hồ Chí Minh '
          'lãnh đạo nhà nước Việt Nam Dân chủ Cộng hòa và sự nghiệp kháng chiến.',
    ),
  };

  static FloorInfo? getFloor(int major) => _catalog[major];
}
