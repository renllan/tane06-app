import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/models/device_location.dart';
import 'package:tane06_app/repositories/location_repository.dart';
import 'package:tane06_app/services/auth_token_store.dart';
import 'package:tane06_app/services/location_service.dart';
import 'package:tane06_app/theme/app_theme.dart';

/// Displays multi-device locations on a unified interactive OpenStreetMap via flutter_map.
/// Supports batch POST /locations/request and GET /locations/history across all user devices.
class WatchLocationMapScreen extends StatefulWidget {
  final String imei;
  final List<Device>? devices;
  final LocationRepository? repository;

  const WatchLocationMapScreen({
    super.key,
    required this.imei,
    this.devices,
    this.repository,
  });

  @override
  State<WatchLocationMapScreen> createState() => _WatchLocationMapScreenState();
}

class _WatchLocationMapScreenState extends State<WatchLocationMapScreen> {
  final MapController _mapController = MapController();

  late LocationRepository _repo;
  late List<Device> _devicesList;
  late String _selectedImei;

  final Map<String, List<DeviceLocation>> _deviceHistories = {};
  bool _isLoading = true;
  bool _isRequestingLocation = false;
  String? _statusMessage;

  List<Device> get _defaultDevices => [
        Device(
          id: '1',
          imei: widget.imei.isNotEmpty ? widget.imei : '868705080304723',
          name: "Father's TanE06",
          owner: 'Father',
          batteryPercent: 20,
          heartRate: 88,
          spo2: 95,
          statusLabel: 'High BP',
          isOnline: true,
        ),
        Device(
          id: '2',
          imei: '868705080309690',
          name: "Mother's TanE06",
          owner: 'Mother',
          batteryPercent: 15,
          heartRate: 76,
          spo2: 97,
          statusLabel: 'Low Battery',
          isOnline: true,
        ),
        Device(
          id: '3',
          imei: '868705080309691',
          name: "My TanE06",
          owner: 'Me',
          batteryPercent: 82,
          heartRate: 72,
          spo2: 98,
          statusLabel: 'Normal',
          isOnline: true,
        ),
      ];



  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        LocationRepository(
          LocationService(
            getAuthToken: () async => AuthTokenStore.instance.token ?? '',
          ),
        );

    _devicesList = (widget.devices != null && widget.devices!.isNotEmpty)
        ? List<Device>.from(widget.devices!)
        : _defaultDevices;

    _selectedImei = widget.imei.isNotEmpty
        ? widget.imei
        : (_devicesList.first.imei ?? _devicesList.first.id);

    _loadAllHistories();
  }

  Future<void> _loadAllHistories() async {
    setState(() {
      _isLoading = true;
    });

    for (int i = 0; i < _devicesList.length; i++) {
      final dev = _devicesList[i];
      final devImei = dev.imei ?? dev.id;
      try {
        final pageRes = await _repo.getHistoryPage(devImei, pageSize: 1);
        if (mounted) {
          final items = pageRes.items;
          if (items.isNotEmpty) {
            final loc = items.first;
            debugPrint('🌐 [MapScreen Fetched] Device "${dev.name}" ($devImei) -> Lat: ${loc.latitude}, Lng: ${loc.longitude}, Time: ${loc.timestamp}');
            _deviceHistories[devImei] = items;
          } else {
            debugPrint('⚠️ [MapScreen Fetched] Device "${dev.name}" ($devImei) returned empty history.');
            _deviceHistories.remove(devImei);
          }
        }
      } catch (e) {
        debugPrint('❌ [MapScreen Fetch Error] Device "${dev.name}" ($devImei): $e');
        if (mounted) {
          _deviceHistories.remove(devImei);
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitAllDevices();
      });
    }
  }

  void _fitAllDevices() {
    final points = <LatLng>[];
    for (final dev in _devicesList) {
      final key = dev.imei ?? dev.id;
      final history = _deviceHistories[key];
      if (history != null && history.isNotEmpty) {
        points.add(LatLng(history.first.latitude, history.first.longitude));
      }
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 16.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(75),
      ),
    );
  }

  Future<void> _triggerBatchLocationRequest() async {
    if (_isRequestingLocation) return;
    setState(() {
      _isRequestingLocation = true;
      _statusMessage = 'Location command sent to all devices. Waiting for response...';
    });

    try {
      final futures = _devicesList.map((dev) {
        final key = dev.imei ?? dev.id;
        return _repo.requestLocation(key).catchError((_) => false);
      }).toList();

      await Future.wait(futures);

      if (mounted) {
        setState(() {
          _statusMessage = 'Command sent! Fetching location history...';
        });
      }

      await Future.delayed(const Duration(seconds: 2));
      await _loadAllHistories();

      if (mounted) {
        setState(() {
          _statusMessage = 'Location updated for all devices!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Batch location request complete';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _statusMessage ?? 'Location update complete',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _triggerSingleLocationRequest(Device dev) async {
    final devImei = dev.imei ?? dev.id;
    if (_isRequestingLocation) return;
    setState(() {
      _isRequestingLocation = true;
      _statusMessage = 'Requesting location for "${dev.name}"...';
    });

    try {
      await _repo.requestLocation(devImei);
      if (mounted) {
        setState(() {
          _statusMessage = 'Command sent, updating history...';
        });
      }
      await Future.delayed(const Duration(seconds: 2));
      final pageRes = await _repo.getHistoryPage(devImei, pageSize: 1);
      if (mounted) {
        final items = pageRes.items;
        if (items.isNotEmpty) {
          final loc = items.first;
          debugPrint('🌐 [MapScreen Refresh] Device "${dev.name}" ($devImei) -> Lat: ${loc.latitude}, Lng: ${loc.longitude}, Time: ${loc.timestamp}');
          _deviceHistories[devImei] = items;
        } else {
          _deviceHistories.remove(devImei);
        }
        setState(() {
          _statusMessage = 'Location updated for "${dev.name}"!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Location request sent for "${dev.name}"';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _statusMessage ?? 'Device location complete',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _selectDevice(Device dev) {
    final key = dev.imei ?? dev.id;
    setState(() {
      _selectedImei = key;
    });

    final history = _deviceHistories[key];
    if (history != null && history.isNotEmpty) {
      final targetLatLng = LatLng(history.first.latitude, history.first.longitude);
      _mapController.move(targetLatLng, 16.5);
    }
  }

  Device get _selectedDevice => _devicesList.firstWhere(
        (d) => (d.imei ?? d.id) == _selectedImei,
        orElse: () => _devicesList.first,
      );

  List<DeviceLocation>? get _selectedHistory =>
      _deviceHistories[_selectedImei] ??
      (_deviceHistories.isNotEmpty ? _deviceHistories.values.first : null);

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _deviceHistories.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Live GPS Tracking Map',
            style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Fetching GPS coordinates from API...',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final activeHistory = _selectedHistory;

    if (activeHistory == null || activeHistory.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Live GPS Tracking Map',
            style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_rounded, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  'No GPS data available yet',
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap below to send a location request command to your device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isRequestingLocation ? null : _triggerBatchLocationRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cell_tower_rounded, size: 18),
                  label: const Text('Request Location', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedLatest = activeHistory.first;
    final selectedLatLng = LatLng(selectedLatest.latitude, selectedLatest.longitude);
    final selectedTrail =
        activeHistory.map((l) => LatLng(l.latitude, l.longitude)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live GPS Tracking Map',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${_devicesList.length} Devices • Multi-Device Tracking',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Fit All Devices',
            icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white),
            onPressed: _fitAllDevices,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAllHistories,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. FlutterMap with Multi-Device Markers
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selectedLatLng,
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tane06_app',
              ),
              // Trail Polyline for Selected Device
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: selectedTrail,
                    strokeWidth: 4.0,
                    color: const Color(0xFF388E3C),
                  ),
                ],
              ),
              // Markers Layer for Devices with Real Location Data
              MarkerLayer(
                markers: _devicesList.where((d) {
                  final k = d.imei ?? d.id;
                  return _deviceHistories.containsKey(k) && _deviceHistories[k]!.isNotEmpty;
                }).map((dev) {
                  final devKey = dev.imei ?? dev.id;
                  final history = _deviceHistories[devKey]!;
                  final latestLoc = history.first;
                  final isSelected = devKey == _selectedImei;

                  debugPrint('🗺️ [Map Display Marker] "${dev.name}" ($devKey) -> Displaying Lat: ${latestLoc.latitude}, Lng: ${latestLoc.longitude}');

                  return Marker(
                    point: LatLng(latestLoc.latitude, latestLoc.longitude),
                    width: isSelected ? 120 : 90,
                    height: isSelected ? 80 : 65,
                    child: GestureDetector(
                      onTap: () => _selectDevice(dev),
                      child: _buildDeviceMapMarker(dev, isSelected),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Status / Loading Indicator Banner
          if (_isRequestingLocation || _isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage ?? 'Loading location data...',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Bottom Multi-Device Controller Card & Info Section
          Positioned(
            left: 14,
            right: 14,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Horizontal Device Cards Selector
                _buildHorizontalDeviceSelector(),
                const SizedBox(height: 10),
                // Selected Device Info Details Card
                _buildSelectedDeviceInfoCard(_selectedDevice, selectedLatLng),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceMapMarker(Device dev, bool isSelected) {
    Color badgeColor = const Color(0xFF2E7D32);
    if (dev.statusLabel.contains('High') || dev.statusLabel.contains('Abnormal')) {
      badgeColor = const Color(0xFFFF3B30);
    } else if (dev.statusLabel.contains('Low')) {
      badgeColor = const Color(0xFFFF9500);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name & Battery Badge Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : badgeColor,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  dev.name,
                  style: GoogleFonts.dmSans(
                    fontSize: isSelected ? 12 : 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${dev.batteryPercent}%',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Pin Pointer Circle
        Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
            Container(
              width: isSelected ? 32 : 26,
              height: isSelected ? 32 : 26,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.watch_rounded,
                color: Colors.white,
                size: isSelected ? 18 : 14,
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildHorizontalDeviceSelector() {
    return SizedBox(
      height: 68,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _devicesList.length,
        itemBuilder: (ctx, index) {
          final dev = _devicesList[index];
          final devKey = dev.imei ?? dev.id;
          final isSelected = devKey == _selectedImei;

          Color badgeBg = const Color(0xFFE8F5E9);
          Color badgeText = const Color(0xFF2E7D32);
          if (dev.statusLabel.contains('High') || dev.statusLabel.contains('Abnormal')) {
            badgeBg = const Color(0xFFFFEBEE);
            badgeText = const Color(0xFFB00020);
          } else if (dev.statusLabel.contains('Low')) {
            badgeBg = const Color(0xFFFFF8E1);
            badgeText = const Color(0xFFB08500);
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _selectDevice(dev),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 145,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.black12,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceMedium,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.watch_rounded,
                        size: 18,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dev.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dev.statusLabel,
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedDeviceInfoCard(Device dev, LatLng latLng) {
    final devKey = dev.imei ?? dev.id;
    final history = _deviceHistories[devKey];
    final location = (history != null && history.isNotEmpty) ? history.first : null;

    final formattedTime = location != null
        ? '${location.timestamp.hour.toString().padLeft(2, '0')}:${location.timestamp.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      dev.name,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Updated $formattedTime',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Battery ${dev.batteryPercent}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRequestingLocation
                      ? null
                      : () => _triggerSingleLocationRequest(dev),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: Text(
                    'Request Location',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _mapController.move(latLng, 16.5),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.center_focus_strong_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
