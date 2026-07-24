import 'dart:math';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';

/// Generates sample blood pressure readings for testing/preview purposes.
///
/// Produces [count] readings spaced [intervalMinutes] apart, ending "now",
/// with values that wobble realistically around [baseSystolic]/[baseDiastolic].
List<BloodPressureReading> generateMockBloodPressureReadings({
  int count = 12,
  int intervalMinutes = 30,
  double baseSystolic = 120,
  double baseDiastolic = 78,
  int seed = 42,
}) {
  final random = Random(seed);
  final now = DateTime.now();
  final baseTime = DateTime(now.year, now.month, now.day, now.hour);

  return List.generate(count, (i) {
    final minutesAgo = (count - 1 - i) * intervalMinutes;
    final time = baseTime.subtract(Duration(minutes: minutesAgo));

    // Small deterministic wobble, plus a gentle sine wave so the chart isn't flat/noisy.
    final wave = sin(i / 2) * 4;
    final systolicNoise = (random.nextDouble() - 0.5) * 6;
    final diastolicNoise = (random.nextDouble() - 0.5) * 4;

    final systolic = (baseSystolic + wave + systolicNoise).clamp(90, 150);
    final diastolic = (baseDiastolic + wave * 0.5 + diastolicNoise).clamp(60, 95);

    return BloodPressureReading(
      time: time,
      systolic: systolic.roundToDouble(),
      diastolic: diastolic.roundToDouble(),
    );
  });
}