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
    return DeviceLocation(
      deviceImei: json['device_imei'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      // API returns millisecond-level Unix timestamps.
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  @override
  String toString() =>
      'DeviceLocation(imei: $deviceImei, lat: $latitude, lng: $longitude, at: $timestamp)';
}
