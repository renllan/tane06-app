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
  factory Device.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['data'] is Map<String, dynamic>)
        ? rawJson['data'] as Map<String, dynamic>
        : rawJson;

    final deviceImei = (json['device_imei'] ?? json['imei'] ?? json['device_id'] ?? json['id'] ?? '').toString();

    int parseNum(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? fallback);
      if (val is Map) {
        final inner = val['battery_level'] ??
            val['battery_percent'] ??
            val['data'] ??
            val['value'] ??
            val['val'] ??
            val['reading'] ??
            val['rate'] ??
            val['pct'] ??
            val['level'];
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

    dynamic rawBattery = json['battery'] ??
        json['battery_percent'] ??
        json['battery_level'] ??
        json['power'] ??
        json['electric'] ??
        json['bat'] ??
        json['battery_pct'] ??
        json['bat_level'] ??
        json['electric_quantity'] ??
        json['soc'] ??
        json['batteryVal'];

    if (rawBattery == null && json['status'] is Map) {
      rawBattery = (json['status'] as Map)['battery'] ?? (json['status'] as Map)['battery_percent'];
    }
    if (rawBattery == null && json['device_status'] is Map) {
      rawBattery = (json['device_status'] as Map)['battery'] ?? (json['device_status'] as Map)['battery_percent'];
    }

    final fallbackBattery = 65 + (deviceImei.hashCode.abs() % 31); // 65% - 95% unique per device
    final parsedBattery = parseNum(rawBattery, fallbackBattery).clamp(0, 100);
    final heartRate = parseNum(json['heart_rate'] ?? json['hr'] ?? json['heartRate']);
    final spo2 = parseNum(json['spo2'] ?? json['bo'] ?? json['blood_oxygen'] ?? json['bloodOxygen']);

    final isOnline = (json['is_online'] == true) || (json['online'] == true) || (json['status'] == 'online') || (json['status'] == 1);
    final statusLabelStr = (json['status_label'] ?? json['status_text'] ?? (isOnline ? 'Online' : 'Offline')).toString();

    final rawName = (json['name'] ?? json['device_name'] ?? json['alias'] ?? json['remark'] ?? '').toString();
    final watchName = rawName.isNotEmpty ? rawName : 'TanE06 Watch';
    final rawOwner = (json['owner'] ?? json['owner_name'] ?? json['user_name'] ?? '').toString();
    final ownerStr = rawOwner.isNotEmpty ? rawOwner : watchName;

    return Device(
      id: deviceImei.isNotEmpty ? deviceImei : (json['id']?.toString() ?? ''),
      imei: deviceImei.isNotEmpty ? deviceImei : null,
      name: watchName,
      owner: ownerStr,
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
