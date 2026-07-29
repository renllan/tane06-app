import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tane06_app/services/auth_token_store.dart';
import '../models/location_history_response.dart';

/// Calls the "查詢設備定位歷史" (device location history) endpoint.
///
/// GET /devices/{imei}/locations/history
class LocationService {
  static const String _baseUrl =
      'https://3qdqrcqr72.execute-api.us-east-1.amazonaws.com';

  /// Supplies the bearer token for the Authorization header.
  /// Wire this up to wherever you store the logged-in user's token
  /// (e.g. secure storage, an auth provider, etc.).
  final Future<String> Function() getAuthToken;

  final http.Client _client;

  LocationService({
    required this.getAuthToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Fetches one page of location history for a device.
  ///
  /// [startTime] / [endTime] are millisecond Unix timestamps.
  /// [pageSize] defaults to 100, max 500 (enforced by the API).
  /// [lastKey] should be the `next_key` from a previous page to continue
  /// pagination.
  Future<LocationHistoryResponse> fetchLocationHistory({
    required String imei,
    int? startTime,
    int? endTime,
    int pageSize = 100,
    String? lastKey,
  }) async {
    final queryParams = <String, String>{
      'page_size': pageSize.toString(),
      if (startTime != null) 'start_time': startTime.toString(),
      if (endTime != null) 'end_time': endTime.toString(),
      if (lastKey != null) 'last_key': lastKey,
    };

    final uri = Uri.parse('$_baseUrl/devices/$imei/locations/history')
        .replace(queryParameters: queryParams);

    final token =  AuthTokenStore.instance.token;

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw LocationServiceException(
        'Failed to load location history (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['success'] != true) {
      throw LocationServiceException('API returned success=false: $json');
    }

    return LocationHistoryResponse.fromJson(json);
  }

  /// Triggers a location request to the device (POST /devices/{imei}/locations/request).
  /// Once received, the watch locates itself and uploads the location,
  /// which can then be fetched via [fetchLocationHistory].
  Future<bool> requestLocation({required String imei}) async {
    final uri = Uri.parse('$_baseUrl/devices/$imei/locations/request');
    final token = AuthTokenStore.instance.token;

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw LocationServiceException(
        'Location request failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['success'] == true;
  }
}

class LocationServiceException implements Exception {
  final String message;
  final int? statusCode;

  LocationServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'LocationServiceException: $message';
}
