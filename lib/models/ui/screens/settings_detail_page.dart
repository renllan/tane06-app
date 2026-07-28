import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/repositories/device_repository.dart';

enum SettingsCategory {
  profile,
  health,
  step,
  sleep,
  safety,
  call,
  location,
  watch,
  remoteCommands,
}

class SettingsDetailPage extends StatefulWidget {
  final SettingsCategory category;
  final Map<String, dynamic> settingsData;
  final String? imei;

  const SettingsDetailPage({
    super.key,
    required this.category,
    required this.settingsData,
    this.imei,
  });

  @override
  State<SettingsDetailPage> createState() => _SettingsDetailPageState();
}

class _SettingsDetailPageState extends State<SettingsDetailPage> {
  late Map<String, dynamic> _data;
  final DeviceRepository _deviceRepository = DeviceRepository();

  @override
  void initState() {
    super.initState();
    // Deep clone state data for responsive second-level editing
    _data = Map<String, dynamic>.from(widget.settingsData);
  }

  void _saveAndPop() {
    Navigator.of(context).pop(_data);
  }

  String _getCategoryTitle() {
    switch (widget.category) {
      case SettingsCategory.profile:
        return '個人資料與體態 (User Profile)';
      case SettingsCategory.health:
        return '健康監測詳細設定';
      case SettingsCategory.step:
        return '運動與計步目標';
      case SettingsCategory.sleep:
        return '睡眠監測與排程';
      case SettingsCategory.safety:
        return '安全防護與 SOS';
      case SettingsCategory.call:
        return '通話與訊息防護';
      case SettingsCategory.location:
        return '定位與同步頻率';
      case SettingsCategory.watch:
        return '手錶系統與硬體';
      case SettingsCategory.remoteCommands:
        return '遠端指令與控制';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveAndPop();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          title: Text(
            _getCategoryTitle(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saveAndPop,
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryContent(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContent() {
    switch (widget.category) {
      case SettingsCategory.profile:
        return _buildProfileDetail();
      case SettingsCategory.health:
        return _buildHealthDetail();
      case SettingsCategory.step:
        return _buildStepDetail();
      case SettingsCategory.sleep:
        return _buildSleepDetail();
      case SettingsCategory.safety:
        return _buildSafetyDetail();
      case SettingsCategory.call:
        return _buildCallDetail();
      case SettingsCategory.location:
        return _buildLocationDetail();
      case SettingsCategory.watch:
        return _buildWatchDetail();
      case SettingsCategory.remoteCommands:
        return _buildRemoteCommandsDetail();
    }
  }

  // ---------------------------------------------------------------------
  // 0. User Profile Detail (Age, Sex, Height, Weight)
  // ---------------------------------------------------------------------
  Widget _buildProfileDetail() {
    final profile = _data['profile'] as Map<String, dynamic>? ?? {
      'age': 32,
      'sex': 'Male',
      'height': 175,
      'weight': 70,
    };
    _data['profile'] ??= profile;

    final age = profile['age'] as int? ?? 32;
    final sex = profile['sex']?.toString() ?? 'Male';
    final height = profile['height'] as num? ?? 175;
    final weight = profile['weight'] as num? ?? 70;

    return Column(
      children: [
        // Profile Summary Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6D5D), Color(0xFF3D8A76)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '使用者個人資料 (User Profile)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '年齡 $age 歲 • 性別 ${sex == "Male" ? "男" : sex == "Female" ? "女" : sex} • $height cm • $weight kg',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // User Profile Attributes Group
        _buildCardGroup(
          title: '基本體態與個人資料設定',
          icon: Icons.badge_rounded,
          iconColor: const Color(0xFF5E5CE6),
          children: [
            // Age
            _buildNumberTile(
              title: '年齡 (Age)',
              value: '$age 歲',
              onTap: () => _editValue(
                '設定年齡 (歲)',
                age.toString(),
                (val) => setState(() => profile['age'] = int.tryParse(val) ?? age),
              ),
            ),
            // Sex / Gender Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    '性別 (Sex)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Male', label: Text('男')),
                      ButtonSegment(value: 'Female', label: Text('女')),
                      ButtonSegment(value: 'Other', label: Text('其他')),
                    ],
                    selected: {sex},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        profile['sex'] = newSelection.first;
                      });
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            // Height
            _buildNumberTile(
              title: '身高 (Height)',
              value: '$height cm',
              onTap: () => _editValue(
                '設定身高 (cm)',
                height.toString(),
                (val) => setState(() => profile['height'] = num.tryParse(val) ?? height),
              ),
            ),
            // Weight
            _buildNumberTile(
              title: '體重 (Weight)',
              value: '$weight kg',
              onTap: () => _editValue(
                '設定體重 (kg)',
                weight.toString(),
                (val) => setState(() => profile['weight'] = num.tryParse(val) ?? weight),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Health Indicators Group based on Profile
        _buildCardGroup(
          title: '體態與基礎代謝預估 (Health Baseline)',
          icon: Icons.analytics_rounded,
          iconColor: const Color(0xFF4CBF87),
          children: [
            _buildInfoTile(
              '基础代謝率 (BMR 預估)',
              '${(10 * weight + 6.25 * height - 5 * age + (sex == "Female" ? -161 : 5)).toStringAsFixed(0)} kcal/日',
            ),
            _buildInfoTile(
              '身體質量指數 (BMI 預估)',
              '${(weight / ((height / 100) * (height / 100))).toStringAsFixed(1)} kg/m²',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeartRateZonesCard(int age) {
    final maxHr = 220 - age;
    final lightMin = (maxHr * 0.50).round();
    final lightMax = (maxHr * 0.63).round();
    final modMin = (maxHr * 0.64).round();
    final modMax = (maxHr * 0.76).round();
    final vigMin = (maxHr * 0.77).round();
    final vigMax = (maxHr * 0.92).round();
    final peakMin = (maxHr * 0.93).round();
    final peakMax = maxHr;

    return _buildCardGroup(
      title: '基於年齡之心率區間 (Heart Rate Zones - Age $age)',
      icon: Icons.monitor_heart_rounded,
      iconColor: const Color(0xFFE96B6B),
      children: [
        _buildInfoTile('預估最大心率 (Max HR = 220 - Age)', '$maxHr bpm'),
        _buildZoneRow('Light (輕度/暖身 50%-63%)', '$lightMin - $lightMax bpm', const Color(0xFF5BB8F5), 0.63),
        _buildZoneRow('Moderate (中度/有氧 64%-76%)', '$modMin - $modMax bpm', const Color(0xFF4CBF87), 0.76),
        _buildZoneRow('Vigorous (重度/無氧 77%-92%)', '$vigMin - $vigMax bpm', const Color(0xFFFFA24D), 0.92),
        _buildZoneRow('Peak (頂峰/極限 93%-100%)', '$peakMin - $peakMax bpm', const Color(0xFFE96B6B), 1.00),
      ],
    );
  }

  Widget _buildZoneRow(String title, String range, Color color, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                range,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.15),
              color: color,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 1. Health Detail (Heart Rate, Blood Pressure, SpO2, Body Temp)
  // ---------------------------------------------------------------------
  Widget _buildHealthDetail() {
    final health = _data['health'] as Map<String, dynamic>;
    final hr = health['heart_rate'] as Map<String, dynamic>;
    final bp = health['blood_pressure'] as Map<String, dynamic>;
    final bo = health['blood_oxygen'] as Map<String, dynamic>;
    final temp = health['body_temperature'] as Map<String, dynamic>;

    return Column(
      children: [
        // Heart Rate Section
        _buildCardGroup(
          title: '心率監測設定',
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFE96B6B),
          children: [
            _buildSwitchTile(
              title: '啟用心率自動監測',
              value: hr['switch_state'] == 1,
              onChanged: (v) => setState(() => hr['switch_state'] = v ? 1 : 0),
            ),
            _buildInfoTile('量測間隔頻率', '${hr['interval']} 分鐘/次'),
            _buildNumberTile(
              title: '高心率警示門檻',
              value: '${hr['high_warning']['value']} bpm',
              onTap: () => _editValue(
                '高心率警示門檻 (bpm)',
                hr['high_warning']['value'].toString(),
                (val) => setState(() => hr['high_warning']['value'] = int.tryParse(val) ?? 120),
              ),
            ),
            _buildNumberTile(
              title: '運動高心率警示門檻',
              value: '${hr['high_warning']['exercise_value']} bpm',
              onTap: () => _editValue(
                '運動高心率警示門檻 (bpm)',
                hr['high_warning']['exercise_value'].toString(),
                (val) => setState(() => hr['high_warning']['exercise_value'] = int.tryParse(val) ?? 140),
              ),
            ),
            _buildNumberTile(
              title: '低心率警示門檻',
              value: '${hr['low_warning']['value']} bpm',
              onTap: () => _editValue(
                '低心率警示門檻 (bpm)',
                hr['low_warning']['value'].toString(),
                (val) => setState(() => hr['low_warning']['value'] = int.tryParse(val) ?? 60),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Age-Based Heart Rate Zones
        _buildHeartRateZonesCard((_data['profile'] as Map<String, dynamic>?)?['age'] as int? ?? 32),

        const SizedBox(height: 16),

        // Blood Pressure Section
        _buildCardGroup(
          title: '血壓監測與預警',
          icon: Icons.monitor_heart_rounded,
          iconColor: AppColors.bloodPressure,
          children: [
            _buildSwitchTile(
              title: '定時自動血壓量測',
              value: bp['timer_measure']['switch_state'] == 1,
              onChanged: (v) => setState(() => bp['timer_measure']['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: '血壓量測頻率 (Measure Frequency)',
              value: (bp['interval'] == '0' || bp['interval'] == 0)
                  ? '手動 / 關閉'
                  : '${bp['interval'] ?? "60"} 分鐘/次',
              onTap: () => _showBpIntervalDialog(bp),
            ),
            _buildInfoTile('早晨定時量測時間', bp['timer_measure']['am_time']),
            _buildInfoTile('傍晚定時量測時間', bp['timer_measure']['pm_time']),
            _buildSwitchTile(
              title: '啟用血壓異常警示',
              value: bp['warning']['switch_state'] == 1,
              onChanged: (v) => setState(() => bp['warning']['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: '收縮壓警示上限',
              value: '${bp['warning']['high']} mmHg',
              onTap: () => _editValue(
                '收縮壓上限 (mmHg)',
                bp['warning']['high'].toString(),
                (val) => setState(() => bp['warning']['high'] = int.tryParse(val) ?? 135),
              ),
            ),
            _buildNumberTile(
              title: '舒張壓警示下限',
              value: '${bp['warning']['low']} mmHg',
              onTap: () => _editValue(
                '舒張壓下限 (mmHg)',
                bp['warning']['low'].toString(),
                (val) => setState(() => bp['warning']['low'] = int.tryParse(val) ?? 90),
              ),
            ),
          ],
        ),


        const SizedBox(height: 16),

        // Blood Oxygen Section
        _buildCardGroup(
          title: '血氧 (SpO₂) 監測',
          icon: Icons.water_drop_rounded,
          iconColor: const Color(0xFF4BA3C7),
          children: [
            _buildSwitchTile(
              title: '啟用血氧自動監測',
              value: bo['switch_state'] == 1,
              onChanged: (v) => setState(() => bo['switch_state'] = v ? 1 : 0),
            ),
            _buildInfoTile('量測頻率', '${bo['interval']} 分鐘/次'),
            _buildNumberTile(
              title: '過低血氧警示門檻',
              value: '${bo['low_warning']['value']}%',
              onTap: () => _editValue(
                '過低血氧門檻 (%)',
                bo['low_warning']['value'].toString(),
                (val) => setState(() => bo['low_warning']['value'] = int.tryParse(val) ?? 90),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Body Temperature Section
        _buildCardGroup(
          title: '體溫監測設定',
          icon: Icons.thermostat_rounded,
          iconColor: const Color(0xFFFFA24D),
          children: [
            _buildSwitchTile(
              title: '啟用體溫自動監測',
              value: temp['switch_state'] == 1,
              onChanged: (v) => setState(() => temp['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: '發燒高溫警示門檻',
              value: '${temp['high_warning']['value']} °C',
              onTap: () => _editValue(
                '高溫警示門檻 (°C)',
                temp['high_warning']['value'].toString(),
                (val) => setState(() => temp['high_warning']['value'] = double.tryParse(val) ?? 38.5),
              ),
            ),
            _buildNumberTile(
              title: '低體溫警示門檻',
              value: '${temp['low_warning']['value']} °C',
              onTap: () => _editValue(
                '低溫警示門檻 (°C)',
                temp['low_warning']['value'].toString(),
                (val) => setState(() => temp['low_warning']['value'] = double.tryParse(val) ?? 35.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 2. Step Detail
  // ---------------------------------------------------------------------
  Widget _buildStepDetail() {
    final step = _data['step'] as Map<String, dynamic>;
    return _buildCardGroup(
      title: '計步與每日運動目標',
      icon: Icons.directions_run_rounded,
      iconColor: const Color(0xFF4BA3C7),
      children: [
        _buildNumberTile(
          title: '每日目標步數',
          value: '${step['step_target']} 步',
          onTap: () => _editValue(
            '每日目標步數',
            step['step_target'].toString(),
            (val) => setState(() => step['step_target'] = val),
          ),
        ),
        _buildNumberTile(
          title: '每日運動時間目標',
          value: '${step['exercise_time_target']} 分鐘',
          onTap: () => _editValue(
            '運動時間目標 (分鐘)',
            step['exercise_time_target'].toString(),
            (val) => setState(() => step['exercise_time_target'] = val),
          ),
        ),
        _buildInfoTile('數據更新同步間隔', '${step['interval']} 分鐘'),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 3. Sleep Detail
  // ---------------------------------------------------------------------
  Widget _buildSleepDetail() {
    final sleep = _data['sleep'] as Map<String, dynamic>;
    final startTimeRaw = sleep['start_time'].toString().padLeft(6, '0');
    final endTimeRaw = sleep['end_time'].toString().padLeft(6, '0');
    final startTimeStr = '${startTimeRaw.substring(0, 2)}:${startTimeRaw.substring(2, 4)}';
    final endTimeStr = '${endTimeRaw.substring(0, 2)}:${endTimeRaw.substring(2, 4)}';

    return _buildCardGroup(
      title: '睡眠監測與排程設定',
      icon: Icons.bedtime_rounded,
      iconColor: const Color(0xFF4CBF87),
      children: [
        _buildSwitchTile(
          title: '啟用自動睡眠追蹤',
          value: sleep['switch_state'] == 1,
          onChanged: (v) => setState(() => sleep['switch_state'] = v ? 1 : 0),
        ),
        _buildNumberTile(
          title: '睡眠偵測開始時間 (Bedtime)',
          value: startTimeStr,
          onTap: () => _pickSleepTime(
            context: context,
            title: '睡眠偵測開始時間',
            initialHHMM: startTimeStr,
            onPicked: (newVal) => setState(() => sleep['start_time'] = newVal),
          ),
        ),
        _buildNumberTile(
          title: '睡眠偵測結束/起床時間 (Wake Time / Stop)',
          value: endTimeStr,
          onTap: () => _pickSleepTime(
            context: context,
            title: '睡眠偵測結束/起床時間',
            initialHHMM: endTimeStr,
            onPicked: (newVal) => setState(() => sleep['end_time'] = newVal),
          ),
        ),
        _buildNumberTile(
          title: '目標睡眠時數',
          value: '${(sleep['target'] as int) ~/ 60} 小時 (${sleep['target']} 分鐘)',
          onTap: () => _editValue(
            '目標睡眠時數 (分鐘)',
            sleep['target'].toString(),
            (val) => setState(() => sleep['target'] = int.tryParse(val) ?? 480),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 4. Safety Detail
  // ---------------------------------------------------------------------
  Widget _buildSafetyDetail() {
    final safety = _data['safety'] as Map<String, dynamic>;
    final sos = safety['sos'] as Map<String, dynamic>;
    final fall = safety['fall_warning'] as Map<String, dynamic>;

    final List<Map<String, dynamic>> sosNumbers =
        ((sos['sos_numbers'] as List?) ?? [
      {'name': '父親 (家長)', 'phone': '0912345678', 'priority': 1},
      {'name': '母親', 'phone': '0923456789', 'priority': 2},
      {'name': '緊急救護 (119)', 'phone': '119', 'priority': 3},
    ]).cast<Map<String, dynamic>>();

    final List<Map<String, dynamic>> familyMembers =
        ((safety['family_members'] as List?) ?? [
      {'name': '父親 (主要照護)', 'relation': '父親', 'phone': '0912345678', 'isPrimary': true},
      {'name': '母親', 'relation': '母親', 'phone': '0923456789', 'isPrimary': false},
      {'name': '女兒', 'relation': '女兒', 'phone': '0934567890', 'isPrimary': false},
    ]).cast<Map<String, dynamic>>();

    return Column(
      children: [
        // 1. SOS System Settings Card
        _buildCardGroup(
          title: '安全防護與 SOS 設定',
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFFFF9500),
          children: [
            _buildSwitchTile(
              title: '啟用 SOS 一鍵求救',
              value: sos['switch_state'] == 1,
              onChanged: (v) => setState(() => sos['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: 'SOS 緊急聯絡人輪播次數',
              value: '${sos['rotation']} 次',
              onTap: () => _editValue(
                'SOS 輪播次數',
                sos['rotation'].toString(),
                (val) => setState(() => sos['rotation'] = val),
              ),
            ),
            _buildSwitchTile(
              title: '跌倒自動偵測與警示通知',
              value: fall['switch_state'] == 1,
              onChanged: (v) => setState(() => fall['switch_state'] = v ? 1 : 0),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 2. SOS Speed-Dial Numbers Section
        _buildCardGroup(
          title: 'SOS 緊急撥號電話 (SOS Numbers)',
          icon: Icons.contact_phone_rounded,
          iconColor: const Color(0xFFEF5350),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '長按手錶實體 SOS 鍵時，將按優先順序自動依次撥打以下號碼。',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ...sosNumbers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMedium,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF5350).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SOS ${index + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF5350),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'].toString(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['phone'].toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            onPressed: () => _showEditSosNumberDialog(context, item, (newName, newPhone) {
                              setState(() {
                                item['name'] = newName;
                                item['phone'] = newPhone;
                              });
                            }),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Family Members Section
        _buildCardGroup(
          title: '家庭成員名單 (Family Members)',
          icon: Icons.family_restroom_rounded,
          iconColor: const Color(0xFF4BA3C7),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '關懷照護者與聯絡家屬',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddFamilyMemberDialog(context, (newMember) {
                          setState(() {
                            familyMembers.add(newMember);
                            safety['family_members'] = familyMembers;
                          });
                        }),
                        icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                        label: const Text(
                          '新增成員',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...familyMembers.map((member) {
                    final bool isPrimary = member['isPrimary'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMedium,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isPrimary ? AppColors.primary.withOpacity(0.2) : Colors.black12,
                            child: Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: isPrimary ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      member['name'].toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isPrimary) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '主要照護者',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${member['relation']} • ${member['phone']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                familyMembers.remove(member);
                                safety['family_members'] = familyMembers;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 5. Call Detail
  // ---------------------------------------------------------------------
  Widget _buildCallDetail() {
    final call = _data['call'] as Map<String, dynamic>;
    final msg = call['message'] as Map<String, dynamic>;
    final limit = call['incoming_call_limit'] as Map<String, dynamic>;
    final answer = call['answer_mode'] as Map<String, dynamic>;

    return _buildCardGroup(
      title: '通話與訊息防護設定',
      icon: Icons.phone_in_talk_rounded,
      iconColor: const Color(0xFF5E5CE6),
      children: [
        _buildSwitchTile(
          title: '新簡訊與訊息推播通知',
          value: msg['switch_state'] == 1,
          onChanged: (v) => setState(() => msg['switch_state'] = v ? 1 : 0),
        ),
        _buildSwitchTile(
          title: '限制陌生來電 (通訊錄白名單)',
          value: limit['switch_state'] == 1,
          onChanged: (v) => setState(() => limit['switch_state'] = v ? 1 : 0),
        ),
        _buildInfoTile('來電接聽模式', answer['value'] == 1 ? '自動接聽 (Auto)' : '手動接聽 (Manual)'),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 6. Location Detail
  // ---------------------------------------------------------------------
  Widget _buildLocationDetail() {
    final location = _data['location'] as Map<String, dynamic>;
    return _buildCardGroup(
      title: '定位與同步頻率',
      icon: Icons.location_on_rounded,
      iconColor: const Color(0xFF30D158),
      children: [
        _buildNumberTile(
          title: 'GPS/LBS 定位更新頻率',
          value: '${location['interval']} 分鐘/次',
          onTap: () => _editValue(
            '定位更新頻率 (分鐘)',
            location['interval'].toString(),
            (val) => setState(() => location['interval'] = int.tryParse(val) ?? 1440),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 7. Watch System Detail
  // ---------------------------------------------------------------------
  Widget _buildWatchDetail() {
    final watch = _data['watch'] as Map<String, dynamic>;

    return Column(
      children: [
        _buildCardGroup(
          title: '系統音量與顯示',
          icon: Icons.tune_rounded,
          iconColor: const Color(0xFF6C7FEA),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('手錶揚聲器音量', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                      Text('${watch['volume']['value']}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                  Slider(
                    value: (watch['volume']['value'] as int).toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => watch['volume']['value'] = v.toInt()),
                  ),
                ],
              ),
            ),
            _buildSwitchTile(
              title: '抬手自動亮屏',
              value: watch['wrist_lift']['switch_state'] == 1,
              onChanged: (v) => setState(() => watch['wrist_lift']['switch_state'] = v ? 1 : 0),
            ),
            _buildSwitchTile(
              title: '錶盤切換開關',
              value: watch['dial']['switch_state'] == 1,
              onChanged: (v) => setState(() => watch['dial']['switch_state'] = v ? 1 : 0),
            ),
            _buildInfoTile('時間顯示格式', '${watch['time_format_mode']['value']} 小時制'),
            _buildInfoTile('手錶系統語言', watch['language']['value'] == 'cn' ? '繁體/簡體中文' : 'English'),
          ],
        ),

        const SizedBox(height: 16),

        _buildCardGroup(
          title: '安全與電源管理',
          icon: Icons.battery_charging_full_rounded,
          iconColor: const Color(0xFF4CBF87),
          children: [
            _buildSwitchTile(
              title: '手錶螢幕解鎖密碼',
              value: watch['unlock_password']['switch_state'] == 1,
              onChanged: (v) => setState(() => watch['unlock_password']['switch_state'] = v ? 1 : 0),
            ),
            _buildSwitchTile(
              title: '省電模式 (Power Save)',
              value: watch['power_save_mode']['switch_state'] == 1,
              onChanged: (v) => setState(() => watch['power_save_mode']['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: '低電量提醒閥值',
              value: '${watch['low_power_battery']['value']}%',
              onTap: () => _editValue(
                '低電量提醒閥值 (%)',
                watch['low_power_battery']['value'].toString(),
                (val) => setState(() => watch['low_power_battery']['value'] = int.tryParse(val) ?? 60),
              ),
            ),
            _buildSwitchTile(
              title: '尋找我的手錶 (蜂鳴發聲)',
              value: watch['find_my_watch']['switch_state'] == 1,
              onChanged: (v) => setState(() => watch['find_my_watch']['switch_state'] = v ? 1 : 0),
            ),
            _buildSwitchTile(
              title: '手錶脫落/遺失防盜警示',
              value: watch['watch_lost']['switch_state'] == 1,
              onChanged: (v) => setState(() => watch['watch_lost']['switch_state'] = v ? 1 : 0),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Reusable Helper UI Widgets
  // ---------------------------------------------------------------------
  Widget _buildCardGroup({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined, size: 14, color: AppColors.textTertiary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _editValue(String title, String currentValue, ValueChanged<String> onSaved) {

    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('設定 $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              onSaved(controller.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 8. Remote Commands Detail (Find, Power off, Restart, Factory reset)
  // ---------------------------------------------------------------------
  Widget _buildRemoteCommandsDetail() {
    return Column(
      children: [
        _buildCardGroup(
          title: '設備尋找指令 (Find Device)',
          icon: Icons.notifications_active_rounded,
          iconColor: const Color(0xFF4BA3C7),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '發送尋找指令後，手錶將發出高音量鳴響與強烈震動，協助您快速尋找與定位手錶。',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmRemoteCommand(
                        title: '尋找手錶 (Find)',
                        message: '確定要向手錶發送尋找指令嗎？手錶將開始響鈴發聲。',
                        confirmText: '發送尋找指令',
                        color: AppColors.primary,
                        onConfirmed: () => _executeRemoteCommand(
                          action: 'find',
                          actionName: '尋找手錶',
                          successMsg: '已成功向手錶發送尋找指令！手錶正在響鈴...',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.ring_volume_rounded, color: AppColors.primary),
                      label: const Text('尋找手錶 (Find Device)', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildCardGroup(
          title: '遠端電源與系統控制 (System Control)',
          icon: Icons.settings_remote_rounded,
          iconColor: const Color(0xFF5E5CE6),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '系統遠端維護與電源控制操作，發送指令前請確認手錶狀況。',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmRemoteCommand(
                            title: '遠端重新啟動 (Restart)',
                            message: '確定要將手錶遠端重新啟動嗎？系統將在幾秒內重啟連線。',
                            confirmText: '重新啟動',
                            color: const Color(0xFF5E5CE6),
                            onConfirmed: () => _executeRemoteCommand(
                              action: 'restart',
                              actionName: '遠端重啟',
                              successMsg: '已發送遠端重啟指令，手錶將在幾秒內重啟...',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5E5CE6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('遠端重啟', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmRemoteCommand(
                            title: '遠端關機 (Power Off)',
                            message: '確定要將手錶遠端關機嗎？關機後需長按實體電源鍵開機。',
                            confirmText: '確定關機',
                            color: const Color(0xFFEF5350),
                            onConfirmed: () => _executeRemoteCommand(
                              action: 'power-off',
                              actionName: '遠端關機',
                              successMsg: '已發送遠端關機指令，手錶準備關機...',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF5350),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                          label: const Text('遠端關機', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildCardGroup(
          title: '危險區域 - 恢復出廠設定',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFB00020),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '恢復出廠設定將會清除手錶內存的所有紀錄與個人設定，並恢復至初次使用的原廠狀態。此操作無法復原！',
                    style: TextStyle(fontSize: 13, color: Color(0xFFB00020), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmRemoteCommand(
                        title: '恢復出廠設定 (Factory Reset)',
                        message: '警告：確定要執行恢復出廠設定嗎？此操作將清除手錶所有數據且無法復原！',
                        confirmText: '確認恢復原廠',
                        color: const Color(0xFFB00020),
                        onConfirmed: () => _executeRemoteCommand(
                          action: 'factory-reset',
                          actionName: '恢復出廠設定',
                          successMsg: '已發送恢復出廠設定指令！',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB00020),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('恢復出廠設定 (Factory Reset)', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmRemoteCommand({
    required String title,
    required String message,
    required String confirmText,
    required Color color,
    required VoidCallback onConfirmed,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.settings_remote_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirmed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRemoteCommand({
    required String action,
    required String actionName,
    required String successMsg,
  }) async {
    final imeiToUse = widget.imei;
    if (imeiToUse == null || imeiToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未提供裝置 IMEI，無法發送遠端指令')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final res = await _deviceRepository.sendCommand(imei: imeiToUse, action: action);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      final isSuccess = res['success'] == true;
      final serverMsg = res['message'] as String?;
      final msg = isSuccess ? (serverMsg ?? successMsg) : (serverMsg ?? '發送 $actionName 指令失敗');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('發送 $actionName 指令失敗：$e'),
          backgroundColor: const Color(0xFFB00020),
        ),
      );
    }
  }

  void _showEditSosNumberDialog(
    BuildContext context,
    Map<String, dynamic> item,
    void Function(String name, String phone) onSaved,
  ) {
    final nameController = TextEditingController(text: item['name'].toString());
    final phoneController = TextEditingController(text: item['phone'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.contact_phone_rounded, color: Color(0xFFEF5350)),
            const SizedBox(width: 8),
            Text(
              '設定 SOS ${item['priority'] ?? ''} 號碼',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '聯絡人名稱 / 稱謂',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '緊急撥號電話號碼',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              onSaved(nameController.text, phoneController.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('儲存號碼', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddFamilyMemberDialog(
    BuildContext context,
    ValueChanged<Map<String, dynamic>> onAdded,
  ) {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final phoneController = TextEditingController();
    bool isPrimary = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.family_restroom_rounded, color: Color(0xFF4BA3C7)),
              SizedBox(width: 8),
              Text(
                '新增家庭成員',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '成員姓名',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                decoration: InputDecoration(
                  labelText: '關係 / 稱謂 (例: 父親, 母親)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '電話號碼',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: isPrimary,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setDialogState(() => isPrimary = v ?? false),
                  ),
                  const Text('設為主要照顧者', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  onAdded({
                    'name': nameController.text,
                    'relation': relationController.text.isEmpty ? '家人' : relationController.text,
                    'phone': phoneController.text,
                    'isPrimary': isPrimary,
                  });
                }
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('新增成員', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSleepTime({
    required BuildContext context,
    required String title,
    required String initialHHMM,
    required ValueChanged<String> onPicked,
  }) async {
    final parts = initialHHMM.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 22,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: '選擇 $title',
    );

    if (picked != null) {
      final String hh = picked.hour.toString().padLeft(2, '0');
      final String mm = picked.minute.toString().padLeft(2, '0');
      final String formattedRaw = '${hh}${mm}00';
      onPicked(formattedRaw);
    }
  }

  void _showBpIntervalDialog(Map<String, dynamic> bp) {
    final currentVal = bp['interval']?.toString() ?? '60';
    final controller = TextEditingController(text: currentVal);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.monitor_heart_rounded, color: AppColors.bloodPressure),
              SizedBox(width: 8),
              Text('血壓量測頻率設定', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '選擇常用頻率或手動輸入分鐘數：',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
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
                  ].map((minutes) {
                    final isSelected = controller.text == minutes;
                    final label = minutes == '0' ? '手動/關閉' : '$minutes 分';
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: AppColors.bloodPressure.withOpacity(0.2),
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() {
                            controller.text = minutes;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '手動輸入頻率 (分鐘)',
                    hintText: '輸入任意分鐘數, 例: 45',
                    prefixIcon: const Icon(Icons.timer_outlined, color: AppColors.bloodPressure),
                    suffixText: '分鐘',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = controller.text.trim();
                final intervalValue = (int.tryParse(input) ?? 60).toString();
                setState(() {
                  bp['interval'] = intervalValue;
                });
                if (widget.imei != null && widget.imei!.isNotEmpty) {
                  try {
                    await _deviceRepository.saveSettings(
                      imei: widget.imei!,
                      patch: {
                        'health': {
                          'blood_pressure': {
                            'interval': intervalValue,
                          }
                        }
                      },
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已設定血壓量測頻率為 $intervalValue 分鐘並同步至伺服器')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('同步至伺服器失敗: $e')),
                      );
                    }
                  }
                }
                if (mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bloodPressure,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('儲存設定', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

