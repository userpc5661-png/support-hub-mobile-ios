import 'dart:convert';

class MetaSignupResult {
  const MetaSignupResult({
    required this.code,
    required this.wabaId,
    required this.phoneNumberId,
    required this.businessId,
  });

  final String code;
  final String wabaId;
  final String phoneNumberId;
  final String businessId;

  factory MetaSignupResult.fromJsonString(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Meta returned an invalid signup result.');
    }
    final data = Map<String, dynamic>.from(decoded);
    final result = MetaSignupResult(
      code: data['code']?.toString() ?? '',
      wabaId: data['wabaId']?.toString() ?? '',
      phoneNumberId: data['phoneNumberId']?.toString() ?? '',
      businessId: data['businessId']?.toString() ?? '',
    );
    if (result.code.isEmpty ||
        result.wabaId.isEmpty ||
        result.phoneNumberId.isEmpty ||
        result.businessId.isEmpty) {
      throw const FormatException(
        'Meta did not return all required WhatsApp assets.',
      );
    }
    return result;
  }
}
