import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/models/health_data_record.dart';

/// Body Temperature status categories
enum TemperatureStatus {
  hypothermia, // < 35.0 °C
  normal,      // 35.0 °C - 37.3 °C
  elevated,    // 37.4 °C - 38.0 °C
  fever,       // > 38.0 °C
}

class TemperatureWidget extends StatefulWidget {
  final String? imei;
  final double? initialTemperature; // in Celsius
  final String? lastUpdatedTime;
  final bool isCompact;
  final VoidCallback? onTap;

  const TemperatureWidget({
    super.key,
    this.imei,
    this.initialTemperature,
    this.lastUpdatedTime,
    this.isCompact = false,
    this.onTap,
  });

  @override
  State<TemperatureWidget> createState() => _TemperatureWidgetState();
}

class _TemperatureWidgetState extends State<TemperatureWidget>
    with SingleTickerProviderStateMixin {
  final DeviceRepository _deviceRepository = DeviceRepository();

  late double _currentTempCelsius;
  bool _isFahrenheit = false;
  bool _isMeasuring = false;
  bool _isLoadingData = false;
  String _lastMeasuredStr = 'Just now';
  List<double> _sparklineData = [36.4, 36.5, 36.6, 36.5, 36.7, 36.6, 36.6];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentTempCelsius = widget.initialTemperature ?? 36.6;
    if (widget.lastUpdatedTime != null) {
      _lastMeasuredStr = widget.lastUpdatedTime!;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (widget.imei != null && widget.imei!.isNotEmpty) {
      _fetchLatestTemperatureFromApi();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Fetches temperature history from Backend API
  Future<void> _fetchLatestTemperatureFromApi() async {
    if (widget.imei == null) return;
    setState(() => _isLoadingData = true);

    try {
      // Fetch body-temperature health data using the API's accepted type code 'BT'
      final List<HealthDataRecord> records =
          await _deviceRepository.fetchHealthData(
        imei: widget.imei!,
        type: 'BT',
      );

      if (records.isNotEmpty && mounted) {
        // Sort by timestamp descending
        records.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        final latest = records.first;

        double? tempVal;
        if (latest.data is num) {
          tempVal = (latest.data as num).toDouble();
        } else if (latest.data is Map) {
          final map = latest.data as Map;
          final raw = map['temp'] ?? map['temperature'] ?? map['body_temp'] ?? map['value'];
          if (raw is num) tempVal = raw.toDouble();
        } else if (latest.data is String) {
          tempVal = double.tryParse(latest.data.toString());
        }

        if (tempVal != null && tempVal > 20 && tempVal < 45) {
          final dt = latest.dateTime;
          final timeFormatted =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

          setState(() {
            _currentTempCelsius = tempVal!;
            _lastMeasuredStr = timeFormatted;

            final extractedVals = records.take(7).map((r) {
              if (r.data is num) return (r.data as num).toDouble();
              return 36.6;
            }).toList().reversed.toList();
            if (extractedVals.isNotEmpty) {
              _sparklineData = extractedVals;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching temperature data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  /// Triggers instant live body-temperature measurement via API endpoint
  Future<void> _requestTemperatureMeasurement() async {
    final imei = widget.imei;
    if (imei == null || imei.isEmpty) {
      // Demo mock measurement trigger
      setState(() => _isMeasuring = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _isMeasuring = false;
        _currentTempCelsius = 36.7;
        _lastMeasuredStr = 'Just now';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '模擬模式：發送體溫量測指令成功 (36.7 °C)',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF2E6D5D),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isMeasuring = true);
    try {
      final res = await _deviceRepository.requestMeasurement(
        imei: imei,
        type: 'body-temperature',
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final isSuccess = res['success'] == true;
      final serverMsg = res['message'] as String?;
      final msg = isSuccess
          ? (serverMsg ?? '已成功發送體溫量測指令！正在同步最新體溫...')
          : (serverMsg ?? '發送量測指令失敗');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          backgroundColor: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
          duration: const Duration(seconds: 3),
        ),
      );

      if (isSuccess) {
        await _fetchLatestTemperatureFromApi();
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _fetchLatestTemperatureFromApi();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('體溫量測請求失敗: $e'),
          backgroundColor: const Color(0xFFB00020),
        ),
      );
    } finally {
      if (mounted) setState(() => _isMeasuring = false);
    }
  }

  TemperatureStatus get _status {
    if (_currentTempCelsius < 35.0) return TemperatureStatus.hypothermia;
    if (_currentTempCelsius <= 37.3) return TemperatureStatus.normal;
    if (_currentTempCelsius <= 38.0) return TemperatureStatus.elevated;
    return TemperatureStatus.fever;
  }

  Color get _statusColor {
    switch (_status) {
      case TemperatureStatus.hypothermia:
        return const Color(0xFF29B6F6); // Ice Blue
      case TemperatureStatus.normal:
        return const Color(0xFF30D158); // Healthy Green
      case TemperatureStatus.elevated:
        return const Color(0xFFFF9F0A); // Warning Orange
      case TemperatureStatus.fever:
        return const Color(0xFFFF2D55); // High Fever Red
    }
  }

  String get _statusLabel {
    switch (_status) {
      case TemperatureStatus.hypothermia:
        return '體溫過低 (Hypothermia)';
      case TemperatureStatus.normal:
        return '體溫正常 (Normal)';
      case TemperatureStatus.elevated:
        return '體溫偏高 (Elevated)';
      case TemperatureStatus.fever:
        return '發燒警示 (Fever)';
    }
  }

  double get _displayedValue {
    if (_isFahrenheit) {
      return (_currentTempCelsius * 9 / 5) + 32;
    }
    return _currentTempCelsius;
  }

  String get _unitStr => _isFahrenheit ? '°F' : '°C';

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactCard();
    }
    return _buildDetailedCard();
  }

  // ---------------------------------------------------------------------------
  // Compact Card View (For Grids & List Items)
  // ---------------------------------------------------------------------------
  Widget _buildCompactCard() {
    return GestureDetector(
      onTap: widget.onTap ?? () => _showTemperatureDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thermometer icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.device_thermostat_rounded,
                color: _statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Title & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Body Temperature',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
            ),
            // Value
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _displayedValue.toStringAsFixed(1),
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' $_unitStr',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Detailed Standalone Card View (Hero Health Section Widget)
  // ---------------------------------------------------------------------------
  Widget _buildDetailedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title, Unit Switcher & Measure Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.device_thermostat_rounded,
                  color: _statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '體溫監測 (Body Temp)',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '最後讀數: $_lastMeasuredStr',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Unit Switcher Toggle
              GestureDetector(
                onTap: () {
                  setState(() => _isFahrenheit = !_isFahrenheit);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.textTertiary.withOpacity(0.2)),
                  ),
                  child: Text(
                    _isFahrenheit ? '切換 °C' : '切換 °F',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Live API Measurement Button
              GestureDetector(
                onTap: _isMeasuring ? null : _requestTemperatureMeasurement,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      if (_isMeasuring)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _statusColor,
                          ),
                        )
                      else
                        Icon(Icons.bolt_rounded, size: 14, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _isMeasuring ? '測量中' : '即時測量',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Value & Gauge Bar Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _displayedValue.toStringAsFixed(1),
                style: GoogleFonts.dmSans(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _unitStr,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              // Status Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _statusColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _statusLabel,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Temperature Range Visual Gauge Indicator Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ((_currentTempCelsius - 34.0) / (40.0 - 34.0))
                      .clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: _statusColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('35.0 °C (過低)',
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.textTertiary)),
                  Text('36.5-37.3 °C (標準)',
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.textTertiary)),
                  Text('38.0+ °C (發燒)',
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.textTertiary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTemperatureDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.device_thermostat_rounded,
                      color: _statusColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    '體溫量測與 API 連線',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '最新即時體溫為 ${_currentTempCelsius.toStringAsFixed(1)} °C。點擊下方按鈕可向 TanE06 設備發送 /measurements/body-temperature API 觸發即時量測。',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _requestTemperatureMeasurement();
                  },
                  icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                  label: Text(
                    '立即向設備請求體溫量測',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
