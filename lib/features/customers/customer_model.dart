class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.tags,
    this.email,
    this.notes,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final List<String> tags;

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] as String,
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email']?.toString(),
        notes: json['notes']?.toString(),
        tags: (json['tags'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
      );
}
