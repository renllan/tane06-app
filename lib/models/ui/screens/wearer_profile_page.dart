import 'package:flutter/material.dart';
import 'package:tane06_app/models/device_profile.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/api_response.dart';

/// Screen for viewing and setting the wearer's physical profile
/// connected to `PUT /devices/{imei}/profile`.
class WearerProfilePage extends StatefulWidget {
  final String imei;
  final DeviceProfile? initialProfile;

  const WearerProfilePage({
    super.key,
    required this.imei,
    this.initialProfile,
  });

  @override
  State<WearerProfilePage> createState() => _WearerProfilePageState();
}

class _WearerProfilePageState extends State<WearerProfilePage> {
  final DeviceRepository _repository = DeviceRepository();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  late bool _gender; // true = male, false = female
  late int _height; // cm
  late double _weight; // kg
  late DateTime _birthday;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile ??
        const DeviceProfile(
          height: 170,
          weight: 65.0,
          birthday: '1992-06-15',
          gender: true,
        );

    _gender = p.gender;
    _height = p.height;
    _weight = p.weight;
    _birthday = _parseBirthday(p.birthday);

    if (widget.initialProfile == null) {
      _loadProfileFromSettings();
    }
  }

  DateTime _parseBirthday(String dateStr) {
    try {
      final digits = dateStr.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8) {
        final year = int.parse(digits.substring(0, 4));
        final month = int.parse(digits.substring(4, 6));
        final day = int.parse(digits.substring(6, 8));
        return DateTime(year, month, day);
      }
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return DateTime(1992, 6, 15);
  }

  String get _formattedBirthdayApi {
    return '${_birthday.year}${_birthday.month.toString().padLeft(2, '0')}${_birthday.day.toString().padLeft(2, '0')}';
  }

  String get _formattedBirthdayDisplay {
    return '${_birthday.year}-${_birthday.month.toString().padLeft(2, '0')}-${_birthday.day.toString().padLeft(2, '0')}';
  }

  int get _calculatedAge {
    final profile = DeviceProfile(
      height: _height,
      weight: _weight,
      birthday: _formattedBirthdayApi,
      gender: _gender,
    );
    return profile.age;
  }

  Future<void> _loadProfileFromSettings() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _repository.fetchProfile(imei: widget.imei);
      if (profile != null && mounted) {
        setState(() {
          _gender = profile.gender;
          _height = profile.height;
          _weight = profile.weight;
          _birthday = _parseBirthday(profile.birthday);
        });
      }
    } catch (_) {
      // Keep defaults on failure
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final profile = DeviceProfile(
      height: _height,
      weight: _weight,
      birthday: _formattedBirthdayApi,
      gender: _gender,
    );

    try {
      await _repository.saveProfile(
        imei: widget.imei,
        profile: profile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wearer profile updated and synced to device'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(profile);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = '${e.error.message} (${e.error.code})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save settings: $e';
        });
      }
    }
  }

  Future<void> _selectBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday,
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceDark,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _birthday) {
      setState(() => _birthday = picked);
    }
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
          'Wearer Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBanner(),
                  const SizedBox(height: 24),
                  _buildGenderSection(),
                  const SizedBox(height: 20),
                  _buildBirthdaySection(),
                  const SizedBox(height: 20),
                  _buildHeightSection(),
                  const SizedBox(height: 20),
                  _buildWeightSection(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    _buildErrorBox(),
                  ],
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5E5CE6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.badge_rounded,
              color: Color(0xFF5E5CE6),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body Metrics & Health Baseline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Accurate height, weight, and age improve calorie and heart rate calculations.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gender',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGenderTile(
                  title: 'Male',
                  icon: Icons.male_rounded,
                  isSelected: _gender,
                  activeColor: AppColors.primary,
                  onTap: () => setState(() => _gender = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderTile(
                  title: 'Female',
                  icon: Icons.female_rounded,
                  isSelected: !_gender,
                  activeColor: const Color(0xFFE96B6B),
                  onTap: () => setState(() => _gender = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? activeColor : AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdaySection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Birthday',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current: $_formattedBirthdayDisplay ($_calculatedAge yrs)',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _selectBirthday,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Select Date'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeightSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Height',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$_height cm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceDark,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.2),
            ),
            child: Slider(
              value: _height.toDouble(),
              min: 100,
              max: 220,
              divisions: 120,
              label: '$_height cm',
              onChanged: (val) {
                setState(() => _height = val.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_weight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4BA3C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF4BA3C7),
              inactiveTrackColor: AppColors.surfaceDark,
              thumbColor: const Color(0xFF4BA3C7),
              overlayColor: const Color(0xFF4BA3C7).withOpacity(0.2),
            ),
            child: Slider(
              value: _weight.clamp(30.0, 180.0),
              min: 30,
              max: 180,
              divisions: 300,
              label: '${_weight.toStringAsFixed(1)} kg',
              onChanged: (val) {
                setState(() => _weight = double.parse(val.toStringAsFixed(1)));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB00020)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFB00020), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(
          _isSaving ? 'Saving...' : 'Save Profile',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
