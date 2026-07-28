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
    final deviceImei = (json['device_imei'] ?? json['imei'] ?? json['device_id'] ?? json['id'] ?? '').toString();

    int parseNum(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? fallback);
      if (val is Map) {
        final inner = val['value'] ?? val['val'] ?? val['reading'] ?? val['data'] ?? val['rate'] ?? val['pct'] ?? val['level'];
        return parseNum(inner, fallback);
      }
      return fallback;
    }

    int? parseNullableInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? double.tryParse(val)?.toInt();
      if (val is Map) {
        final inner = val['timestamp'] ?? val['ts'] ?? val['val'] ?? val['value'];
        return parseNullableInt(inner);
      }
      return null;
    }

    final rawBattery = json['battery_percent'] ??
        json['battery'] ??
        json['battery_level'] ??
        json['power'] ??
        json['electric'] ??
        json['bat'] ??
        json['battery_pct'] ??
        json['bat_level'];

    final parsedBattery = parseNum(rawBattery, 85).clamp(0, 100);
    final heartRate = parseNum(json['heart_rate'] ?? json['hr'] ?? json['heartRate']);
    final spo2 = parseNum(json['spo2'] ?? json['bo'] ?? json['blood_oxygen'] ?? json['bloodOxygen']);

    final isOnline = (json['is_online'] == true) || (json['online'] == true) || (json['status'] == 'online') || (json['status'] == 1);
    final statusLabelStr = (json['status_label'] ?? json['status_text'] ?? (isOnline ? '連線中' : '離線')).toString();

    return Device(
      id: deviceImei.isNotEmpty ? deviceImei : (json['id']?.toString() ?? ''),
      imei: deviceImei.isNotEmpty ? deviceImei : null,
      name: (json['name'] ?? json['device_name'] ?? json['alias'] ?? 'TanE06').toString(),
      owner: 'User ${json['user_id'] ?? json['userId'] ?? ''}',
      model: (json['model'] ?? json['device_model'] ?? 'TanE06').toString(),
      isOnline: isOnline,
      batteryPercent: parsedBattery,
      heartRate: heartRate,
      spo2: spo2,
      statusLabel: statusLabelStr,
      createdAt: parseNullableInt(json['created_at'] ?? json['createdAt']),
      updatedAt: parseNullableInt(json['updated_at'] ?? json['updatedAt']),
      createdAtStr: json['created_at_str']?.toString() ?? json['createdAtStr']?.toString(),
      updatedAtStr: json['updated_at_str']?.toString() ?? json['updatedAtStr']?.toString(),
    );
  }
}
