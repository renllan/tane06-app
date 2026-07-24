/// Health data record from the TanE06 API `/devices/{imei}/health-data`.
///
/// [type] is one of: HR, BO, BP, SC, TA, BT, blood-pressure, etc.
/// [data] is a dynamic value whose shape depends on [type].
class HealthDataRecord {
  final String deviceImei;
  final String recordKey;
  final int timestamp;
  final String type;
  final dynamic data;

  const HealthDataRecord({
    required this.deviceImei,
    required this.recordKey,
    required this.timestamp,
    required this.type,
    required this.data,
  });

  factory HealthDataRecord.fromJson(Map<String, dynamic> json) {
    final imei = (json['device_imei'] ?? json['imei'] ?? json['device_id'] ?? '').toString();
    final key = (json['record_key'] ?? json['id'] ?? json['_id'] ?? json['key'] ?? '').toString();

    final rawTs = json['timestamp'] ??
        json['created_at'] ??
        json['time'] ??
        json['date'] ??
        json['ts'] ??
        json['time_stamp'];

    int ts = 0;
    if (rawTs is num) {
      ts = rawTs.toInt();
    } else if (rawTs is String) {
      ts = int.tryParse(rawTs) ?? (double.tryParse(rawTs)?.toInt() ?? 0);
    }

    // Convert seconds timestamp (10 digits) to milliseconds (13 digits)
    if (ts > 0 && ts < 10000000000) {
      ts = ts * 1000;
    }

    if (ts == 0 && rawTs is String) {
      final parsedDt = DateTime.tryParse(rawTs);
      if (parsedDt != null) {
        ts = parsedDt.millisecondsSinceEpoch;
      }
    }

    final recordType = (json['type'] ??
            json['metric_type'] ??
            json['data_type'] ??
            json['record_type'] ??
            '')
        .toString();

    dynamic recordData = json['data'] ?? json['value'] ?? json['val'] ?? json['payload'] ?? json['details'];
    recordData ??= json;

    return HealthDataRecord(
      deviceImei: imei,
      recordKey: key,
      timestamp: ts,
      type: recordType,
      data: recordData,
    );
  }

  DateTime get dateTime => timestamp > 0
      ? DateTime.fromMillisecondsSinceEpoch(timestamp)
      : DateTime.now();
}
