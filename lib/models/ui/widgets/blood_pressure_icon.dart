import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';

/// A custom, modern Blood Pressure Icon widget representing a vital monitor / gauge.
class BloodPressureIconWidget extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const BloodPressureIconWidget({
    super.key,
    this.size = 24.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.bloodPressure;
    final bg = backgroundColor ?? iconColor.withOpacity(0.12);

    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: iconColor.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.monitor_heart_rounded,
          size: size,
          color: iconColor,
        ),
      ),
    );
  }
}
