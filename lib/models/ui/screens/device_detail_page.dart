import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/ui/screens/hrv_screen.dart';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';
import 'package:tane06_app/models/mock_blood_pressure_data.dart';
import 'package:tane06_app/models/ui/screens/metric_detail_page.dart';
import 'package:tane06_app/models/ui/screens/activity_detail_page.dart';
import 'package:tane06_app/models/ui/screens/device_settings_page.dart';
import 'package:tane06_app/models/ui/screens/temperature_detail_page.dart';
import 'package:tane06_app/models/ui/widgets/sleep_overview_card.dart';
import 'package:tane06_app/models/ui/widgets/quick_action_widget.dart';
import 'package:tane06_app/repositories/device_repository.dart';

class DeviceDetailPage extends StatefulWidget {
  final Device device;

  const DeviceDetailPage({super.key, required this.device});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage>
    with TickerProviderStateMixin {
  final DeviceRepository _deviceRepository = DeviceRepository();
  final Map<String, bool> _measuringMap = {};
  final Map<String, String> _latestReadings = {};

  String _getLatestReading(String key) {
    if (_latestReadings.containsKey(key)) {
      return _latestReadings[key]!;
    }
    if (widget.device.imei != null && widget.device.imei!.isNotEmpty) {
      return '--';
    }
    switch (key) {
      case 'heart-rate':
        return '62 - 134 bpm';
      case 'blood-oxygen':
        return '${widget.device.spo2} %';
      case 'blood-pressure':
        return '120/78 mmHg';
      case 'sleep':
        return '8h 58m';
      default:
        return '—';
    }
  }


  late AnimationController _pulseController;
  late AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));
    _entryController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Device? _fetchedDevice;
  Device get _currentDevice => _fetchedDevice ?? widget.device;

  bool get _isOnline => _currentDevice.isOnline;
  bool get _hasAlert =>
      _currentDevice.statusLabel.contains('偏高') ||
      _currentDevice.statusLabel.contains('異常');
  bool get _isLowBattery => _currentDevice.batteryPercent < 20;

  Future<void> _refreshDeviceData() async {
    final imeiToUse = _currentDevice.imei;
    if (imeiToUse != null && imeiToUse.isNotEmpty) {
      try {
        final fetched = await _deviceRepository.getDevice(imei: imeiToUse);
        if (mounted) {
          setState(() {
            _fetchedDevice = fetched;
          });
        }
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        onRefresh: _refreshDeviceData,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildSliverAppBar(context),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _entryFade,
                child: SlideTransition(
                  position: _entrySlide,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _buildStatusStrip(),
                        const SizedBox(height: 24),
                        _buildSectionLabel('Vital Signs'),
                        const SizedBox(height: 14),
                        _buildVitalsGrid(),
                        const SizedBox(height: 14),
                        SleepOverviewCard(
                          imei: widget.device.imei,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionLabel('Activity Today'),
                        const SizedBox(height: 14),
                        _buildActivityRow(),
                        const SizedBox(height: 24),
                        QuickActionWidget(imei: widget.device.imei),
                        const SizedBox(height: 20),
                        _buildDeviceInfo(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }




  // ── Sliver App Bar / Hero Header ──────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      collapsedHeight: 56,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      // No title here — title lives in FlexibleSpaceBar so it only
      // appears (fades in) when the bar is fully collapsed.
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 16),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 18),
          ),
          onPressed: () async {
            final res = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeviceSettingsPage(
                    imei: widget.device.imei ?? widget.device.id),
              ),
            );
            if (res == 'unbound' && mounted) {
              Navigator.of(context).pop(true);
            }
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildHeroBackground(),
      ),
    );
  }

  Widget _buildHeroBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B4F42), Color(0xFF2E6D5D), Color(0xFF3D8A76)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Decorative circles
        Positioned(
          top: -40,
          right: -30,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 40,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        // Content anchored to the BOTTOM of the hero — never overlaps the
        // appbar buttons which live at the top of the Stack.
        Positioned(
          bottom: 16,
          left: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device name + status pill row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildDeviceAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.device.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _onlinePill(),
                            if (_hasAlert) _alertPill(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Battery pill on the right
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _batteryIcon(),
                          color: _isLowBattery
                              ? const Color(0xFFFF8A65)
                              : const Color(0xFFA5D6A7),
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_currentDevice.batteryPercent}%',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.15),
            border: Border.all(
              color: _isOnline
                  ? Colors.greenAccent
                      .withOpacity(0.4 + _pulseController.value * 0.4)
                  : Colors.white.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: _isOnline
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(
                          0.15 + _pulseController.value * 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: const Icon(Icons.watch_rounded,
              size: 26, color: Colors.white),
        );
      },
    );
  }

  Widget _onlinePill() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isOnline
                ? Colors.greenAccent.withOpacity(0.18)
                : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isOnline
                  ? Colors.greenAccent
                      .withOpacity(0.5 + _pulseController.value * 0.3)
                  : Colors.white.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isOnline ? Colors.greenAccent : Colors.white54,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: GoogleFonts.dmSans(
                  color: _isOnline ? Colors.greenAccent : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _alertPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 12),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              widget.device.statusLabel,
              style: GoogleFonts.dmSans(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _heroDivider() {
    return Container(height: 36, width: 1, color: Colors.white12);
  }

  IconData _batteryIcon() {
    final pct = _currentDevice.batteryPercent;
    if (pct >= 80) return Icons.battery_full_rounded;
    if (pct >= 50) return Icons.battery_5_bar_rounded;
    if (pct >= 20) return Icons.battery_3_bar_rounded;
    return Icons.battery_1_bar_rounded;
  }

  // ── Status strip ──────────────────────────────────────────────────────────

  Widget _buildStatusStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Flexible(
            child: _statusChip(
              icon: Icons.watch_rounded,
              label: widget.device.model ?? 'TanE-06',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _statusChip(
              icon: Icons.calendar_today_rounded,
              label: _formatBindDate(),
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          _refreshButton(),
        ],
      ),
    );
  }

  Widget _statusChip(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _refreshButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.sync_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              'Sync',
              style: GoogleFonts.dmSans(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBindDate() {
    if (widget.device.createdAtStr != null) return widget.device.createdAtStr!;
    if (widget.device.createdAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          widget.device.createdAt! * 1000);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    }
    return 'TanE-06';
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  // ── Vitals grid ────────────────────────────────────────────────────────────

  Widget _buildVitalsGrid() {
    final vitals = [
      _VitalConfig(
        icon: Icons.favorite_rounded,
        label: 'Heart Rate',
        value: '${widget.device.heartRate}',
        unit: 'bpm',
        color: AppColors.heartRate,
        bgColor: const Color(0xFFFFF0F0),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MetricDetailPage(
              metric: HealthMetric(
                type: MetricType.heartRate,
                label: 'Heart Rate',
                value: '${widget.device.heartRate}',
                unit: 'bpm',
                icon: Icons.favorite_rounded,
                color: AppColors.heartRate,
                glowColor: AppColors.heartRateGlow,
                gradient: AppColors.heartRateGradient,
                status: MetricStatus.normal,
                trendPercentage: -1.2,
                trendLabel: 'vs last hour',
                sparklineData: [78.0, 80.0, 76.0, widget.device.heartRate.toDouble(), 74.0, 72.0, 70.0],
              ),
              imei: widget.device.imei,
            ),
          ),
        ),
      ),
      _VitalConfig(
        icon: Icons.water_drop_rounded,
        label: 'Blood Oxygen',
        value: '${widget.device.spo2}',
        unit: '%',
        color: AppColors.bloodPressure,
        bgColor: const Color(0xFFF0F2FF),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MetricDetailPage(
              metric: HealthMetric(
                type: MetricType.bloodPressure,
                label: 'Blood Oxygen',
                value: '${widget.device.spo2}',
                unit: '%',
                icon: Icons.water_drop_rounded,
                color: AppColors.bloodPressure,
                glowColor: AppColors.bloodPressureGlow,
                gradient: AppColors.bloodPressureGradient,
                status: MetricStatus.normal,
                trendPercentage: 0.4,
                trendLabel: 'vs last hour',
                sparklineData: [96.0, 97.0, widget.device.spo2.toDouble(), 95.0, 97.0, 98.0],
              ),
              imei: widget.device.imei,
            ),
          ),
        ),
      ),
      _VitalConfig(
        icon: Icons.monitor_heart_rounded,
        label: 'Blood Pressure',
        value: '120/78',
        unit: 'mmHg',
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFF6EE),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BloodPressurePage(
              readings: generateMockBloodPressureReadings(),
              imei: widget.device.imei,
            ),
          ),
        ),
      ),
      // _VitalConfig(
      //   icon: Icons.analytics_rounded,
      //   label: 'HRV',
      //   value: '49.4',
      //   unit: 'ms',
      //   color: AppColors.hrv,
      //   bgColor: const Color(0xFFFFF8EE),
      //   onTap: () => Navigator.of(context).push(
      //     MaterialPageRoute(builder: (_) => const HRVScreen()),
      //   ),
      // ),
      _VitalConfig(
        icon: Icons.device_thermostat_rounded,
        label: 'Body Temp',
        value: '36.6',
        unit: '°C',
        color: const Color(0xFFFF9F0A),
        bgColor: const Color(0xFFFFF8E1),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TemperatureDetailPage(
              imei: widget.device.imei,
              initialTemp: 36.6,
            ),
          ),
        ),
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < vitals.length; i++) ...[
          _buildVitalCard(vitals[i]),
          if (i < vitals.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildVitalCard(_VitalConfig v) {
    return GestureDetector(
      onTap: v.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: v.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(v.icon, color: v.color, size: 22),
            ),
            const SizedBox(width: 14),
            // Label
            Expanded(
              child: Text(
                v.label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Value + unit
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: v.value,
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' ${v.unit}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (v.onTap != null) ...[
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: AppColors.textTertiary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow() {
    const double stepsToday = 6543;
    const double stepsGoal = 10000;
    const double goalPct = stepsToday / stepsGoal;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActivityDetailPage(imei: widget.device.imei),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: ring + headline stats ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Goal ring
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: goalPct,
                      color: AppColors.steps,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(goalPct * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.steps,
                            ),
                          ),
                          Text(
                            'goal',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                // Steps headline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '6,543',
                        style: GoogleFonts.dmSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'steps today',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: goalPct,
                          minHeight: 6,
                          backgroundColor: AppColors.steps.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.steps),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(stepsGoal - stepsToday).toStringAsFixed(0)} steps to daily goal',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 14),
            // ── Stat grid ──
            Row(
              children: [
                Expanded(
                  child: _activityStatCard(
                    icon: Icons.local_fire_department_rounded,
                    value: '368',
                    unit: 'kcal',
                    label: 'Calories',
                    color: const Color(0xFFFF6B35),
                    bgColor: const Color(0xFFFFF3EE),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _activityStatCard(
                    icon: Icons.route_rounded,
                    value: '4.2',
                    unit: 'km',
                    label: 'Distance',
                    color: AppColors.bloodPressure,
                    bgColor: const Color(0xFFF0F2FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _activityStatCard(
                    icon: Icons.timer_rounded,
                    value: '58',
                    unit: 'min',
                    label: 'Active',
                    color: AppColors.primary,
                    bgColor: const Color(0xFFEDF6F3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityStatCard({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _activityStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }


  // ── Quick Actions ──────────────────────────────────────────────────────────

  Future<void> _requestQuickMeasurement(String type, String name) async {
    final imei = widget.device.imei;
    if (imei == null || imei.isEmpty) return;

    setState(() => _measuringMap[type] = true);
    try {
      await _deviceRepository.requestMeasurement(imei: imei, type: type);
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        if (type == 'heart-rate') {
          _latestReadings[type] = '62 - 138 bpm';
        } else if (type == 'blood-oxygen') {
          _latestReadings[type] =
              '${math.min(100, widget.device.spo2 + (math.Random().nextInt(3) - 1))}%';
        } else if (type == 'blood-pressure') {
          _latestReadings[type] = '118/76 mmHg';
        } else if (type == 'sleep') {
          _latestReadings[type] = '8h 58m';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name measurement requested and updated',
                style: GoogleFonts.dmSans()),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Measurement failed: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _measuringMap[type] = false);
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    final quickItems = [
      (
        key: 'heart-rate',
        label: 'Heart Rate',
        icon: Icons.favorite_rounded,
        color: AppColors.heartRate,
        bgColor: const Color(0xFFFFF0F0),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MetricDetailPage(
                  metric: HealthMetric(
                    type: MetricType.heartRate,
                    label: 'Heart Rate',
                    value: '${widget.device.heartRate}',
                    unit: 'bpm',
                    icon: Icons.favorite_rounded,
                    color: AppColors.heartRate,
                    glowColor: AppColors.heartRateGlow,
                    gradient: AppColors.heartRateGradient,
                    status: MetricStatus.normal,
                    trendPercentage: -1.2,
                    trendLabel: 'vs last hour',
                    sparklineData: [78.0, 80.0, 76.0, widget.device.heartRate.toDouble(), 74.0, 72.0, 70.0],
                  ),
                  imei: widget.device.imei,
                ),
              ),
            ),
      ),
      (
        key: 'blood-oxygen',
        label: 'Blood Oxygen',
        icon: Icons.water_drop_rounded,
        color: AppColors.bloodPressure,
        bgColor: const Color(0xFFF0F2FF),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MetricDetailPage(
                  metric: HealthMetric(
                    type: MetricType.bloodPressure,
                    label: 'Blood Oxygen',
                    value: '${widget.device.spo2}',
                    unit: '%',
                    icon: Icons.water_drop_rounded,
                    color: AppColors.bloodPressure,
                    glowColor: AppColors.bloodPressureGlow,
                    gradient: AppColors.bloodPressureGradient,
                    status: MetricStatus.normal,
                    trendPercentage: 0.4,
                    trendLabel: 'vs last hour',
                    sparklineData: [96.0, 97.0, widget.device.spo2.toDouble(), 95.0, 97.0, 98.0],
                  ),
                  imei: widget.device.imei,
                ),
              ),
            ),
      ),
      (
        key: 'blood-pressure',
        label: 'Blood Pressure',
        icon: Icons.monitor_heart_rounded,
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFF6EE),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BloodPressurePage(
                  readings: generateMockBloodPressureReadings(),
                  imei: widget.device.imei,
                ),
              ),
            ),
      ),
      (
        key: 'sleep',
        label: 'Sleep Screen',
        icon: Icons.bedtime_rounded,
        color: AppColors.sleep,
        bgColor: const Color(0xFFE8F8F0),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SleepDetailPage(imei: widget.device.imei),
              ),
            ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quickItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) {
        final item = quickItems[i];
        final latestVal = _getLatestReading(item.key);
        final isMeasuring = _measuringMap[item.key] ?? false;

        return _buildSmallQuickActionTile(
          label: item.label,
          latestValue: latestVal,
          icon: item.icon,
          color: item.color,
          bgColor: item.bgColor,
          isMeasuring: isMeasuring,
          onMeasure: () => _requestQuickMeasurement(item.key, item.label),
          onTap: item.onTap,
        );
      },
    );
  }

  Widget _buildSmallQuickActionTile({
    required String label,
    required String latestValue,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isMeasuring,
    required VoidCallback onMeasure,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isMeasuring
                      ? Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      : Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  latestValue,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: isMeasuring ? null : onMeasure,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors_rounded, color: color, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      'Measure',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Device Info ────────────────────────────────────────────────────────────

  Widget _buildDeviceInfo() {
    final rows = [
      ('Device Name', widget.device.name),
      ('Owner', widget.device.owner),
      ('IMEI', widget.device.imei ?? '—'),
      ('Model', widget.device.model ?? 'TanE-06'),
      ('Status', widget.device.isOnline ? 'Online' : 'Offline'),
      ('Last Update', widget.device.updatedAtStr ?? '2 min ago'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 17),
            ),
            title: Text(
              'Device Info',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${widget.device.name} • ${widget.device.model ?? "TanE-06"}',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            children: List.generate(rows.length, (i) {
              return Column(
                children: [
                  Divider(
                    height: 1,
                    color: AppColors.background,
                    indent: 16,
                    endIndent: 16,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    child: Row(
                      children: [
                        Text(
                          rows[i].$1,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            rows[i].$2,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _VitalConfig {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _VitalConfig({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

class _ActionConfig {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionConfig({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

// ── Custom ring painter ───────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 5;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.12);

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}