/// Device model enriched with fields from the TanE06 API.
///
/// Provides both the original constructor for backward compatibility
/// and a [Device.fromJson] factory for API deserialization.
class Device {
  final String id;
  final String name;
  final String owner;
  final int batteryPercent;
  final int heartRate;
  final int spo2;
  final String statusLabel;

  // API-specific fields
  final String? imei;
  final String? model;
  final bool isOnline;
  final int? createdAt;
  final int? updatedAt;
  final String? createdAtStr;
  final String? updatedAtStr;

  Device({
    required this.id,
    required this.name,
    required this.owner,
    required this.batteryPercent,
    required this.heartRate,
    required this.spo2,
    required this.statusLabel,
    this.imei,
    this.model,
    this.isOnline = false,
    this.createdAt,
    this.updatedAt,
    this.createdAtStr,
    this.updatedAtStr,
  });

  /// Creates a [Device] from the TanE06 API response JSON.
  ///
  /// Maps `device_imei` → [id] and [imei]; health fields default to 0
  /// since the device status endpoint doesn't include live vitals.
  factory Device.fromJson(Map<String, dynamic> json) {
    final deviceImei = json['device_imei'] as String? ?? '';
    return Device(
      id: deviceImei,
      imei: deviceImei,
      name: json['name'] as String? ?? 'TanE06',
      owner: 'User ${json['user_id'] ?? ''}',
      model: json['model'] as String? ?? 'TanE06',
      isOnline: json['is_online'] as bool? ?? false,
      batteryPercent: 0,
      heartRate: 0,
      spo2: 0,
      statusLabel: (json['is_online'] == true) ? '連線中' : '離線',
      createdAt: json['created_at'] as int?,
      updatedAt: json['updated_at'] as int?,
      createdAtStr: json['created_at_str'] as String?,
      updatedAtStr: json['updated_at_str'] as String?,
    );
  }
}
