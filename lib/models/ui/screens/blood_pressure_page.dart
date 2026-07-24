import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/mock_blood_pressure_data.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/models/health_data_record.dart';

/// A single blood pressure reading.
class BloodPressureReading {
  final DateTime time;
  final double systolic;
  final double diastolic;

  const BloodPressureReading({
    required this.time,
    required this.systolic,
    required this.diastolic,
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
    required this.readings,
    this.imei,
  });

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  final DeviceRepository _deviceRepository = DeviceRepository();
  TimeFilter _selectedFilter = TimeFilter.day;
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
    if (widget.imei == null) return;
    setState(() => _isLoadingApi = true);
    try {
      // 1. Primary query using official API code 'BP'
      List<HealthDataRecord> records = await _deviceRepository.fetchHealthData(
        imei: widget.imei!,
        type: 'BP',
      );

      if (records.isEmpty) {
        records = await _deviceRepository.fetchHealthData(
          imei: widget.imei!,
          type: 'bp',
        );
      }

      if (records.isEmpty) {
        records = await _deviceRepository.fetchHealthData(
          imei: widget.imei!,
          type: 'blood-pressure',
        );
      }

      if (records.isEmpty) {
        records = await _deviceRepository.fetchHealthData(
          imei: widget.imei!,
          type: 'blood_pressure',
        );
      }

      if (records.isEmpty) {
        records = await _deviceRepository.fetchHealthData(
          imei: widget.imei!,
        );
      }

      final parsed = records
          .map((r) => _recordToReading(r))
          .whereType<BloodPressureReading>()
          .toList();

      parsed.sort((a, b) => a.time.compareTo(b.time));

      if (mounted) {
        setState(() {
          if (parsed.isNotEmpty) {
            _apiReadings = parsed;
          }
          _isLoadingApi = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching health data in BloodPressurePage: $e');
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
  }

  BloodPressureReading? _recordToReading(HealthDataRecord record) {
    final dt = record.dateTime;
    double? sys;
    double? dia;

    void extractFromMap(Map map) {
      final sysRaw = map['systolic'] ??
          map['sys'] ??
          map['bp_sys'] ??
          map['sbp'] ??
          map['high'] ??
          map['systolic_pressure'] ??
          map['systolicPressure'] ??
          map['high_pressure'];

      final diaRaw = map['diastolic'] ??
          map['dia'] ??
          map['bp_dia'] ??
          map['dbp'] ??
          map['low'] ??
          map['diastolic_pressure'] ??
          map['diastolicPressure'] ??
          map['low_pressure'];

      if (sysRaw != null) {
        sys = (sysRaw is num) ? sysRaw.toDouble() : double.tryParse(sysRaw.toString());
      }
      if (diaRaw != null) {
        dia = (diaRaw is num) ? diaRaw.toDouble() : double.tryParse(diaRaw.toString());
      }
    }

    if (record.data is Map) {
      extractFromMap(record.data as Map);
    }

    // String formats: "120/80", "120 80", "120,80", "120-80"
    if ((sys == null || dia == null) && record.data is String) {
      final str = (record.data as String).trim();
      final parts = str.split(RegExp(r'[/\s\-,]'));
      final numbers = parts.map((p) => double.tryParse(p)).whereType<double>().toList();
      if (numbers.length >= 2) {
        sys = numbers[0];
        dia = numbers[1];
      }
    }

    if (sys != null && dia != null) {
      return BloodPressureReading(time: dt, systolic: sys!, diastolic: dia!);
    }
    return null;
  }

  Future<void> _triggerLiveMeasurement() async {
    final imeiToUse = widget.imei;
    if (imeiToUse == null || imeiToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前為範例模式，發送模擬量測信號')),
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
          ? (serverMsg ?? '已成功發送即時量測指令！正在同步最新血壓數據...')
          : (serverMsg ?? '發送量測指令失敗');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
        ),
      );

      if (isSuccess) {
        // Refetch immediately
        await _fetchHealthDataApi();

        // Refetch after delays to catch device upload
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
          content: Text('即時量測請求失敗：$e'),
          backgroundColor: const Color(0xFFB00020),
        ),
      );
    }
  }

  Widget _buildDataSourceBadge() {
    final isApi = _apiReadings != null && _apiReadings!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isApi ? const Color(0x2530D158) : const Color(0x25FF9F0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApi ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApi ? Icons.cloud_done_rounded : Icons.science_rounded,
            size: 11,
            color: isApi ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
          ),
          const SizedBox(width: 4),
          Text(
            isApi ? 'API 數據' : '模擬數據 (Mock)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isApi ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
            ),
          ),
        ],
      ),
    );
  }

  List<BloodPressureReading> get _currentReadings {
    if (_userCustomReadings.isNotEmpty) {
      return [...(_apiReadings ?? widget.readings), ..._userCustomReadings];
    }
    if (_apiReadings != null && _apiReadings!.isNotEmpty) {
      return _apiReadings!;
    }
    switch (_selectedFilter) {
      case TimeFilter.day:
        return widget.readings.isNotEmpty
            ? widget.readings
            : generateMockBloodPressureReadings(count: 12, intervalMinutes: 120, seed: 101);
      case TimeFilter.week:
        return generateMockBloodPressureReadings(count: 7, intervalMinutes: 1440, seed: 202);
      case TimeFilter.month:
        return generateMockBloodPressureReadings(count: 15, intervalMinutes: 2880, seed: 303);
    }
  }

  BloodPressureReading get _lastReading => _currentReadings.last;

  double get _maxSystolic =>
      _currentReadings.map((r) => r.systolic).reduce((a, b) => a > b ? a : b);
  double get _minSystolic =>
      _currentReadings.map((r) => r.systolic).reduce((a, b) => a < b ? a : b);
  double get _avgSystolic =>
      _currentReadings.map((r) => r.systolic).reduce((a, b) => a + b) /
      _currentReadings.length;

  double get _maxDiastolic =>
      _currentReadings.map((r) => r.diastolic).reduce((a, b) => a > b ? a : b);
  double get _minDiastolic =>
      _currentReadings.map((r) => r.diastolic).reduce((a, b) => a < b ? a : b);
  double get _avgDiastolic =>
      _currentReadings.map((r) => r.diastolic).reduce((a, b) => a + b) /
      _currentReadings.length;

  String get _statsSectionTitle {
    switch (_selectedFilter) {
      case TimeFilter.day:
        return '每日統計';
      case TimeFilter.week:
        return '本週統計';
      case TimeFilter.month:
        return '本月統計';
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
              '自訂警示閥值',
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
                labelText: '收縮壓警示上限 (mmHg)',
                prefixIcon: const Icon(Icons.speed_rounded,
                    color: BloodPressurePage.systolicColor),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: diaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '舒張壓警示上限 (mmHg)',
                prefixIcon: const Icon(Icons.speed_rounded,
                    color: BloodPressurePage.diastolicColor),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消',
                style: TextStyle(color: AppColors.textSecondary)),
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
                      '已更新警示閥值：${newSys.toInt()}/${newDia.toInt()} mmHg',
                    ),
                  ),
                );
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('儲存設定',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddReadingDialog(BuildContext context) {
    final sysController = TextEditingController(text: '125');
    final diaController = TextEditingController(text: '82');

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
                  '手動輸入血壓數值',
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
                labelText: '收縮壓 (Systolic mmHg)',
                prefixIcon: const Icon(Icons.favorite_rounded,
                    color: BloodPressurePage.systolicColor),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: diaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '舒張壓 (Diastolic mmHg)',
                prefixIcon: const Icon(Icons.favorite_border_rounded,
                    color: BloodPressurePage.diastolicColor),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  if (sys != null && dia != null) {
                    setState(() {
                      _userCustomReadings.add(
                        BloodPressureReading(
                          time: DateTime.now(),
                          systolic: sys,
                          diastolic: dia,
                        ),
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已記錄新數值：${sys.toInt()}/${dia.toInt()} mmHg'),
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bloodPressure,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  '儲存並更新圖表',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
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
          '血壓',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _buildDataSourceBadge(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.speed_rounded, color: AppColors.bloodPressure),
            tooltip: '發送即時量測指令',
            onPressed: _triggerLiveMeasurement,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastReadingCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '血壓趨勢',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                _buildPeriodSelector(),
              ],
            ),
            const SizedBox(height: 16),
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
    );
  }

  // ---------------------------------------------------------------------
  // Warning Values & Threshold Section
  // ---------------------------------------------------------------------
  Widget _buildWarningValuesSection() {
    final statusInfo = _evaluateBPStatus(_lastReading.systolic, _lastReading.diastolic);
    final Color statusColor = statusInfo['color'] as Color;
    final Color bgColor = statusInfo['bgColor'] as Color;
    final String statusTitle = statusInfo['status'] as String;
    final String statusDesc = statusInfo['desc'] as String;
    final IconData statusIcon = statusInfo['icon'] as IconData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '血壓警示標準與閥值',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        // 1. Current Reading Status Evaluation Banner
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
                          '目前狀態評估：',
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

        // 2. Reference Table / Range Guide
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
                    '血壓分級警示對照表',
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
                category: '理想正常 (Normal)',
                systolicRange: '< 120',
                diastolicRange: '< 80',
                badgeColor: const Color(0xFF2E7D32),
                badgeBg: const Color(0xFFE8F5E9),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: '偏高警示 (Elevated)',
                systolicRange: '120-129',
                diastolicRange: '< 80',
                badgeColor: const Color(0xFFB08500),
                badgeBg: const Color(0xFFFFF8E1),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: '輕度高血壓 (Stage 1)',
                systolicRange: '130-139',
                diastolicRange: '80-89',
                badgeColor: const Color(0xFFE65100),
                badgeBg: const Color(0xFFFFF3E0),
              ),
              const Divider(height: 20),
              _thresholdRow(
                category: '重度高血壓 (Stage 2)',
                systolicRange: '≥ 140',
                diastolicRange: '≥ 90',
                badgeColor: const Color(0xFFB00020),
                badgeBg: const Color(0xFFFFEBEE),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Custom Warning Alert Settings Card
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
                  const Text(
                    '個人推播警示閥值',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
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
                            '自訂閥值',
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
                        '收縮壓警示上限',
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
                        '舒張壓警示上限',
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

    if (systolic >= 140 || diastolic >= 90) {
      return {
        'status': '重度高血壓 (Stage 2)',
        'color': const Color(0xFFB00020),
        'bgColor': const Color(0xFFFFEBEE),
        'desc': '目前數值顯著偏高！建議靜坐休息後重新測量，並儘速諮詢醫師專業評估。',
        'icon': Icons.error_rounded,
      };
    } else if (exceedsUserThreshold) {
      return {
        'status': '超出個人自訂閥值',
        'color': const Color(0xFFE65100),
        'bgColor': const Color(0xFFFFF3E0),
        'desc': '讀數高於您設定的個人警示門檻 (${_warningSystolicLimit.toInt()}/${_warningDiastolicLimit.toInt()} mmHg)，請適度放鬆休息。',
        'icon': Icons.warning_amber_rounded,
      };
    } else if (systolic >= 120) {
      return {
        'status': '偏高警示 (Elevated)',
        'color': const Color(0xFFB08500),
        'bgColor': const Color(0xFFFFF8E1),
        'desc': '血壓處於臨界區間，保持規律運動與放鬆心情即可恢復理想狀態。',
        'icon': Icons.info_rounded,
      };
    } else {
      return {
        'status': '理想正常 (Normal)',
        'color': const Color(0xFF2E7D32),
        'bgColor': const Color(0xFFE8F5E9),
        'desc': '血壓數值符合健康標準與個人自訂閥值，請繼續維持良好的健康習慣！',
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
        Container(
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
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '收縮壓: $systolicRange mmHg',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '舒張壓: $diastolicRange mmHg',
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
          _periodButton('日', TimeFilter.day),
          _periodButton('週', TimeFilter.week),
          _periodButton('月', TimeFilter.month),
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

  // ---------------------------------------------------------------------
  // Last reading
  // ---------------------------------------------------------------------
  Widget _buildLastReadingCard() {
    final r = _lastReading;
    final year = r.time.year;
    final month = r.time.month.toString().padLeft(2, '0');
    final day = r.time.day.toString().padLeft(2, '0');
    final hour = r.time.hour.toString().padLeft(2, '0');
    final minute = r.time.minute.toString().padLeft(2, '0');
    final second = r.time.second.toString().padLeft(2, '0');
    final fullTimestamp = '$year-$month-$day $hour:$minute:$second';

    // Blood Pressure Category Percentage Donut Circle calculation
    final readings = _currentReadings;
    int normalCount = 0;
    int elevatedCount = 0;
    int stage1Count = 0;
    int stage2Count = 0;

    for (final reading in readings) {
      final sys = reading.systolic;
      final dia = reading.diastolic;
      if (sys >= 140 || dia >= 90) {
        stage2Count++;
      } else if ((sys >= 130 && sys <= 139) || (dia >= 80 && dia <= 89)) {
        stage1Count++;
      } else if ((sys >= 120 && sys <= 129) && dia < 80) {
        elevatedCount++;
      } else {
        normalCount++;
      }
    }

    final total = readings.length;
    final normalPct = total > 0 ? (normalCount / total * 100).round() : 0;
    final elevatedPct = total > 0 ? (elevatedCount / total * 100).round() : 0;
    final stage1Pct = total > 0 ? (stage1Count / total * 100).round() : 0;
    final stage2Pct = total > 0 ? (stage2Count / total * 100).round() : 0;

    final categories = [
      (name: '理想正常 (Normal)', count: normalCount, pct: normalPct, color: const Color(0xFF30D158)),
      (name: '血壓偏高 (Elevated)', count: elevatedCount, pct: elevatedPct, color: const Color(0xFFFF9F0A)),
      (name: '一級高血壓 (Stage 1)', count: stage1Count, pct: stage1Pct, color: const Color(0xFFFF6B35)),
      (name: '二級高血壓 (Stage 2)', count: stage2Count, pct: stage2Pct, color: const Color(0xFFFF2D55)),
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
          // Upper section: Reading Info on Left, Donut Circle Chart on Top Right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Latest Reading Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '最新讀數',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildDataSourceBadge(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$fullTimestamp',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right Column (Top Right): Circle Donut Chart
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

          // Divider separating top reading & donut chart from category list
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: AppColors.textTertiary.withOpacity(0.2),
            ),
          ),

          // Lower Section: Category Breakdown List
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
                '血壓分佈比例',
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
                      '${cat.count}次 (${cat.pct}%)',
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

  // ---------------------------------------------------------------------
  // Chart
  // ---------------------------------------------------------------------
  Widget _buildChartCard() {
    final readings = _currentReadings;
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
          Row(
            children: [
              _legendDot(BloodPressurePage.systolicColor, '收縮壓 (Systolic)'),
              const SizedBox(width: 16),
              _legendDot(BloodPressurePage.diastolicColor, '舒張壓 (Diastolic)'),
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
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.toInt()}',
                            TextStyle(
                              color: s.barIndex == 0
                                  ? BloodPressurePage.systolicColor
                                  : BloodPressurePage.diastolicColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: systolicSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: BloodPressurePage.systolicColor,
                    dotData: const FlDotData(show: false),
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
                    dotData: const FlDotData(show: false),
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

  // ---------------------------------------------------------------------
  // Daily stats
  // ---------------------------------------------------------------------
  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: '收縮壓',
            max: _maxSystolic,
            min: _minSystolic,
            avg: _avgSystolic,
            color: BloodPressurePage.systolicColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            title: '舒張壓',
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
          _statRow('最高', max),
          const SizedBox(height: 6),
          _statRow('最低', min),
          const SizedBox(height: 6),
          _statRow('平均', avg),
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
        Text(
          '${value.toStringAsFixed(0)} mmHg',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Measure now button
  // ---------------------------------------------------------------------
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
              label: const Text(
                '手動輸入',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.bloodPressure),
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
              label: const Text(
                '立即測量',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}