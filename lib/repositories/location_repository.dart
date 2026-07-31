import '../models/device_location.dart';
import '../models/location_history_response.dart';
import '../services/location_service.dart';

class LocationRepository {
  final LocationService _service;

  LocationRepository(this._service);

  /// Fetches only the most recent location for a device (page_size = 1).
  Future<DeviceLocation?> getLatestLocation(String imei) async {
    final result = await _service.fetchLocationHistory(
      imei: imei,
      pageSize: 1,
    );
    return result.items.isNotEmpty ? result.items.first : null;
  }

  /// Fetches a single page of history. Useful if you want to show a
  /// manageable chunk and let the UI trigger "load more".
  Future<LocationHistoryResponse> getHistoryPage(
    String imei, {
    int? startTime,
    int? endTime,
    int pageSize = 1,
    String? lastKey,
  }) {
    return _service.fetchLocationHistory(
      imei: imei,
      startTime: startTime,
      endTime: endTime,
      pageSize: pageSize,
      lastKey: lastKey,
    );
  }

  /// Fetches the full history by auto-paginating through every page.
  /// Careful with this on devices with long histories — it can mean many
  /// requests. Prefer [getHistoryPage] with start_time/end_time bounds
  /// for large datasets.
  Future<List<DeviceLocation>> getFullHistory(
    String imei, {
    int? startTime,
    int? endTime,
  }) async {
    final all = <DeviceLocation>[];
    String? lastKey;

    do {
      final page = await _service.fetchLocationHistory(
        imei: imei,
        startTime: startTime,
        endTime: endTime,
        lastKey: lastKey,
      );
      all.addAll(page.items);
      lastKey = page.nextKey;
    } while (lastKey != null);

    return all;
  }

  /// Triggers a location request (POST /devices/{imei}/locations/request) to the device.
  Future<bool> requestLocation(String imei) {
    return _service.requestLocation(imei: imei);
  }

  /// Sends a POST location request, waits briefly for device to update,
  /// then GETs the latest location history (GET /devices/{imei}/locations/history).
  Future<DeviceLocation?> requestAndGetLatestLocation(String imei) async {
    await _service.requestLocation(imei: imei);
    await Future.delayed(const Duration(seconds: 2));
    return getLatestLocation(imei);
  }
}
