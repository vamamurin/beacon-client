import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Screen 1 — Màn hình Trang chủ (Home) tĩnh.
/// 
/// Chứa các thành phần UI giả (Mock) theo đúng thiết kế Figma.
/// Nút Action Button ở giữa BottomNavigationBar là điểm chạm duy nhất có
/// chức năng thật: Mở màn hình Khám phá (DiscoveryScreen).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface, // Nền trắng sáng
      extendBodyBehindAppBar: true, // Để ảnh nền chui xuống dưới AppBar
      
      // Khung nội dung chính có thể cuộn được
      body: const SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroHeader(),
            SizedBox(height: 24),
            _QuickActions(),
            SizedBox(height: 24),
            _BeaconStatusCard(),
            SizedBox(height: 32),
            _ThematicDiscovery(),
            SizedBox(height: 32),
            _SuggestedRoute(),
            SizedBox(height: 100), // Khoảng trống cho Bottom Nav
          ],
        ),
      ),

      // Thanh điều hướng dưới cùng (Bottom Navigation)
      floatingActionButton: _BeaconsFAB(
        onTap: () {
          // CHỨC NĂNG DUY NHẤT HOẠT ĐỘNG: Đẩy màn hình Discovery lên
          // Lưu ý: Thay đổi '/discovery' thành tên route thực tế của bạn
          // trong AppRouter nếu bạn đang dùng tên khác.
          Navigator.of(context).pushNamed('/discovery');
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const _CustomBottomAppBar(),
    );
  }
}

// =============================================================================
// CÁC THÀNH PHẦN GIAO DIỆN CON (WIDGETS)
// =============================================================================

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: size.height * 0.55,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh nền bảo tàng
          Image.network(
            'https://images.unsplash.com/photo-1518998053901-5348d3961a04?q=80&w=1200&auto=format&fit=crop',
            fit: BoxFit.cover,
          ),
          
          // Lớp phủ Gradient đen tối dần xuống dưới
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000), // Đen hơi đậm ở trên cho rõ chữ
                  Color(0x33000000),
                  AppColors.surface, // Trắng tệp màu với nền dưới
                ],
                stops: [0.0, 0.7, 1.0],
              ),
            ),
          ),

          // Nội dung Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar giả
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.menu, color: Colors.white, size: 28),
                      Column(
                        children: [
                          Text(
                            'BẢO TÀNG TỰ ĐỘNG',
                            style: GoogleFonts.beVietnamPro(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Khám phá – Kết nối – Trải nghiệm',
                            style: GoogleFonts.beVietnamPro(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.language, color: Colors.white, size: 22),
                          const SizedBox(width: 4),
                          Text('VI', style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 16),
                          const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                        ],
                      )
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Text chào mừng
                  Text(
                    'Chào mừng bạn đến với\nBảo tàng Tự Động',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ứng dụng sử dụng Beacons để tự động\ncung cấp thông tin và trải nghiệm cá nhân hóa\nkhi bạn tham quan.',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Nút Bắt đầu tham quan
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCC5A0), // Màu be vàng
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_outlined, color: Colors.black87, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Bắt đầu tham quan',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionItem(icon: Icons.account_balance, label: 'Giới thiệu\nbảo tàng'),
            _ActionItem(icon: Icons.map_outlined, label: 'Bản đồ\nnội khu'),
            _ActionItem(icon: Icons.headphones_outlined, label: 'Thuyết minh\ntự động'),
            _ActionItem(icon: Icons.confirmation_number_outlined, label: 'Vé của tôi'),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 28, color: Colors.black87),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeaconStatusCard extends StatelessWidget {
  const _BeaconStatusCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Trải nghiệm thông minh với Beacons',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8F1FF)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8F1FF).withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.bluetooth, color: Color(0xFF4A8BFF), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Beacons đang hoạt động',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Đang kết nối',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Khi bạn đến gần hiện vật, thông tin, hình ảnh, và thuyết minh sẽ tự động hiển thị tại đây.',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThematicDiscovery extends StatelessWidget {
  const _ThematicDiscovery();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Khám phá theo chủ đề',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                'Xem tất cả >',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: const [
              _ThemeCard(
                title: 'Văn hóa\nĐông Sơn',
                count: '28 hiện vật',
                image: 'https://images.unsplash.com/photo-1600172454132-41126788db32?q=80&w=400&auto=format&fit=crop',
                icon: Icons.account_balance,
              ),
              _ThemeCard(
                title: 'Lịch sử ngành\nTự động hóa',
                count: '36 hiện vật',
                image: 'https://images.unsplash.com/photo-1565514020179-026b92b84bb6?q=80&w=400&auto=format&fit=crop',
                icon: Icons.settings,
              ),
              _ThemeCard(
                title: 'Công nghệ\nhiện đại',
                count: '24 hiện vật',
                image: 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?q=80&w=400&auto=format&fit=crop',
                icon: Icons.memory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String title;
  final String count;
  final String image;
  final IconData icon;

  const _ThemeCard({
    required this.title,
    required this.count,
    required this.image,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(image),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
            stops: [0.4, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.beVietnamPro(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: GoogleFonts.beVietnamPro(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedRoute extends StatelessWidget {
  const _SuggestedRoute();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lộ trình gợi ý',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                'Xem tất cả >',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF7F0), // Màu be rất nhạt
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: Color(0xFFC7A56F), size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lộ trình 60 phút',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tuyến tham quan dành cho người lần đầu đến bảo tàng.',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11.5,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SmallChip(icon: Icons.location_on_outlined, text: '12 điểm dừng'),
                    SizedBox(height: 6),
                    _SmallChip(icon: Icons.schedule, text: '~ 60 phút'),
                  ],
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC7A56F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.beVietnamPro(
            fontSize: 11,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// BOTTOM NAVIGATION BAR
// =============================================================================

class _CustomBottomAppBar extends StatelessWidget {
  const _CustomBottomAppBar();

  @override
  Widget build(BuildContext context) {
    return const BottomAppBar(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 20,
      shadowColor: Colors.black45,
      shape: CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomIcon(icon: Icons.home_filled, label: 'Trang chủ', isActive: true),
            _BottomIcon(icon: Icons.map_outlined, label: 'Bản đồ'),
            SizedBox(width: 48), // Khoảng trống cho nút nổi Beacons
            _BottomIcon(icon: Icons.search, label: 'Tìm kiếm'),
            _BottomIcon(icon: Icons.person_outline, label: 'Cá nhân'),
          ],
        ),
      ),
    );
  }
}

class _BottomIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _BottomIcon({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFC7A56F) : AppColors.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BeaconsFAB extends StatelessWidget {
  final VoidCallback onTap;

  const _BeaconsFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(4), // Vòng tròn viền ngoài mờ mờ
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface, // Màu nền tối bên trong nút
            shape: BoxShape.circle,
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sensors, color: AppColors.text, size: 24),
              SizedBox(height: 2),
              Text(
                'Beacons',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}