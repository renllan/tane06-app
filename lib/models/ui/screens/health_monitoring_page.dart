import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/models/health_data_record.dart';
import 'package:tane06_app/repositories/device_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

class _MetricConfig {
  final String title;
  final String apiType;       // API type code passed to fetchHealthData
  final List<String> fallbacks; // alternative type codes if primary empty
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String unit;
  final double Function(HealthDataRecord) valueExtractor;
  final String? secondaryUnit;
  final double Function(HealthDataRecord)? secondaryExtractor;

  const _MetricConfig({
    required this.title,
    required this.apiType,
    this.fallbacks = const [],
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.unit,
    required this.valueExtractor,
    this.secondaryUnit,
    this.secondaryExtractor,
  });
}

double _safeDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double _hrExtractor(HealthDataRecord r) {
  final d = r.data;
  if (d is Map) {
    return _safeDouble(d['heart_rate'] ?? d['hr'] ?? d['value'] ?? d['bpm'] ?? d['heartRate']);
  }
  return _safeDouble(d);
}

double _boExtractor(HealthDataRecord r) {
  final d = r.data;
  if (d is Map) {
    return _safeDouble(d['blood_oxygen'] ?? d['spo2'] ?? d['SpO2'] ?? d['value'] ?? d['bo']);
  }
  return _safeDouble(d);
}

double _bpSystolicExtractor(HealthDataRecord r) {
  final d = r.data;
  if (d is Map) {
    return _safeDouble(d['systolic'] ?? d['sys'] ?? d['high'] ?? d['sbp'] ?? d['bp_high']);
  }
  return 0;
}

double _bpDiastolicExtractor(HealthDataRecord r) {
  final d = r.data;
  if (d is Map) {
    return _safeDouble(d['diastolic'] ?? d['dia'] ?? d['low'] ?? d['dbp'] ?? d['bp_low']);
  }
  return 0;
}

double _stepsExtractor(HealthDataRecord r) {
  final d = r.data;
  if (d is Map) {
    return _safeDouble(d['steps'] ?? d['step_count'] ?? d['count'] ?? d['value']);
  }
  return _safeDouble(d);
}

double _tempExtractor(HealthDataRecord r) {
  final d = r.data;
  if (d is Map) {
    return _safeDouble(d['temperature'] ?? d['temp'] ?? d['value'] ?? d['body_temp']);
  }
  return _safeDouble(d);
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class HealthMonitoringPage extends StatefulWidget {
  final Device device;

  const HealthMonitoringPage({super.key, required this.device});

  @override
  State<HealthMonitoringPage> createState() => _HealthMonitoringPageState();
}

class _HealthMonitoringPageState extends State<HealthMonitoringPage>
    with SingleTickerProviderStateMixin {
  final DeviceRepository _repo = DeviceRepository();

  late TabController _tabController;

  // One entry per metric
  final List<_MetricConfig> _metrics = [
    _MetricConfig(
      title: 'Heart Rate',
      apiType: 'HR',
      fallbacks: ['hr', 'heart-rate', 'heartrate'],
      icon: Icons.favorite_rounded,
      color: AppColors.heartRate,
      bgColor: const Color(0xFFFFF0F0),
      unit: 'bpm',
      valueExtractor: _hrExtractor,
    ),
    _MetricConfig(
      title: 'Blood Oxygen',
      apiType: 'BO',
      fallbacks: ['bo', 'spo2', 'blood-oxygen'],
      icon: Icons.water_drop_rounded,
      color: AppColors.bloodPressure,
      bgColor: const Color(0xFFF0F2FF),
      unit: '%',
      valueExtractor: _boExtractor,
    ),
    _MetricConfig(
      title: 'Blood Pressure',
      apiType: 'BP',
      fallbacks: ['bp', 'blood-pressure'],
      icon: Icons.monitor_heart_rounded,
      color: const Color(0xFFF97316),
      bgColor: const Color(0xFFFFF6EE),
      unit: 'mmHg',
      valueExtractor: _bpSystolicExtractor,
      secondaryUnit: 'mmHg',
      secondaryExtractor: _bpDiastolicExtractor,
    ),
    _MetricConfig(
      title: 'Steps',
      apiType: 'SC',
      fallbacks: ['steps', 'sc', 'step_count'],
      icon: Icons.directions_walk_rounded,
      color: AppColors.steps,
      bgColor: const Color(0xFFEFF8FF),
      unit: 'steps',
      valueExtractor: _stepsExtractor,
    ),
    _MetricConfig(
      title: 'Temperature',
      apiType: 'BT',
      fallbacks: ['bt', 'temperature', 'body-temp'],
      icon: Icons.thermostat_rounded,
      color: const Color(0xFF10B981),
      bgColor: const Color(0xFFEFFBF5),
      unit: '°C',
      valueExtractor: _tempExtractor,
    ),
  ];

  // State: records and loading per metric
  late final List<List<HealthDataRecord>> _records;
  late final List<bool> _loading;
  late final List<String?> _errors;
  bool _isMeasuring = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _metrics.length, vsync: this);
    _records = List.generate(_metrics.length, (_) => []);
    _loading = List.generate(_metrics.length, (_) => false);
    _errors = List.generate(_metrics.length, (_) => null);
    // Load all metrics
    for (int i = 0; i < _metrics.length; i++) {
      _fetchMetric(i);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetric(int idx) async {
    final imei = widget.device.imei;
    if (imei == null || imei.isEmpty) return;

    setState(() {
      _loading[idx] = true;
      _errors[idx] = null;
    });

    try {
      final cfg = _metrics[idx];
      List<HealthDataRecord> records =
          await _repo.fetchHealthData(imei: imei, type: cfg.apiType);

      // Try fallback type codes if primary came back empty
      for (final fb in cfg.fallbacks) {
        if (records.isNotEmpty) break;
        records = await _repo.fetchHealthData(imei: imei, type: fb);
      }

      // Sort newest first
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _records[idx] = records;
          _loading[idx] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors[idx] = e.toString();
          _loading[idx] = false;
        });
      }
    }
  }

  Future<void> _requestMeasurement() async {
    final imei = widget.device.imei;
    if (imei == null || imei.isEmpty) return;
    setState(() => _isMeasuring = true);
    try {
      // Map current tab to measurement type
      const typeMap = {
        0: 'heart-rate',
        1: 'blood-oxygen',
        2: 'blood-pressure',
        3: 'heart-rate', // steps not a live measurement type
        4: 'body-temperature',
      };
      final type = typeMap[_tabController.index] ?? 'heart-rate';
      await _repo.requestMeasurement(imei: imei, type: type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Measurement requested — refreshing in 5s…',
                style: GoogleFonts.dmSans()),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 5));
        await _fetchMetric(_tabController.index);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.dmSans()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMeasuring = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Health Monitoring',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 15),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Measure button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isMeasuring
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : GestureDetector(
                    onTap: _requestMeasurement,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors_rounded,
                              color: Colors.white, size: 15),
                          const SizedBox(width: 5),
                          Text('Measure',
                              style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w500),
          tabs: _metrics
              .map((m) => Tab(
                    child: Row(
                      children: [
                        Icon(m.icon, size: 14),
                        const SizedBox(width: 5),
                        Text(m.title),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          _metrics.length,
          (i) => _buildMetricTab(i),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Per-metric tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMetricTab(int idx) {
    final cfg = _metrics[idx];
    final records = _records[idx];

    if (_loading[idx]) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cfg.color),
            const SizedBox(height: 16),
            Text('Loading ${cfg.title}…',
                style: GoogleFonts.dmSans(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_errors[idx] != null) {
      return _buildError(idx, cfg);
    }

    if (records.isEmpty) {
      return _buildEmpty(idx, cfg);
    }

    return RefreshIndicator(
      onRefresh: () => _fetchMetric(idx),
      color: cfg.color,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          // Summary card
          _buildSummaryCard(cfg, records),
          const SizedBox(height: 16),
          // Chart
          _buildChartCard(cfg, records),
          const SizedBox(height: 16),
          // History list
          _buildHistoryHeader(cfg, records),
          const SizedBox(height: 10),
          ...records.take(30).map((r) => _buildRecordRow(cfg, r)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Summary card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryCard(_MetricConfig cfg, List<HealthDataRecord> records) {
    final latest = records.first;
    final latestVal = cfg.valueExtractor(latest);
    final latestSecondary = cfg.secondaryExtractor?.call(latest);

    // Stats over all records
    final vals = records.map(cfg.valueExtractor).where((v) => v > 0).toList();
    final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
    final min = vals.isEmpty ? 0.0 : vals.reduce(math.min);
    final max = vals.isEmpty ? 0.0 : vals.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cfg.color, cfg.color.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cfg.color.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cfg.icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cfg.title,
                        style: GoogleFonts.dmSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        )),
                    Text('Latest reading',
                        style: GoogleFonts.dmSans(
                          color: Colors.white54,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              Text(
                _formatTime(latest.dateTime),
                style: GoogleFonts.dmSans(
                    color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Big value
          if (cfg.title == 'Blood Pressure' && latestSecondary != null)
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text:
                      '${latestVal.toStringAsFixed(0)}/${latestSecondary.toStringAsFixed(0)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: ' ${cfg.unit}',
                  style: GoogleFonts.dmSans(
                      fontSize: 16, color: Colors.white70),
                ),
              ]),
            )
          else
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: latestVal > 0
                      ? latestVal.toStringAsFixed(
                          cfg.unit == 'steps' ? 0 : 1)
                      : '—',
                  style: GoogleFonts.dmSans(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                if (latestVal > 0)
                  TextSpan(
                    text: ' ${cfg.unit}',
                    style: GoogleFonts.dmSans(
                        fontSize: 16, color: Colors.white70),
                  ),
              ]),
            ),
          const SizedBox(height: 20),
          // Min / Avg / Max pills
          if (vals.isNotEmpty)
            Row(
              children: [
                _statPill('Min', _fmtVal(min, cfg), cfg),
                const SizedBox(width: 10),
                _statPill('Avg', _fmtVal(avg, cfg), cfg),
                const SizedBox(width: 10),
                _statPill('Max', _fmtVal(max, cfg), cfg),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String value, _MetricConfig cfg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chart card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildChartCard(_MetricConfig cfg, List<HealthDataRecord> records) {
    // Use last 20 records for the chart, reversed for chronological order
    final chartRecords = records.reversed.toList().take(20).toList();
    if (chartRecords.isEmpty) return const SizedBox.shrink();

    if (cfg.apiType == 'HR') {
      return _buildGoogleHealthHrChartCard(cfg, records);
    }

    final spots = <FlSpot>[];
    final spotsSecondary = <FlSpot>[];

    for (int i = 0; i < chartRecords.length; i++) {
      final v = cfg.valueExtractor(chartRecords[i]);
      if (v > 0) spots.add(FlSpot(i.toDouble(), v));
      if (cfg.secondaryExtractor != null) {
        final v2 = cfg.secondaryExtractor!(chartRecords[i]);
        if (v2 > 0) spotsSecondary.add(FlSpot(i.toDouble(), v2));
      }
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    final allVals = [
      ...spots.map((s) => s.y),
      ...spotsSecondary.map((s) => s.y),
    ];
    final minY = (allVals.reduce(math.min) - 5).clamp(0, double.infinity);
    final maxY = allVals.reduce(math.max) + 10;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Trend',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(width: 8),
              Text('Last ${chartRecords.length} readings',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textSecondary)),
              if (cfg.secondaryExtractor != null) ...[
                const Spacer(),
                _chartLegendDot(cfg.color, 'Systolic'),
                const SizedBox(width: 10),
                _chartLegendDot(const Color(0xFF6C7FEA), 'Diastolic'),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 175,
            child: LineChart(
              LineChartData(
                minY: minY.toDouble(),
                maxY: maxY,
                clipData: const FlClipData.all(),
                rangeAnnotations: cfg.apiType == 'HR'
                    ? RangeAnnotations(
                        horizontalRangeAnnotations: [
                          HorizontalRangeAnnotation(
                            y1: 94,
                            y2: 118,
                            color: const Color(0xFF5BB8F5).withOpacity(0.08),
                          ),
                          HorizontalRangeAnnotation(
                            y1: 120,
                            y2: 143,
                            color: const Color(0xFF4CBF87).withOpacity(0.08),
                          ),
                          HorizontalRangeAnnotation(
                            y1: 145,
                            y2: 173,
                            color: const Color(0xFFFFA24D).withOpacity(0.08),
                          ),
                          HorizontalRangeAnnotation(
                            y1: 175,
                            y2: 188,
                            color: const Color(0xFFE96B6B).withOpacity(0.08),
                          ),
                        ],
                      )
                    : const RangeAnnotations(),
                extraLinesData: cfg.apiType == 'HR'
                    ? ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 94,
                            color: const Color(0xFF5BB8F5).withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 6, bottom: 2),
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF5BB8F5),
                              ),
                              labelResolver: (_) => 'Light (94+)',
                            ),
                          ),
                          HorizontalLine(
                            y: 120,
                            color: const Color(0xFF4CBF87).withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 6, bottom: 2),
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4CBF87),
                              ),
                              labelResolver: (_) => 'Mod (120+)',
                            ),
                          ),
                          HorizontalLine(
                            y: 145,
                            color: const Color(0xFFFFA24D).withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 6, bottom: 2),
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFFA24D),
                              ),
                              labelResolver: (_) => 'Vig (145+)',
                            ),
                          ),
                          HorizontalLine(
                            y: 175,
                            color: const Color(0xFFE96B6B).withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 6, bottom: 2),
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE96B6B),
                              ),
                              labelResolver: (_) => 'Peak (175+)',
                            ),
                          ),
                        ],
                      )
                    : const ExtraLinesData(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY.toDouble()) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.background,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (val, _) => Text(
                        val.toStringAsFixed(0),
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: math.max(1.0, (chartRecords.length / 4).floorToDouble()),
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < chartRecords.length) {
                          final dt = chartRecords[idx].dateTime;
                          final hh = dt.hour.toString().padLeft(2, '0');
                          final mm = dt.minute.toString().padLeft(2, '0');
                          return Text(
                            '$hh:$mm',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _lineBar(spots, cfg.color),
                  if (spotsSecondary.isNotEmpty)
                    _lineBar(spotsSecondary, const Color(0xFF6C7FEA)),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              s.y.toStringAsFixed(1),
                              GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          if (cfg.apiType == 'HR') ...[
            const SizedBox(height: 16),
            _buildHrZoneBreakdownBar(spots.map((s) => s.y).toList()),
          ],
        ],
      ),
  Widget _buildGoogleHealthHrChartCard(_MetricConfig cfg, List<HealthDataRecord> records) {
    final chartRecords = records.reversed.toList().take(20).toList();
    if (chartRecords.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < chartRecords.length; i++) {
      final v = cfg.valueExtractor(chartRecords[i]);
      if (v > 0) spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final rawVals = spots.map((s) => s.y).toList();
    final minVal = rawVals.reduce(math.min).toInt();
    final maxVal = rawVals.reduce(math.max).toInt();
    final latestVal = rawVals.last.toInt();
    final avgVal = (rawVals.reduce((a, b) => a + b) / rawVals.length).round();

    final minY = (minVal - 10).clamp(50, 220).toDouble();
    final maxY = (maxVal + 15).clamp(100, 220).toDouble();

    // Zone status for latest reading
    String latestZone = 'Resting';
    Color latestColor = const Color(0xFF6C7FEA);
    if (latestVal >= 175) {
      latestZone = 'Peak Zone (93-100%)';
      latestColor = const Color(0xFFE96B6B);
    } else if (latestVal >= 145) {
      latestZone = 'Vigorous Zone (77-92%)';
      latestColor = const Color(0xFFFFA24D);
    } else if (latestVal >= 120) {
      latestZone = 'Moderate Zone (64-76%)';
      latestColor = const Color(0xFF4CBF87);
    } else if (latestVal >= 94) {
      latestZone = 'Light Zone (50-63%)';
      latestColor = const Color(0xFF5BB8F5);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16181E), // Deep Google Health Dark Slate
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: latestColor.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Google Health aesthetic
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE96B6B).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFE96B6B),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HEART RATE ZONES',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$latestVal',
                          style: GoogleFonts.dmSans(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'bpm',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: latestColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: latestColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            latestZone,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: latestColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Range Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Min: $minVal • Max: $maxVal',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Avg: $avgVal bpm',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Google Health Chart Body
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                      y1: 94,
                      y2: 118,
                      color: const Color(0xFF5BB8F5).withOpacity(0.09),
                    ),
                    HorizontalRangeAnnotation(
                      y1: 120,
                      y2: 143,
                      color: const Color(0xFF4CBF87).withOpacity(0.09),
                    ),
                    HorizontalRangeAnnotation(
                      y1: 145,
                      y2: 173,
                      color: const Color(0xFFFFA24D).withOpacity(0.09),
                    ),
                    HorizontalRangeAnnotation(
                      y1: 175,
                      y2: 188,
                      color: const Color(0xFFE96B6B).withOpacity(0.09),
                    ),
                  ],
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 94,
                      color: const Color(0xFF5BB8F5).withOpacity(0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5BB8F5),
                        ),
                        labelResolver: (_) => 'Light 94',
                      ),
                    ),
                    HorizontalLine(
                      y: 120,
                      color: const Color(0xFF4CBF87).withOpacity(0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4CBF87),
                        ),
                        labelResolver: (_) => 'Mod 120',
                      ),
                    ),
                    HorizontalLine(
                      y: 145,
                      color: const Color(0xFFFFA24D).withOpacity(0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFA24D),
                        ),
                        labelResolver: (_) => 'Vig 145',
                      ),
                    ),
                    HorizontalLine(
                      y: 175,
                      color: const Color(0xFFE96B6B).withOpacity(0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE96B6B),
                        ),
                        labelResolver: (_) => 'Peak 175',
                      ),
                    ),
                  ],
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY) / 3).clamp(10, 50),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, _) => Text(
                        val.toInt().toString(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: math.max(1.0, (chartRecords.length / 4).floorToDouble()),
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < chartRecords.length) {
                          final dt = chartRecords[idx].dateTime;
                          final hh = dt.hour.toString().padLeft(2, '0');
                          final mm = dt.minute.toString().padLeft(2, '0');
                          return Text(
                            '$hh:$mm',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    barWidth: 3.2,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6C7FEA), // Rest
                        Color(0xFF5BB8F5), // Light
                        Color(0xFF4CBF87), // Mod
                        Color(0xFFFFA24D), // Vig
                        Color(0xFFE96B6B), // Peak
                      ],
                      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        return spot.x == barData.spots.last.x;
                      },
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: latestColor,
                        strokeWidth: 2.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          latestColor.withOpacity(0.25),
                          latestColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF2C2F3A),
                    getTooltipItems: (spots) => spots.map((s) {
                      final val = s.y.toInt();
                      String zone = 'Rest';
                      if (val >= 175) zone = 'Peak';
                      else if (val >= 145) zone = 'Vigorous';
                      else if (val >= 120) zone = 'Moderate';
                      else if (val >= 94) zone = 'Light';

                      return LineTooltipItem(
                        '$val bpm • $zone',
                        GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Google Health Style Time-in-Zone Breakdown
          _buildGoogleHealthZoneBreakdownBar(rawVals),
        ],
      ),
    );
  }

  Widget _buildGoogleHealthZoneBreakdownBar(List<double> values) {
    if (values.isEmpty) return const SizedBox.shrink();

    int lightCount = 0;
    int modCount = 0;
    int vigCount = 0;
    int peakCount = 0;
    int restCount = 0;

    for (final v in values) {
      if (v >= 175) {
        peakCount++;
      } else if (v >= 145) {
        vigCount++;
      } else if (v >= 120) {
        modCount++;
      } else if (v >= 94) {
        lightCount++;
      } else {
        restCount++;
      }
    }

    final total = values.length;
    final lightPct = (lightCount / total * 100).round();
    final modPct = (modCount / total * 100).round();
    final vigPct = (vigCount / total * 100).round();
    final peakPct = (peakCount / total * 100).round();
    final restPct = 100 - (lightPct + modPct + vigPct + peakPct);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TIME IN HEART RATE ZONES',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
              Text(
                '$total Readings',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (restCount > 0)
                    Expanded(
                      flex: restCount,
                      child: Container(color: Colors.white24),
                    ),
                  if (lightCount > 0)
                    Expanded(
                      flex: lightCount,
                      child: Container(color: const Color(0xFF5BB8F5)),
                    ),
                  if (modCount > 0)
                    Expanded(
                      flex: modCount,
                      child: Container(color: const Color(0xFF4CBF87)),
                    ),
                  if (vigCount > 0)
                    Expanded(
                      flex: vigCount,
                      child: Container(color: const Color(0xFFFFA24D)),
                    ),
                  if (peakCount > 0)
                    Expanded(
                      flex: peakCount,
                      child: Container(color: const Color(0xFFE96B6B)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _darkZoneBadge('Rest', '$restPct%', Colors.white38),
              _darkZoneBadge('Light', '$lightPct%', const Color(0xFF5BB8F5)),
              _darkZoneBadge('Moderate', '$modPct%', const Color(0xFF4CBF87)),
              _darkZoneBadge('Vigorous', '$vigPct%', const Color(0xFFFFA24D)),
              _darkZoneBadge('Peak', '$peakPct%', const Color(0xFFE96B6B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkZoneBadge(String label, String pct, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
        Text(
          pct,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHrZoneBreakdownBar(List<double> values) {
    if (values.isEmpty) return const SizedBox.shrink();

    // Zone thresholds for Age 32
    int lightCount = 0;
    int modCount = 0;
    int vigCount = 0;
    int peakCount = 0;
    int restCount = 0;

    for (final v in values) {
      if (v >= 175) {
        peakCount++;
      } else if (v >= 145) {
        vigCount++;
      } else if (v >= 120) {
        modCount++;
      } else if (v >= 94) {
        lightCount++;
      } else {
        restCount++;
      }
    }

    final total = values.length;
    final lightPct = (lightCount / total * 100).round();
    final modPct = (modCount / total * 100).round();
    final vigPct = (vigCount / total * 100).round();
    final peakPct = (peakCount / total * 100).round();
    final restPct = 100 - (lightPct + modPct + vigPct + peakPct);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Heart Rate Zone Distribution',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$total readings analyzed',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (restCount > 0)
                    Expanded(
                      flex: restCount,
                      child: Container(color: AppColors.textTertiary.withOpacity(0.3)),
                    ),
                  if (lightCount > 0)
                    Expanded(
                      flex: lightCount,
                      child: Container(color: const Color(0xFF5BB8F5)),
                    ),
                  if (modCount > 0)
                    Expanded(
                      flex: modCount,
                      child: Container(color: const Color(0xFF4CBF87)),
                    ),
                  if (vigCount > 0)
                    Expanded(
                      flex: vigCount,
                      child: Container(color: const Color(0xFFFFA24D)),
                    ),
                  if (peakCount > 0)
                    Expanded(
                      flex: peakCount,
                      child: Container(color: const Color(0xFFE96B6B)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _zoneLegendBadge('Rest', '$restPct%', AppColors.textSecondary),
              _zoneLegendBadge('Light', '$lightPct%', const Color(0xFF5BB8F5)),
              _zoneLegendBadge('Moderate', '$modPct%', const Color(0xFF4CBF87)),
              _zoneLegendBadge('Vigorous', '$vigPct%', const Color(0xFFFFA24D)),
              _zoneLegendBadge('Peak', '$peakPct%', const Color(0xFFE96B6B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoneLegendBadge(String label, String pct, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          pct,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _chartLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: spots.length <= 10,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // History list
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHistoryHeader(_MetricConfig cfg, List<HealthDataRecord> records) {
    return Row(
      children: [
        Text('History',
            style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6)),
        const SizedBox(width: 8),
        Text('${records.length} records',
            style: GoogleFonts.dmSans(
                fontSize: 12, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _buildRecordRow(_MetricConfig cfg, HealthDataRecord record) {
    final val = cfg.valueExtractor(record);
    final val2 = cfg.secondaryExtractor?.call(record);

    String displayValue;
    if (cfg.title == 'Blood Pressure' && val2 != null && val2 > 0) {
      displayValue =
          '${val.toStringAsFixed(0)} / ${val2.toStringAsFixed(0)} ${cfg.unit}';
    } else {
      displayValue = val > 0
          ? '${val.toStringAsFixed(cfg.unit == 'steps' ? 0 : 1)} ${cfg.unit}'
          : '—';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cfg.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(record.dateTime),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  record.type.toUpperCase(),
                  style: GoogleFonts.dmSans(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            displayValue,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error / empty states
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildError(int idx, _MetricConfig cfg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text('Could not load ${cfg.title}',
                style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(_errors[idx] ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _fetchMetric(idx),
              style: ElevatedButton.styleFrom(
                backgroundColor: cfg.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Retry', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(int idx, _MetricConfig cfg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cfg.bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No ${cfg.title} data',
                style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
                'Tap "Measure" to request a live reading from the device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isMeasuring ? null : _requestMeasurement,
              style: ElevatedButton.styleFrom(
                backgroundColor: cfg.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.sensors_rounded, size: 16),
              label: Text('Request Measurement',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _fmtVal(double v, _MetricConfig cfg) {
    return cfg.unit == 'steps'
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDateTime(DateTime dt) {
    final d = '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }
}
