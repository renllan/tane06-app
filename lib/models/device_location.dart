class DeviceLocation {
  final String deviceImei;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  DeviceLocation({
    required this.deviceImei,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory DeviceLocation.fromJson(Map<String, dynamic> json) {
    final imei = (json['device_imei'] ?? json['imei'] ?? '').toString();

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final lat = parseDouble(json['lat'] ?? json['latitude']);
    final lng = parseDouble(json['lon'] ?? json['longitude'] ?? json['lng']);

    final rawTs = json['timestamp'] ?? json['created_at'];

    int ts = 0;
    if (rawTs is num) {
      ts = rawTs.toInt();
    } else if (rawTs is String) {
      ts = int.tryParse(rawTs) ?? (double.tryParse(rawTs)?.toInt() ?? 0);
    }

    if (ts > 0 && ts < 10000000000) {
      ts = ts * 1000;
    }

    final dt = ts > 0
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : DateTime.now();

    return DeviceLocation(
      deviceImei: imei,
      latitude: lat,
      longitude: lng,
      timestamp: dt,
    );
  }

  @override
  String toString() =>
      'DeviceLocation(imei: $deviceImei, lat: $latitude, lng: $longitude, at: $timestamp)';
}
