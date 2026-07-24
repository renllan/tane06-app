/// Family contact model matching the TanE06 API `/devices/{imei}/family-numbers`.
class FamilyNumber {
  final String? familyNumberId;
  final String name;
  final String phone;
  final int sosSwitch;
  final String areaCode;

  const FamilyNumber({
    this.familyNumberId,
    required this.name,
    required this.phone,
    this.sosSwitch = 0,
    this.areaCode = '886',
  });

  factory FamilyNumber.fromJson(Map<String, dynamic> json) {
    return FamilyNumber(
      familyNumberId: json['familyNumberId'] as String?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      sosSwitch: json['sosSwitch'] as int? ?? 0,
      areaCode: json['areaCode'] as String? ?? '886',
    );
  }

  /// Serializes for PUT request (familyNumberId is server-generated).
  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'sosSwitch': sosSwitch,
        'areaCode': areaCode,
      };
}
