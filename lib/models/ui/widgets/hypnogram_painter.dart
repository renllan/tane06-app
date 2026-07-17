import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum SleepStage {
  deep,
  light,
  rem,
  awake,
}

class SleepSegment {
  final SleepStage stage;
  final int durationMinutes;

  const SleepSegment({
    required this.stage,
    required this.durationMinutes,
  });
}

class Hypnogram extends StatelessWidget {
  final List<SleepSegment> segments;

  const Hypnogram({
    super.key,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(
        painter: HypnogramPainter(segments),
      ),
    );
  }
}

class HypnogramPainter extends CustomPainter {
  final List<SleepSegment> segments;

  HypnogramPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    //----------------------------------
    // Dashed grid lines (like picture 2)
    //----------------------------------

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.8;

    // 4 horizontal grid lines for Awake / REM / Light / Deep
    final gridYs = [
      _getY(SleepStage.awake, size.height),
      _getY(SleepStage.rem, size.height),
      _getY(SleepStage.light, size.height),
      _getY(SleepStage.deep, size.height),
    ];

    for (final y in gridYs) {
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint,
          dashWidth: 4, dashSpace: 4);
    }

    //----------------------------------
    // Total duration
    //----------------------------------

    final totalDuration = segments.fold(
      0,
      (sum, item) => sum + item.durationMinutes,
    );

    //----------------------------------
    // Build (x, y) anchor points
    //----------------------------------

    final List<Offset> points = [];
    double currentX = 0;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final segmentWidth =
          (segment.durationMinutes / totalDuration) * size.width;
      final y = _getY(segment.stage, size.height);

      // start of segment
      points.add(Offset(currentX, y));
      // end of segment
      points.add(Offset(currentX + segmentWidth, y));

      currentX += segmentWidth;
    }

    //----------------------------------
    // Draw the smooth gradient path
    //----------------------------------

    // We'll draw segment by segment:
    //   - horizontal stroke coloured by stage colour
    //   - transition: cubic bezier between end of current and start of next,
    //     painted with a linear gradient from current→next colour

    currentX = 0;
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final segmentWidth =
          (segment.durationMinutes / totalDuration) * size.width;

      final startX = currentX;
      final endX = currentX + segmentWidth;
      final y = _getY(segment.stage, size.height);
      final color = _getColor(segment.stage);

      // --- Horizontal flat segment ---
      final flatPaint = Paint()
        ..color = color
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(startX, y), Offset(endX, y), flatPaint);

      // --- Slightly diagonal transition to next segment ---
      if (i < segments.length - 1) {
        final nextSegment = segments[i + 1];
        final nextY = _getY(nextSegment.stage, size.height);
        final nextColor = _getColor(nextSegment.stage);

        // Amount the line extends past each horizontal segment (overshoot)
        const overshoot = 8.0;
        // Horizontal slant: line leans slightly to the right as it goes down
        const slant = 4.0;

        // Top and bottom Y (with overshoot), accounting for up/down direction
        final goingDown = y < nextY;
        final topY = (goingDown ? y : nextY) - overshoot;
        final bottomY = (goingDown ? nextY : y) + overshoot;

        // Slant direction mirrors travel: going down → slant right ╲, going up → slant left ╱
        final topX = goingDown ? endX - slant : endX + slant;
        final bottomX = goingDown ? endX + slant : endX - slant;

        // Gradient shader from the colour at the top to the colour at the bottom
        final topColor = goingDown ? color : nextColor;
        final bottomColor = goingDown ? nextColor : color;
        final shader = ui.Gradient.linear(
          Offset(topX, topY),
          Offset(bottomX, bottomY),
          [topColor, bottomColor],
        );

        final transitionPaint = Paint()
          ..shader = shader
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.butt
          ..style = PaintingStyle.stroke;

        canvas.drawLine(Offset(topX, topY), Offset(bottomX, bottomY), transitionPaint);
      }

      currentX += segmentWidth;
    }
  }

  //----------------------------------
  // Helpers
  //----------------------------------

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 5,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final total = (dx * dx + dy * dy);
    if (total == 0) return;
    final len = total.isFinite ? total : 0.0;
    // simple horizontal assumption (all our grid lines are horizontal)
    double x = start.dx;
    bool drawing = true;
    while (x < end.dx) {
      final segEnd = x + (drawing ? dashWidth : dashSpace);
      if (drawing) {
        canvas.drawLine(
          Offset(x, start.dy),
          Offset(segEnd.clamp(start.dx, end.dx), start.dy),
          paint,
        );
      }
      x = segEnd;
      drawing = !drawing;
    }
  }

  double _getY(SleepStage stage, double height) {
    switch (stage) {
      case SleepStage.awake:
        return height * 0.05;
      case SleepStage.rem:
        return height * 0.33;
      case SleepStage.light:
        return height * 0.62;
      case SleepStage.deep:
        return height * 0.92;
    }
  }

  Color _getColor(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return const Color(0xFF3B4FC8); // rich indigo-blue
      case SleepStage.light:
        return const Color(0xFF5BB8F5); // sky blue
      case SleepStage.rem:
        return const Color(0xFFAB68E8); // violet
      case SleepStage.awake:
        return const Color(0xFFFF9F43); // warm orange
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}