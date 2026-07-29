import 'device_location.dart';

class LocationHistoryResponse {
  final int pageSize;
  final List<DeviceLocation> items;
  final String? nextKey;

  LocationHistoryResponse({
    required this.pageSize,
    required this.items,
    this.nextKey,
  });

  bool get hasNextPage => nextKey != null;

  factory LocationHistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return LocationHistoryResponse(
      pageSize: data['page_size'] as int,
      items: (data['items'] as List<dynamic>)
          .map((e) => DeviceLocation.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextKey: data['next_key'] as String?,
    );
  }
}
