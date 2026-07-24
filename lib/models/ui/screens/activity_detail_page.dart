import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';

class ActivityDetailPage extends StatefulWidget {
  final String? imei;

  const ActivityDetailPage({super.key, this.imei});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _barController;
  late Animation<double> _ringAnim;
  late Animation<double> _barAnim;

  // Mock daily stats
  static const double _stepsToday = 6543;
  static const double _stepsGoal = 10000;
  static const double _caloriesBurned = 368;
  static const double _distanceKm = 4.2;
  static const int _activeMinutes = 58;
  static const int _floorsClimbed = 12;

  // Hourly step distribution (mock)
  static const List<_HourlyStep> _hourlySteps = [
    _HourlyStep(hour: 6, steps: 200),
    _HourlyStep(hour: 7, steps: 850),
    _HourlyStep(hour: 8, steps: 1100),
    _HourlyStep(hour: 9, steps: 450),
    _HourlyStep(hour: 10, steps: 320),
    _HourlyStep(hour: 11, steps: 580),
    _HourlyStep(hour: 12, steps: 720),
    _HourlyStep(hour: 13, steps: 290),
    _HourlyStep(hour: 14, steps: 410),
    _HourlyStep(hour: 15, steps: 630),
    _HourlyStep(hour: 16, steps: 480),
    _HourlyStep(hour: 17, steps: 513),
  ];

  // Weekly steps (Mon–Sun)
  static const List<_DayStep> _weeklySteps = [
    _DayStep(day: 'Mon', steps: 7200),
    _DayStep(day: 'Tue', steps: 9100),
    _DayStep(day: 'Wed', steps: 5400),
    _DayStep(day: 'Thu', steps: 8300),
    _DayStep(day: 'Fri', steps: 6100),
    _DayStep(day: 'Sat', steps: 11200),
    _DayStep(day: 'Sun', steps: 6543),
  ];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ringAnim = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    _barAnim = CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _ringController.forward();
        _barController.forward();
      }
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHeader(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionHeader(
                  icon: Icons.speed_rounded,
                  title: "Today's Stats",
                  subtitle: 'Progress toward daily targets',
                  color: const Color(0xFF5E5CE6),
                ),
                const SizedBox(height: 12),
                _buildStatGrid(),

                const SizedBox(height: 20),
                _buildHourlyChart(),
                const SizedBox(height: 20),
                _buildWeeklyChart(),
                const SizedBox(height: 20),
                _buildHealthTips(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver hero header ──────────────────────────────────────────────────────

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.steps,
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
      title: Text(
        'Activity',
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
          colors: [Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative orbs
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Content
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated goal ring
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (context, _) {
                    return SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: _ActivityRingPainter(
                          progress: (_stepsToday / _stepsGoal) * _ringAnim.value,
                          trackColor: Colors.white.withOpacity(0.2),
                          ringColor: Colors.white,
                          strokeWidth: 10,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${((_stepsToday / _stepsGoal) * _ringAnim.value * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.dmSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'goal',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 24),
                // Step count headline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _numberFormat(_stepsToday.toInt()),
                        style: GoogleFonts.dmSans(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'steps today',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedBuilder(
                          animation: _ringAnim,
                          builder: (_, __) => LinearProgressIndicator(
                            value: (_stepsToday / _stepsGoal) * _ringAnim.value,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_numberFormat((_stepsGoal - _stepsToday).toInt())} steps remaining',
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

  // ── Stat bars card ────────────────────────────────────────────────────────

  Widget _buildStatGrid() => _buildStatBarsCard();

  Widget _buildStatBarsCard() {
    // Each bar defines its current value and the max (daily target)
    final bars = [
      _BarItem(
        icon: Icons.local_fire_department_rounded,
        label: 'Calories',
        value: _caloriesBurned,
        max: 500,
        unit: 'kcal',
        color: const Color(0xFFFF6B35),
      ),
      _BarItem(
        icon: Icons.route_rounded,
        label: 'Distance',
        value: _distanceKm,
        max: 8.0,
        unit: 'km',
        color: AppColors.bloodPressure,
      ),
      _BarItem(
        icon: Icons.timer_rounded,
        label: 'Active Time',
        value: _activeMinutes.toDouble(),
        max: 60,
        unit: 'min',
        color: const Color(0xFF5E5CE6),
      ),
      _BarItem(
        icon: Icons.stairs_rounded,
        label: 'Floors',
        value: _floorsClimbed.toDouble(),
        max: 20,
        unit: 'floors',
        color: const Color(0xFFFF9F0A),
      ),
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
          ...bars.asMap().entries.map((entry) {
            final i = entry.key;
            final b = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < bars.length - 1 ? 10 : 0),
              child: _buildBarRow(b),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBarRow(_BarItem b) {
    final pct = (b.value / b.max).clamp(0.0, 1.0);
    final displayValue = b.value == b.value.roundToDouble()
        ? b.value.toInt().toString()
        : b.value.toStringAsFixed(1);

    return Row(
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: b.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(b.icon, color: b.color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label + value
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    b.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: displayValue,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' ${b.unit}',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Animated bar
              AnimatedBuilder(
                animation: _barAnim,
                builder: (_, __) {
                  return Stack(
                    children: [
                      // Track
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: b.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      // Fill
                      FractionallySizedBox(
                        widthFactor: pct * _barAnim.value,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: b.color,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: b.color.withOpacity(0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 3),
              // Max label
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Goal: ${b.max == b.max.roundToDouble() ? b.max.toInt() : b.max.toStringAsFixed(1)} ${b.unit}',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  // ── Hourly bar chart ────────────────────────────────────────────────────────

  Widget _buildHourlyChart() {
    final maxSteps = _hourlySteps.map((h) => h.steps).reduce(math.max).toDouble();

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
            icon: Icons.bar_chart_rounded,
            title: 'Hourly Steps',
            subtitle: 'Activity distribution today',
            color: AppColors.steps,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: _barAnim,
              builder: (_, __) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _hourlySteps.map((h) {
                    final pct = h.steps / maxSteps;
                    final isActive = h.steps == _hourlySteps
                        .map((e) => e.steps)
                        .reduce(math.max);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              height: math.max(4, 90 * pct * _barAnim.value),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.steps
                                    : AppColors.steps.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${h.hour}',
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly trend chart ──────────────────────────────────────────────────────

  Widget _buildWeeklyChart() {
    final maxSteps = _weeklySteps.map((d) => d.steps).reduce(math.max).toDouble();
    final isToday = (idx) => idx == _weeklySteps.length - 1;

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
            icon: Icons.calendar_view_week_rounded,
            title: 'This Week',
            subtitle: 'Daily step totals',
            color: const Color(0xFF5E5CE6),
          ),
          const SizedBox(height: 8),
          // Goal line label
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 20,
                height: 2,
                color: AppColors.textTertiary.withOpacity(0.5),
                margin: const EdgeInsets.only(right: 6),
              ),
              Text(
                'Goal: ${_numberFormat(_stepsGoal.toInt())}',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _barAnim,
            builder: (_, __) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_weeklySteps.length, (i) {
                  final d = _weeklySteps[i];
                  final pct = d.steps / maxSteps;
                  final goalPct = _stepsGoal / maxSteps;
                  final metGoal = d.steps >= _stepsGoal;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isToday(i))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.steps.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _numberFormat(d.steps),
                                style: GoogleFonts.dmSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.steps,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 16),
                          const SizedBox(height: 4),
                          Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // Background track
                              Container(
                                height: 80,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F6FA),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              // Goal dashed line (visual only via opacity)
                              Positioned(
                                bottom: 80 * goalPct,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1,
                                  color: AppColors.textTertiary.withOpacity(0.3),
                                ),
                              ),
                              // Fill bar
                              Container(
                                height: math.max(4, 80 * pct * _barAnim.value),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isToday(i)
                                      ? AppColors.steps
                                      : metGoal
                                          ? const Color(0xFF30D158)
                                          : const Color(0xFFB0BEC5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.day,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: isToday(i)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isToday(i)
                                  ? AppColors.steps
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 14),
          // Weekly summary chips
          Row(
            children: [
              _weekChip(
                label: 'Avg / day',
                value: _numberFormat(
                  (_weeklySteps.map((d) => d.steps).reduce((a, b) => a + b) ~/
                          _weeklySteps.length),
                ),
                color: const Color(0xFF5E5CE6),
              ),
              const SizedBox(width: 10),
              _weekChip(
                label: 'Goals met',
                value:
                    '${_weeklySteps.where((d) => d.steps >= _stepsGoal).length}/${_weeklySteps.length}',
                color: const Color(0xFF30D158),
              ),
              const SizedBox(width: 10),
              _weekChip(
                label: 'Best day',
                value: _numberFormat(
                    _weeklySteps.map((d) => d.steps).reduce(math.max)),
                color: const Color(0xFFFF9F0A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Health tips ─────────────────────────────────────────────────────────────

  Widget _buildHealthTips() {
    final tips = [
      _Tip(
        icon: Icons.directions_walk_rounded,
        title: '3,457 more steps to goal',
        body: 'A 25-minute walk burns those remaining steps. Try a loop around the block after dinner.',
        color: AppColors.steps,
      ),
      _Tip(
        icon: Icons.local_fire_department_rounded,
        title: 'Calorie burn on track',
        body: '368 kcal burned today. Add a 15-min brisk walk to reach your 500 kcal target.',
        color: const Color(0xFFFF6B35),
      ),
      _Tip(
        icon: Icons.bedtime_rounded,
        title: 'Active minutes boost sleep',
        body: '58 active minutes helps deepen sleep quality. Keep the momentum through the week.',
        color: const Color(0xFF5E5CE6),
      ),
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
            icon: Icons.lightbulb_rounded,
            title: 'Health Insights',
            subtitle: 'Personalised tips',
            color: const Color(0xFFFF9F0A),
          ),
          const SizedBox(height: 16),
          ...tips.map((t) => _buildTipRow(t)).toList(),
        ],
      ),
    );
  }

  Widget _buildTipRow(_Tip t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(t.icon, color: t.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.body,
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

  // ── Shared helpers ──────────────────────────────────────────────────────────

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
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _numberFormat(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Data models ─────────────────────────────────────────────────────────────

class _HourlyStep {
  final int hour;
  final int steps;
  const _HourlyStep({required this.hour, required this.steps});
}

class _DayStep {
  final String day;
  final int steps;
  const _DayStep({required this.day, required this.steps});
}

class _BarItem {
  final IconData icon;
  final String label;
  final double value;
  final double max;
  final String unit;
  final Color color;
  const _BarItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    required this.color,
  });
}

class _Tip {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const _Tip({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}

// ── Custom ring painter ──────────────────────────────────────────────────────

class _ActivityRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color ringColor;
  final double strokeWidth;

  const _ActivityRingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Arc
    final arcPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ActivityRingPainter old) => old.progress != progress;
}
