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
    return LocationRecord(
      deviceImei: json['device_imei'] as String? ?? '',
      latitude: (json['latitude'] as num? ?? 0).toDouble(),
      longitude: (json['longitude'] as num? ?? 0).toDouble(),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);
}
