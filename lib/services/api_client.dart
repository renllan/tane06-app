import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tane06_app/models/api_response.dart';
import 'package:tane06_app/services/auth_token_store.dart';

/// Low-level HTTP client for the TanE06 REST API.
///
/// All public methods return the parsed `data` field on success,
/// or throw an [ApiException] on failure.
///
/// Endpoints are grouped by API tag for readability:
///   1. Users           – bind, list devices
///   2. Devices         – get device status
///   3. Device Settings – get / patch
///   4. Contacts        – family numbers, SOS numbers
///   5. Health          – health data, measurements
///   6. Location        – request location, history
///   7. Commands        – find, power off, restart, factory reset
class TanE06ApiClient {
  static const String _baseUrl =
      'https://3qdqrcqr72.execute-api.us-east-1.amazonaws.com';

  final http.Client _http;

  TanE06ApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  Uri _uri(String path, [Map<String, String>? queryParams]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);

  Map<String, String> get _jsonHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = AuthTokenStore.instance.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Parses a JSON response body and returns the decoded map.
  /// Throws [ApiException] if the response indicates failure.
  Map<String, dynamic> _parseResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final success = body['success'] as bool? ?? false;

    if (!success || response.statusCode >= 400) {
      final error = body['error'] != null
          ? ApiError.fromJson(body['error'] as Map<String, dynamic>)
          : ApiError(code: 'HttpError', message: 'Status ${response.statusCode}');
      throw ApiException(statusCode: response.statusCode, error: error);
    }
    return body;
  }

  // -----------------------------------------------------------------------
  // 1. Users
  // -----------------------------------------------------------------------

  /// POST /users/{userId}/bind — Bind a device to a user.
  Future<Map<String, dynamic>> bindDevice({
    required dynamic userId,
    required String imei,
    String? name,
    String model = 'TanE06',
  }) async {
    final response = await _http.post(
      _uri('/users/$userId/bind'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'imei': imei,
        if (name != null) 'name': name,
        'model': model,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}
      final errorMsg = body?['error']?['message'] ?? body?['message'] ?? '請求失敗';
      throw ApiException(
        statusCode: response.statusCode,
        error: ApiError(
          code: 'Http${response.statusCode}',
          message: '$errorMsg (HTTP 狀態碼: ${response.statusCode})',
        ),
      );
    }

    final body = _parseResponse(response);
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return body;
  }

  /// POST /users/{userId}/unbind — Unbind a device from a user.
  Future<Map<String, dynamic>> unbindDevice({
    required dynamic userId,
    required String imei,
  }) async {
    final response = await _http.post(
      _uri('/users/$userId/unbind'),
      headers: _jsonHeaders,
      body: jsonEncode({'imei': imei}),
    );
    final body = _parseResponse(response);
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return body;
  }

  /// GET /users/{userId}/devices — List user's bound devices.
  Future<Map<String, dynamic>> listUserDevices({
    required dynamic userId,
    int pageSize = 100,
    String? lastKey,
  }) async {
    final params = <String, String>{'page_size': pageSize.toString()};
    if (lastKey != null) params['last_key'] = lastKey;

    final response = await _http.get(
      _uri('/users/$userId/devices', params),
      headers: _jsonHeaders,
    );
    final body = _parseResponse(response);
    final data = body['data'];
    if (data is List) {
      return {'items': data};
    } else if (data is Map<String, dynamic>) {
      return data;
    }
    return {'items': []};
  }

  // -----------------------------------------------------------------------
  // 2. Devices
  // -----------------------------------------------------------------------

  /// GET /devices/{imei} — Get device last status.
  Future<Map<String, dynamic>> getDevice({required String imei}) async {
    final response = await _http.get(
      _uri('/devices/$imei'),
      headers: _jsonHeaders,
    );
    final body = _parseResponse(response);
    return body['data'] as Map<String, dynamic>;
  }

  // -----------------------------------------------------------------------
  // 3. Device Settings
  // -----------------------------------------------------------------------

  /// GET /devices/{imei}/settings — Get device settings (all or by section).
  Future<Map<String, dynamic>> getDeviceSettings({
    required String imei,
    String? section,
  }) async {
    final params = <String, String>{};
    if (section != null) params['section'] = section;

    final response = await _http.get(
      _uri('/devices/$imei/settings', params.isNotEmpty ? params : null),
      headers: _jsonHeaders,
    );
    final body = _parseResponse(response);
    return body['data'] as Map<String, dynamic>;
  }

  /// PATCH /devices/{imei}/settings — Update device settings (partial).
  Future<void> patchDeviceSettings({
    required String imei,
    required Map<String, dynamic> settings,
  }) async {
    final response = await _http.patch(
      _uri('/devices/$imei/settings'),
      headers: _jsonHeaders,
      body: jsonEncode(settings),
    );
    _parseResponse(response);
  }

  // -----------------------------------------------------------------------
  // 4. Contacts & Safety
  // -----------------------------------------------------------------------

  /// GET /devices/{imei}/family-numbers — Read family contact list.
  Future<Map<String, dynamic>> getFamilyNumbers({
    required String imei,
  }) async {
    final response = await _http.get(
      _uri('/devices/$imei/family-numbers'),
      headers: _jsonHeaders,
    );
    final body = _parseResponse(response);
    return body['data'] as Map<String, dynamic>;
  }

  /// PUT /devices/{imei}/family-numbers — Replace family contact list.
  Future<void> putFamilyNumbers({
    required String imei,
    required List<Map<String, dynamic>> familyNumbers,
  }) async {
    final response = await _http.put(
      _uri('/devices/$imei/family-numbers'),
      headers: _jsonHeaders,
      body: jsonEncode(familyNumbers),
    );
    _parseResponse(response);
  }

  /// GET /devices/{imei}/sos-numbers — Read SOS contact list.
  Future<Map<String, dynamic>> getSosNumbers({
    required String imei,
  }) async {
    final response = await _http.get(
      _uri('/devices/$imei/sos-numbers'),
      headers: _jsonHeaders,
    );
    final body = _parseResponse(response);
    return body['data'] as Map<String, dynamic>;
  }

  /// PUT /devices/{imei}/sos-numbers — Replace SOS contact list.
  Future<void> putSosNumbers({
    required String imei,
    required List<Map<String, dynamic>> sosNumbers,
  }) async {
    final response = await _http.put(
      _uri('/devices/$imei/sos-numbers'),
      headers: _jsonHeaders,
      body: jsonEncode(sosNumbers),
    );
    _parseResponse(response);
  }

  // -----------------------------------------------------------------------
  // 5. Health
  // -----------------------------------------------------------------------

  /// GET /devices/{imei}/health-data — Query health records.
  Future<Map<String, dynamic>> getHealthData({
    required String imei,
    String? type,
    int? startTime,
    int? endTime,
    int pageSize = 100,
    String? lastKey,
  }) async {
    final params = <String, String>{'page_size': pageSize.toString()};
    if (type != null) params['type'] = type;
    if (startTime != null) params['start_time'] = startTime.toString();
    if (endTime != null) params['end_time'] = endTime.toString();
    if (lastKey != null) params['last_key'] = lastKey;

    final response = await _http.get(
      _uri('/devices/$imei/health-data', params),
      headers: _jsonHeaders,
    );
    final body = _parseResponse(response);
    if (body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    } else if (body['data'] is List) {
      return {'items': body['data']};
    } else if (body['items'] is List) {
      return {'items': body['items']};
    } else if (body['records'] is List) {
      return {'items': body['records']};
    }
    return {'items': []};
  }

  /// POST /devices/{imei}/measurements/{type} — Request a live measurement.
  ///
  /// [type] is one of: heart-rate, blood-pressure, blood-oxygen, body-temperature.
  Future<Map<String, dynamic>> requestMeasurement({
    required String imei,
    required String type,
  }) async {
    final response = await _http.post(
      _uri('/devices/$imei/measurements/$type'),
      headers: _jsonHeaders,
    );
    return _parseResponse(response);
  }

  // -----------------------------------------------------------------------
  // 6. Location
  // -----------------------------------------------------------------------

  /// POST /devices/{imei}/locations/request — Request device to locate now.
  Future<Map<String, dynamic>> requestLocation({required String imei}) async {
    final response = await _http.post(
      _uri('/devices/$imei/locations/request'),
      headers: _jsonHeaders,
    );
    return _parseResponse(response);
  }

  /// GET /devices/{imei}/locations/history — Query location history.
  Future<Map<String, dynamic>> getLocationHistory({
    required String imei,
    int? startTime,
    int? endTime,
    int pageSize = 100,
    String? lastKey,
  }) async {
    final params = <String, String>{'page_size': pageSize.toString()};
    if (startTime != null) params['start_time'] = startTime.toString();
    if (endTime != null) params['end_time'] = endTime.toString();
    if (lastKey != null) params['last_key'] = lastKey;

    final response = await _http.get(
      _uri('/devices/$imei/locations/history', params),
      headers: _jsonHeaders,
    );
    final body = _parseResponse(response);
    return body['data'] as Map<String, dynamic>;
  }

  // -----------------------------------------------------------------------
  // 7. Device Commands
  // -----------------------------------------------------------------------

  /// POST /devices/{imei}/commands/{action}
  ///
  /// [action] is one of: find, power-off, restart, factory-reset.
  Future<Map<String, dynamic>> sendCommand({
    required String imei,
    required String action,
  }) async {
    final response = await _http.post(
      _uri('/devices/$imei/commands/$action'),
      headers: _jsonHeaders,
    );
    return _parseResponse(response);
  }
}
