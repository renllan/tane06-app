import 'dart:math';
import 'package:tane06_app/models/ui/screens/blood_pressure_page.dart';

/// Generates sample blood pressure readings for testing/preview purposes.
///
/// Produces [count] readings distributed realistically across [spanDays] days,
/// with values that wobble realistically around [baseSystolic]/[baseDiastolic].
List<BloodPressureReading> generateMockBloodPressureReadings({
  int count = 50,
  int spanDays = 28,
  double baseSystolic = 120,
  double baseDiastolic = 78,
  int seed = 42,
}) {
  final random = Random(seed);
  final now = DateTime.now();

  return List.generate(count, (i) {
    // Distribute readings across 28 days, ending "now"
    final fraction = i / (count - 1);
    final daysAgo = (1 - fraction) * spanDays;
    final minutesAgo = (daysAgo * 1440).round();
    final time = now.subtract(Duration(minutes: minutesAgo));

    // Realistic wobble with sine wave trends over time
    final wave = sin(i / 3) * 6;
    final systolicNoise = (random.nextDouble() - 0.5) * 8;
    final diastolicNoise = (random.nextDouble() - 0.5) * 5;

    final systolic = (baseSystolic + wave + systolicNoise).clamp(95, 145);
    final diastolic = (baseDiastolic + wave * 0.5 + diastolicNoise).clamp(60, 92);

    return BloodPressureReading(
      time: time,
      systolic: systolic.roundToDouble(),
      diastolic: diastolic.roundToDouble(),
    );
  });
}