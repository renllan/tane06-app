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
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final itemsList = (data['items'] is List) ? data['items'] as List : [];

    final parsedItems = itemsList
        .whereType<Map<String, dynamic>>()
        .map((e) => DeviceLocation.fromJson(e))
        .toList();

    int parseNum(dynamic val, [int fallback = 1]) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    return LocationHistoryResponse(
      pageSize: parseNum(data['page_size'], 1),
      items: parsedItems,
      nextKey: data['next_key']?.toString(),
    );
  }
}
