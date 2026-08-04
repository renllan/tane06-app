import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/models/ui/screens/watch_location_map_screen.dart';

enum QuickActionType {
  measureTemperature,
  measureHeartRate,
  measureBloodPressure,
  measureSpo2,
  requestLocation,
  findDevice,
  restartDevice,
  powerOffDevice,
}

class QuickActionItem {
  final QuickActionType type;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const QuickActionItem({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class QuickActionWidget extends StatefulWidget {
  final String? imei;
  final List<Device>? devices;
  final Function(String action, String message)? onActionResult;

  const QuickActionWidget({
    super.key,
    this.imei,
    this.devices,
    this.onActionResult,
  });

  @override
  State<QuickActionWidget> createState() => _QuickActionWidgetState();
}

class _QuickActionWidgetState extends State<QuickActionWidget> {
  final DeviceRepository _deviceRepository = DeviceRepository();
  final Map<QuickActionType, bool> _loadingMap = {};

  static const List<QuickActionItem> _actionItems = [
    QuickActionItem(
      type: QuickActionType.measureHeartRate,
      label: 'Heart Rate',
      description: 'Measure HR',
      icon: Icons.favorite_rounded,
      color: AppColors.heartRate,
      bgColor: Color(0xFFFFF0F0),
    ),
    QuickActionItem(
      type: QuickActionType.measureBloodPressure,
      label: 'Blood Pressure',
      description: 'Measure BP',
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFFF97316),
      bgColor: Color(0xFFFFF6EE),
    ),
    QuickActionItem(
      type: QuickActionType.measureSpo2,
      label: 'Blood Oxygen',
      description: 'Measure SpO₂',
      icon: Icons.water_drop_rounded,
      color: AppColors.bloodPressure,
      bgColor: Color(0xFFF0F2FF),
    ),
    QuickActionItem(
      type: QuickActionType.requestLocation,
      label: 'Locate Now',
      description: 'GPS Track',
      icon: Icons.my_location_rounded,
      color: Color(0xFF30D158),
      bgColor: Color(0xFFE8F5E9),
    ),
    QuickActionItem(
      type: QuickActionType.findDevice,
      label: 'Find Watch',
      description: 'Ring Alarm',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF5E5CE6),
      bgColor: Color(0xFFF0F0FF),
    ),
    QuickActionItem(
      type: QuickActionType.restartDevice,
      label: 'Reboot Watch',
      description: 'Restart',
      icon: Icons.restart_alt_rounded,
      color: Color(0xFF64D2FF),
      bgColor: Color(0xFFEBF9FF),
    ),
    QuickActionItem(
      type: QuickActionType.powerOffDevice,
      label: 'Power Off',
      description: 'Shutdown',
      icon: Icons.power_settings_new_rounded,
      color: Color(0xFFFF453A),
      bgColor: Color(0xFFFFEBEA),
    ),
  ];

  Future<void> _handleAction(QuickActionItem item) async {
    final imei = widget.imei;
    if (imei == null || imei.isEmpty) {
      if (item.type == QuickActionType.requestLocation && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WatchLocationMapScreen(
              imei: '868705080309689',
              devices: widget.devices,
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demo mode action: ${item.label}',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _loadingMap[item.type] = true);

    try {
      Map<String, dynamic> result = {};
      String successMessage = '';

      switch (item.type) {
        case QuickActionType.measureTemperature:
          result = await _deviceRepository.requestMeasurement(
              imei: imei, type: 'body-temperature');
          successMessage = 'Body temperature command sent!';
          break;
        case QuickActionType.measureHeartRate:
          result = await _deviceRepository.requestMeasurement(
              imei: imei, type: 'heart-rate');
          successMessage = 'Heart rate measurement command sent!';
          break;
        case QuickActionType.measureBloodPressure:
          result = await _deviceRepository.requestMeasurement(
              imei: imei, type: 'blood-pressure');
          successMessage = 'Blood pressure measurement command sent!';
          break;
        case QuickActionType.measureSpo2:
          result = await _deviceRepository.requestMeasurement(
              imei: imei, type: 'blood-oxygen');
          successMessage = 'SpO₂ measurement command sent!';
          break;
        case QuickActionType.requestLocation:
          result = await _deviceRepository.requestLocation(imei: imei);
          successMessage = 'Location request sent! Opening map...';
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WatchLocationMapScreen(
                  imei: imei,
                  devices: widget.devices,
                ),
              ),
            );
          }
          break;
        case QuickActionType.findDevice:
          result = await _deviceRepository.sendCommand(
              imei: imei, action: 'find');
          successMessage = 'Find watch alarm command sent!';
          break;
        case QuickActionType.restartDevice:
          result = await _deviceRepository.sendCommand(
              imei: imei, action: 'restart');
          successMessage = 'Reboot command sent!';
          break;
        case QuickActionType.powerOffDevice:
          result = await _deviceRepository.sendCommand(
              imei: imei, action: 'power-off');
          successMessage = 'Power off command sent!';
          break;
      }

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        final isSuccess = result['success'] == true;
        final msg = isSuccess
            ? (result['message'] as String? ?? successMessage)
            : (result['message'] as String? ?? 'Failed to execute ${item.label}');

        if (widget.onActionResult != null) {
          widget.onActionResult!(item.label, msg);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            backgroundColor:
                isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.label} request failed: $e'),
            backgroundColor: const Color(0xFFB00020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMap[item.type] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flash_on_rounded,
                  color: AppColors.primary, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Dynamic items grid (rows of up to 4 items)
        Builder(
          builder: (context) {
            final rows = <List<QuickActionItem>>[];
            for (int i = 0; i < _actionItems.length; i += 4) {
              final end = (i + 4 < _actionItems.length) ? i + 4 : _actionItems.length;
              rows.add(_actionItems.sublist(i, end));
            }

            return Column(
              children: rows.map((rowItems) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      ...rowItems.map((item) {
                        final isLoading = _loadingMap[item.type] ?? false;
                        return Expanded(
                          child: _buildCircleButton(item, isLoading),
                        );
                      }),
                      for (int k = 0; k < (4 - rowItems.length); k++)
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton(QuickActionItem item, bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : () => _handleAction(item),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: item.color.withOpacity(isLoading ? 0.5 : 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.color.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: item.color,
                    ),
                  )
                : Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

