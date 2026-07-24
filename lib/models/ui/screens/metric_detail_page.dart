import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/health_data_record.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';
import 'package:tane06_app/models/mock_blood_pressure_data.dart';
import 'package:tane06_app/models/ui/widgets/sparkline_painter.dart';
import 'package:tane06_app/theme/app_theme.dart';

class MetricDetailPage extends StatefulWidget {
  final HealthMetric metric;
  final String? imei;

  const MetricDetailPage({
    super.key,
    required this.metric,
    this.imei,
  });

  @override
  State<MetricDetailPage> createState() => _MetricDetailPageState();
}

class _MetricDetailPageState extends State<MetricDetailPage> {
  final DeviceRepository _deviceRepository = DeviceRepository();
  List<HealthDataRecord> _apiRecords = [];
  bool _isLoadingApi = false;
  String? _latestApiValue;
  List<double>? _dynamicSparkline;
  bool _isMeasuring = false;

  @override
  void initState() {
    super.initState();
    if (widget.imei != null && widget.imei!.isNotEmpty) {
      _fetchMetricApiData();
    }
  }

  String _getApiTypeCode() {
    switch (widget.metric.type) {
      case MetricType.heartRate:
        return 'HR';
      case MetricType.steps:
        return 'SC';
      case MetricType.hrv:
        return 'HRV';
      case MetricType.sleep:
        return 'SLEEP';
      case MetricType.bloodPressure:
        if (widget.metric.label.toUpperCase().contains('O₂') ||
            widget.metric.label.toUpperCase().contains('SPO2') ||
            widget.metric.label.toUpperCase().contains('OXYGEN')) {
          return 'BO';
        }
        return 'BP';
    }
  }

  String _getMeasurementTypeCode() {
    switch (widget.metric.type) {
      case MetricType.heartRate:
        return 'heart-rate';
      case MetricType.steps:
        return 'heart-rate';
      case MetricType.hrv:
        return 'heart-rate';
      case MetricType.sleep:
        return 'heart-rate';
      case MetricType.bloodPressure:
        if (widget.metric.label.toUpperCase().contains('O₂') ||
            widget.metric.label.toUpperCase().contains('SPO2') ||
            widget.metric.label.toUpperCase().contains('OXYGEN')) {
          return 'blood-oxygen';
        }
        return 'blood-pressure';
    }
  }

  Future<void> _fetchMetricApiData() async {
    final imei = widget.imei;
    if (imei == null || imei.isEmpty) return;

    setState(() => _isLoadingApi = true);
    try {
      final typeCode = _getApiTypeCode();
      List<HealthDataRecord> records = await _deviceRepository.fetchHealthData(
        imei: imei,
        type: typeCode,
      );

      if (records.isEmpty && typeCode == 'BO') {
        records = await _deviceRepository.fetchHealthData(
          imei: imei,
          type: 'blood-oxygen',
        );
      } else if (records.isEmpty && typeCode == 'HR') {
        records = await _deviceRepository.fetchHealthData(
          imei: imei,
          type: 'heart-rate',
        );
      }

      records.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        setState(() {
          _apiRecords = records;
          _isLoadingApi = false;

          if (records.isNotEmpty) {
            final latest = records.last;
            final val = _extractNumericValue(latest);
            if (val > 0) {
              _latestApiValue = widget.metric.unit == 'steps'
                  ? val.toStringAsFixed(0)
                  : val.toStringAsFixed(1);
            }

            final sparkValues = records
                .map(_extractNumericValue)
                .where((v) => v > 0)
                .toList();

            if (sparkValues.length >= 2) {
              _dynamicSparkline = sparkValues;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
  }

  double _extractNumericValue(HealthDataRecord r) {
    final d = r.data;
    if (d is num) return d.toDouble();
    if (d is String) return double.tryParse(d) ?? 0;
    if (d is Map) {
      final v = d['value'] ??
          d['heart_rate'] ??
          d['hr'] ??
          d['spo2'] ??
          d['blood_oxygen'] ??
          d['steps'] ??
          d['count'] ??
          d['val'];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
    }
    return 0;
  }

  Future<void> _triggerLiveMeasurement() async {
    final imei = widget.imei;
    if (imei == null || imei.isEmpty) return;

    setState(() => _isMeasuring = true);
    try {
      await _deviceRepository.requestMeasurement(
        imei: imei,
        type: _getMeasurementTypeCode(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已發送測量指令，5 秒後自動刷新...', style: GoogleFonts.dmSans()),
            backgroundColor: AppColors.primary,
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        await _fetchMetricApiData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('發送測量指令失敗: $e', style: GoogleFonts.dmSans()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMeasuring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metric = widget.metric;
    final isPositive = metric.trendPercentage >= 0;
    final isGoodTrend = _isGoodTrend(metric.type, isPositive);
    
    String displayValue;
    if (metric.type == MetricType.heartRate) {
      if (_apiRecords.isNotEmpty) {
        final hrVals = _apiRecords.map(_extractNumericValue).where((v) => v > 0).toList();
        if (hrVals.isNotEmpty) {
          final minHr = hrVals.reduce(math.min).toInt();
          final maxHr = hrVals.reduce(math.max).toInt();
          displayValue = '$minHr - $maxHr';
        } else {
          displayValue = '62 - 134';
        }
      } else {
        displayValue = '62 - 134';
      }
    } else {
      displayValue = _latestApiValue ?? metric.value;
    }

    final sparkData = _dynamicSparkline ?? metric.sparklineData;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          metric.label,
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (widget.imei != null && widget.imei!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: _isLoadingApi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.primary),
                onPressed: _isLoadingApi ? null : _fetchMetricApiData,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Summary Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      metric.color.withOpacity(0.16),
                      AppColors.surfaceLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: metric.color.withOpacity(0.18),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: metric.gradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(metric.icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.label.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_latestApiValue != null)
                                Text(
                                  '已從設備 API 即時同步',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          displayValue,
                          style: GoogleFonts.dmSans(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          metric.unit,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (metric.secondaryValue != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: metric.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${metric.secondaryValue} ${metric.secondaryUnit ?? ''}',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: metric.color,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _getDescription(),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recent Trend Section
              Text(
                'Recent trend',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final apiTimestamps = _apiRecords.isNotEmpty
                      ? _apiRecords.map((r) {
                          final dt = r.dateTime;
                          final hh = dt.hour.toString().padLeft(2, '0');
                          final mm = dt.minute.toString().padLeft(2, '0');
                          return '$hh:$mm';
                        }).toList()
                      : null;

                  return Container(
                    height: 180,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: metric.color.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: CustomPaint(
                      painter: SparklinePainter(
                        data: sparkData,
                        timestamps: apiTimestamps,
                        lineColor: metric.color,
                        strokeWidth: 2.6,
                        animationProgress: 1.0,
                        isHeartRate: metric.type == MetricType.heartRate,
                      ),
                      size: const Size(double.infinity, 140),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Insight Cards
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Change',
                      value: '${isPositive ? '+' : ''}${metric.trendPercentage.toStringAsFixed(1)}%',
                      accentColor: isGoodTrend
                          ? const Color(0xFF30D158)
                          : const Color(0xFFFF9F0A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Status',
                      value: _statusLabel(metric.status),
                      accentColor: _statusColor(metric.status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInsightCard(
                title: 'Suggested focus',
                value: _getFocusTip(),
                accentColor: metric.color,
                isWide: true,
              ),

              // Heart Rate Zone Analysis Section
              if (metric.type == MetricType.heartRate) ...[
                const SizedBox(height: 20),
                _buildHrZoneAnalysisCard(_apiRecords, 32),
              ],

              // Action Buttons
              if (widget.imei != null && widget.imei!.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isMeasuring ? null : _triggerLiveMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: metric.color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isMeasuring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sensors_rounded),
                    label: Text(
                      _isMeasuring ? '正在發送測量指令...' : '立即發送測量指令 (Live)',
                      style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],

              if (metric.type == MetricType.bloodPressure ||
                  metric.label.toUpperCase() == 'BLOOD PRESSURE') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BloodPressurePage(
                            readings: generateMockBloodPressureReadings(),
                            imei: widget.imei,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bloodPressure,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_rounded),
                    label: Text(
                      '查看完整血壓分析與歷史趨勢',
                      style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required Color accentColor,
    bool isWide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.16), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: isWide ? 14 : 16,
              fontWeight: FontWeight.w700,
              color: accentColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _getDescription() {
    switch (widget.metric.type) {
      case MetricType.heartRate:
        return 'Your resting rhythm is staying in a healthy range. Keep hydration and light movement consistent for steady recovery.';
      case MetricType.bloodPressure:
        if (widget.metric.label.toUpperCase().contains('O₂') ||
            widget.metric.label.toUpperCase().contains('SPO2')) {
          return 'Blood oxygen saturation level indicates good respiratory health and blood oxygenation.';
        }
        return 'Blood pressure looks balanced today. Continue your routine and keep stress levels low before bedtime.';
      case MetricType.sleep:
        return 'Sleep quality is trending well. Aim for a consistent wind-down routine to maintain this recovery streak.';
      case MetricType.hrv:
        return 'HRV is slightly elevated, which can be a sign of good recovery. Keep your sleep and breathing habits consistent.';
      case MetricType.steps:
        return 'Activity is on track this week. A short walk after meals can help keep your momentum going.';
    }
  }

  String _getFocusTip() {
    switch (widget.metric.type) {
      case MetricType.heartRate:
        return 'Try a 10-minute breathing break after work to support a calm recovery pace.';
      case MetricType.bloodPressure:
        if (widget.metric.label.toUpperCase().contains('O₂') ||
            widget.metric.label.toUpperCase().contains('SPO2')) {
          return 'Maintain deep breathing exercises to keep oxygen saturation optimal.';
        }
        return 'Stay hydrated and avoid salty late-night snacks to keep it steady.';
      case MetricType.sleep:
        return 'Keep screens away 30 minutes before bed for a smoother night.';
      case MetricType.hrv:
        return 'A gentle stretch session can help your nervous system settle.';
      case MetricType.steps:
        return 'Add one extra walk around the block to build on today\'s progress.';
    }
  }

  String _statusLabel(MetricStatus status) {
    switch (status) {
      case MetricStatus.normal:
        return 'Normal';
      case MetricStatus.warning:
        return 'Needs attention';
      case MetricStatus.critical:
        return 'Critical';
    }
  }

  Color _statusColor(MetricStatus status) {
    switch (status) {
      case MetricStatus.normal:
        return const Color(0xFF30D158);
      case MetricStatus.warning:
        return const Color(0xFFFF9F0A);
      case MetricStatus.critical:
        return const Color(0xFFFF2D55);
    }
  }

  bool _isGoodTrend(MetricType type, bool isPositive) {
    switch (type) {
      case MetricType.heartRate:
        return !isPositive;
      case MetricType.steps:
        return isPositive;
      case MetricType.hrv:
        return isPositive;
      case MetricType.sleep:
        return isPositive;
      case MetricType.bloodPressure:
        return !isPositive;
    }
  }

  Widget _buildHrZoneAnalysisCard(List<HealthDataRecord> records, int age) {
    final maxHr = 220 - age;
    final lightMin = (maxHr * 0.50).round();
    final lightMax = (maxHr * 0.63).round();
    final modMin = (maxHr * 0.64).round();
    final modMax = (maxHr * 0.76).round();
    final vigMin = (maxHr * 0.77).round();
    final vigMax = (maxHr * 0.92).round();
    final peakMin = (maxHr * 0.93).round();
    final peakMax = maxHr;

    int restCount = 0;
    int lightCount = 0;
    int modCount = 0;
    int vigCount = 0;
    int peakCount = 0;

    if (records.isNotEmpty) {
      for (final r in records) {
        final val = _extractNumericValue(r);
        if (val <= 0) continue;
        if (val >= peakMin) {
          peakCount++;
        } else if (val >= vigMin) {
          vigCount++;
        } else if (val >= modMin) {
          modCount++;
        } else if (val >= lightMin) {
          lightCount++;
        } else {
          restCount++;
        }
      }
    } else {
      restCount = 28;
      lightCount = 8;
      modCount = 4;
      vigCount = 2;
      peakCount = 1;
    }

    final total = math.max(1, restCount + lightCount + modCount + vigCount + peakCount);

    String formatZoneTime(int count) {
      final totalMinutes = count * 12;
      if (totalMinutes < 60) return '${totalMinutes}m';
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }

    final restPct = (restCount / total * 100).round();
    final lightPct = (lightCount / total * 100).round();
    final modPct = (modCount / total * 100).round();
    final vigPct = (vigCount / total * 100).round();
    final peakPct = (peakCount / total * 100).round();

    final zones = [
      (
        name: 'Peak (發揮 / 極限)',
        range: '$peakMin - $peakMax bpm',
        pct: peakPct,
        timeStr: formatZoneTime(peakCount),
        color: const Color(0xFFE96B6B),
      ),
      (
        name: 'Vigorous (重度 / 無氧)',
        range: '$vigMin - $vigMax bpm',
        pct: vigPct,
        timeStr: formatZoneTime(vigCount),
        color: const Color(0xFFFFA24D),
      ),
      (
        name: 'Moderate (中度 / 有氧)',
        range: '$modMin - $modMax bpm',
        pct: modPct,
        timeStr: formatZoneTime(modCount),
        color: const Color(0xFF4CBF87),
      ),
      (
        name: 'Light (輕度 / 暖身)',
        range: '$lightMin - $lightMax bpm',
        pct: lightPct,
        timeStr: formatZoneTime(lightCount),
        color: const Color(0xFF5BB8F5),
      ),
      (
        name: 'Resting (靜息 / 恢復)',
        range: '< $lightMin bpm',
        pct: restPct,
        timeStr: formatZoneTime(restCount),
        color: const Color(0xFF6C7FEA),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.heartRate.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_rounded, color: AppColors.heartRate, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Spent in Heart Rate Zones',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Age $age • Max HR $maxHr bpm',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Multi-Segmented Time Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: zones.reversed.map((z) {
                  return Expanded(
                    flex: math.max(1, z.pct),
                    child: Container(color: z.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...zones.map((z) => _zoneTimeRow(z.name, z.range, z.timeStr, z.pct, z.color)),
        ],
      ),
    );
  }

  Widget _zoneTimeRow(String name, String range, String timeStr, int pct, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  range,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$pct%',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            timeStr,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
