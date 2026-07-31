import 'package:tane06_app/models/api_response.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/models/device_profile.dart';
import 'package:tane06_app/models/device_settings.dart';
import 'package:tane06_app/models/family_number.dart';
import 'package:tane06_app/models/health_data_record.dart';
import 'package:tane06_app/models/location_record.dart';
import 'package:tane06_app/models/sos_number.dart';
import 'package:tane06_app/services/api_client.dart';

/// Repository layer that wraps [TanE06ApiClient] and returns typed models.
///
/// UI screens should interact with this class instead of [TanE06ApiClient]
/// directly, keeping the presentation layer free of raw JSON parsing.
class DeviceRepository {
  final TanE06ApiClient _api;
  static final Map<String, DeviceProfile> _profileCache = {};
  static final Map<String, String> _nameCache = {};

  DeviceRepository({TanE06ApiClient? apiClient})
      : _api = apiClient ?? TanE06ApiClient();

  /// Binds a device to [userId].
  Future<Device> bindDevice({
    dynamic userId = 1,
    required String imei,
    String? name,
    String model = 'TanE06',
  }) async {
    final data = await _api.bindDevice(
      userId: userId,
      imei: imei,
      name: name,
      model: model,
    );
    return Device.fromJson(data);
  }

  /// Unbinds (removes) a device from [userId].
  Future<Map<String, dynamic>> unbindDevice({
    dynamic userId = 1,
    required String imei,
  }) async {
    return await _api.unbindDevice(
      userId: userId,
      imei: imei,
    );
  }

  /// Fetches a list of devices bound to [userId].
  Future<List<Device>> listUserDevices({required dynamic userId}) async {
    final data = await _api.listUserDevices(userId: userId);
    final rawItems = data['items'] ?? data['devices'] ?? data['records'] ?? data['list'] ?? data['data'];
    final items = rawItems is List ? rawItems : [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Device.fromJson(e))
        .toList();
  }

  /// Fetches the last known status of a single device.
  Future<Device> getDevice({required String imei}) async {
    final data = await _api.getDevice(imei: imei);
    return Device.fromJson(data);
  }

  // -----------------------------------------------------------------------
  // Settings
  // -----------------------------------------------------------------------

  /// Fetches all settings for a device, returned as a typed [DeviceSettings].
  Future<DeviceSettings> fetchSettings({required String imei}) async {
    final data = await _api.getDeviceSettings(imei: imei);
    final settings = data['settings'] as Map<String, dynamic>? ?? {};
    return DeviceSettings.fromJson(settings);
  }

  /// Fetches a raw settings map for a device (for passing to existing UI).
  Future<Map<String, dynamic>> fetchSettingsRaw({required String imei}) async {
    Map<String, dynamic> rawSettings = {};
    try {
      final data = await _api.getDeviceSettings(imei: imei);
      rawSettings = (data['settings'] as Map<String, dynamic>?) ?? {};
    } catch (_) {}

    final settings = Map<String, dynamic>.from(rawSettings);

    if (_profileCache.containsKey(imei)) {
      settings['profile'] = _profileCache[imei]!.toJson();
    }
    if (_nameCache.containsKey(imei)) {
      settings['name'] = _nameCache[imei];
    }
    return settings;
  }

  /// Fetches the profile for a device (with fallback to settings/cache).
  Future<DeviceProfile?> fetchProfile({required String imei}) async {
    if (_profileCache.containsKey(imei)) {
      return _profileCache[imei];
    }

    try {
      final profileMap = await _api.getProfile(imei: imei);
      if (profileMap.isNotEmpty) {
        final profile = DeviceProfile.fromJson(profileMap);
        _profileCache[imei] = profile;
        return profile;
      }
    } catch (_) {}

    final rawSettings = await fetchSettingsRaw(imei: imei);
    final rawProfile = rawSettings['profile'] as Map<String, dynamic>?;
    if (rawProfile != null) {
      final profile = DeviceProfile.fromJson(rawProfile);
      _profileCache[imei] = profile;
      return profile;
    }
    return null;
  }

  /// Patches (partially updates) device settings.
  ///
  /// [patch] should only contain the sections/fields that changed.
  /// Example: `{'health': {'heart_rate': {'interval': '30'}}}`.
  Future<void> saveSettings({
    required String imei,
    required Map<String, dynamic> patch,
  }) async {
    await _api.patchDeviceSettings(imei: imei, settings: patch);
  }

  // -----------------------------------------------------------------------
  // Contacts & Safety
  // -----------------------------------------------------------------------

  /// Fetches the family contact list for a device.
  Future<List<FamilyNumber>> fetchFamilyNumbers({
    required String imei,
  }) async {
    final data = await _api.getFamilyNumbers(imei: imei);
    final items = data['familyNumbers'] as List? ?? [];
    return items
        .map((e) => FamilyNumber.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Replaces the full family contact list for a device.
  Future<void> updateFamilyNumbers({
    required String imei,
    required List<FamilyNumber> contacts,
  }) async {
    await _api.putFamilyNumbers(
      imei: imei,
      familyNumbers: contacts.map((c) => c.toJson()).toList(),
    );
  }

  /// Fetches SOS emergency contacts for a device.
  Future<List<SosNumber>> fetchSosNumbers({required String imei}) async {
    final data = await _api.getSosNumbers(imei: imei);
    final items = data['sosNumbers'] as List? ?? [];
    return items
        .map((e) => SosNumber.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Replaces the full SOS contact list for a device.
  Future<void> updateSosNumbers({
    required String imei,
    required List<SosNumber> contacts,
  }) async {
    await _api.putSosNumbers(
      imei: imei,
      sosNumbers: contacts.map((c) => c.toJson()).toList(),
    );
  }

  // -----------------------------------------------------------------------
  // Health Data
  // -----------------------------------------------------------------------

  /// Fetches health data records with optional filters.
  Future<List<HealthDataRecord>> fetchHealthData({
    required String imei,
    String? type,
    int? startTime,
    int? endTime,
    int pageSize = 100,
  }) async {
    final data = await _api.getHealthData(
      imei: imei,
      type: type,
      startTime: startTime,
      endTime: endTime,
      pageSize: pageSize,
    );
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems : [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => HealthDataRecord.fromJson(e))
        .toList();
  }

  /// Requests a live health measurement from the device.
  ///
  /// [type] is one of: `heart-rate`, `blood-pressure`,
  /// `blood-oxygen`, `body-temperature`.
  Future<Map<String, dynamic>> requestMeasurement({
    required String imei,
    required String type,
  }) async {
    return await _api.requestMeasurement(imei: imei, type: type);
  }

  // -----------------------------------------------------------------------
  // Location
  // -----------------------------------------------------------------------

  /// Requests the device to report its current location.
  Future<Map<String, dynamic>> requestLocation({required String imei}) async {
    return await _api.requestLocation(imei: imei);
  }

  /// Fetches location history for a device.
  Future<List<LocationRecord>> fetchLocationHistory({
    required String imei,
    int? startTime,
    int? endTime,
    int pageSize = 1,
  }) async {
    final data = await _api.getLocationHistory(
      imei: imei,
      startTime: startTime,
      endTime: endTime,
      pageSize: pageSize,
    );
    final items = data['items'] as List? ?? [];
    return items
        .map((e) => LocationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -----------------------------------------------------------------------
  // Remote Commands
  // -----------------------------------------------------------------------

  /// Sends a remote command to the device.
  ///
  /// [action] is one of: `find`, `power-off`, `restart`, `factory-reset`.
  Future<Map<String, dynamic>> sendCommand({
    required String imei,
    required String action,
  }) async {
    return await _api.sendCommand(imei: imei, action: action);
  }

  /// Renames the device display name.
  Future<Map<String, dynamic>> rename({
    required String imei,
    required String name,
  }) async {
    _nameCache[imei] = name;
    try {
      return await _api.rename(imei: imei, name: name);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return {'success': true, 'name': name, 'imei': imei, 'note': 'Local state updated'};
      }
      rethrow;
    }
  }

  /// Sets/updates the wearer profile for the specified device.
  Future<Map<String, dynamic>> setProfile({
    required String imei,
    required int height,
    required double weight,
    required String birthday,
    required dynamic gender,
  }) async {
    final int genderInt = (gender is bool)
        ? (gender ? 1 : 0)
        : (int.tryParse(gender.toString()) ?? 1);

    final profile = DeviceProfile(
      height: height,
      weight: weight,
      birthday: birthday,
      gender: genderInt == 1,
    );
    _profileCache[imei] = profile;

    try {
      return await _api.setProfile(
        imei: imei,
        height: height,
        weight: weight,
        birthday: birthday,
        gender: genderInt,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return {'success': true, 'imei': imei, 'note': 'Local state updated'};
      }
      rethrow;
    }
  }

  /// Sets/updates the wearer profile using a typed [DeviceProfile].
  Future<Map<String, dynamic>> saveProfile({
    required String imei,
    required DeviceProfile profile,
  }) async {
    return await setProfile(
      imei: imei,
      height: profile.height,
      weight: profile.weight,
      birthday: profile.birthday,
      gender: profile.gender,
    );
  }
}
