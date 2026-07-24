import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'hypnogram_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sleep Screen (SleepDetailPage)
// ─────────────────────────────────────────────────────────────────────────────

class SleepDetailPage extends StatefulWidget {
  final String? imei;
  final int? totalMinutes;
  final String? sleepQuality;
  final int? qualityScore;
  final String? startTimeStr;
  final String? endTimeStr;
  final List<SleepSegment>? segments;

  const SleepDetailPage({
    super.key,
    this.imei,
    this.totalMinutes,
    this.sleepQuality,
    this.qualityScore,
    this.startTimeStr,
    this.endTimeStr,
    this.segments,
  });

  @override
  State<SleepDetailPage> createState() => _SleepDetailPageState();
}

class _SleepDetailPageState extends State<SleepDetailPage> {
  final DeviceRepository _repo = DeviceRepository();
  bool showHR = false;
  bool showSpo2 = false;
  bool isMeasuring = false;

  late int _totalMinutes;
  late String _qualityText;
  late int _score;
  late String _startTime;
  late String _endTime;
  late List<SleepSegment> _sleepSegments;

  @override
  void initState() {
    super.initState();
    _totalMinutes = widget.totalMinutes ?? 538; // 8h 58m
    _qualityText = widget.sleepQuality ?? "Excellent";
    _score = widget.qualityScore ?? 88;
    _startTime = widget.startTimeStr ?? "Jul 14, 21:34";
    _endTime = widget.endTimeStr ?? "Jul 15, 06:32";
    _sleepSegments = widget.segments ??
        const [
          SleepSegment(stage: SleepStage.light, durationMinutes: 30),
          SleepSegment(stage: SleepStage.deep, durationMinutes: 110),
          SleepSegment(stage: SleepStage.light, durationMinutes: 90),
          SleepSegment(stage: SleepStage.rem, durationMinutes: 75),
          SleepSegment(stage: SleepStage.light, durationMinutes: 60),
          SleepSegment(stage: SleepStage.awake, durationMinutes: 15),
          SleepSegment(stage: SleepStage.deep, durationMinutes: 80),
          SleepSegment(stage: SleepStage.light, durationMinutes: 45),
          SleepSegment(stage: SleepStage.rem, durationMinutes: 33),
        ];
  }

  Future<void> _requestSleepMeasurement() async {
    final imei = widget.imei;
    setState(() => isMeasuring = true);
    try {
      if (imei != null && imei.isNotEmpty) {
        await _repo.requestMeasurement(imei: imei, type: 'heart-rate');
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sleep data refreshed',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isMeasuring = false);
    }
  }

  // Calculate duration breakdown per stage
  Map<SleepStage, int> _calculateStageMinutes() {
    final Map<SleepStage, int> map = {
      SleepStage.deep: 0,
      SleepStage.light: 0,
      SleepStage.rem: 0,
      SleepStage.awake: 0,
    };
    for (final s in _sleepSegments) {
      map[s.stage] = (map[s.stage] ?? 0) + s.durationMinutes;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final h = _totalMinutes ~/ 60;
    final m = _totalMinutes % 60;
    final stageMinutes = _calculateStageMinutes();
    final totalSegMins = stageMinutes.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Sleep Monitoring",
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: isMeasuring
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : GestureDetector(
                    onTap: _requestSleepMeasurement,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sync_rounded,
                              color: Colors.white, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            'Refresh',
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────────────
            // 1. HERO SLEEP SUMMARY CARD (Duration + Quality + Start/End)
            // ─────────────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B3B36), Color(0xFF2E6D5D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.bedtime_rounded,
                              color: Color(0xFF7DE0A5),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Sleep Overview",
                            style: GoogleFonts.dmSans(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Quality Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CBF87).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF7DE0A5).withOpacity(0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFF7DE0A5), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "$_qualityText ($_score)",
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Big Sleep Duration
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "${h}h ${m}m",
                          style: GoogleFonts.dmSans(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: " Total Sleep",
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),

                  // Start and End Sleep Time
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: Color(0xFF7DE0A5), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "$_startTime  ➔  $_endTime",
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────────
            // 2. HYPNOGRAM CHART CARD (Awake, REM, Light, Deep stages)
            // ─────────────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                  // Title + HR/SpO2 Toggles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Sleep Stage Hypnogram",
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          _filterChip("HR", showHR, (v) {
                            setState(() => showHR = v);
                          }),
                          const SizedBox(width: 6),
                          _filterChip("SpO₂", showSpo2, (v) {
                            setState(() => showSpo2 = v);
                          }),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stage Legend Row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LegendItem(color: Color(0xFFFF9F43), label: "Awake"),
                      LegendItem(color: Color(0xFFAB68E8), label: "REM"),
                      LegendItem(color: Color(0xFF5BB8F5), label: "Light"),
                      LegendItem(color: Color(0xFF3B4FC8), label: "Deep"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Hypnogram CustomPaint
                  Hypnogram(segments: _sleepSegments),

                  const SizedBox(height: 12),

                  // Time axis labels below hypnogram
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _startTime.split(',').last.trim(),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        "02:00",
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        _endTime.split(',').last.trim(),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────────
            // 3. STAGE BREAKDOWN GRID
            // ─────────────────────────────────────────────────────────────────
            Text(
              "Sleep Stage Breakdown",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _stageTile(
                    label: "Deep Sleep",
                    minutes: stageMinutes[SleepStage.deep] ?? 0,
                    totalMinutes: totalSegMins,
                    color: const Color(0xFF3B4FC8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stageTile(
                    label: "Light Sleep",
                    minutes: stageMinutes[SleepStage.light] ?? 0,
                    totalMinutes: totalSegMins,
                    color: const Color(0xFF5BB8F5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _stageTile(
                    label: "REM Sleep",
                    minutes: stageMinutes[SleepStage.rem] ?? 0,
                    totalMinutes: totalSegMins,
                    color: const Color(0xFFAB68E8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stageTile(
                    label: "Awake Time",
                    minutes: stageMinutes[SleepStage.awake] ?? 0,
                    totalMinutes: totalSegMins,
                    color: const Color(0xFFFF9F43),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────────
            // 4. SLEEP VITALS & STATS
            // ─────────────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                  Text(
                    "Sleep Vitals & Metrics",
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SleepDonut(totalMinutes: _totalMinutes),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            InfoTile(title: "Avg Heart Rate", value: "70.7 bpm"),
                            SizedBox(height: 12),
                            InfoTile(title: "Min Heart Rate", value: "61 bpm"),
                            SizedBox(height: 12),
                            InfoTile(title: "Avg SpO₂", value: "97.5 %"),
                            SizedBox(height: 12),
                            InfoTile(title: "HRV (RMSSD)", value: "49.4 ms"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: value ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _stageTile({
    required String label,
    required int minutes,
    required int totalMinutes,
    required Color color,
  }) {
    final pct = totalMinutes > 0 ? (minutes / totalMinutes * 100) : 0.0;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final timeStr = h > 0 ? "${h}h ${m}m" : "${m}m";

    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                timeStr,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                "${pct.toStringAsFixed(0)}%",
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.15),
              color: color,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend Item
// ─────────────────────────────────────────────────────────────────────────────

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Tile
// ─────────────────────────────────────────────────────────────────────────────

class InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const InfoTile({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleep Donut
// ─────────────────────────────────────────────────────────────────────────────

class SleepDonut extends StatelessWidget {
  final int totalMinutes;

  const SleepDonut({
    super.key,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    return Center(
      child: SizedBox(
        width: 105,
        height: 105,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: DonutPainter(),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${h}h ${m}m",
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    "Sleep",
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (side - 16) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      rect,
      0,
      6.283185307179586,
      false,
      backgroundPaint,
    );

    final progressPaint = Paint()
      ..color = AppColors.sleep
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -1.5707963267948966,
      5.2,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SLEEP WIDGET (SleepOverviewCard)
// ─────────────────────────────────────────────────────────────────────────────

class SleepOverviewCard extends StatefulWidget {
  final String? imei;
  final int? totalMinutes;
  final String? sleepQuality;
  final int? qualityScore;
  final String? startTimeStr;
  final String? endTimeStr;
  final List<SleepSegment>? segments;

  const SleepOverviewCard({
    super.key,
    this.imei,
    this.totalMinutes,
    this.sleepQuality = "Excellent",
    this.qualityScore = 88,
    this.startTimeStr = "Jul 14, 21:34",
    this.endTimeStr = "Jul 15, 06:32",
    this.segments,
  });

  @override
  State<SleepOverviewCard> createState() => _SleepOverviewCardState();
}

class _SleepOverviewCardState extends State<SleepOverviewCard> {
  @override
  Widget build(BuildContext context) {
    final sample = widget.segments ??
        const [
          SleepSegment(stage: SleepStage.light, durationMinutes: 30),
          SleepSegment(stage: SleepStage.deep, durationMinutes: 110),
          SleepSegment(stage: SleepStage.light, durationMinutes: 90),
          SleepSegment(stage: SleepStage.rem, durationMinutes: 75),
          SleepSegment(stage: SleepStage.light, durationMinutes: 60),
          SleepSegment(stage: SleepStage.awake, durationMinutes: 15),
          SleepSegment(stage: SleepStage.deep, durationMinutes: 80),
          SleepSegment(stage: SleepStage.light, durationMinutes: 45),
          SleepSegment(stage: SleepStage.rem, durationMinutes: 33),
        ];

    final total = widget.totalMinutes ??
        sample.fold<int>(0, (p, e) => p + e.durationMinutes);
    final hours = total ~/ 60;
    final mins = total % 60;

    final quality = widget.sleepQuality ?? "Excellent";
    final score = widget.qualityScore ?? 88;
    final startTime = widget.startTimeStr ?? "Jul 14, 21:34";
    final endTime = widget.endTimeStr ?? "Jul 15, 06:32";

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SleepDetailPage(
              imei: widget.imei,
              totalMinutes: total,
              sleepQuality: quality,
              qualityScore: score,
              startTimeStr: startTime,
              endTimeStr: endTime,
              segments: sample,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.sleep.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.sleepGlow.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppColors.sleepGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bedtime_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SLEEP',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '$startTime - $endTime',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quality Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.sleep.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.sleep, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '$quality ($score)',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Duration & Vitals Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${hours}h ${mins}m',
                    style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'total sleep',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Mini Hypnogram Preview
              SizedBox(
                height: 90,
                child: Hypnogram(segments: sample),
              ),

              const SizedBox(height: 12),

              // Bottom stage legend summary
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LegendItem(color: Color(0xFFFF9F43), label: "Awake"),
                  LegendItem(color: Color(0xFFAB68E8), label: "REM"),
                  LegendItem(color: Color(0xFF5BB8F5), label: "Light"),
                  LegendItem(color: Color(0xFF3B4FC8), label: "Deep"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}