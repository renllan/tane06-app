import 'package:flutter/material.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/ui/screens/metric_detail_page.dart';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';
import 'package:tane06_app/models/mock_blood_pressure_data.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/ui/widgets/sparkline_painter.dart';

class MetricCard extends StatefulWidget {
  final HealthMetric metric;
  final bool isLarge;
  final int animationDelay;
  final VoidCallback? onTap;
  final String? imei;

  const MetricCard({
    super.key,
    required this.metric,
    this.isLarge = false,
    this.animationDelay = 0,
    this.onTap,
    this.imei,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _sparklineController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _sparklineController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) {
        _fadeController.forward();
        _sparklineController.forward();
        if (widget.metric.type == MetricType.heartRate) {
          _pulseController.repeat(reverse: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _sparklineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.metric.color.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.metric.glowColor.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: widget.metric.color.withOpacity(0.1),
              highlightColor: widget.metric.color.withOpacity(0.05),
              onTap: widget.onTap ??
                  () {
                    if (widget.metric.label.toUpperCase() == 'BLOOD PRESSURE' ||
                        (widget.metric.type == MetricType.bloodPressure &&
                            widget.metric.label == 'Blood Pressure')) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BloodPressurePage(
                            imei: widget.imei,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MetricDetailPage(metric: widget.metric),
                        ),
                      );
                    }
                  },
              child: Padding(
                padding: EdgeInsets.all(widget.isLarge ? 20 : 16),
                child: widget.isLarge
                    ? _buildLargeCardContent()
                    : _buildSmallCardContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildValueRow(),
        const SizedBox(height: 16),
        Expanded(child: _buildSparkline()),
        const SizedBox(height: 8),
        _buildTrendRow(),
      ],
    );
  }

  Widget _buildSmallCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildValueRow(),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: _buildSparkline(),
        ),
        const SizedBox(height: 8),
        _buildTrendRow(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildIconContainer(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.metric.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildStatusDot(),
      ],
    );
  }

  Widget _buildIconContainer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = widget.metric.type == MetricType.heartRate
            ? 1.0 + (_pulseController.value * 0.1)
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: widget.metric.gradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: widget.metric.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              widget.metric.icon,
              color: Colors.white,
              size: 18,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusDot() {
    Color dotColor;
    switch (widget.metric.status) {
      case MetricStatus.normal:
        dotColor = const Color(0xFF30D158);
        break;
      case MetricStatus.warning:
        dotColor = const Color(0xFFFF9F0A);
        break;
      case MetricStatus.critical:
        dotColor = const Color(0xFFFF2D55);
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: dotColor.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildValueRow() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            widget.metric.value,
            style: TextStyle(
              fontSize: widget.isLarge ? 36 : 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              widget.metric.unit,
              style: TextStyle(
                fontSize: widget.isLarge ? 14 : 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (widget.metric.secondaryValue != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.metric.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.metric.secondaryValue} ${widget.metric.secondaryUnit ?? ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.metric.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSparkline() {
    return AnimatedBuilder(
      animation: _sparklineController,
      builder: (context, child) {
        return CustomPaint(
          painter: SparklinePainter(
            data: widget.metric.sparklineData,
            lineColor: widget.metric.color,
            strokeWidth: widget.isLarge ? 2.5 : 2.0,
            animationProgress: CurvedAnimation(
              parent: _sparklineController,
              curve: Curves.easeInOut,
            ).value,
            isHeartRate: widget.metric.type == MetricType.heartRate,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildTrendRow() {
    final isPositive = widget.metric.trendPercentage >= 0;
    // For some metrics, going down is good (e.g., resting HR)
    final isGoodTrend = _isGoodTrend(widget.metric.type, isPositive);

    return Row(
      children: [
        Icon(
          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: isGoodTrend ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${widget.metric.trendPercentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                isGoodTrend ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            widget.metric.trendLabel,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  bool _isGoodTrend(MetricType type, bool isPositive) {
    switch (type) {
      case MetricType.heartRate:
        return !isPositive; // Lower resting HR is better
      case MetricType.steps:
        return isPositive; // More steps is better
      case MetricType.hrv:
        return isPositive; // Higher HRV is better
      case MetricType.sleep:
        return isPositive; // More sleep is better
      case MetricType.bloodPressure:
        return !isPositive; // Lower BP is better
    }
  }
}
