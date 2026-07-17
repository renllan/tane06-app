import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';
// Health metrics removed from home; details shown on device page
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/models/ui/screens/device_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  // mutable devices list (initialized in initState)
  late List<Device> _devices;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _headerController.forward();

    // initialize devices (mutable so user can reorder)
    _devices = [
      Device(
        id: '1',
        name: '父親的 TanE06',
        owner: '父親',
        batteryPercent: 20,
        heartRate: 88,
        spo2: 95,
        statusLabel: '血壓偏高',
      ),
      Device(
        id: '2',
        name: '母親的 TanE06',
        owner: '母親',
        batteryPercent: 15,
        heartRate: 76,
        spo2: 97,
        statusLabel: '低電量',
      ),
      Device(
        id: '3',
        name: '我的 TanE06',
        owner: '我',
        batteryPercent: 82,
        heartRate: 72,
        spo2: 98,
        statusLabel: '狀態良好',
      ),
    ];
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildDevicesSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDevicesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('我的設備', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Text('${_devices.length} 個設備', style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          // Reorderable list so user can move cards to customize order
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _onReorder,
            children: [
              for (final d in _devices)
                Padding(
                  key: ValueKey(d.id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDeviceCard(d),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _devices.removeAt(oldIndex);
      _devices.insert(newIndex, item);
    });
  }

  Widget _buildDeviceCard(Device d) {
    // choose background color per status
    Color bgColor = AppColors.surfaceLight;
    Color accent = AppColors.surfaceMedium;
    Widget? rightBadge;

    if (d.statusLabel.contains('偏高') || d.statusLabel.contains('異常')) {
      bgColor = const Color(0xFFFFEBEE); // light red
      accent = const Color(0xFFFFCDD2);
      rightBadge = const Icon(Icons.error_outline, color: Color(0xFFB00020));
    } else if (d.statusLabel.contains('低電量')) {
      bgColor = const Color(0xFFFFF8E1); // light yellow
      accent = const Color(0xFFFFE5B4);
      rightBadge = const Icon(Icons.report_problem_rounded, color: Color(0xFFB08500));
    } else if (d.statusLabel.contains('良好')) {
      bgColor = const Color(0xFFE8F5E9); // light green
      accent = const Color(0xFFD7F0DD);
      rightBadge = const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32));
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeviceDetailPage(device: d))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.6)),
        ),
        child: Column(
          children: [
            // top row: image, title+badge, right icon
            Row(
              children: [
                // device image placeholder
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMedium,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.watch_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(d.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                        if (rightBadge != null) rightBadge,
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Text('在線 | 配戴中', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: accent.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                          child: Text(d.statusLabel, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // vitals row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _vitalItem(Icons.favorite, '心率', '${d.heartRate} bpm', AppColors.heartRate),
                _vitalItem(Icons.water_drop_rounded, '血氧', '${d.spo2} %', AppColors.bloodPressure),
                _vitalItem(Icons.battery_full_rounded, '電量', '${d.batteryPercent}%', AppColors.textPrimary),
              ],
            ),
            const SizedBox(height: 12),
            // bottom row: last updated and chevron
            const Row(
              children: [
                Text('最後更新：2 分鐘前', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vitalItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'TanE-06',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Date badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getFormattedDate(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Health score and quick stats removed from home page

  // section title removed (metrics moved to device detail)

  // metrics grid removed from home page

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: _blurFilter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                      _buildNavItem(Icons.home_rounded, 'Home', true),
                  _buildNavItem(Icons.analytics_rounded, 'Analytics', false),
                  _buildNavItem(Icons.watch_rounded, 'Devices', false),
                  _buildNavItem(Icons.person_rounded, 'Profile', false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static final _blurFilter =
      ImageFilter.blur(sigmaX: 20, sigmaY: 20);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF5E5CE6).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? const Color(0xFF5E5CE6) : AppColors.textTertiary,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF5E5CE6) : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
