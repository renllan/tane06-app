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

  bool _areMapsEqual(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_areMapsEqual(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_areMapsEqual(a[i], b[i])) return false;
      }
      return true;
    }
    return false;
  }

  Future<void> _saveAndPop() async {
    final imeiToUse = widget.imei;

    bool hasChanges = false;
    Map<String, dynamic> patch = {};

    if (widget.category == SettingsCategory.profile) {
      hasChanges = !_areMapsEqual(_data['profile'], widget.settingsData['profile']);
    } else if (widget.category == SettingsCategory.health) {
      hasChanges = !_areMapsEqual(_data['health'], widget.settingsData['health']);
      if (hasChanges) patch['health'] = _data['health'];
    } else if (widget.category == SettingsCategory.step) {
      hasChanges = !_areMapsEqual(_data['step'], widget.settingsData['step']);
      if (hasChanges) patch['step'] = _data['step'];
    } else if (widget.category == SettingsCategory.sleep) {
      hasChanges = !_areMapsEqual(_data['sleep'], widget.settingsData['sleep']);
      if (hasChanges) patch['sleep'] = _data['sleep'];
    } else if (widget.category == SettingsCategory.safety) {
      hasChanges = !_areMapsEqual(_data['safety'], widget.settingsData['safety']);
      if (hasChanges) patch['safety'] = _data['safety'];
    } else if (widget.category == SettingsCategory.location ||
        widget.category == SettingsCategory.call ||
        widget.category == SettingsCategory.watch) {
      final locationChanged = !_areMapsEqual(_data['location'], widget.settingsData['location']);
      final callChanged = !_areMapsEqual(_data['call'], widget.settingsData['call']);
      final watchChanged = !_areMapsEqual(_data['watch'], widget.settingsData['watch']);
      hasChanges = locationChanged || callChanged || watchChanged;
      if (locationChanged) patch['location'] = _data['location'];
      if (callChanged) patch['call'] = _data['call'];
      if (watchChanged) patch['watch'] = _data['watch'];
    }

    if (hasChanges && imeiToUse != null && imeiToUse.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      try {
        if (widget.category == SettingsCategory.profile) {
          final profile = _data['profile'] as Map<String, dynamic>?;
          if (profile != null) {
            final height = (profile['height'] as num?)?.toInt() ?? 175;
            final weight = (profile['weight'] as num?)?.toDouble() ?? 70.0;
            final rawBirthday = profile['birthday']?.toString() ?? '19900101';
            final birthday = rawBirthday.replaceAll(RegExp(r'\D'), '');
            final formattedBirthday = birthday.length >= 8 ? birthday.substring(0, 8) : '19900101';
            final sex = profile['sex']?.toString() ?? 'Male';
            final int genderInt = (sex.toLowerCase() == 'male') ? 1 : 0;

            await _deviceRepository.setProfile(
              imei: imeiToUse,
              height: height,
              weight: weight,
              birthday: formattedBirthday,
              gender: genderInt,
            );
          }
        } else {
          await _deviceRepository.saveSettings(
            imei: imeiToUse,
            patch: patch,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save settings to server: $e'),
              backgroundColor: const Color(0xFFB00020),
            ),
          );
        }
      } finally {
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading indicator
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop(_data); // Return data to previous route
    }
  }

  String _getCategoryTitle() {
    switch (widget.category) {
      case SettingsCategory.profile:
        return 'User Profile';
      case SettingsCategory.health:
        return 'Health Monitoring Settings';
      case SettingsCategory.step:
        return 'Fitness & Step Goals';
      case SettingsCategory.sleep:
        return 'Sleep Tracking & Schedule';
      case SettingsCategory.safety:
        return 'Safety Protection & SOS';
      case SettingsCategory.call:
        return 'Calls & Messages Protection';
      case SettingsCategory.location:
        return 'Location & Sync Frequency';
      case SettingsCategory.watch:
        return 'Watch System & Hardware';
      case SettingsCategory.remoteCommands:
        return 'Remote Commands & Control';
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
                'Done',
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
        return _buildSafetySettingsGroup();
      case SettingsCategory.call:
        return _buildCommunicationAndSystem();
      case SettingsCategory.location:
        return _buildCommunicationAndSystem();
      case SettingsCategory.watch:
        return _buildCommunicationAndSystem();
      case SettingsCategory.remoteCommands:
        return _buildRemoteCommandsGroup();
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
                      'User Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age $age • Sex $sex • $height cm • $weight kg',
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
          title: 'Profile & Body Metrics',
          icon: Icons.badge_rounded,
          iconColor: const Color(0xFF5E5CE6),
          children: [
            // Age
            _buildNumberTile(
              title: 'Age',
              value: '$age yrs',
              onTap: () => _editValue(
                'Set Age (years)',
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
                    'Sex',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Male', label: Text('Male')),
                      ButtonSegment(value: 'Female', label: Text('Female')),
                      ButtonSegment(value: 'Other', label: Text('Other')),
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
              title: 'Height',
              value: '$height cm',
              onTap: () => _editValue(
                'Set Height (cm)',
                height.toString(),
                (val) => setState(() => profile['height'] = num.tryParse(val) ?? height),
              ),
            ),
            // Weight
            _buildNumberTile(
              title: 'Weight',
              value: '$weight kg',
              onTap: () => _editValue(
                'Set Weight (kg)',
                weight.toString(),
                (val) => setState(() => profile['weight'] = num.tryParse(val) ?? weight),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Health Indicators Group based on Profile
        _buildCardGroup(
          title: 'Health Baseline & Metabolism',
          icon: Icons.analytics_rounded,
          iconColor: const Color(0xFF4CBF87),
          children: [
            _buildInfoTile(
              'Basal Metabolic Rate (Est. BMR)',
              '${(10 * weight + 6.25 * height - 5 * age + (sex == "Female" ? -161 : 5)).toStringAsFixed(0)} kcal/day',
            ),
            _buildInfoTile(
              'Body Mass Index (Est. BMI)',
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
      title: 'Heart Rate Zones (Age $age)',
      icon: Icons.monitor_heart_rounded,
      iconColor: const Color(0xFFE96B6B),
      children: [
        _buildInfoTile('Estimated Max HR (220 - Age)', '$maxHr bpm'),
        _buildZoneRow('Light (Warm-up 50%-63%)', '$lightMin - $lightMax bpm', const Color(0xFF5BB8F5), 0.63),
        _buildZoneRow('Moderate (Aerobic 64%-76%)', '$modMin - $modMax bpm', const Color(0xFF4CBF87), 0.76),
        _buildZoneRow('Vigorous (Anaerobic 77%-92%)', '$vigMin - $vigMax bpm', const Color(0xFFFFA24D), 0.92),
        _buildZoneRow('Peak (Extreme 93%-100%)', '$peakMin - $peakMax bpm', const Color(0xFFE96B6B), 1.00),
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
    final profile = _data['profile'] as Map<String, dynamic>?;
    final hr = health['heart_rate'] as Map<String, dynamic>;
    final bp = health['blood_pressure'] as Map<String, dynamic>;
    final bo = health['blood_oxygen'] as Map<String, dynamic>;

    return Column(
      children: [
        // Heart Rate Section
        _buildCardGroup(
          title: 'Heart Rate Monitoring',
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFE96B6B),
          children: [
            _buildSwitchTile(
              title: 'Auto Heart Rate Monitoring',
              value: hr['switch_state'] == 1,
              onChanged: (v) => setState(() => hr['switch_state'] = v ? 1 : 0),
            ),
            // Updated to be editable via dialog
            _buildNumberTile(
              title: 'Interval Frequency',
              value: (hr['interval'] == '0' || hr['interval'] == 0)
                  ? 'Off / Manual'
                  : '${hr['interval'] ?? "10"} min/test',
              onTap: () => _showHrIntervalDialog(hr),
            ),
            _buildNumberTile(
              title: 'High HR Warning Limit',
              value: '${hr['high_warning']['value']} bpm',
              onTap: () => _editValue(
                'High HR Warning (bpm)',
                hr['high_warning']['value'].toString(),
                (val) => setState(() => hr['high_warning']['value'] = int.tryParse(val) ?? 120),
              ),
            ),
            _buildNumberTile(
              title: 'Exercise High HR Warning Limit',
              value: '${hr['high_warning']['exercise_value']} bpm',
              onTap: () => _editValue(
                'Exercise High HR Warning (bpm)',
                hr['high_warning']['exercise_value'].toString(),
                (val) => setState(() => hr['high_warning']['exercise_value'] = int.tryParse(val) ?? 140),
              ),
            ),
            _buildNumberTile(
              title: 'Low HR Warning Limit',
              value: '${hr['low_warning']['value']} bpm',
              onTap: () => _editValue(
                'Low HR Warning (bpm)',
                hr['low_warning']['value'].toString(),
                (val) => setState(() => hr['low_warning']['value'] = int.tryParse(val) ?? 60),
              ),
            ),
          ],
        ),

        // Age-Based Heart Rate Zones
        _buildHeartRateZonesCard(profile?['age'] as int? ?? 32),

        const SizedBox(height: 16),

        // Blood Pressure Section
        _buildCardGroup(
          title: 'Blood Pressure Monitoring',
          icon: Icons.monitor_heart_rounded,
          iconColor: AppColors.bloodPressure,
          children: [
            _buildSwitchTile(
              title: 'Scheduled Auto BP Measurement',
              value: bp['timer_measure']['switch_state'] == 1,
              onChanged: (v) => setState(() => bp['timer_measure']['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: 'BP Measurement Frequency',
              value: (bp['interval'] == '0' || bp['interval'] == 0)
                  ? 'Off / Manual'
                  : '${bp['interval'] ?? "60"} min/test',
              onTap: () => _showBpIntervalDialog(bp),
            ),
            _buildNumberTile(
              title: 'Morning Scheduled Time',
              value: bp['timer_measure']['am_time']?.toString() ?? '07:00',
              onTap: () => _pickBpTime(
                context: context,
                title: 'Morning Scheduled Time',
                initialHHMM: bp['timer_measure']['am_time']?.toString() ?? '07:00',
                onPicked: (newVal) => setState(() => bp['timer_measure']['am_time'] = newVal),
              ),
            ),
            _buildNumberTile(
              title: 'Evening Scheduled Time',
              value: bp['timer_measure']['pm_time']?.toString() ?? '18:00',
              onTap: () => _pickBpTime(
                context: context,
                title: 'Evening Scheduled Time',
                initialHHMM: bp['timer_measure']['pm_time']?.toString() ?? '18:00',
                onPicked: (newVal) => setState(() => bp['timer_measure']['pm_time'] = newVal),
              ),
            ),
            _buildSwitchTile(
              title: 'Enable Abnormal BP Warning',
              value: bp['warning']['switch_state'] == 1,
              onChanged: (v) => setState(() => bp['warning']['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: 'Systolic Warning Limit',
              value: '${bp['warning']['high']} mmHg',
              onTap: () => _editValue(
                'Systolic Limit (mmHg)',
                bp['warning']['high'].toString(),
                (val) => setState(() => bp['warning']['high'] = int.tryParse(val) ?? 140),
              ),
            ),
            _buildNumberTile(
              title: 'Diastolic Warning Limit',
              value: '${bp['warning']['low']} mmHg',
              onTap: () => _editValue(
                'Diastolic Limit (mmHg)',
                bp['warning']['low'].toString(),
                (val) => setState(() => bp['warning']['low'] = int.tryParse(val) ?? 90),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Blood Oxygen Section
        _buildCardGroup(
          title: 'Blood Oxygen (SpO₂) Monitoring',
          icon: Icons.water_drop_rounded,
          iconColor: const Color(0xFF5BB8F5),
          children: [
            _buildSwitchTile(
              title: 'Auto SpO₂ Monitoring',
              value: bo['switch_state'] == 1,
              onChanged: (v) => setState(() => bo['switch_state'] = v ? 1 : 0),
            ),
            // Updated to be editable via dialog
            _buildNumberTile(
              title: 'Measurement Interval',
              value: (bo['interval'] == '0' || bo['interval'] == 0)
                  ? 'Off / Manual'
                  : '${bo['interval'] ?? "30"} min/test',
              onTap: () => _showSpo2IntervalDialog(bo),
            ),
            _buildNumberTile(
              title: 'Low SpO₂ Warning Limit',
              value: '${bo['low_warning']['value']}%',
              onTap: () => _editValue(
                'Low SpO₂ Limit (%)',
                bo['low_warning']['value'].toString(),
                (val) => setState(() => bo['low_warning']['value'] = int.tryParse(val) ?? 90),
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
      title: 'Fitness & Step Goals',
      icon: Icons.directions_run_rounded,
      iconColor: const Color(0xFF4BA3C7),
      children: [
        _buildNumberTile(
          title: 'Daily Step Goal',
          value: '${step['step_target']} steps',
          onTap: () => _editValue(
            'Daily Step Goal',
            step['step_target'].toString(),
            (val) => setState(() => step['step_target'] = val),
          ),
        ),
        _buildNumberTile(
          title: 'Daily Exercise Time Goal',
          value: '${step['exercise_time_target']} min',
          onTap: () => _editValue(
            'Exercise Goal (minutes)',
            step['exercise_time_target'].toString(),
            (val) => setState(() => step['exercise_time_target'] = val),
          ),
        ),
        _buildInfoTile('Sync Interval', '${step['interval']} min'),
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
      title: 'Sleep Tracking & Schedule',
      icon: Icons.bedtime_rounded,
      iconColor: const Color(0xFF4CBF87),
      children: [
        _buildSwitchTile(
          title: 'Auto Sleep Tracking',
          value: sleep['switch_state'] == 1,
          onChanged: (v) => setState(() => sleep['switch_state'] = v ? 1 : 0),
        ),
        _buildNumberTile(
          title: 'Bedtime',
          value: startTimeStr,
          onTap: () => _pickSleepTime(
            context: context,
            title: 'Bedtime',
            initialHHMM: startTimeStr,
            onPicked: (newVal) => setState(() => sleep['start_time'] = newVal),
          ),
        ),
        _buildNumberTile(
          title: 'Wake Time',
          value: endTimeStr,
          onTap: () => _pickSleepTime(
            context: context,
            title: 'Wake Time',
            initialHHMM: endTimeStr,
            onPicked: (newVal) => setState(() => sleep['end_time'] = newVal),
          ),
        ),
        _buildNumberTile(
          title: 'Target Sleep Duration',
          value: '${(sleep['target'] as int) ~/ 60} hrs (${sleep['target']} min)',
          onTap: () => _editValue(
            'Target Sleep Hours (min)',
            sleep['target'].toString(),
            (val) => setState(() => sleep['target'] = int.tryParse(val) ?? 480),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 4. Safety Settings
  // ---------------------------------------------------------------------
  Widget _buildSafetySettingsGroup() {
    final safety = _data['safety'] as Map<String, dynamic>? ?? {
      'sos': {'switch_state': 1, 'rotation': '3'},
      'fall_warning': {'switch_state': 0},
    };
    _data['safety'] ??= safety;

    final sos = safety['sos'] as Map<String, dynamic>? ?? {'switch_state': 1, 'rotation': '3'};
    safety['sos'] ??= sos;

    final fall = safety['fall_warning'] as Map<String, dynamic>? ?? {'switch_state': 0};
    safety['fall_warning'] ??= fall;

    final List<Map<String, dynamic>> defaultSosList = [
      {'name': 'Father (Parent)', 'phone': '0912345678', 'priority': 1},
      {'name': 'Mother', 'phone': '0923456789', 'priority': 2},
      {'name': 'Emergency (119)', 'phone': '119', 'priority': 3},
    ];

    final List<Map<String, dynamic>> defaultFamilyList = [
      {'name': 'Father (Primary Caregiver)', 'relation': 'Father', 'phone': '0912345678', 'isPrimary': true},
      {'name': 'Mother', 'relation': 'Mother', 'phone': '0923456789', 'isPrimary': false},
    ];

    final sosNumbers = (sos['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? defaultSosList;
    final familyMembers = (_data['family'] as List?)?.cast<Map<String, dynamic>>() ?? defaultFamilyList;

    return Column(
      children: [
        _buildCardGroup(
          title: 'Safety Protection & SOS',
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFFE96B6B),
          children: [
            _buildSwitchTile(
              title: 'Enable One-Touch SOS',
              value: sos['switch_state'] == 1,
              onChanged: (v) => setState(() => sos['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: 'SOS Contact Rotation Count',
              value: '${sos['rotation']} times',
              onTap: () => _editValue(
                'SOS Rotation Count',
                sos['rotation'].toString(),
                (val) => setState(() => sos['rotation'] = val),
              ),
            ),
            _buildSwitchTile(
              title: 'Fall Detection & Alert Notification',
              value: fall['switch_state'] == 1,
              onChanged: (v) => setState(() => fall['switch_state'] = v ? 1 : 0),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildCardGroup(
          title: 'SOS Emergency Numbers',
          icon: Icons.emergency_rounded,
          iconColor: const Color(0xFFE96B6B),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'When holding the physical SOS key, the watch automatically dials the following numbers in sequence.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ),
            ...sosNumbers.map((item) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceMedium, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: Text('${item['name']}\n${item['phone']}')),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _showEditSosNumberDialog(context, item, (newName, newPhone) {
                      setState(() {
                        item['name'] = newName;
                        item['phone'] = newPhone;
                      });
                    }),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),

        const SizedBox(height: 16),

        _buildCardGroup(
          title: 'Family Members',
          icon: Icons.people_rounded,
          iconColor: const Color(0xFF5E5CE6),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Caregivers & Family Contacts',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddFamilyMemberDialog(context, (newMember) {
                      setState(() => familyMembers.add(newMember));
                    }),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Member'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 5. Call & System Detail
  // ---------------------------------------------------------------------
  Widget _buildCommunicationAndSystem() {
    // Safely extract maps or initialize with default schemas if missing
    final call = _data['call'] as Map<String, dynamic>? ?? {
      'message': {'switch_state': 1},
      'incoming_call_limit': {'switch_state': 0},
      'answer_mode': {'value': 1},
    };
    _data['call'] ??= call;

    final sms = call['message'] as Map<String, dynamic>? ?? {'switch_state': 1};
    call['message'] ??= sms;

    final incomingCallLimit = call['incoming_call_limit'] as Map<String, dynamic>? ?? {'switch_state': 0};
    call['incoming_call_limit'] ??= incomingCallLimit;

    final answer = call['answer_mode'] as Map<String, dynamic>? ?? {'value': 1};
    call['answer_mode'] ??= answer;

    final location = _data['location'] as Map<String, dynamic>? ?? {'interval': 1440};
    _data['location'] ??= location;

    final watch = _data['watch'] as Map<String, dynamic>? ?? {
      'scene_mode': {'value': 3},
      'dial': {'switch_state': 1},
      'unlock_password': {'switch_state': 1},
      'volume': {'value': 51},
      'wrist_lift': {'switch_state': 1},
      'time_format_mode': {'value': 24},
      'find_my_watch': {'switch_state': 1},
      'watch_lost': {'switch_state': 0},
      'power_save_mode': {'switch_state': 0},
      'low_power_battery': {'value': 60},
      'language': {'value': 'cn'},
    };
    _data['watch'] ??= watch;

    // Ensure all individual watch settings sub-maps are present:
    final watchVolume = watch['volume'] as Map<String, dynamic>? ?? {'value': 51};
    watch['volume'] ??= watchVolume;

    final watchWristLift = watch['wrist_lift'] as Map<String, dynamic>? ?? {'switch_state': 1};
    watch['wrist_lift'] ??= watchWristLift;

    final watchDial = watch['dial'] as Map<String, dynamic>? ?? {'switch_state': 1};
    watch['dial'] ??= watchDial;

    final watchUnlockPassword = watch['unlock_password'] as Map<String, dynamic>? ?? {'switch_state': 1};
    watch['unlock_password'] ??= watchUnlockPassword;

    final watchTimeFormatMode = watch['time_format_mode'] as Map<String, dynamic>? ?? {'value': 24};
    watch['time_format_mode'] ??= watchTimeFormatMode;

    final watchPowerSaveMode = watch['power_save_mode'] as Map<String, dynamic>? ?? {'switch_state': 0};
    watch['power_save_mode'] ??= watchPowerSaveMode;

    final watchLowPowerBattery = watch['low_power_battery'] as Map<String, dynamic>? ?? {'value': 60};
    watch['low_power_battery'] ??= watchLowPowerBattery;

    final watchFindMyWatch = watch['find_my_watch'] as Map<String, dynamic>? ?? {'switch_state': 1};
    watch['find_my_watch'] ??= watchFindMyWatch;

    final watchLost = watch['watch_lost'] as Map<String, dynamic>? ?? {'switch_state': 0};
    watch['watch_lost'] ??= watchLost;

    final List<Widget> cards = [];

    if (widget.category == SettingsCategory.call) {
      cards.add(
        _buildCardGroup(
          title: 'Calls & Messages Protection',
          icon: Icons.security_rounded,
          iconColor: const Color(0xFF5E5CE6),
          children: [
            _buildSwitchTile(
              title: 'SMS & Message Notifications',
              value: sms['switch_state'] == 1,
              onChanged: (v) => setState(() => sms['switch_state'] = v ? 1 : 0),
            ),
            _buildSwitchTile(
              title: 'Block Unknown Calls (Whitelist Only)',
              value: incomingCallLimit['switch_state'] == 1,
              onChanged: (v) => setState(() => incomingCallLimit['switch_state'] = v ? 1 : 0),
            ),
            _buildInfoTile('Call Answering Mode', answer['value'] == 1 ? 'Auto Answer' : 'Manual Answer'),
          ],
        ),
      );
    }

    if (widget.category == SettingsCategory.location) {
      cards.add(
        _buildCardGroup(
          title: 'Location & Sync Frequency',
          icon: Icons.my_location_rounded,
          iconColor: const Color(0xFF4CBF87),
          children: [
            _buildNumberTile(
              title: 'GPS/LBS Location Sync Frequency',
              value: '${location['interval']} min/update',
              onTap: () => _editValue(
                'Location Update Interval (minutes)',
                location['interval'].toString(),
                (val) => setState(() => location['interval'] = int.tryParse(val) ?? 10),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.category == SettingsCategory.watch) {
      cards.add(
        _buildCardGroup(
          title: 'System Volume & Display',
          icon: Icons.volume_up_rounded,
          iconColor: const Color(0xFFFFA24D),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('Speaker Volume', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: Slider(
                      value: ((watchVolume['value'] ?? 80) as num).toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      onChanged: (v) => setState(() => watchVolume['value'] = v.toInt()),
                    ),
                  ),
                ],
              ),
            ),
            _buildSwitchTile(
              title: 'Raise Wrist to Wake Screen',
              value: watchWristLift['switch_state'] == 1,
              onChanged: (v) => setState(() => watchWristLift['switch_state'] = v ? 1 : 0),
            ),
            _buildSwitchTile(
              title: 'Watch Face Switcher',
              value: watchDial['switch_state'] == 1,
              onChanged: (v) => setState(() => watchDial['switch_state'] = v ? 1 : 0),
            ),
            _buildInfoTile('Time Display Format', '${watchTimeFormatMode['value']}-hour format'),
            _buildInfoTile('Watch Language', 'English'),
          ],
        ),
      );
      cards.add(
        _buildCardGroup(
          title: 'Security & Power Management',
          icon: Icons.battery_charging_full_rounded,
          iconColor: const Color(0xFF4CBF87),
          children: [
            _buildSwitchTile(
              title: 'Watch Lockscreen Password',
              value: watchUnlockPassword['switch_state'] == 1,
              onChanged: (v) => setState(() => watchUnlockPassword['switch_state'] = v ? 1 : 0),
            ),
            _buildSwitchTile(
              title: 'Power Saver Mode',
              value: watchPowerSaveMode['switch_state'] == 1,
              onChanged: (v) => setState(() => watchPowerSaveMode['switch_state'] = v ? 1 : 0),
            ),
            _buildNumberTile(
              title: 'Low Battery Warning Limit',
              value: '${watchLowPowerBattery['value']}%',
              onTap: () => _editValue(
                'Low Battery Limit (%)',
                watchLowPowerBattery['value'].toString(),
                (val) => setState(() => watchLowPowerBattery['value'] = int.tryParse(val) ?? 20),
              ),
            ),
            _buildSwitchTile(
              title: 'Find My Watch (Buzzer Sound)',
              value: watchFindMyWatch['switch_state'] == 1,
              onChanged: (v) => setState(() => watchFindMyWatch['switch_state'] = v ? 1 : 0),
            ),
            _buildSwitchTile(
              title: 'Watch Removal / Anti-Loss Alert',
              value: watchLost['switch_state'] == 1,
              onChanged: (v) => setState(() => watchLost['switch_state'] = v ? 1 : 0),
            ),
          ],
        ),
      );
    }

    final List<Widget> children = [];
    for (int i = 0; i < cards.length; i++) {
      children.add(cards[i]);
      if (i < cards.length - 1) {
        children.add(const SizedBox(height: 16));
      }
    }

    return Column(
      children: children,
    );
  }

  // ---------------------------------------------------------------------
  // 8. Remote Commands Detail
  // ---------------------------------------------------------------------
  Widget _buildRemoteCommandsGroup() {
    return Column(
      children: [
        _buildCardGroup(
          title: 'Find Watch',
          icon: Icons.ring_volume_rounded,
          iconColor: AppColors.primary,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'When triggered, the watch will play a loud alarm sound to help locate it quickly.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmRemoteCommand(
                        title: 'Find Watch',
                        message: 'Are you sure you want to send find command to watch? Watch will start ringing.',
                        confirmText: 'Send Find Command',
                        color: AppColors.primary,
                        onConfirmed: () => _executeRemoteCommand(
                          action: 'find',
                          actionName: 'Find Watch',
                          successMsg: 'Find command sent successfully!',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.ring_volume_rounded, color: AppColors.primary),
                      label: const Text('Find Watch', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildCardGroup(
          title: 'Remote Power & System Control',
          icon: Icons.settings_remote_rounded,
          iconColor: const Color(0xFF5E5CE6),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Remote maintenance and power controls for the watch.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmRemoteCommand(
                            title: 'Restart Device',
                            message: 'Are you sure you want to restart the watch remotely?',
                            confirmText: 'Restart',
                            color: const Color(0xFF5E5CE6),
                            onConfirmed: () => _executeRemoteCommand(
                              action: 'restart',
                              actionName: 'Remote Restart',
                              successMsg: 'Restart command sent to watch!',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5E5CE6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Remote Restart', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmRemoteCommand(
                            title: 'Power Off',
                            message: 'Are you sure you want to power off the watch remotely?',
                            confirmText: 'Power Off',
                            color: const Color(0xFFEF5350),
                            onConfirmed: () => _executeRemoteCommand(
                              action: 'power-off',
                              actionName: 'Remote Power Off',
                              successMsg: 'Power off command sent to watch!',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF5350),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                          label: const Text('Power Off', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Reusable Helper UI Widgets
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
        title: Text('Setup $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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
            child: const Text('Save'),
          ),
        ],
      ),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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
        const SnackBar(content: Text('Device IMEI unavailable')),
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
      Navigator.of(context).pop();

      final isSuccess = res['success'] == true;
      final serverMsg = res['message'] as String?;
      final msg = isSuccess ? (serverMsg ?? successMsg) : (serverMsg ?? 'Failed to send $actionName command');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Command failed: $e'),
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
              'Edit SOS Number',
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
                labelText: 'Contact Name / Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Emergency Phone Number',
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
              onSaved(nameController.text, phoneController.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Number', style: TextStyle(fontWeight: FontWeight.w700)),
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
                'Add Family Member',
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
                  labelText: 'Member Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                decoration: InputDecoration(
                  labelText: 'Relationship (e.g. Father, Mother)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
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
                  const Text('Set as Primary Caregiver', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ],
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
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  onAdded({
                    'name': nameController.text,
                    'relation': relationController.text.isEmpty ? 'Family' : relationController.text,
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
              child: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w700)),
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
      helpText: 'Select $title',
    );

    if (picked != null) {
      final String hh = picked.hour.toString().padLeft(2, '0');
      final String mm = picked.minute.toString().padLeft(2, '0');
      final String formattedRaw = '${hh}${mm}00';
      onPicked(formattedRaw);
    }
  }

  Future<void> _pickBpTime({
    required BuildContext context,
    required String title,
    required String initialHHMM,
    required ValueChanged<String> onPicked,
  }) async {
    final cleanTime = initialHHMM.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = cleanTime.split(':');
    int hour = 7;
    int minute = 0;
    if (parts.isNotEmpty) {
      if (parts[0].length == 4) {
        hour = int.tryParse(parts[0].substring(0, 2)) ?? 7;
        minute = int.tryParse(parts[0].substring(2, 4)) ?? 0;
      } else {
        hour = int.tryParse(parts[0]) ?? 7;
      }
    }
    if (parts.length > 1) {
      minute = int.tryParse(parts[1]) ?? 0;
    }

    final isMorning = title.toLowerCase().contains('morning') || hour < 12;
    final List<String> presets = isMorning
        ? ['06:30', '07:00', '07:30', '08:00', '08:30']
        : ['17:30', '18:00', '18:30', '19:00', '20:00'];

    final textCtrl = TextEditingController(text: initialHHMM);
    final accentColor = isMorning ? const Color(0xFFE67E22) : const Color(0xFF4A69BD);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          String formatBadge(String raw) {
            final clean = raw.replaceAll(RegExp(r'[^0-9:]'), '');
            final p = clean.split(':');
            int h = 7;
            int m = 0;
            if (p.isNotEmpty) {
              if (p[0].length == 4) {
                h = int.tryParse(p[0].substring(0, 2)) ?? 7;
                m = int.tryParse(p[0].substring(2, 4)) ?? 0;
              } else {
                h = int.tryParse(p[0]) ?? 7;
              }
            }
            if (p.length > 1) {
              m = int.tryParse(p[1]) ?? 0;
            }
            final period = h >= 12 ? 'PM' : 'AM';
            final dh = h % 12 == 0 ? 12 : h % 12;
            return '$period (${dh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')})';
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
                          color: accentColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMorning ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'Enter time (HH:mm) or select preset',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textCtrl,
                            keyboardType: TextInputType.datetime,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 1,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Measurement Time (HH:mm)',
                              labelStyle: TextStyle(fontSize: 12, color: accentColor),
                              hintText: isMorning ? '07:00' : '18:00',
                              prefixIcon: Icon(Icons.edit_outlined, color: accentColor, size: 20),
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
                            onChanged: (_) => setSheetState(() {}),
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
                            formatBadge(textCtrl.text),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Preset Times',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets.map((preset) {
                        final isSelected = textCtrl.text.trim() == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(preset),
                            selected: isSelected,
                            selectedColor: accentColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color: isSelected ? accentColor : Colors.grey.shade300,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() {
                                  textCtrl.text = preset;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final raw = textCtrl.text.trim();
                        final clean = raw.replaceAll(RegExp(r'[^0-9:]'), '').trim();
                        String sanitized = isMorning ? '07:00' : '18:00';
                        if (clean.isNotEmpty) {
                          final parts = clean.split(':');
                          int h = 7;
                          int m = 0;
                          if (parts.length == 1) {
                            if (parts[0].length == 4) {
                              h = int.tryParse(parts[0].substring(0, 2)) ?? 7;
                              m = int.tryParse(parts[0].substring(2, 4)) ?? 0;
                            } else if (parts[0].length <= 2) {
                              h = int.tryParse(parts[0]) ?? 7;
                            }
                          } else {
                            h = int.tryParse(parts[0]) ?? 7;
                            m = int.tryParse(parts[1]) ?? 0;
                          }
                          h = h.clamp(0, 23);
                          m = m.clamp(0, 59);
                          sanitized = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                        }
                        onPicked(sanitized);
                        Navigator.of(sheetCtx).pop();
                      },
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBpIntervalDialog(Map<String, dynamic> bp) {
    final String initialInterval = bp['interval']?.toString() ?? '60';
    final controller = TextEditingController(text: initialInterval);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('BP Measurement Frequency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select preset interval or enter custom minutes:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: ['10', '15', '30', '60', '120', '0'].map((minutes) {
                  final isSelected = controller.text == minutes;
                  final label = minutes == '0' ? 'Off/Manual' : '$minutes min';
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) setDialogState(() => controller.text = minutes);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custom Frequency (min)',
                  hintText: 'e.g. 45',
                  suffixText: 'min',
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
              onPressed: () async {
                final input = controller.text.trim();
                final intervalValue = (int.tryParse(input) ?? 60).toString();
                setState(() {
                  bp['interval'] = intervalValue;
                });
                
                final hasChanges = intervalValue != initialInterval;
                if (!hasChanges) {
                  Navigator.of(ctx).pop();
                  return;
                }

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
                        SnackBar(content: Text('BP interval set to $intervalValue min and synced')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync failed: $e')),
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
              child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
  void _showHrIntervalDialog(Map<String, dynamic> hr) {
    final String initialInterval = hr['interval']?.toString() ?? '10';
    final controller = TextEditingController(text: initialInterval);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Heart Rate Frequency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select preset interval or enter custom minutes:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: ['5', '10', '15', '30', '60', '0'].map((minutes) {
                  final isSelected = controller.text == minutes;
                  final label = minutes == '0' ? 'Off/Manual' : '$minutes min';
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) setDialogState(() => controller.text = minutes);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custom Frequency (min)',
                  hintText: 'e.g. 10',
                  suffixText: 'min',
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
              onPressed: () async {
                final input = controller.text.trim();
                final intervalVal = (int.tryParse(input) ?? 10).toString();
                setState(() {
                  hr['interval'] = intervalVal;
                });

                final hasChanges = intervalVal != initialInterval;
                if (!hasChanges) {
                  Navigator.of(ctx).pop();
                  return;
                }

                if (widget.imei != null && widget.imei!.isNotEmpty) {
                  try {
                    await _deviceRepository.saveSettings(
                      imei: widget.imei!,
                      patch: {
                        'health': {
                          'heart_rate': {
                            'interval': intervalVal,
                          }
                        }
                      },
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('HR interval set to $intervalVal min and synced')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync failed: $e')),
                      );
                    }
                  }
                }
                if (mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE96B6B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SpO2 Interval Dialog (Immediate API Sync)
  // ---------------------------------------------------------------------
  void _showSpo2IntervalDialog(Map<String, dynamic> bo) {
    final String initialInterval = bo['interval']?.toString() ?? '30';
    final controller = TextEditingController(text: initialInterval);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('SpO₂ Frequency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select preset interval or enter custom minutes:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: ['10', '15', '30', '60', '120', '0'].map((minutes) {
                  final isSelected = controller.text == minutes;
                  final label = minutes == '0' ? 'Off/Manual' : '$minutes min';
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) setDialogState(() => controller.text = minutes);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custom Frequency (min)',
                  hintText: 'e.g. 30',
                  suffixText: 'min',
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
              onPressed: () async {
                final input = controller.text.trim();
                final intervalVal = (int.tryParse(input) ?? 30).toString();
                setState(() {
                  bo['interval'] = intervalVal;
                });

                final hasChanges = intervalVal != initialInterval;
                if (!hasChanges) {
                  Navigator.of(ctx).pop();
                  return;
                }

                if (widget.imei != null && widget.imei!.isNotEmpty) {
                  try {
                    await _deviceRepository.saveSettings(
                      imei: widget.imei!,
                      patch: {
                        'health': {
                          'blood_oxygen': {
                            'interval': intervalVal,
                          }
                        }
                      },
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('SpO₂ interval set to $intervalVal min and synced')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync failed: $e')),
                      );
                    }
                  }
                }
                if (mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5BB8F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

