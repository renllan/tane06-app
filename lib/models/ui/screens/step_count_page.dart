import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/models/health_data_record.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/theme/app_theme.dart';

/// Step Count Detail Page for TanE06 Smart Watch.
///
/// Connects to GET /devices/{imei}/health-data with `type: SC`.
/// Type SC records hourly step count updates for the watch user.
class StepCountPage extends StatefulWidget {
  final String? imei;
  final DateTime? initialDate;

  const StepCountPage({
    super.key,
    this.imei,
    this.initialDate,
  });

  @override
  State<StepCountPage> createState() => _StepCountPageState();
}

class _StepCountPageState extends State<StepCountPage>
    with SingleTickerProviderStateMixin {
  final DeviceRepository _deviceRepository = DeviceRepository();

  late DateTime _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;

  List<HealthDataRecord> _apiRecords = [];
  List<int> _hourlySteps = List.filled(24, 0);
  int _totalSteps = 0;
  int _selectedHourIndex = -1;
  bool _showAllHours = false;
  bool _showRawApiData = false;

  late AnimationController _animController;
  late Animation<double> _chartAnimation;

  final int _dailyStepGoal = 10000;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _fetchStepData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  /// Calculates start and end epoch timestamps in milliseconds for _selectedDate
  (int startMs, int endMs) _getTimestampRange(DateTime date) {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }

  Future<void> _fetchStepData() async {
    final imei = widget.imei;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedHourIndex = -1;
    });

    try {
      if (imei != null && imei.isNotEmpty) {
        final (startMs, endMs) = _getTimestampRange(_selectedDate);

        // Fetch health data for type SC (Step Count)
        List<HealthDataRecord> records =
            await _deviceRepository.fetchHealthData(
          imei: imei,
          type: 'SC',
          startTime: startMs,
          endTime: endMs,
          pageSize: 100,
        );

        // Fallback: If type=SC yields no records, try fetching general health data
        if (records.isEmpty) {
          final allRecords = await _deviceRepository.fetchHealthData(
            imei: imei,
            startTime: startMs,
            endTime: endMs,
            pageSize: 100,
          );
          records = allRecords
              .where((r) =>
                  r.type.toUpperCase() == 'SC' ||
                  r.type.toLowerCase().contains('step'))
              .toList();
        }

        _processRecords(records);
      } else {
        // Mock data when no IMEI is bound or present
        _generateMockHourlyData();
      }
    } catch (e) {
      _errorMessage = 'Failed to load step data: $e';
      _generateMockHourlyData();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward(from: 0.0);
      }
    }
  }

  void _processRecords(List<HealthDataRecord> records) {
    _apiRecords = List.from(records);
    final List<int> hourly = List.filled(24, 0);

    for (final record in records) {
      final stepVal = _extractStepCount(record.data);
      int hour = record.dateTime.hour;

      // Also try parsing hour from record.time string if format is HHmmss (e.g., "124901640")
      if (record.data is Map && record.data['time'] != null) {
        final timeStr = record.data['time'].toString();
        if (timeStr.length >= 2) {
          final parsedH = int.tryParse(timeStr.substring(0, 2));
          if (parsedH != null && parsedH >= 0 && parsedH < 24) {
            hour = parsedH;
          }
        }
      }

      // Accumulate hourly step count from SC records
      hourly[hour] += stepVal;
    }

    _hourlySteps = hourly;
    _totalSteps = _hourlySteps.reduce((a, b) => a + b);
  }

  int _extractStepCount(dynamic data) {
    if (data == null) return 0;
    if (data is num) return data.toInt();
    if (data is String) {
      return int.tryParse(data) ?? (double.tryParse(data)?.toInt() ?? 0);
    }
    if (data is Map) {
      final val = data['steps'] ??
          data['sc'] ??
          data['step_count'] ??
          data['count'] ??
          data['value'] ??
          data['data'];
      return _extractStepCount(val);
    }
    return 0;
  }

  void _generateMockHourlyData() {
    // Generate realistic 24-hour step profile for demonstration
    final randomSeed = _selectedDate.day + _selectedDate.month * 31;
    final rng = math.Random(randomSeed);

    final List<int> hourly = List.filled(24, 0);
    // Typical active hours: 07:00 to 22:00
    hourly[7] = 250 + rng.nextInt(300);
    hourly[8] = 800 + rng.nextInt(600); // Morning commute / walk
    hourly[9] = 450 + rng.nextInt(350);
    hourly[10] = 320 + rng.nextInt(250);
    hourly[11] = 510 + rng.nextInt(300);
    hourly[12] = 1200 + rng.nextInt(500); // Lunch walk
    hourly[13] = 640 + rng.nextInt(300);
    hourly[14] = 420 + rng.nextInt(300);
    hourly[15] = 580 + rng.nextInt(350);
    hourly[16] = 730 + rng.nextInt(400);
    hourly[17] = 1150 + rng.nextInt(600); // Evening activity
    hourly[18] = 980 + rng.nextInt(500);
    hourly[19] = 620 + rng.nextInt(300);
    hourly[20] = 410 + rng.nextInt(200);
    hourly[21] = 210 + rng.nextInt(150);

    _hourlySteps = hourly;
    _totalSteps = hourly.reduce((a, b) => a + b);
  }

  int get _peakHour {
    int maxSteps = -1;
    int peakH = 0;
    for (int i = 0; i < 24; i++) {
      if (_hourlySteps[i] > maxSteps) {
        maxSteps = _hourlySteps[i];
        peakH = i;
      }
    }
    return peakH;
  }

  void _onDateChanged(DateTime newDate) {
    if (newDate.isAfter(DateTime.now())) return;
    setState(() {
      _selectedDate = newDate;
    });
    _fetchStepData();
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.steps,
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

  @override
  Widget build(BuildContext context) {
    final progress = (_totalSteps / _dailyStepGoal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildHeroStepCard(progress),
                  const SizedBox(height: 20),
                  _buildHourlyChartSection(),
                  const SizedBox(height: 20),
                  _buildHourlyBreakdownList(),
                  const SizedBox(height: 20),
                  _buildRawApiDataSection(),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.steps,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 20),
          ),
          onPressed: _isLoading ? null : _fetchStepData,
          tooltip: 'Refresh SC Data',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Text(
          'Step Count (SC)',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.stepsGradient,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.directions_walk_rounded,
                  size: 160,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final canGoNext = !_isToday;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () =>
                _onDateChanged(_selectedDate.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppColors.textPrimary, size: 28),
            tooltip: 'Previous Day',
          ),
          Expanded(
            child: GestureDetector(
              onTap: _selectCustomDate,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.steps),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateString(_selectedDate),
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.steps.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Today',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.steps,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext
                ? () {
                    final next = _selectedDate.add(const Duration(days: 1));
                    if (!next.isAfter(now)) _onDateChanged(next);
                  }
                : null,
            icon: Icon(Icons.chevron_right_rounded,
                color: canGoNext ? AppColors.textPrimary : Colors.grey.shade300,
                size: 28),
            tooltip: 'Next Day',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.redAccent.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStepCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.stepsGlow.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY STEPS',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _totalSteps.toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (m) => '${m[1]},',
                                ),
                            style: GoogleFonts.dmSans(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '/ $_dailyStepGoal steps',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.steps.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: AppColors.steps,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar with smooth animation
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.steps.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.steps),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Goal Progress: ${(progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: progress >= 1.0
                      ? const Color(0xFFE8F5E9)
                      : AppColors.steps.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  progress >= 1.0
                      ? '🎯 Goal Met!'
                      : 'In Progress',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: progress >= 1.0
                        ? const Color(0xFF2E7D32)
                        : AppColors.steps,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChartSection() {
    final peakCount = _hourlySteps[_peakHour];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hourly Step Tracking (24 Hours)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type SC API tracks by-hour step counts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.steps.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Peak: ${_formatHourRange(_peakHour)} ($peakCount)',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.steps,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Chart view with AnimatedBuilder
          SizedBox(
            height: 180,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: HourlyStepChartPainter(
                    hourlySteps: _hourlySteps,
                    animationProgress: _chartAnimation.value,
                    selectedHourIndex: _selectedHourIndex,
                    barColor: AppColors.steps,
                    peakColor: const Color(0xFF00B4D8),
                    accentColor: const Color(0xFF90E0EF),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Touch gestures over bar chart
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final local = details.localPosition;
                const leftMargin = 42.0;
                const rightMargin = 8.0;
                final width = box.size.width - leftMargin - rightMargin;
                if (width > 0) {
                  final hourWidth = width / 24;
                  final hour = ((local.dx - leftMargin) / hourWidth).floor().clamp(0, 23);
                  setState(() {
                    _selectedHourIndex = _selectedHourIndex == hour ? -1 : hour;
                  });
                }
              }
            },
            child: Container(
              height: 24,
              alignment: Alignment.center,
              child: Text(
                _selectedHourIndex >= 0
                    ? 'Selected: ${_formatHourRange(_selectedHourIndex)} → ${_hourlySteps[_selectedHourIndex]} steps'
                    : 'Tap any bar to inspect specific hour steps',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedHourIndex >= 0
                      ? AppColors.steps
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyBreakdownList() {
    final activeHoursList = <int>[];
    for (int i = 0; i < 24; i++) {
      if (_showAllHours || _hourlySteps[i] > 0) {
        activeHoursList.add(i);
      }
    }

    final maxHourlyStep = _hourlySteps.isEmpty ? 1 : math.max(_hourlySteps.reduce(math.max), 1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hourly Log Breakdown',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _showAllHours = !_showAllHours);
                },
                child: Text(
                  _showAllHours ? 'Active Only' : 'Show All 24h',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.steps,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (activeHoursList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No step activity recorded for this day',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeHoursList.length,
              separatorBuilder: (_, __) => Divider(height: 16, color: Colors.grey.withOpacity(0.2)),
              itemBuilder: (context, index) {
                final hour = activeHoursList[index];
                final stepCount = _hourlySteps[hour];
                final barRatio = (stepCount / maxHourlyStep).clamp(0.0, 1.0);
                final isPeak = hour == _peakHour && stepCount > 0;

                return Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              isPeak
                                  ? Icons.star_rounded
                                  : Icons.access_time_rounded,
                              size: 14,
                              color: isPeak
                                  ? const Color(0xFFFFB703)
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatHourRange(hour),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: isPeak
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isPeak
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.steps.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barRatio > 0 ? barRatio : 0.005,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: isPeak
                                    ? const Color(0xFF00B4D8)
                                    : AppColors.steps,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 75,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$stepCount steps',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: stepCount > 0
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRawApiDataSection() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.steps.withOpacity(0.2)),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          initiallyExpanded: false,
          onExpansionChanged: (val) => setState(() => _showRawApiData = val),
          leading: const Icon(Icons.api_rounded, color: AppColors.steps),
          title: Text(
            'API Data Details (type: SC)',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            _apiRecords.isNotEmpty
                ? '${_apiRecords.length} raw SC items fetched'
                : 'GET /devices/{imei}/health-data?type=SC',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  _apiRecords.isNotEmpty
                      ? _apiRecords
                          .map((r) =>
                              '• record_key: ${r.recordKey}\n  timestamp: ${r.timestamp} (${r.dateTime})\n  type: ${r.type}\n  data: ${r.data}\n')
                          .join('\n')
                      : '{\n  "status": "No raw SC records returned for selected range",\n  "type": "SC",\n  "imei": "${widget.imei ?? 'Demo/Mock Mode'}"\n}',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateString(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatHourRange(int hour) {
    final hStr = hour.toString().padLeft(2, '0');
    final nextHStr = ((hour + 1) % 24).toString().padLeft(2, '0');
    return '$hStr:00 - $nextHStr:00';
  }
}

/// Custom painter for rendering the 24-hour step bar chart with Y-Axis and X-Axis
class HourlyStepChartPainter extends CustomPainter {
  final List<int> hourlySteps;
  final double animationProgress;
  final int selectedHourIndex;
  final Color barColor;
  final Color peakColor;
  final Color accentColor;

  HourlyStepChartPainter({
    required this.hourlySteps,
    required this.animationProgress,
    required this.selectedHourIndex,
    required this.barColor,
    required this.peakColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlySteps.length < 24) return;

    final rawMax = hourlySteps.reduce(math.max);
    final maxStep = rawMax > 0 ? rawMax : 100;

    const double leftMargin = 42; // Space reserved for Y-axis labels
    const double rightMargin = 8;
    const double bottomMargin = 22;
    final double chartWidth = size.width - leftMargin - rightMargin;
    final double chartHeight = size.height - bottomMargin;

    final double barWidth = (chartWidth / 24) * 0.65;
    final double barSpacing = chartWidth / 24;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final axisLinePaint = Paint()
      ..color = AppColors.textTertiary.withOpacity(0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final yLabelStyle = TextStyle(
      color: AppColors.textTertiary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    // 1. Draw Y-Axis Labels and Horizontal Grid Lines (Max, Mid, 0)
    final yTicks = [
      (0.0, maxStep),
      (0.5, (maxStep / 2).round()),
      (1.0, 0),
    ];

    for (final tick in yTicks) {
      final y = chartHeight * tick.$1;

      // Grid line across chart
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );

      // Y-axis step label text
      final textSpan = TextSpan(
        text: tick.$2.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
            ),
        style: yLabelStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final yOffset = (y - textPainter.height / 2).clamp(0.0, chartHeight - textPainter.height);
      textPainter.paint(canvas, Offset(leftMargin - 6 - textPainter.width, yOffset));
    }

    // 2. Draw Y-Axis vertical baseline
    canvas.drawLine(
      Offset(leftMargin, 0),
      Offset(leftMargin, chartHeight),
      axisLinePaint,
    );

    // 3. Draw X-Axis horizontal baseline
    canvas.drawLine(
      Offset(leftMargin, chartHeight),
      Offset(size.width - rightMargin, chartHeight),
      axisLinePaint,
    );

    // 4. Draw 24 hourly bars
    for (int i = 0; i < 24; i++) {
      final steps = hourlySteps[i];
      final double normalizedHeight = (steps / maxStep).clamp(0.0, 1.0);
      final double barH =
          chartHeight * normalizedHeight * animationProgress.clamp(0.0, 1.0);

      final double x = leftMargin + (i * barSpacing) + (barSpacing - barWidth) / 2;
      final double y = chartHeight - barH;

      final isSelected = selectedHourIndex == i;
      final isPeak = steps == rawMax && steps > 0;

      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x, y, barWidth, barH > 2.0 ? barH : 2.0),
        const Radius.circular(4),
      );

      final Paint paint = Paint()..style = PaintingStyle.fill;

      if (isPeak) {
        paint.shader = LinearGradient(
          colors: [peakColor, accentColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect.outerRect);
      } else if (isSelected) {
        paint.color = const Color(0xFF0077B6);
      } else {
        paint.color = barColor.withOpacity(steps > 0 ? 0.75 : 0.2);
      }

      canvas.drawRRect(rect, paint);

      // Draw active indicator dot on top of peak or selected bar
      if (isSelected || isPeak) {
        final dotPaint = Paint()
          ..color = isPeak ? const Color(0xFFFFB703) : const Color(0xFF0077B6)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x + barWidth / 2, y - 5), 3, dotPaint);
      }
    }

    // 5. Draw X-Axis bottom hour labels: 00:00, 06:00, 12:00, 18:00, 23:00
    final xLabelStyle = TextStyle(
      color: AppColors.textTertiary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    final hourLabels = [0, 6, 12, 18, 23];
    for (final h in hourLabels) {
      final textSpan = TextSpan(
        text: '${h.toString().padLeft(2, '0')}:00',
        style: xLabelStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final x = leftMargin + (h * barSpacing) + (barSpacing / 2) - (textPainter.width / 2);
      textPainter.paint(canvas, Offset(x, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant HourlyStepChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.selectedHourIndex != selectedHourIndex ||
        oldDelegate.hourlySteps != hourlySteps;
  }
}
