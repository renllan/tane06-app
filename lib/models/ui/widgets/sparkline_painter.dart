import 'package:flutter/material.dart';
import 'dart:math' as math;

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;
  final double animationProgress;

  SparklinePainter({
    required this.data,
    required this.lineColor,
    Color? fillColor,
    this.strokeWidth = 2.0,
    this.animationProgress = 1.0,
  }) : fillColor = fillColor ?? lineColor.withOpacity(0.15);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double minVal = data.reduce(math.min);
    final double maxVal = data.reduce(math.max);
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final animatedCount = (data.length * animationProgress).ceil();
    const padding = 4.0;

    for (int i = 0; i < animatedCount; i++) {
      final x = i / (data.length - 1) * (size.width - padding * 2) + padding;
      final y = size.height -
          padding -
          ((data[i] - minVal) / range) * (size.height - padding * 2);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve using cubic bezier
        final prevX =
            (i - 1) / (data.length - 1) * (size.width - padding * 2) + padding;
        final prevY = size.height -
            padding -
            ((data[i - 1] - minVal) / range) * (size.height - padding * 2);
        final controlX1 = prevX + (x - prevX) / 2;
        final controlX2 = prevX + (x - prevX) / 2;
        path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        fillPath.cubicTo(controlX1, prevY, controlX2, y, x, y);
      }
    }

    if (animatedCount > 0) {
      final lastX = (animatedCount - 1) /
              (data.length - 1) *
              (size.width - padding * 2) +
          padding;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw glow dot at the last point
    if (animatedCount > 0 && animationProgress >= 1.0) {
      final lastIdx = animatedCount - 1;
      final dotX =
          lastIdx / (data.length - 1) * (size.width - padding * 2) + padding;
      final dotY = size.height -
          padding -
          ((data[lastIdx] - minVal) / range) * (size.height - padding * 2);

      // Outer glow
      canvas.drawCircle(
        Offset(dotX, dotY),
        6,
        Paint()..color = lineColor.withOpacity(0.3),
      );
      // Inner dot
      canvas.drawCircle(
        Offset(dotX, dotY),
        3,
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.data != data;
  }
}
