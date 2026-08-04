import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/ui/screens/device_detail_page.dart';
import 'package:tane06_app/models/ui/screens/add_device_page.dart';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';
import 'package:tane06_app/models/ui/screens/login_page.dart';
import 'package:tane06_app/models/mock_blood_pressure_data.dart';
import 'package:tane06_app/models/ui/widgets/metric_card.dart';
import 'package:tane06_app/models/ui/widgets/sleep_overview_card.dart';
import 'package:tane06_app/models/ui/widgets/temperature_widget.dart';
import 'package:tane06_app/models/ui/widgets/quick_action_widget.dart';
import 'package:tane06_app/models/ui/screens/watch_location_map_screen.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/services/auth_token_store.dart';

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
          name: "Father's TanE06",
          owner: 'Father',
          batteryPercent: 20,
          heartRate: 88,
          spo2: 95,
          statusLabel: 'High BP',
        ),
        Device(
          id: '2',
          name: "Mother's TanE06",
          owner: 'Mother',
          batteryPercent: 15,
          heartRate: 76,
          spo2: 97,
          statusLabel: 'Low Battery',
        ),
        Device(
          id: '3',
          name: "My TanE06",
          owner: 'Me',
          batteryPercent: 82,
          heartRate: 72,
          spo2: 98,
          statusLabel: 'Normal',
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
              if (_currentIndex == 3)
                SliverToBoxAdapter(child: _buildProfileSection())
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



  // -----------------------------------------------------------------------
  // Profile tab
  // -----------------------------------------------------------------------

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFFF453A), size: 22),
            SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Log Out',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Clear the auth token
    AuthTokenStore.instance.clear();

    // Navigate back to login, removing all routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _buildProfileSection() {
    final userId = widget.userId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Account card ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5E5CE6), Color(0xFF4B7BEC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthTokenStore.instance.username ?? 'TanE-06 User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userId != null ? 'User ID: $userId' : 'Not Logged In',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Device summary ───────────────────────────────────────────
          _profileInfoRow(
            icon: Icons.watch_rounded,
            label: 'Bound Devices',
            value: '${_devices.length} devices',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _profileInfoRow(
            icon: Icons.devices_other_rounded,
            label: 'Device Model',
            value: 'TanE-06',
            color: AppColors.primary,
          ),

          const SizedBox(height: 28),

          // ── Logout button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text(
                'Log Out',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF453A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
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

  void _openMultiDeviceMapPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WatchLocationMapScreen(
          imei: _firstImei ?? '868705080304723',
          devices: _devices,
        ),
      ),
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
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('My Devices',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('${_devices.length} devices',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openAddDevicePage,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Device',
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
            Text('Unbind Device', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to unbind "${d.name}"?\nThis will remove the device from your account.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Unbind', style: TextStyle(fontWeight: FontWeight.w700)),
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
          content: Text('Unbound "${d.name}"'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  /// Converts an epoch-millisecond timestamp to a human-readable relative-time string.
  /// Returns "No updates yet" when [epochMs] is null or zero.
  String _formatRelativeTime(int? epochMs) {
    if (epochMs == null || epochMs == 0) return 'No updates yet';

    final ms = epochMs < 10000000000 ? epochMs * 1000 : epochMs;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);

    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()} mo ago';
  }

  Widget _buildDeviceCard(Device d) {
    Color bgColor = AppColors.surfaceLight;
    Color accent = AppColors.surfaceMedium;
    Widget? rightBadge;

    if (d.statusLabel.contains('High') || d.statusLabel.contains('Abnormal')) {
      bgColor = const Color(0xFFFFEBEE);
      accent = const Color(0xFFFFCDD2);
      rightBadge = const Icon(Icons.error_outline, color: Color(0xFFB00020));
    } else if (d.statusLabel.contains('Low')) {
      bgColor = const Color(0xFFFFF8E1);
      accent = const Color(0xFFFFE5B4);
      rightBadge = const Icon(Icons.report_problem_rounded, color: Color(0xFFB08500));
    } else if (d.statusLabel.contains('Normal')) {
      bgColor = const Color(0xFFE8F5E9);
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
                                  Text('Unbind Device', style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        // Online / offline indicator dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: d.isOnline
                                ? const Color(0xFF30D158)
                                : const Color(0xFF8E8E93),
                            shape: BoxShape.circle,
                            boxShadow: d.isOnline
                                ? [BoxShadow(color: const Color(0xFF30D158).withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              if (d.statusLabel.toLowerCase().contains('bp')) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BloodPressurePage(
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
                _vitalItem(Icons.favorite, 'Heart Rate', '${d.heartRate} bpm', AppColors.heartRate),
                _vitalItem(Icons.water_drop_rounded, 'SpO₂', '${d.spo2} %', AppColors.bloodPressure),
                _vitalItem(
                  d.batteryPercent >= 80
                      ? Icons.battery_full_rounded
                      : (d.batteryPercent >= 30
                          ? Icons.battery_5_bar_rounded
                          : Icons.battery_alert_rounded),
                  'Battery',
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
                    'Updated: ${_formatRelativeTime(d.updatedAt)}',
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
                tooltip: 'Add Device',
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
                  _buildNavItem(Icons.map_rounded, 'Map', false, _openMultiDeviceMapPage),
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

