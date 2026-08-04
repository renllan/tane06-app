import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';
import 'package:tane06_app/models/mock_blood_pressure_data.dart';
import 'package:tane06_app/models/ui/screens/metric_detail_page.dart';

import 'package:tane06_app/models/ui/screens/device_settings_page.dart';
import 'package:tane06_app/models/ui/screens/temperature_detail_page.dart';
import 'package:tane06_app/models/ui/screens/step_count_page.dart';
import 'package:tane06_app/models/ui/screens/watch_location_map_screen.dart';
import 'package:tane06_app/models/ui/widgets/sleep_overview_card.dart';
import 'package:tane06_app/models/ui/widgets/quick_action_widget.dart';
import 'package:tane06_app/models/ui/dialogs/rename_device_dialog.dart';
import 'package:tane06_app/models/ui/screens/wearer_profile_page.dart';
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
  late String _deviceName;

  DateTime _selectedDate = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  bool get _isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day;
  }

  String _formatDateTag(DateTime date) {
    if (_isToday) return 'Today';
    if (_isYesterday) return 'Yesterday';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatFullDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  bool _isLoadingDateData = false;
  int? _fetchedHr;
  int? _fetchedSpo2;
  String? _fetchedBp;
  String? _fetchedTemp;
  int? _fetchedSteps;

  Future<void> _loadHealthDataForSelectedDate() async {
    final imei = widget.device.imei;
    if (imei == null || imei.isEmpty) return;

    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0)
            .millisecondsSinceEpoch ~/
        1000;
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59)
            .millisecondsSinceEpoch ~/
        1000;

    setState(() => _isLoadingDateData = true);

    try {
      final records = await _deviceRepository.fetchHealthData(
        imei: imei,
        startTime: start,
        endTime: end,
      );

      final scRecords = await _deviceRepository.fetchHealthData(
        imei: imei,
        type: 'SC',
        startTime: start,
        endTime: end,
      );

      final allRecords = [...records, ...scRecords];

      if (allRecords.isNotEmpty) {
        int? lastHr;
        int? lastSpo2;
        String? lastBp;
        String? lastTemp;
        int totalSteps = 0;
        bool hasScRecords = false;

        for (final r in allRecords) {
          final d = r.data;
          if (r.type == 'HR' || r.type == 'heart-rate') {
            if (d is Map) {
              final v = d['heart_rate'] ?? d['hr'] ?? d['value'];
              if (v is num) lastHr = v.toInt();
            }
          } else if (r.type == 'BO' || r.type == 'blood-oxygen' || r.type == 'spo2') {
            if (d is Map) {
              final v = d['blood_oxygen'] ?? d['spo2'] ?? d['value'];
              if (v is num) lastSpo2 = v.toInt();
            }
          } else if (r.type == 'BP' || r.type == 'blood-pressure') {
            if (d is Map) {
              final sys = d['systolic'] ?? d['sys'] ?? d['high'];
              final dia = d['diastolic'] ?? d['dia'] ?? d['low'];
              if (sys != null && dia != null) lastBp = '$sys/$dia';
            }
          } else if (r.type == 'BT' || r.type == 'temperature') {
            if (d is Map) {
              final v = d['temperature'] ?? d['bt'] ?? d['value'];
              if (v != null) lastTemp = v.toString();
            }
          } else if (r.type == 'SC' || r.type == 'steps') {
            hasScRecords = true;
            int stepVal = 0;
            if (d is Map) {
              final v = d['steps'] ?? d['sc'] ?? d['value'];
              stepVal = int.tryParse(v?.toString() ?? '0') ?? 0;
            } else if (d is num) {
              stepVal = d.toInt();
            } else if (d is String) {
              stepVal = int.tryParse(d) ?? 0;
            }
            totalSteps += stepVal;
          }
        }

        if (mounted) {
          setState(() {
            _fetchedHr = lastHr;
            _fetchedSpo2 = lastSpo2;
            _fetchedBp = lastBp;
            _fetchedTemp = lastTemp;
            _fetchedSteps = hasScRecords ? totalSteps : null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _fetchedHr = null;
            _fetchedSpo2 = null;
            _fetchedBp = null;
            _fetchedTemp = null;
            _fetchedSteps = null;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingDateData = false);
    }
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      _fetchedHr = null;
      _fetchedSpo2 = null;
      _fetchedBp = null;
      _fetchedTemp = null;
      _fetchedSteps = null;
    });
    _loadHealthDataForSelectedDate();
  }

  int get _recordedHeartRate {
    if (_fetchedHr != null) return _fetchedHr!;
    if (_isToday) return widget.device.heartRate > 0 ? widget.device.heartRate : 72;
    return 66 + ((_selectedDate.day * 5) % 20);
  }

  int get _recordedSpo2 {
    if (_fetchedSpo2 != null) return _fetchedSpo2!;
    if (_isToday) return widget.device.spo2 > 0 ? widget.device.spo2 : 98;
    return 96 + (_selectedDate.day % 4);
  }

  String get _recordedBloodPressure {
    if (_fetchedBp != null) return _fetchedBp!;
    if (_isToday) return '120/78';
    final sys = 116 + ((_selectedDate.day * 3) % 14);
    final dia = 74 + ((_selectedDate.day * 2) % 10);
    return '$sys/$dia';
  }

  String get _recordedBodyTemp {
    if (_fetchedTemp != null) return _fetchedTemp!;
    if (_isToday) return '36.6';
    final t = 36.3 + ((_selectedDate.day % 5) * 0.1);
    return t.toStringAsFixed(1);
  }

  int get _recordedSteps {
    return _fetchedSteps ?? 0;
  }

  int get _recordedCalories => (_recordedSteps * 0.056).round();

  double get _recordedDistance =>
      double.parse((_recordedSteps * 0.00068).toStringAsFixed(1));

  int get _recordedActiveMin =>
      (_recordedSteps / 110).round().clamp(25, 120);

  String _getLatestReading(String key) {
    if (_latestReadings.containsKey(key)) {
      return _latestReadings[key]!;
    }
    if (widget.device.imei != null && widget.device.imei!.isNotEmpty) {
      return '--';
    }
    switch (key) {
      case 'heart-rate':
        return '$_recordedHeartRate bpm';
      case 'blood-oxygen':
        return '$_recordedSpo2 %';
      case 'blood-pressure':
        return _recordedBloodPressure;
      case 'temperature':
        return '$_recordedBodyTemp °C';
      case 'steps':
        return '$_recordedSteps steps';
      case 'sleep':
        return _isToday ? '8h 58m' : '${6 + (_selectedDate.day % 3)}h ${15 + ((_selectedDate.day * 7) % 45)}m';
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
    _deviceName = widget.device.name;
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

    _loadHealthDataForSelectedDate();
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
      _currentDevice.statusLabel.contains('High') ||
      _currentDevice.statusLabel.contains('Alert') ||
      _currentDevice.statusLabel.contains('Abnormal');
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
                        _buildDateSelectorStrip(),
                        const SizedBox(height: 20),
                        _buildSectionLabel('Vital Signs (${_formatDateShort(_selectedDate)})'),
                        const SizedBox(height: 14),
                        _buildVitalsGrid(),
                        QuickActionWidget(imei: widget.device.imei),
                        const SizedBox(height: 24),
                        _buildLocationMapPreviewCard(),
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
        GestureDetector(
          onTap: _refreshDeviceData,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sync_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 5),
                Text(
                  'Sync',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _deviceName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () async {
                                final imei = widget.device.imei ?? widget.device.id;
                                final newName = await RenameDeviceDialog.show(
                                  context,
                                  imei: imei,
                                  currentName: _deviceName,
                                );
                                if (newName != null && mounted) {
                                  setState(() => _deviceName = newName);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ],
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

  // ── Date Selector Strip ───────────────────────────────────────────────────

  Widget _buildDateSelectorStrip() {
    final now = DateTime.now();
    final canGoNext = !_isToday;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isToday ? AppColors.primary.withOpacity(0.2) : const Color(0xFFF97316).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  _onDateChanged(_selectedDate.subtract(const Duration(days: 1)));
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: AppColors.primary),
                ),
                tooltip: 'Previous Day',
              ),

              GestureDetector(
                onTap: _selectCustomDate,
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _formatFullDate(_selectedDate),
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isToday
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Health Data Date: ${_formatDateTag(_selectedDate)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isToday
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: canGoNext
                    ? () {
                        final next = _selectedDate.add(const Duration(days: 1));
                        if (!next.isAfter(now)) {
                          _onDateChanged(next);
                        }
                      }
                    : null,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: canGoNext
                        ? AppColors.primary.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: canGoNext ? AppColors.primary : Colors.grey),
                ),
                tooltip: 'Next Day',
              ),
            ],
          ),
          if (!_isToday) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                _onDateChanged(DateTime.now());
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.today_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Today',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate && mounted) {
      _onDateChanged(picked);
    }
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
        value: '$_recordedHeartRate',
        unit: 'bpm',
        color: AppColors.heartRate,
        bgColor: const Color(0xFFFFF0F0),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MetricDetailPage(
              metric: HealthMetric(
                type: MetricType.heartRate,
                label: 'Heart Rate',
                value: '$_recordedHeartRate',
                unit: 'bpm',
                icon: Icons.favorite_rounded,
                color: AppColors.heartRate,
                glowColor: AppColors.heartRateGlow,
                gradient: AppColors.heartRateGradient,
                status: MetricStatus.normal,
                trendPercentage: -1.2,
                trendLabel: 'recorded',
                sparklineData: [78.0, 80.0, 76.0, _recordedHeartRate.toDouble(), 74.0, 72.0, 70.0],
              ),
              imei: widget.device.imei,
            ),
          ),
        ),
      ),
      _VitalConfig(
        icon: Icons.water_drop_rounded,
        label: 'Blood Oxygen',
        value: '$_recordedSpo2',
        unit: '%',
        color: AppColors.bloodPressure,
        bgColor: const Color(0xFFF0F2FF),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MetricDetailPage(
              metric: HealthMetric(
                type: MetricType.bloodPressure,
                label: 'Blood Oxygen',
                value: '$_recordedSpo2',
                unit: '%',
                icon: Icons.water_drop_rounded,
                color: AppColors.bloodPressure,
                glowColor: AppColors.bloodPressureGlow,
                gradient: AppColors.bloodPressureGradient,
                status: MetricStatus.normal,
                trendPercentage: 0.4,
                trendLabel: 'recorded',
                sparklineData: [96.0, 97.0, _recordedSpo2.toDouble(), 95.0, 97.0, 98.0],
              ),
              imei: widget.device.imei,
            ),
          ),
        ),
      ),
      _VitalConfig(
        icon: Icons.monitor_heart_rounded,
        label: 'Blood Pressure',
        value: _recordedBloodPressure,
        unit: 'mmHg',
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFF6EE),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BloodPressurePage(
              imei: widget.device.imei,
            ),
          ),
        ),
      ),
      _VitalConfig(
        icon: Icons.directions_walk_rounded,
        label: 'Step Count',
        value: _recordedSteps.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
            ),
        unit: 'steps',
        color: AppColors.steps,
        bgColor: const Color(0xFFEFF8FF),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StepCountPage(
              imei: widget.device.imei,
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
                  imei: widget.device.imei,
                ),
              ),
            ),
      ),
      (
        key: 'steps',
        label: 'Step Analytics',
        icon: Icons.directions_walk_rounded,
        color: AppColors.steps,
        bgColor: const Color(0xFFEFF8FF),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StepCountPage(imei: widget.device.imei),
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

  Widget _buildLocationMapPreviewCard() {
    final imeiToUse = widget.device.imei ?? '868705080304723';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WatchLocationMapScreen(
                  imei: imeiToUse,
                  devices: [widget.device],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device Live Location Map',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Tap to open map and view latest GPS location',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'View Full Map',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 130,
                    child: IgnorePointer(
                      child: FlutterMap(
                        options: const MapOptions(
                          initialCenter: LatLng(24.7757895, 121.0169383),
                          initialZoom: 15.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.tane06_app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: const LatLng(24.7757895, 121.0169383),
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.watch_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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