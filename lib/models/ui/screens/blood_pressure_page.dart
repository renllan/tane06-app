import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/models/health_data_record.dart';

/// A single blood pressure reading.
class BloodPressureReading {
  final DateTime time;
  final double systolic;
  final double diastolic;
  final double? heartRate;

  const BloodPressureReading({
    required this.time,
    required this.systolic,
    required this.diastolic,
    this.heartRate,
  });
}

enum TimeFilter { day, week, month }

class BloodPressurePage extends StatefulWidget {
  final List<BloodPressureReading> readings;
  final String? imei;

  static const Color systolicColor = Color(0xFFFF5252);
  static const Color diastolicColor = Color(0xFF4B7BEC);

  const BloodPressurePage({
    super.key,
    this.readings = const [],
    this.imei,
  });

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  final DeviceRepository _deviceRepository = DeviceRepository();
  TimeFilter _selectedFilter = TimeFilter.day;
  DateTime _selectedDay = DateTime.now();
  double _warningSystolicLimit = 135;
  double _warningDiastolicLimit = 85;
  final List<BloodPressureReading> _userCustomReadings = [];
  List<BloodPressureReading>? _apiReadings;
  bool _isLoadingApi = false;

  @override
  void initState() {
    super.initState();
    if (widget.imei != null && widget.imei!.isNotEmpty) {
      _fetchHealthDataApi();
    }
  }

  Future<void> _fetchHealthDataApi() async {
    final imeiToUse = widget.imei;
    if (imeiToUse == null || imeiToUse.isEmpty) {
      if (mounted) {
        setState(() {
          _apiReadings = [];
          _isLoadingApi = false;
        });
      }
      return;
    }

    setState(() => _isLoadingApi = true);

    try {
      // 1. Fetch both BP and HR data endpoints concurrently
      final results = await Future.wait([
        _deviceRepository.fetchHealthData(imei: imeiToUse, type: 'BP'),
        _deviceRepository.fetchHealthData(imei: imeiToUse, type: 'HR'),
      ]);

      final bpRecords = results[0];
      final hrRecords = results[1];

      // 2. Build a map of Heart Rates indexed by timestamp/time window
      // Key: "YYYY-MM-DD HH:mm" or exact epoch millisecond
      final Map<String, double> hrLookupMap = {};
      for (final hrRecord in hrRecords) {
        final dt = hrRecord.dateTime;
        final timeKey = '${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}';
        
        double? extractedHr;
        if (hrRecord.data is Map) {
          final map = hrRecord.data as Map;
          final rawVal = map['heart_rate'] ?? map['heartRate'] ?? map['hr'] ?? map['bpm'] ?? map['value'] ?? map['val'];
          if (rawVal is num) extractedHr = rawVal.toDouble();
          else if (rawVal is String) extractedHr = double.tryParse(rawVal);
        } else if (hrRecord.data is num) {
          extractedHr = (hrRecord.data as num).toDouble();
        } else if (hrRecord.data is String) {
          extractedHr = double.tryParse(hrRecord.data as String);
        }

        if (extractedHr != null) {
          hrLookupMap[timeKey] = extractedHr;
        }
      }

      // 3. Parse BP records and pair with nearest matching Heart Rate
      final List<BloodPressureReading> parsedList = [];

      for (final bpRecord in bpRecords) {
        final bpReading = _recordToReading(bpRecord);
        if (bpReading == null) continue;

        // If BP record already contains HR internally, keep it;
        // otherwise match against the separate HR API results by timestamp minute
        if (bpReading.heartRate != null) {
          parsedList.add(bpReading);
        } else {
          final timeKey = '${bpReading.time.year}-${bpReading.time.month}-${bpReading.time.day} ${bpReading.time.hour}:${bpReading.time.minute}';
          final matchedHr = hrLookupMap[timeKey];

          parsedList.add(
            BloodPressureReading(
              time: bpReading.time,
              systolic: bpReading.systolic,
              diastolic: bpReading.diastolic,
              heartRate: matchedHr,
            ),
          );
        }
      }

      parsedList.sort((a, b) => a.time.compareTo(b.time));

      if (mounted) {
        setState(() {
          _apiReadings = parsedList;
          _isLoadingApi = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching health data in BloodPressurePage: $e');
      if (mounted) {
        setState(() {
          _apiReadings ??= [];
          _isLoadingApi = false;
        });
      }
    }
  }

  BloodPressureReading? _recordToReading(HealthDataRecord record) {
    final dt = record.dateTime;
    double? sys;
    double? dia;
    double? hr;

    void parseNumbers(String str) {
      final numbers = str
          .trim()
          .split(RegExp(r'[/\s\-,]'))
          .map(double.tryParse)
          .whereType<double>()
          .toList();

      if (numbers.length >= 2) {
        sys ??= numbers[0];
        dia ??= numbers[1];
        if (numbers.length >= 3) hr ??= numbers[2];
      }
    }

    void processData(dynamic data) {
      if (data is String) {
        parseNumbers(data);
        return;
      }

      if (data is! Map) return;

      // Unwrap nested map wrappers
      for (final key in ['bp', 'blood_pressure', 'bloodPressure', 'data']) {
        if (data[key] != null) processData(data[key]);
      }

      double? findNum(List<String> keys) {
        for (final k in keys) {
          final val = data[k];
          if (val is num) return val.toDouble();
          if (val is String) {
            final parsed = double.tryParse(val);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      sys ??= findNum(['systolic', 'sys', 'bp_sys', 'sbp', 'high', 'systolic_pressure', 'systolicPressure', 'high_pressure']);
      dia ??= findNum(['diastolic', 'dia', 'bp_dia', 'dbp', 'low', 'diastolic_pressure', 'diastolicPressure', 'low_pressure']);
      hr ??= findNum(['heart_rate', 'heartRate', 'hr', 'pulse', 'bpm', 'rate', 'pulse_rate', 'pulseRate']);

      if (sys == null || dia == null) {
        final rawStr = data['val'] ?? data['value'] ?? data['reading'];
        if (rawStr is String) parseNumbers(rawStr);
      }
    }

    processData(record.data);

    if (sys != null && dia != null) {
      return BloodPressureReading(
        time: dt,
        systolic: sys!,
        diastolic: dia!,
        heartRate: hr,
      );
    }
    return null;
  }

  Future<void> _triggerLiveMeasurement() async {
    final imeiToUse = widget.imei;
    if (imeiToUse == null || imeiToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo mode: sending simulated measurement signal')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.bloodPressure),
      ),
    );

    try {
      final res = await _deviceRepository.requestMeasurement(
        imei: imeiToUse,
        type: 'blood-pressure',
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      final isSuccess = res['success'] == true;
      final serverMsg = res['message'] as String?;
      final msg = isSuccess
          ? (serverMsg ?? 'Measurement command sent! Syncing latest BP data...')
          : (serverMsg ?? 'Failed to send measurement command');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
        ),
      );

      if (isSuccess) {
        await _fetchHealthDataApi();
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _fetchHealthDataApi();
        });
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) _fetchHealthDataApi();
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Measurement request failed: $e'),
          backgroundColor: const Color(0xFFB00020),
        ),
      );
    }
  }

  Widget _buildDataSourceBadge() {
    String labelText;
    Color badgeColor;
    Widget iconWidget;

    if (_isLoadingApi) {
      labelText = 'Fetching API Data...';
      badgeColor = const Color(0xFF007AFF);
      iconWidget = const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Color(0xFF007AFF),
        ),
      );
    } else if (_apiReadings != null && _apiReadings!.isNotEmpty) {
      labelText = 'API Data (${_apiReadings!.length} records)';
      badgeColor = const Color(0xFF30D158);
      iconWidget = Icon(
        Icons.cloud_done_rounded,
        size: 11,
        color: badgeColor,
      );
    } else {
      labelText = 'No API Data';
      badgeColor = const Color(0xFF8E8E93);
      iconWidget = Icon(
        Icons.cloud_off_rounded,
        size: 11,
        color: badgeColor,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 4),
          Text(
            labelText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  List<BloodPressureReading> get _currentReadings {
    final apiData = _apiReadings ?? [];
    if (_userCustomReadings.isNotEmpty) {
      return [...apiData, ..._userCustomReadings];
    }
    return apiData;
  }

  bool get _isTodaySelected {
    final now = DateTime.now();
    return _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;
  }

  bool get _isYesterdaySelected {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _selectedDay.year == yesterday.year &&
        _selectedDay.month == yesterday.month &&
        _selectedDay.day == yesterday.day;
  }

  String _formatDayLabel(DateTime dt) {
    if (_isTodaySelected) return 'Today';
    if (_isYesterdaySelected) return 'Yesterday';
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdayNames[dt.weekday - 1];
  }

  String _formatDayDateStr(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  List<BloodPressureReading> get _filteredReadings {
    final DateTime startCutoff;
    final DateTime endCutoff;

    switch (_selectedFilter) {
      case TimeFilter.day:
        startCutoff = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 0, 0, 0);
        endCutoff = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 23, 59, 59);
        break;
      case TimeFilter.week:
        endCutoff = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 23, 59, 59);
        startCutoff = endCutoff.subtract(const Duration(days: 7));
        break;
      case TimeFilter.month:
        endCutoff = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 23, 59, 59);
        startCutoff = endCutoff.subtract(const Duration(days: 30));
        break;
    }

    return _currentReadings
        .where((r) => !r.time.isBefore(startCutoff) && !r.time.isAfter(endCutoff))
        .toList();
  }

  Widget _buildDaySelectorBar() {
    final canGoNext = !_isTodaySelected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bloodPressure.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDay = _selectedDay.subtract(const Duration(days: 1));
              });
              _fetchHealthDataApi();
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.bloodPressure.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: AppColors.bloodPressure,
              ),
            ),
            tooltip: 'Previous Day',
          ),

          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDay,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDay = picked;
                });
                _fetchHealthDataApi();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.bloodPressure),
                    const SizedBox(width: 6),
                    Text(
                      _formatDayDateStr(_selectedDay),
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDayLabel(_selectedDay),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bloodPressure,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: canGoNext
                ? () {
                    setState(() {
                      _selectedDay = _selectedDay.add(const Duration(days: 1));
                    });
                    _fetchHealthDataApi();
                  }
                : null,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: canGoNext
                    ? AppColors.bloodPressure.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: canGoNext ? AppColors.bloodPressure : Colors.grey,
              ),
            ),
            tooltip: 'Next Day',
          ),
        ],
      ),
    );
  }

  BloodPressureReading? get _lastReading =>
      _filteredReadings.isNotEmpty ? _filteredReadings.last : null;

  double get _maxSystolic => _filteredReadings.isEmpty
      ? 0
      : _filteredReadings.map((r) => r.systolic).reduce((a, b) => a > b ? a : b);
  double get _minSystolic => _filteredReadings.isEmpty
      ? 0
      : _filteredReadings.map((r) => r.systolic).reduce((a, b) => a < b ? a : b);
  double get _avgSystolic => _filteredReadings.isEmpty
      ? 0
      : _filteredReadings.map((r) => r.systolic).reduce((a, b) => a + b) /
          _filteredReadings.length;

  double get _maxDiastolic => _filteredReadings.isEmpty
      ? 0
      : _filteredReadings.map((r) => r.diastolic).reduce((a, b) => a > b ? a : b);
  double get _minDiastolic => _filteredReadings.isEmpty
      ? 0
      : _filteredReadings.map((r) => r.diastolic).reduce((a, b) => a < b ? a : b);
  double get _avgDiastolic => _filteredReadings.isEmpty
      ? 0
      : _filteredReadings.map((r) => r.diastolic).reduce((a, b) => a + b) /
          _filteredReadings.length;

  String get _statsSectionTitle {
    switch (_selectedFilter) {
      case TimeFilter.day:
        return 'Daily Statistics';
      case TimeFilter.week:
        return 'Weekly Statistics';
      case TimeFilter.month:
        return 'Monthly Statistics';
    }
  }

  void _showEditThresholdsDialog(BuildContext context) {
    final sysController =
        TextEditingController(text: _warningSystolicLimit.toInt().toString());
    final diaController =
        TextEditingController(text: _warningDiastolicLimit.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Custom Warning Limits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Systolic Limit (mmHg)',
                prefixIcon: const Icon(Icons.arrow_upward_rounded,
                    color: BloodPressurePage.systolicColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: diaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Diastolic Limit (mmHg)',
                prefixIcon: const Icon(Icons.arrow_downward_rounded,
                    color: BloodPressurePage.diastolicColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newSys = double.tryParse(sysController.text);
              final newDia = double.tryParse(diaController.text);
              if (newSys != null && newDia != null) {
                setState(() {
                  _warningSystolicLimit = newSys;
                  _warningDiastolicLimit = newDia;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Warning threshold updated: ${newSys.toInt()}/${newDia.toInt()} mmHg',
                    ),
                  ),
                );
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddReadingDialog(BuildContext context) {
    final sysController = TextEditingController(text: '125');
    final diaController = TextEditingController(text: '82');
    final hrController = TextEditingController(text: '72');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_chart_rounded, color: AppColors.bloodPressure),
                SizedBox(width: 8),
                Text(
                  'Enter Blood Pressure Reading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Systolic (mmHg)',
                prefixIcon: const Icon(Icons.arrow_upward_rounded, color: BloodPressurePage.systolicColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: diaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Diastolic (mmHg)',
                prefixIcon: const Icon(Icons.arrow_downward_rounded, color: BloodPressurePage.diastolicColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: hrController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Heart Rate (bpm)',
                prefixIcon: const Icon(Icons.favorite_rounded, color: Color(0xFFE96B6B)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final sys = double.tryParse(sysController.text);
                  final dia = double.tryParse(diaController.text);
                  final hr = double.tryParse(hrController.text);
                  if (sys != null && dia != null) {
                    setState(() {
                      _userCustomReadings.add(
                        BloodPressureReading(
                          time: DateTime.now(),
                          systolic: sys,
                          diastolic: dia,
                          heartRate: hr,
                        ),
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recorded new value: ${sys.toInt()}/${dia.toInt()} mmHg'),
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bloodPressure,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Save & Update Chart',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sanitizeBpTime(String input, String fallback) {
    final clean = input.replaceAll(RegExp(r'[^0-9:]'), '').trim();
    if (clean.isEmpty) return fallback;

    final parts = clean.split(':');
    int h = 7;
    int m = 0;

    if (parts.length == 1) {
      final digits = parts[0];
      if (digits.length == 4) {
        h = int.tryParse(digits.substring(0, 2)) ?? 7;
        m = int.tryParse(digits.substring(2, 4)) ?? 0;
      } else if (digits.length <= 2) {
        h = int.tryParse(digits) ?? 7;
        m = 0;
      } else {
        return fallback;
      }
    } else {
      h = int.tryParse(parts[0]) ?? 7;
      m = int.tryParse(parts[1]) ?? 0;
    }

    h = h.clamp(0, 23);
    m = m.clamp(0, 59);

    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  void _showFrequencySettingDialog() async {
    String currentInterval = '60';
    String currentAmTime = '07:00';
    String currentPmTime = '18:00';

    if (widget.imei != null && widget.imei!.isNotEmpty) {
      try {
        final settings = await _deviceRepository.fetchSettings(imei: widget.imei!);
        final bp = settings.health.bloodPressure;
        currentInterval = bp.interval;
        currentAmTime = bp.timerMeasure.amTime;
        currentPmTime = bp.timerMeasure.pmTime;
      } catch (_) {}
    }

    if (!mounted) return;

    final controller = TextEditingController(text: currentInterval);
    final amController = TextEditingController(text: currentAmTime);
    final pmController = TextEditingController(text: currentPmTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String formatTimeBadge(String rawTime) {
            final clean = rawTime.replaceAll(RegExp(r'[^0-9:]'), '');
            final parts = clean.split(':');
            int h = 7;
            int m = 0;
            if (parts.isNotEmpty) {
              if (parts[0].length == 4) {
                h = int.tryParse(parts[0].substring(0, 2)) ?? 7;
                m = int.tryParse(parts[0].substring(2, 4)) ?? 0;
              } else {
                h = int.tryParse(parts[0]) ?? 7;
              }
            }
            if (parts.length > 1) {
              m = int.tryParse(parts[1]) ?? 0;
            }
            final period = h >= 12 ? 'PM' : 'AM';
            final displayH = h % 12 == 0 ? 12 : h % 12;
            final hhStr = displayH.toString().padLeft(2, '0');
            final mmStr = m.toString().padLeft(2, '0');
            return '$hhStr:$mmStr $period';
          }

          Widget buildScheduleCard({
            required String title,
            required String subtitle,
            required IconData icon,
            required Color accentColor,
            required Color bgGradientStart,
            required Color bgGradientEnd,
            required TextEditingController timeController,
            required List<String> presets,
            required ValueChanged<String> onChanged,
          }) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [bgGradientStart, bgGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accentColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: timeController,
                          keyboardType: TextInputType.datetime,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 1.0,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Input Time (HH:mm)',
                            hintText: 'e.g. 07:30',
                            prefixIcon: Icon(Icons.edit_outlined, color: accentColor, size: 18),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor, width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            onChanged(val);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          formatTimeBadge(timeController.text),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets.map((preset) {
                        final isSelected = timeController.text.trim() == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(preset),
                            selected: isSelected,
                            selectedColor: accentColor,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected ? accentColor : Colors.grey.withOpacity(0.3),
                            ),
                            visualDensity: VisualDensity.compact,
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  timeController.text = preset;
                                  onChanged(preset);
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.bloodPressure.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time_filled_rounded,
                              color: AppColors.bloodPressure, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BP Measurement Frequency',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Enter measurement time (HH:mm) or select preset',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Periodic Measurement Frequency',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        '10',
                        '15',
                        '30',
                        '60',
                        '120',
                        '0',
                      ].map((m) {
                        final isSelected = controller.text == m;
                        final label = m == '0' ? 'Off / Manual' : '$m min';
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.bloodPressure,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: AppColors.bloodPressure.withOpacity(0.05),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.bloodPressure
                                : Colors.grey.withOpacity(0.2),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                controller.text = m;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Custom Frequency (minutes)',
                        hintText: 'Enter custom minutes (e.g. 45)',
                        prefixIcon: const Icon(Icons.edit_calendar_rounded, color: AppColors.bloodPressure),
                        suffixText: 'min',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Daily Scheduled Times',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildScheduleCard(
                      title: 'Morning Time',
                      subtitle: 'Recommended within 1 hour after waking up',
                      icon: Icons.wb_sunny_rounded,
                      accentColor: const Color(0xFFE67E22),
                      bgGradientStart: const Color(0xFFFFF9F2),
                      bgGradientEnd: const Color(0xFFFFF2E5),
                      timeController: amController,
                      presets: ['06:30', '07:00', '07:30', '08:00', '08:30'],
                      onChanged: (val) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    buildScheduleCard(
                      title: 'Evening Time',
                      subtitle: 'Recommended before dinner or before sleep',
                      icon: Icons.nights_stay_rounded,
                      accentColor: const Color(0xFF4A69BD),
                      bgGradientStart: const Color(0xFFF4F6FD),
                      bgGradientEnd: const Color(0xFFEAEEFC),
                      timeController: pmController,
                      presets: ['17:30', '18:00', '18:30', '19:00', '20:00'],
                      onChanged: (val) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final val = controller.text.trim();
                          final intervalValue = (int.tryParse(val) ?? 60).clamp(0, 1440).toString();
                          final amTimeVal = _sanitizeBpTime(amController.text, '07:00');
                          final pmTimeVal = _sanitizeBpTime(pmController.text, '18:00');
                          if (widget.imei != null && widget.imei!.isNotEmpty) {
                            try {
                              await _deviceRepository.saveSettings(
                                imei: widget.imei!,
                                patch: {
                                  'health': {
                                    'blood_pressure': {
                                      'interval': intervalValue,
                                      'timer_measure': {
                                        'am_time': amTimeVal,
                                        'pm_time': pmTimeVal,
                                      }
                                    }
                                  }
                                },
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('BP settings updated! (Interval: $intervalValue min, AM: $amTimeVal, PM: $pmTimeVal)'),
                                    backgroundColor: const Color(0xFF2E7D32),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Update failed: $e')),
                                );
                              }
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('BP measurement settings changed (AM: $amTimeVal, PM: $pmTimeVal)')),
                              );
                            }
                          }
                          if (mounted) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bloodPressure,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Blood Pressure',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _buildDataSourceBadge(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: AppColors.bloodPressure),
            tooltip: 'BP Measurement Settings',
            onPressed: _showFrequencySettingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.monitor_heart_rounded, color: AppColors.bloodPressure),
            tooltip: 'Measure Now',
            onPressed: _triggerLiveMeasurement,
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchHealthDataApi();
        },
        color: AppColors.bloodPressure,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLastReadingCard(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BP Trends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodSelector(),
                ],
              ),
              const SizedBox(height: 14),
              _buildDaySelectorBar(),
              const SizedBox(height: 14),
              _buildChartCard(),
              const SizedBox(height: 24),
              Text(
                _statsSectionTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatsSection(),
              const SizedBox(height: 24),
              _buildWarningValuesSection(),
              const SizedBox(height: 32),
              _buildMeasureNowButton(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningValuesSection() {
    final sys = _lastReading?.systolic ?? 120;
    final dia = _lastReading?.diastolic ?? 80;
    final statusInfo = _evaluateBPStatus(sys, dia);
    final Color statusColor = statusInfo['color'] as Color;
    final Color bgColor = statusInfo['bgColor'] as Color;
    final String statusTitle = statusInfo['status'] as String;
    final String statusDesc = statusInfo['desc'] as String;
    final IconData statusIcon = statusInfo['icon'] as IconData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BP Standards & Thresholds',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Current Assessment: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            statusTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusDesc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Blood Pressure Reference Guide',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _thresholdRow(
                category: 'Low BP',
                systolicRange: '< 90',
                diastolicRange: '< 60',
                badgeColor: const Color(0xFF00ACC1),
                badgeBg: const Color(0xFFE0F7FA),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: 'Normal',
                systolicRange: '90-119',
                diastolicRange: '60-79',
                badgeColor: const Color(0xFF2E7D32),
                badgeBg: const Color(0xFFE8F5E9),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: 'Normal High',
                systolicRange: '120-129',
                diastolicRange: '< 80',
                badgeColor: const Color(0xFF1976D2),
                badgeBg: const Color(0xFFE3F2FD),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: 'Mild',
                systolicRange: '130-139',
                diastolicRange: '80-89',
                badgeColor: const Color(0xFFB08500),
                badgeBg: const Color(0xFFFFF8E1),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: 'Moderate',
                systolicRange: '140-159',
                diastolicRange: '90-99',
                badgeColor: const Color(0xFFE65100),
                badgeBg: const Color(0xFFFFF3E0),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: 'Severe',
                systolicRange: '160-179',
                diastolicRange: '100-109',
                badgeColor: const Color(0xFFB00020),
                badgeBg: const Color(0xFFFFEBEE),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: 'Crisis',
                systolicRange: '≥ 180',
                diastolicRange: '≥ 110',
                badgeColor: const Color(0xFF880E4F),
                badgeBg: const Color(0xFFFCE4EC),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, size: 18, color: AppColors.bloodPressure),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Personal Alert Thresholds',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showEditThresholdsDialog(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Edit Thresholds',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showEditThresholdsDialog(context),
                      child: _alertLimitItem(
                        'Systolic Limit',
                        '${_warningSystolicLimit.toInt()} mmHg',
                        BloodPressurePage.systolicColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showEditThresholdsDialog(context),
                      child: _alertLimitItem(
                        'Diastolic Limit',
                        '${_warningDiastolicLimit.toInt()} mmHg',
                        BloodPressurePage.diastolicColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _evaluateBPStatus(double systolic, double diastolic) {
    final bool exceedsUserThreshold =
        systolic >= _warningSystolicLimit || diastolic >= _warningDiastolicLimit;

    if (systolic >= 180 || diastolic >= 110) {
      return {
        'status': 'Crisis',
        'color': const Color(0xFF880E4F),
        'bgColor': const Color(0xFFFCE4EC),
        'desc': 'Extremely dangerous blood pressure! Stop activity and seek emergency medical care immediately.',
        'icon': Icons.emergency_rounded,
      };
    } else if (systolic >= 160 || diastolic >= 100) {
      return {
        'status': 'Severe',
        'color': const Color(0xFFB00020),
        'bgColor': const Color(0xFFFFEBEE),
        'desc': 'Blood pressure is significantly high. Please rest quietly and consult a physician promptly.',
        'icon': Icons.error_rounded,
      };
    } else if (systolic >= 140 || diastolic >= 90) {
      return {
        'status': 'Moderate',
        'color': const Color(0xFFE65100),
        'bgColor': const Color(0xFFFFF3E0),
        'desc': 'Blood pressure is elevated. Consider lifestyle adjustments and medical evaluation.',
        'icon': Icons.warning_rounded,
      };
    } else if (exceedsUserThreshold) {
      return {
        'status': 'Exceeds Custom Limit',
        'color': const Color(0xFFE65100),
        'bgColor': const Color(0xFFFFF3E0),
        'desc': 'Reading is higher than your custom warning limit (${_warningSystolicLimit.toInt()}/${_warningDiastolicLimit.toInt()} mmHg).',
        'icon': Icons.warning_amber_rounded,
      };
    } else if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
      return {
        'status': 'Mild',
        'color': const Color(0xFFB08500),
        'bgColor': const Color(0xFFFFF8E1),
        'desc': 'Blood pressure is slightly high. Maintain a healthy diet, exercise, and adequate rest.',
        'icon': Icons.info_rounded,
      };
    } else if ((systolic >= 120 && systolic <= 129) && diastolic < 80) {
      return {
        'status': 'Normal High',
        'color': const Color(0xFF1976D2),
        'bgColor': const Color(0xFFE3F2FD),
        'desc': 'Blood pressure is in borderline normal range.',
        'icon': Icons.info_outline_rounded,
      };
    } else if (systolic < 90 || diastolic < 60) {
      return {
        'status': 'Low BP',
        'color': const Color(0xFF00ACC1),
        'bgColor': const Color(0xFFE0F7FA),
        'desc': 'Blood pressure is low. Stay hydrated and monitor for dizziness.',
        'icon': Icons.arrow_downward_rounded,
      };
    } else {
      return {
        'status': 'Normal',
        'color': const Color(0xFF2E7D32),
        'bgColor': const Color(0xFFE8F5E9),
        'desc': 'Blood pressure is within optimal healthy range. Keep up the good habits!',
        'icon': Icons.check_circle_rounded,
      };
    }
  }

  Widget _thresholdRow({
    required String category,
    required String systolicRange,
    required String diastolicRange,
    required Color badgeColor,
    required Color badgeBg,
  }) {
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Systolic: $systolicRange mmHg',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'Diastolic: $diastolicRange mmHg',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _alertLimitItem(String label, String limitValue, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Icon(Icons.edit_outlined, size: 12, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            limitValue,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodButton('Day', TimeFilter.day),
          _periodButton('Week', TimeFilter.week),
          _periodButton('Month', TimeFilter.month),
        ],
      ),
    );
  }

  Widget _periodButton(String label, TimeFilter filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLastReadingCard() {
    final r = _lastReading;
    if (r == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart_rounded, color: AppColors.bloodPressure),
                const SizedBox(width: 8),
                const Text(
                  'Live Blood Pressure',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x25FF9F0A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF9F0A), width: 1),
                  ),
                  child: Text(
                    '${_formatDayDateStr(_selectedDay)} No Data',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9F0A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '-- / --',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Text('mmHg', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            const Text(
              'No blood pressure data uploaded for today. Tap the button below to request a measurement.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _triggerLiveMeasurement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bloodPressure,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.sensors_rounded, size: 18),
              label: const Text('Measure Now', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final year = r.time.year;
    final month = r.time.month.toString().padLeft(2, '0');
    final day = r.time.day.toString().padLeft(2, '0');
    final hour = r.time.hour.toString().padLeft(2, '0');
    final minute = r.time.minute.toString().padLeft(2, '0');
    final second = r.time.second.toString().padLeft(2, '0');
    final fullTimestamp = '$year-$month-$day $hour:$minute:$second';

    final readings = _filteredReadings;
    int lowBpCount = 0;
    int normalCount = 0;
    int normalHighCount = 0;
    int mildCount = 0;
    int moderateCount = 0;
    int severeCount = 0;
    int crisisCount = 0;

    for (final reading in readings) {
      final sys = reading.systolic;
      final dia = reading.diastolic;
      if (sys >= 180 || dia >= 110) {
        crisisCount++;
      } else if (sys >= 160 || dia >= 100) {
        severeCount++;
      } else if (sys >= 140 || dia >= 90) {
        moderateCount++;
      } else if ((sys >= 130 && sys <= 139) || (dia >= 80 && dia <= 89)) {
        mildCount++;
      } else if ((sys >= 120 && sys <= 129) && dia < 80) {
        normalHighCount++;
      } else if (sys < 90 || dia < 60) {
        lowBpCount++;
      } else {
        normalCount++;
      }
    }

    final total = readings.length;
    final lowBpPct = total > 0 ? (lowBpCount / total * 100).round() : 0;
    final normalPct = total > 0 ? (normalCount / total * 100).round() : 0;
    final normalHighPct = total > 0 ? (normalHighCount / total * 100).round() : 0;
    final mildPct = total > 0 ? (mildCount / total * 100).round() : 0;
    final moderatePct = total > 0 ? (moderateCount / total * 100).round() : 0;
    final severePct = total > 0 ? (severeCount / total * 100).round() : 0;
    final crisisPct = total > 0 ? (crisisCount / total * 100).round() : 0;

    final categories = [
      (name: 'Low BP', count: lowBpCount, pct: lowBpPct, color: const Color(0xFF00ACC1)),
      (name: 'Normal', count: normalCount, pct: normalPct, color: const Color(0xFF30D158)),
      (name: 'Normal High', count: normalHighCount, pct: normalHighPct, color: const Color(0xFF42A5F5)),
      (name: 'Mild', count: mildCount, pct: mildPct, color: const Color(0xFFFFCA28)),
      (name: 'Moderate', count: moderateCount, pct: moderatePct, color: const Color(0xFFFF9F0A)),
      (name: 'Severe', count: severeCount, pct: severePct, color: const Color(0xFFFF2D55)),
      (name: 'Crisis', count: crisisCount, pct: crisisPct, color: const Color(0xFF880E4F)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Latest Reading',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        _buildDataSourceBadge(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${r.systolic.toInt()}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: BloodPressurePage.systolicColor,
                            ),
                          ),
                          const Text(
                            ' / ',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${r.diastolic.toInt()}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: BloodPressurePage.diastolicColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'mmHg',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (r.heartRate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE96B6B).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_rounded, size: 12, color: Color(0xFFE96B6B)),
                                const SizedBox(width: 4),
                                Text(
                                  '${r.heartRate!.toInt()} bpm',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE96B6B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              fullTimestamp,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 125,
                height: 125,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    startDegreeOffset: -90,
                    sections: categories.map((cat) {
                      return PieChartSectionData(
                        color: cat.color,
                        value: cat.pct > 0 ? cat.pct.toDouble() : 0.1,
                        title: '',
                        radius: 20,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: AppColors.textTertiary.withOpacity(0.2),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.bloodPressure.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: AppColors.bloodPressure, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'BP Category Breakdown',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: cat.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${cat.count} times (${cat.pct}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cat.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String get _emptyChartLabel {
    final dateStr = _formatDayDateStr(_selectedDay);
    switch (_selectedFilter) {
      case TimeFilter.day:
        return 'No BP trend data for $dateStr';
      case TimeFilter.week:
        return 'No BP trend data for 7 days before $dateStr';
      case TimeFilter.month:
        return 'No BP trend data for 30 days before $dateStr';
    }
  }

  List<BloodPressureReading> _aggregateByDay(
      List<BloodPressureReading> readings) {
    if (readings.isEmpty) return [];

    final Map<DateTime, List<BloodPressureReading>> groups = {};
    for (final r in readings) {
      final date = DateTime(r.time.year, r.time.month, r.time.day);
      groups.putIfAbsent(date, () => []).add(r);
    }

    final result = groups.entries.map((entry) {
      final date = entry.key;
      final list = entry.value;
      final avgSys =
          list.map((r) => r.systolic).reduce((a, b) => a + b) / list.length;
      final avgDia =
          list.map((r) => r.diastolic).reduce((a, b) => a + b) / list.length;

      final hrList = list.map((r) => r.heartRate).whereType<double>();
      final avgHr = hrList.isNotEmpty
          ? (hrList.reduce((a, b) => a + b) / hrList.length).roundToDouble()
          : null;

      return BloodPressureReading(
        time: date.add(const Duration(hours: 12)),
        systolic: avgSys.roundToDouble(),
        diastolic: avgDia.roundToDouble(),
        heartRate: avgHr,
      );
    }).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return result;
  }

  Widget _buildChartCard() {
    final rawReadings = List<BloodPressureReading>.from(_filteredReadings)
      ..sort((a, b) => a.time.compareTo(b.time));

    final readings = _selectedFilter == TimeFilter.day
        ? rawReadings
        : _aggregateByDay(rawReadings);

    if (readings.isEmpty) {
      return Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.show_chart_rounded, size: 36, color: AppColors.textTertiary),
              const SizedBox(height: 8),
              Text(
                _emptyChartLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final systolicSpots = <FlSpot>[];
    final diastolicSpots = <FlSpot>[];
    for (var i = 0; i < readings.length; i++) {
      systolicSpots.add(FlSpot(i.toDouble(), readings[i].systolic));
      diastolicSpots.add(FlSpot(i.toDouble(), readings[i].diastolic));
    }

    return Container(
      width: double.infinity,
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legendDot(BloodPressurePage.systolicColor, 'Systolic'),
              _legendDot(BloodPressurePage.diastolicColor, 'Diastolic'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 40,
                maxY: 160,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 20,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 40,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (readings.length / 4).clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= readings.length) {
                          return const SizedBox.shrink();
                        }
                        final t = readings[i].time;
                        return Text(
                          _getBottomTitleText(t),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceMedium,
                    getTooltipItems: (spots) {
                      if (spots.isEmpty) return [];
                      final idx = spots.first.spotIndex;
                      final reading = readings[idx];
                      final hrText = reading.heartRate != null
                          ? '\nHR: ${reading.heartRate!.toInt()} bpm'
                          : '';

                      return spots.map((s) {
                        final isSys = s.barIndex == 0;
                        return LineTooltipItem(
                          isSys
                              ? 'Sys: ${s.y.toInt()} mmHg$hrText'
                              : 'Dia: ${s.y.toInt()} mmHg',
                          TextStyle(
                            color: isSys
                                ? BloodPressurePage.systolicColor
                                : BloodPressurePage.diastolicColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: systolicSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: BloodPressurePage.systolicColor,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: BloodPressurePage.systolicColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          BloodPressurePage.systolicColor.withOpacity(0.18),
                          BloodPressurePage.systolicColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: diastolicSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: BloodPressurePage.diastolicColor,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: BloodPressurePage.diastolicColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          BloodPressurePage.diastolicColor.withOpacity(0.12),
                          BloodPressurePage.diastolicColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getBottomTitleText(DateTime time) {
    switch (_selectedFilter) {
      case TimeFilter.day:
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      case TimeFilter.week:
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[time.weekday - 1];
      case TimeFilter.month:
        return '${time.month}/${time.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: 'Systolic',
            max: _maxSystolic,
            min: _minSystolic,
            avg: _avgSystolic,
            color: BloodPressurePage.systolicColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            title: 'Diastolic',
            max: _maxDiastolic,
            min: _minDiastolic,
            avg: _avgDiastolic,
            color: BloodPressurePage.diastolicColor,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required double max,
    required double min,
    required double avg,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statRow('Max', max),
          const SizedBox(height: 6),
          _statRow('Min', min),
          const SizedBox(height: 6),
          _statRow('Average', avg),
        ],
      ),
    );
  }

  Widget _statRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            '${value.toStringAsFixed(0)} mmHg',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasureNowButton(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showAddReadingDialog(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.bloodPressure, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.edit_note_rounded, color: AppColors.bloodPressure),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Manual Entry',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.bloodPressure),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _triggerLiveMeasurement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bloodPressure,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.monitor_heart_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Measure Now',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}