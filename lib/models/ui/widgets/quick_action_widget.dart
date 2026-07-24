import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/repositories/device_repository.dart';

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
  final Function(String action, String message)? onActionResult;

  const QuickActionWidget({
    super.key,
    this.imei,
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
      type: QuickActionType.measureTemperature,
      label: '測量體溫',
      description: 'Body Temp',
      icon: Icons.device_thermostat_rounded,
      color: Color(0xFFFF9F0A),
      bgColor: Color(0xFFFFF8E1),
    ),
    QuickActionItem(
      type: QuickActionType.measureHeartRate,
      label: '測量心率',
      description: 'Heart Rate',
      icon: Icons.favorite_rounded,
      color: AppColors.heartRate,
      bgColor: Color(0xFFFFF0F0),
    ),
    QuickActionItem(
      type: QuickActionType.measureBloodPressure,
      label: '測量血壓',
      description: 'Blood Pressure',
      icon: Icons.speed_rounded,
      color: Color(0xFFF97316),
      bgColor: Color(0xFFFFF6EE),
    ),
    QuickActionItem(
      type: QuickActionType.measureSpo2,
      label: '測量血氧',
      description: 'Blood Oxygen',
      icon: Icons.water_drop_rounded,
      color: AppColors.bloodPressure,
      bgColor: Color(0xFFF0F2FF),
    ),
    QuickActionItem(
      type: QuickActionType.requestLocation,
      label: '即時定位',
      description: 'Locate Now',
      icon: Icons.my_location_rounded,
      color: Color(0xFF30D158),
      bgColor: Color(0xFFE8F5E9),
    ),
    QuickActionItem(
      type: QuickActionType.findDevice,
      label: '尋找手錶',
      description: 'Find Device',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF5E5CE6),
      bgColor: Color(0xFFF0F0FF),
    ),
    QuickActionItem(
      type: QuickActionType.restartDevice,
      label: '重啟設備',
      description: 'Reboot',
      icon: Icons.restart_alt_rounded,
      color: Color(0xFF64D2FF),
      bgColor: Color(0xFFEBF9FF),
    ),
    QuickActionItem(
      type: QuickActionType.powerOffDevice,
      label: '遠端關機',
      description: 'Power Off',
      icon: Icons.power_settings_new_rounded,
      color: Color(0xFFFF453A),
      bgColor: Color(0xFFFFEBEA),
    ),
  ];

  Future<void> _handleAction(QuickActionItem item) async {
    final imei = widget.imei;
    if (imei == null || imei.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('目前為範例模式，觸發指令：${item.label}',
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
          successMessage = '體溫量測指令已發送！數據正在同步...';
          break;
        case QuickActionType.measureHeartRate:
          result = await _deviceRepository.requestMeasurement(
              imei: imei, type: 'heart-rate');
          successMessage = '心率量測指令已發送！';
          break;
        case QuickActionType.measureBloodPressure:
          result = await _deviceRepository.requestMeasurement(
              imei: imei, type: 'blood-pressure');
          successMessage = '血壓量測指令已發送！';
          break;
        case QuickActionType.measureSpo2:
          result = await _deviceRepository.requestMeasurement(
              imei: imei, type: 'blood-oxygen');
          successMessage = '血氧量測指令已發送！';
          break;
        case QuickActionType.requestLocation:
          result = await _deviceRepository.requestLocation(imei: imei);
          successMessage = '即時定位請求已發送！正在更新設備位置...';
          break;
        case QuickActionType.findDevice:
          result = await _deviceRepository.sendCommand(
              imei: imei, action: 'find');
          successMessage = '已發送尋找手錶響鈴指令！';
          break;
        case QuickActionType.restartDevice:
          result = await _deviceRepository.sendCommand(
              imei: imei, action: 'restart');
          successMessage = '已發送重啟設備指令！';
          break;
        case QuickActionType.powerOffDevice:
          result = await _deviceRepository.sendCommand(
              imei: imei, action: 'power-off');
          successMessage = '已發送關機指令！';
          break;
      }

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        final isSuccess = result['success'] == true;
        final msg = isSuccess
            ? (result['message'] as String? ?? successMessage)
            : (result['message'] as String? ?? '${item.label} 指令執行失敗');

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
            content: Text('${item.label} 請求失敗: $e'),
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
              '快捷指令',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Quick Actions',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Circle buttons row — evenly spread across full width
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _actionItems.map((item) {
            final isLoading = _loadingMap[item.type] ?? false;
            return Expanded(
              child: _buildCircleButton(item, isLoading),
            );
          }).toList(),
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

