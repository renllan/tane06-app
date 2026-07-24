/// SOS emergency contact model matching the TanE06 API `/devices/{imei}/sos-numbers`.
class SosNumber {
  final String sosNumberId;
  final String name;
  final String phone;

  const SosNumber({
    required this.sosNumberId,
    required this.name,
    required this.phone,
  });

  factory SosNumber.fromJson(Map<String, dynamic> json) {
    return SosNumber(
      sosNumberId: json['sosNumberId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'sosNumberId': sosNumberId,
        'name': name,
        'phone': phone,
      };
}
