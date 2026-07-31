/// Location record from the TanE06 API `/devices/{imei}/locations/history`.
class LocationRecord {
  final String deviceImei;
  final double latitude;
  final double longitude;
  final int timestamp;

  const LocationRecord({
    required this.deviceImei,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory LocationRecord.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    final rawTs = json['timestamp'] ?? json['created_at'] ?? json['time'] ?? json['ts'];
    var ts = parseInt(rawTs);
    if (ts > 0 && ts < 10000000000) {
      ts = ts * 1000;
    }

    return LocationRecord(
      deviceImei: (json['device_imei'] ?? json['imei'] ?? json['device_id'] ?? '').toString(),
      latitude: parseDouble(json['latitude'] ?? json['lat'] ?? json['lats']),
      longitude: parseDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
      timestamp: ts,
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);
}
