import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/ui/screens/device_detail_page.dart';
import 'package:tane06_app/models/ui/screens/add_device_page.dart';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';
import 'package:tane06_app/models/mock_blood_pressure_data.dart';
import 'package:tane06_app/models/ui/screens/hrv_screen.dart';
import 'package:tane06_app/models/ui/widgets/metric_card.dart';
import 'package:tane06_app/models/ui/widgets/sleep_overview_card.dart';
import 'package:tane06_app/models/ui/widgets/temperature_widget.dart';
import 'package:tane06_app/models/ui/widgets/quick_action_widget.dart';
import 'package:tane06_app/repositories/device_repository.dart';

class HomePage extends StatefulWidget {
  final int? userId;
  final List<Device>? initialDevices;

  const HomePage({
    super.key,
    this.userId,
    this.initialDevices,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DeviceRepository _deviceRepository = DeviceRepository();

  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  int _currentIndex = 0;

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
    if (widget.initialDevices != null && widget.initialDevices!.isNotEmpty) {
      _devices = List<Device>.from(widget.initialDevices!);
    } else {
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
      if (widget.userId != null) {
        _loadUserDevices();
      }
    }
  }

  Future<void> _loadUserDevices() async {
    if (widget.userId == null) return;
    try {
      final fetchedDevices =
          await _deviceRepository.listUserDevices(userId: widget.userId!);
      if (fetchedDevices.isNotEmpty && mounted) {
        setState(() {
          _devices = fetchedDevices;
        });
      }
    } catch (e) {
      debugPrint('Error loading user devices in HomePage: $e');
    }
  }

  String? get _firstImei {
    for (final d in _devices) {
      if (d.imei != null && d.imei!.isNotEmpty) return d.imei;
    }
    return _devices.isNotEmpty ? _devices.first.id : null;
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
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUserDevices();
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_currentIndex == 1)
                SliverToBoxAdapter(child: _buildAnalyticsSection())
              else
                SliverToBoxAdapter(child: _buildDevicesSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAnalyticsSection() {
    final bpMetric = const HealthMetric(
      type: MetricType.bloodPressure,
      label: 'Blood Pressure',
      value: '120/78',
      unit: 'mmHg',
      icon: Icons.monitor_heart_rounded,
      color: AppColors.bloodPressure,
      glowColor: AppColors.bloodPressureGlow,
      gradient: AppColors.bloodPressureGradient,
      status: MetricStatus.normal,
      trendPercentage: -2.5,
      trendLabel: 'vs yesterday',
      sparklineData: [124.0, 122.0, 119.0, 121.0, 120.0],
    );

    final hrMetric = const HealthMetric(
      type: MetricType.heartRate,
      label: 'Heart Rate',
      value: '72',
      unit: 'bpm',
      icon: Icons.favorite_rounded,
      color: AppColors.heartRate,
      glowColor: AppColors.heartRateGlow,
      gradient: AppColors.heartRateGradient,
      status: MetricStatus.normal,
      trendPercentage: -1.2,
      trendLabel: 'resting',
      sparklineData: [78.0, 80.0, 76.0, 74.0, 72.0],
    );

    final hrvMetric = const HealthMetric(
      type: MetricType.hrv,
      label: 'HRV',
      value: '49.4',
      unit: 'ms',
      icon: Icons.analytics_rounded,
      color: AppColors.heartRate,
      glowColor: AppColors.heartRateGlow,
      gradient: AppColors.heartRateGradient,
      status: MetricStatus.normal,
      trendPercentage: 2.1,
      trendLabel: 'recovery',
      sparklineData: [45.0, 48.0, 47.5, 49.4, 50.1],
    );

    final stepsMetric = const HealthMetric(
      type: MetricType.steps,
      label: 'Steps',
      value: '6,543',
      unit: 'steps',
      icon: Icons.directions_walk_rounded,
      color: AppColors.steps,
      glowColor: AppColors.stepsGlow,
      gradient: AppColors.stepsGradient,
      status: MetricStatus.normal,
      trendPercentage: 8.4,
      trendLabel: 'today',
      sparklineData: [4200.0, 5400.0, 6000.0, 6543.0],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '健康分析與總覽',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Featured Blood Pressure Card
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BloodPressurePage(
                    readings: generateMockBloodPressureReadings(),
                    imei: _firstImei,
                  ),
                ),
              );
            },
            child: MetricCard(metric: bpMetric, isLarge: true, imei: _firstImei),
          ),
          const SizedBox(height: 16),
          const SleepOverviewCard(),
          const SizedBox(height: 16),
          const TemperatureWidget(),
          const SizedBox(height: 16),
          const QuickActionWidget(),
          const SizedBox(height: 16),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              MetricCard(metric: hrMetric),
              MetricCard(metric: hrvMetric),
              MetricCard(metric: stepsMetric),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openAddDevicePage() async {
    final result = await Navigator.of(context).push<Device>(
      MaterialPageRoute(
        builder: (_) => AddDevicePage(userId: widget.userId ?? 1),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final existingIndex = _devices.indexWhere(
          (d) => d.id == result.id || (d.imei != null && d.imei == result.imei),
        );
        if (existingIndex >= 0) {
          _devices[existingIndex] = result;
        } else {
          _devices.insert(0, result);
        }
      });
    }
  }

  Widget _buildDevicesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('我的設備',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('${_devices.length} 個設備',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openAddDevicePage,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('新增設備',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reorderable list with guaranteed unique keys
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _onReorder,
            children: [
              for (int i = 0; i < _devices.length; i++)
                Padding(
                  key: ValueKey('device_${_devices[i].id}_${_devices[i].imei}_$i'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDeviceCard(_devices[i]),
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

  Future<void> _unbindDeviceDirectly(Device d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF453A), size: 22),
            SizedBox(width: 8),
            Text('解除綁定設備', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          '確定要解除綁定「${d.name}」嗎？\n解除後將從您的帳號及裝置清單中移除該設備。',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('確認解除綁定', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _deviceRepository.unbindDevice(
        userId: widget.userId ?? 1,
        imei: d.imei ?? d.id,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _devices.removeWhere((item) => item.id == d.id || (item.imei != null && item.imei == d.imei));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已解除綁定「${d.name}」'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
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
      onTap: () async {
        final unbound = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => DeviceDetailPage(device: d)),
        );
        if (unbound == true && mounted) {
          setState(() {
            _devices.removeWhere((item) => item.id == d.id || (item.imei != null && item.imei == d.imei));
          });
        }
      },
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
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                          onSelected: (val) {
                            if (val == 'unbind') {
                              _unbindDeviceDirectly(d);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'unbind',
                              child: Row(
                                children: [
                                  Icon(Icons.link_off_rounded, color: Color(0xFFFF453A), size: 18),
                                  SizedBox(width: 8),
                                  Text('解除綁定 (Unbind)', style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Text('在線 | 配戴中', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              if (d.statusLabel.contains('血壓')) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BloodPressurePage(
                                      readings: generateMockBloodPressureReadings(),
                                      imei: d.imei ?? d.id,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: accent.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                d.statusLabel,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
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
                _vitalItem(
                  d.batteryPercent >= 80
                      ? Icons.battery_full_rounded
                      : (d.batteryPercent >= 30
                          ? Icons.battery_5_bar_rounded
                          : Icons.battery_alert_rounded),
                  '電量',
                  '${d.batteryPercent}%',
                  d.batteryPercent <= 20
                      ? const Color(0xFFFF453A)
                      : AppColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // bottom row: last updated and chevron
            Row(
              children: [
                Expanded(
                  child: Text(
                    '最後更新：2 分鐘前',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              const SizedBox(width: 8),
              // Add Device IconButton
              IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                onPressed: _openAddDevicePage,
                tooltip: '新增設備 (Add Device)',
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  _buildNavItem(Icons.home_rounded, 'Home', _currentIndex == 0, () => setState(() => _currentIndex = 0)),
                  _buildNavItem(Icons.analytics_rounded, 'Analytics', _currentIndex == 1, () => setState(() => _currentIndex = 1)),
                  _buildNavItem(Icons.watch_rounded, 'Devices', _currentIndex == 2, () => setState(() => _currentIndex = 2)),
                  _buildNavItem(Icons.person_rounded, 'Profile', _currentIndex == 3, () => setState(() => _currentIndex = 3)),
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

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
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
      ),
    );
  }
}

