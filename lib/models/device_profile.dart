/// Model representing a device wearer's profile information.
class DeviceProfile {
  final int height;
  final double weight;
  final String birthday; // Format: YYYYMMDD (e.g. "19900101")
  final bool gender; // true = male, false = female

  const DeviceProfile({
    required this.height,
    required this.weight,
    required this.birthday,
    required this.gender,
  });

  /// Factory constructor to create a [DeviceProfile] from JSON.
  factory DeviceProfile.fromJson(Map<String, dynamic> json) {
    final rawGender = json['gender'];
    bool parsedGender = true;
    if (rawGender is bool) {
      parsedGender = rawGender;
    } else if (rawGender is String) {
      parsedGender = rawGender.toLowerCase() == 'male' || rawGender == '男' || rawGender == '1' || rawGender.toLowerCase() == 'true';
    } else if (rawGender is num) {
      parsedGender = rawGender == 1;
    }

    final rawBirthday = json['birthday']?.toString() ?? '19900101';
    final cleanedBirthday = formatBirthdayYyyymmdd(rawBirthday);

    return DeviceProfile(
      height: (json['height'] is num) ? (json['height'] as num).toInt() : int.tryParse(json['height']?.toString() ?? '175') ?? 175,
      weight: (json['weight'] is num) ? (json['weight'] as num).toDouble() : double.tryParse(json['weight']?.toString() ?? '70.0') ?? 70.0,
      birthday: cleanedBirthday,
      gender: parsedGender,
    );
  }

  /// Ensures birthday string is in YYYYMMDD format.
  static String formatBirthdayYyyymmdd(String dateStr) {
    final digits = dateStr.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 8) {
      return digits.substring(0, 8);
    }
    return '19900101';
  }

  /// Formatted birthday for display in UI (YYYY-MM-DD).
  String get displayBirthday {
    if (birthday.length == 8) {
      return '${birthday.substring(0, 4)}-${birthday.substring(4, 6)}-${birthday.substring(6, 8)}';
    }
    return birthday;
  }

  /// Converts this profile to a JSON map for API calls.
  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'weight': weight,
      'birthday': formatBirthdayYyyymmdd(birthday),
      'gender': gender ? 1 : 0,
      'age': age,
    };
  }

  /// Gender label string.
  String get genderLabel => gender ? 'Male' : 'Female';

  /// Helper to calculate age based on YYYYMMDD birthday.
  int get age {
    try {
      final formatted = formatBirthdayYyyymmdd(birthday);
      final year = int.parse(formatted.substring(0, 4));
      final month = int.parse(formatted.substring(4, 6));
      final day = int.parse(formatted.substring(6, 8));
      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age > 0 ? age : 0;
    } catch (_) {}
    return 30;
  }

  DeviceProfile copyWith({
    int? height,
    double? weight,
    String? birthday,
    bool? gender,
  }) {
    return DeviceProfile(
      height: height ?? this.height,
      weight: weight ?? this.weight,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
    );
  }
}
