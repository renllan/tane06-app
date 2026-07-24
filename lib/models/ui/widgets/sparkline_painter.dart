import 'package:flutter/material.dart';
import 'dart:math' as math;

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final List<String>? timestamps;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;
  final double animationProgress;
  final bool isHeartRate;
  final int age;

  SparklinePainter({
    required this.data,
    this.timestamps,
    required this.lineColor,
    Color? fillColor,
    this.strokeWidth = 2.0,
    this.animationProgress = 1.0,
    this.isHeartRate = false,
    this.age = 32,
  }) : fillColor = fillColor ?? lineColor.withOpacity(0.15);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double minVal = isHeartRate ? math.min(data.reduce(math.min), 55.0) : data.reduce(math.min);
    final double maxVal = isHeartRate ? math.max(data.reduce(math.max), 188.0) : data.reduce(math.max);
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    const padding = 6.0;
    final bottomMargin = (timestamps != null && timestamps!.isNotEmpty) ? 22.0 : 0.0;
    final chartHeight = size.height - bottomMargin;

    double getY(double val) {
      return chartHeight - padding - ((val - minVal) / range) * (chartHeight - padding * 2);
    }

    // 1. Draw Google Health Style Heart Rate Zone Shaded Background Bands & Labels
    if (isHeartRate) {
      final maxHr = 220 - age;
      final lightMin = (maxHr * 0.50).roundToDouble();
      final modMin = (maxHr * 0.64).roundToDouble();
      final vigMin = (maxHr * 0.77).roundToDouble();
      final peakMin = (maxHr * 0.93).roundToDouble();

      final zones = [
        (peakMin, maxVal, const Color(0xFFE96B6B), 'PEAK'),
        (vigMin, peakMin, const Color(0xFFFFA24D), 'VIGOROUS'),
        (modMin, vigMin, const Color(0xFF4CBF87), 'MODERATE'),
        (lightMin, modMin, const Color(0xFF5BB8F5), 'LIGHT'),
        (minVal, lightMin, const Color(0xFF6C7FEA), 'REST'),
      ];

      for (final zone in zones) {
        final yTop = getY(zone.$2).clamp(0.0, size.height);
        final yBottom = getY(zone.$1).clamp(0.0, size.height);
        if (yBottom > yTop) {
          // Shaded band
          final rect = Rect.fromLTRB(0, yTop, size.width, yBottom);
          canvas.drawRect(rect, Paint()..color = zone.$3.withOpacity(0.08));

          // Dashed threshold line
          final linePaint = Paint()
            ..color = zone.$3.withOpacity(0.4)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke;

          double startX = 0;
          while (startX < size.width) {
            canvas.drawLine(
              Offset(startX, yTop),
              Offset(math.min(startX + 4, size.width), yTop),
              linePaint,
            );
            startX += 8;
          }

          // Zone text label on right margin
          final textStyle = TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: zone.$3.withOpacity(0.85),
            letterSpacing: 0.5,
          );
          final tp = TextPainter(
            text: TextSpan(text: '${zone.$4} ${zone.$1.toInt()}+', style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(size.width - tp.width - 4, yTop + 2));
        }
      }
    }

    final animatedCount = (data.length * animationProgress).ceil();

    final fillPath = Path();
    for (int i = 0; i < animatedCount; i++) {
      final x = i / (data.length - 1) * (size.width - padding * 2) + padding;
      final y = getY(data[i]);

      if (i == 0) {
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) / (data.length - 1) * (size.width - padding * 2) + padding;
        final prevY = getY(data[i - 1]);
        final controlX1 = prevX + (x - prevX) / 2;
        final controlX2 = prevX + (x - prevX) / 2;
        fillPath.cubicTo(controlX1, prevY, controlX2, y, x, y);
      }
    }

    if (animatedCount > 0) {
      final lastX = (animatedCount - 1) / (data.length - 1) * (size.width - padding * 2) + padding;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();
    }

    // Paint background fill gradient under curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw Multi-Zone Per-Segment Dynamic Line Transitions
    if (isHeartRate && data.length > 1) {
      for (int i = 1; i < animatedCount; i++) {
        final prevX = (i - 1) / (data.length - 1) * (size.width - padding * 2) + padding;
        final prevY = getY(data[i - 1]);
        final x = i / (data.length - 1) * (size.width - padding * 2) + padding;
        final y = getY(data[i]);

        final c1 = _getZoneColor(data[i - 1], age);
        final c2 = _getZoneColor(data[i], age);

        final segmentPath = Path()..moveTo(prevX, prevY);
        final controlX1 = prevX + (x - prevX) / 2;
        final controlX2 = prevX + (x - prevX) / 2;
        segmentPath.cubicTo(controlX1, prevY, controlX2, y, x, y);

        final segmentPaint = Paint()
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        if (c1 == c2) {
          segmentPaint.color = c1;
        } else {
          final rect = Rect.fromLTRB(
            math.min(prevX, x) - 2,
            math.min(prevY, y) - 2,
            math.max(prevX, x) + 2,
            math.max(prevY, y) + 2,
          );
          segmentPaint.shader = LinearGradient(
            begin: prevX <= x ? Alignment.centerLeft : Alignment.centerRight,
            end: prevX <= x ? Alignment.centerRight : Alignment.centerLeft,
            colors: [c1, c2],
          ).createShader(rect);
        }

        canvas.drawPath(segmentPath, segmentPaint);
      }
    } else {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < animatedCount; i++) {
        final x = i / (data.length - 1) * (size.width - padding * 2) + padding;
        final y = getY(data[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final prevX = (i - 1) / (data.length - 1) * (size.width - padding * 2) + padding;
          final prevY = getY(data[i - 1]);
          final controlX1 = prevX + (x - prevX) / 2;
          final controlX2 = prevX + (x - prevX) / 2;
          path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        }
      }
      canvas.drawPath(path, linePaint);
    }

    // 3. Draw Glow Dot at the last point
    if (animatedCount > 0 && animationProgress >= 1.0) {
      final lastIdx = animatedCount - 1;
      final dotX = lastIdx / (data.length - 1) * (size.width - padding * 2) + padding;
      final dotY = getY(data[lastIdx]);
      final dotColor = isHeartRate ? _getZoneColor(data[lastIdx], age) : lineColor;

      canvas.drawCircle(
        Offset(dotX, dotY),
        7,
        Paint()..color = dotColor.withOpacity(0.3),
      );
      canvas.drawCircle(
        Offset(dotX, dotY),
        3.5,
        Paint()..color = dotColor,
      );
    }

    // 4. Draw X-axis Timestamps
    if (timestamps != null && timestamps!.isNotEmpty && animatedCount > 0) {
      final textStyle = TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: isHeartRate ? Colors.white60 : Colors.grey.shade600,
      );

      final step = math.max(1, (timestamps!.length / 4).floor());
      final indicesToDraw = <int>{};
      for (int i = 0; i < timestamps!.length; i += step) {
        indicesToDraw.add(i);
      }
      indicesToDraw.add(timestamps!.length - 1);

      for (final idx in indicesToDraw) {
        if (idx < animatedCount && idx < timestamps!.length) {
          final x = idx / (data.length - 1) * (size.width - padding * 2) + padding;
          final timeText = timestamps![idx];

          final tp = TextPainter(
            text: TextSpan(text: timeText, style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();

          double drawX = x - tp.width / 2;
          drawX = drawX.clamp(0.0, size.width - tp.width);

          tp.paint(canvas, Offset(drawX, size.height - 14));
        }
      }
    }
  }

  Color _getZoneColor(double val, int age) {
    final maxHr = 220 - age;
    if (val >= maxHr * 0.93) return const Color(0xFFE96B6B);
    if (val >= maxHr * 0.77) return const Color(0xFFFFA24D);
    if (val >= maxHr * 0.64) return const Color(0xFF4CBF87);
    if (val >= maxHr * 0.50) return const Color(0xFF5BB8F5);
    return const Color(0xFF6C7FEA);
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.data != data ||
        oldDelegate.isHeartRate != isHeartRate;
  }
}
