import 'package:flutter/material.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/ui/widgets/sparkline_painter.dart';
import 'package:tane06_app/theme/app_theme.dart';

class MetricDetailPage extends StatelessWidget {
  final HealthMetric metric;

  const MetricDetailPage({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    final isPositive = metric.trendPercentage >= 0;
    final isGoodTrend = _isGoodTrend(metric.type, isPositive);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          child: Text(
                            metric.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.textSecondary,
                            ),
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
                          metric.value,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          metric.unit,
                          style: const TextStyle(
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
                          style: TextStyle(
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Recent trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                    data: metric.sparklineData,
                    lineColor: metric.color,
                    strokeWidth: 2.6,
                    animationProgress: 1.0,
                  ),
                  size: const Size(double.infinity, 140),
                ),
              ),
              const SizedBox(height: 20),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
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
    switch (metric.type) {
      case MetricType.heartRate:
        return 'Your resting rhythm is staying in a healthy range. Keep hydration and light movement consistent for steady recovery.';
      case MetricType.bloodPressure:
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
    switch (metric.type) {
      case MetricType.heartRate:
        return 'Try a 10-minute breathing break after work to support a calm recovery pace.';
      case MetricType.bloodPressure:
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
}
