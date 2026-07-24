import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/models/health_data_record.dart';

class TemperatureDetailPage extends StatefulWidget {
  final String? imei;
  final double initialTemp;

  const TemperatureDetailPage({
    super.key,
    this.imei,
    this.initialTemp = 36.6,
  });

  @override
  State<TemperatureDetailPage> createState() => _TemperatureDetailPageState();
}

class _TemperatureDetailPageState extends State<TemperatureDetailPage>
    with TickerProviderStateMixin {
  final DeviceRepository _deviceRepository = DeviceRepository();

  late AnimationController _entryController;
  late AnimationController _ringController;
  late Animation<double> _entryAnim;
  late Animation<double> _ringAnim;

  bool _isLoading = false;
  bool _isMeasuring = false;
  double _currentTemp = 36.6;
  List<_TempRecord> _history = [];

  // Colour zones
  static const Color _hypothermiaColor = Color(0xFF5BB8F5);
  static const Color _normalColor = Color(0xFF30D158);
  static const Color _elevatedColor = Color(0xFFFF9F0A);
  static const Color _feverColor = Color(0xFFFF453A);

  // Mock 24-h history (°C per hour)
  static final List<_TempRecord> _mockHistory = [
    _TempRecord(hour: 0, temp: 36.1),
    _TempRecord(hour: 2, temp: 35.9),
    _TempRecord(hour: 4, temp: 36.0),
    _TempRecord(hour: 6, temp: 36.3),
    _TempRecord(hour: 8, temp: 36.6),
    _TempRecord(hour: 10, temp: 36.8),
    _TempRecord(hour: 12, temp: 37.0),
    _TempRecord(hour: 14, temp: 37.2),
    _TempRecord(hour: 16, temp: 36.9),
    _TempRecord(hour: 18, temp: 36.7),
    _TempRecord(hour: 20, temp: 36.6),
    _TempRecord(hour: 22, temp: 36.4),
  ];

  @override
  void initState() {
    super.initState();
    _currentTemp = widget.initialTemp;
    _history = _mockHistory;

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _entryAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
    _ringAnim = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);

    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ringController.forward();
    });

    if (widget.imei != null && widget.imei!.isNotEmpty) {
      _fetchData();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final records = await _deviceRepository.fetchHealthData(
        imei: widget.imei!,
        type: 'BT',
      );
      if (records.isNotEmpty && mounted) {
        records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final latest = records.last;
        final val = _extractTemp(latest);
        if (val != null) setState(() => _currentTemp = val);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  double? _extractTemp(HealthDataRecord r) {
    final d = r.data;
    if (d is num) return d.toDouble();
    if (d is String) return double.tryParse(d);
    if (d is Map) {
      final raw = d['temp'] ?? d['temperature'] ?? d['body_temp'] ?? d['value'];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw);
    }
    return null;
  }

  Future<void> _requestMeasurement() async {
    if (widget.imei == null || widget.imei!.isEmpty) return;
    setState(() => _isMeasuring = true);
    try {
      await _deviceRepository.requestMeasurement(
        imei: widget.imei!,
        type: 'body-temperature',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('測量指令已發送，5 秒後刷新...', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFFF9F0A),
        ));
      }
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('發送失敗: $e', style: GoogleFonts.dmSans()),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isMeasuring = false);
    }
  }

  // ── Temperature helpers ────────────────────────────────────────────────────

  _TempZone get _zone {
    if (_currentTemp < 35.0) return _TempZone.hypothermia;
    if (_currentTemp <= 37.3) return _TempZone.normal;
    if (_currentTemp <= 38.0) return _TempZone.elevated;
    return _TempZone.fever;
  }

  Color get _zoneColor {
    switch (_zone) {
      case _TempZone.hypothermia: return _hypothermiaColor;
      case _TempZone.normal:      return _normalColor;
      case _TempZone.elevated:    return _elevatedColor;
      case _TempZone.fever:       return _feverColor;
    }
  }

  String get _zoneLabel {
    switch (_zone) {
      case _TempZone.hypothermia: return 'Hypothermia';
      case _TempZone.normal:      return 'Normal';
      case _TempZone.elevated:    return 'Slightly Elevated';
      case _TempZone.fever:       return 'Fever';
    }
  }

  String get _zoneTip {
    switch (_zone) {
      case _TempZone.hypothermia:
        return 'Temperature is below normal. Warm up and monitor closely. Seek medical advice if it persists.';
      case _TempZone.normal:
        return 'Temperature is in the healthy range. Keep hydrated and maintain regular activity.';
      case _TempZone.elevated:
        return 'Slightly above normal. Rest, increase fluid intake, and monitor every few hours.';
      case _TempZone.fever:
        return 'Temperature indicates fever. Rest, stay hydrated, and consult a healthcare professional.';
    }
  }

  /// Maps 35–40 °C onto 0–1 for the gauge ring
  double get _ringProgress => ((_currentTemp - 35.0) / 5.0).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHeader(context),
          SliverFadeTransition(
            opacity: _entryAnim,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  _buildZoneLegend(),
                  const SizedBox(height: 20),
                  _buildTrendChart(),
                  const SizedBox(height: 20),
                  _buildTip(),
                  if (widget.imei != null && widget.imei!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildMeasureButton(),
                  ],
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver app bar ──────────────────────────────────────────────────────────

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFFFF9F0A),
      leading: IconButton(
        icon: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 15),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
          )
        else if (widget.imei != null && widget.imei!.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchData,
          ),
      ],
      title: Text(
        'Body Temperature',
        style: GoogleFonts.dmSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildHeroBackground(),
      ),
    );
  }

  Widget _buildHeroBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF9F0A), Color(0xFFFFCC02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40, right: -30,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 10, left: -50,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Hero content
          Positioned(
            bottom: 24, left: 24, right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated gauge ring
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, __) => SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _TempGaugePainter(
                        progress: _ringProgress * _ringAnim.value,
                        trackColor: Colors.white.withOpacity(0.2),
                        fillColor: Colors.white,
                        strokeWidth: 9,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentTemp.toStringAsFixed(1),
                              style: GoogleFonts.dmSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '°C',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentTemp.toStringAsFixed(1)} °C',
                        style: GoogleFonts.dmSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _zoneLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Range: 35.0 – 40.0 °C',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white60,
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

  // ── Status stats card ────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final min = _history.map((r) => r.temp).reduce(math.min);
    final max = _history.map((r) => r.temp).reduce(math.max);
    final avg = _history.map((r) => r.temp).reduce((a, b) => a + b) /
        _history.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          _sectionHeader(
            icon: Icons.thermostat_rounded,
            title: "Today's Summary",
            subtitle: 'Last 24 hours',
            color: const Color(0xFFFF9F0A),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statChip('Min', '${min.toStringAsFixed(1)} °C', _hypothermiaColor)),
              const SizedBox(width: 10),
              Expanded(child: _statChip('Avg', '${avg.toStringAsFixed(1)} °C', _normalColor)),
              const SizedBox(width: 10),
              Expanded(child: _statChip('Max', '${max.toStringAsFixed(1)} °C', _elevatedColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Zone legend ───────────────────────────────────────────────────────────

  Widget _buildZoneLegend() {
    final zones = [
      _ZoneDef('< 35.0°C', 'Hypothermia', _hypothermiaColor),
      _ZoneDef('35.0–37.3°C', 'Normal', _normalColor),
      _ZoneDef('37.4–38.0°C', 'Elevated', _elevatedColor),
      _ZoneDef('> 38.0°C', 'Fever', _feverColor),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          _sectionHeader(
            icon: Icons.legend_toggle_rounded,
            title: 'Temperature Zones',
            subtitle: 'Clinical reference',
            color: const Color(0xFF5E5CE6),
          ),
          const SizedBox(height: 16),
          // Gradient bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_hypothermiaColor, _normalColor, _elevatedColor, _feverColor],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: zones.map((z) {
              final isCurrent = z.label == _zoneLabel;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isCurrent ? z.color : z.color.withOpacity(0.35),
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: z.color, width: 2)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      z.range,
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      z.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                        color: isCurrent ? z.color : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 24-h trend chart ──────────────────────────────────────────────────────

  Widget _buildTrendChart() {
    final temps = _history.map((r) => r.temp).toList();
    final minT = temps.reduce(math.min) - 0.5;
    final maxT = temps.reduce(math.max) + 0.5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          _sectionHeader(
            icon: Icons.show_chart_rounded,
            title: '24-Hour Trend',
            subtitle: 'Temperature over time',
            color: const Color(0xFFFF9F0A),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _entryAnim,
            builder: (_, __) => SizedBox(
              height: 130,
              child: CustomPaint(
                size: const Size(double.infinity, 130),
                painter: _TempLinePainter(
                  records: _history,
                  minY: minT,
                  maxY: maxT,
                  lineColor: _zoneColor,
                  progress: _entryAnim.value,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Hour labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _history
                .where((r) => r.hour % 6 == 0)
                .map((r) => Text(
                      '${r.hour.toString().padLeft(2, '0')}:00',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Health tip ────────────────────────────────────────────────────────────

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _zoneColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zoneColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _zoneColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lightbulb_rounded, color: _zoneColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _zoneLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _zoneColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _zoneTip,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Measure button ────────────────────────────────────────────────────────

  Widget _buildMeasureButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isMeasuring ? null : _requestMeasurement,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9F0A),
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
            : const Icon(Icons.device_thermostat_rounded),
        label: Text(
          _isMeasuring ? '發送量測指令中...' : '立即量測體溫 (Live)',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            Text(subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                )),
          ],
        ),
      ],
    );
  }
}

// ── Enums & data models ──────────────────────────────────────────────────────

enum _TempZone { hypothermia, normal, elevated, fever }

class _TempRecord {
  final int hour;
  final double temp;
  const _TempRecord({required this.hour, required this.temp});
}

class _ZoneDef {
  final String range;
  final String label;
  final Color color;
  const _ZoneDef(this.range, this.label, this.color);
}

// ── Custom painters ──────────────────────────────────────────────────────────

class _TempGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  const _TempGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TempGaugePainter old) => old.progress != progress;
}

class _TempLinePainter extends CustomPainter {
  final List<_TempRecord> records;
  final double minY;
  final double maxY;
  final Color lineColor;
  final double progress;

  const _TempLinePainter({
    required this.records,
    required this.minY,
    required this.maxY,
    required this.lineColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final xStep = size.width / (records.length - 1);
    final yRange = maxY - minY;

    double yPos(double t) =>
        size.height - ((t - minY) / yRange * size.height).clamp(0.0, size.height);

    final points = List.generate(records.length, (i) {
      return Offset(i * xStep, yPos(records[i].temp));
    });

    // Draw up to progress
    final visibleCount = (points.length * progress).ceil().clamp(1, points.length);

    // Gradient fill under line
    final fillPath = Path()..moveTo(points[0].dx, size.height);
    for (int i = 0; i < visibleCount; i++) fillPath.lineTo(points[i].dx, points[i].dy);
    fillPath.lineTo(points[visibleCount - 1].dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.2), lineColor.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < visibleCount; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cx = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dot at latest point
    if (visibleCount > 0) {
      final last = points[visibleCount - 1];
      canvas.drawCircle(last, 5, Paint()..color = lineColor);
      canvas.drawCircle(last, 3, Paint()..color = Colors.white);
    }

    // Dotted normal-zone reference lines
    final normalPaint = Paint()
      ..color = const Color(0xFF30D158).withOpacity(0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final t in [35.0, 37.3]) {
      final y = yPos(t);
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), normalPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_TempLinePainter old) =>
      old.progress != progress || old.records != records;
}
