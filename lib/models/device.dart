class Device {
  final String id;
  final String name;
  final String owner;
  final int batteryPercent;
  final int heartRate;
  final int spo2;
  final String statusLabel; // e.g., "正常", "低電量", "異常"

  Device({
    required this.id,
    required this.name,
    required this.owner,
    required this.batteryPercent,
    required this.heartRate,
    required this.spo2,
    required this.statusLabel,
  });
}
