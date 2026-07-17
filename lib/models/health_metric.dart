import 'package:flutter/material.dart';

enum MetricType { heartRate, bloodPressure, sleep, hrv, steps }

enum MetricStatus { normal, warning, critical }

class HealthMetric {
  final MetricType type;
  final String label;
  final String value;
  final String unit;
  final String? secondaryValue;
  final String? secondaryUnit;
  final IconData icon;
  final Color color;
  final Color glowColor;
  final LinearGradient gradient;
  final MetricStatus status;
  final double trendPercentage; // positive = up, negative = down
  final String trendLabel;
  final List<double> sparklineData;

  const HealthMetric({
    required this.type,
    required this.label,
    required this.value,
    required this.unit,
    this.secondaryValue,
    this.secondaryUnit,
    required this.icon,
    required this.color,
    required this.glowColor,
    required this.gradient,
    required this.status,
    required this.trendPercentage,
    required this.trendLabel,
    required this.sparklineData,
  });
}
