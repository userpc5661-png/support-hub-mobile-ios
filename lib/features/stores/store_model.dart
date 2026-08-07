class StoreOwnerModel {
  const StoreOwnerModel({
    required this.id,
    required this.name,
    required this.username,
    required this.status,
    required this.mustChangePassword,
    this.email,
  });
  final String id;
  final String name;
  final String username;
  final String? email;
  final String status;
  final bool mustChangePassword;

  factory StoreOwnerModel.fromJson(Map<String, dynamic> json) =>
      StoreOwnerModel(
        id: json['id'] as String,
        name: json['name']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        email: json['email']?.toString(),
        status: json['status']?.toString() ?? '',
        mustChangePassword: json['mustChangePassword'] == true,
      );
}

class StoreModel {
  const StoreModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.employeeCount,
    this.email,
    this.phone,
    this.owner,
  });

  final String id;
  final String name;
  final String slug;
  final String? email;
  final String? phone;
  final bool isActive;
  final int employeeCount;
  final StoreOwnerModel? owner;

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    return StoreModel(
      id: json['id'] as String,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      isActive: json['isActive'] == true,
      employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
      owner: owner is Map
          ? StoreOwnerModel.fromJson(Map<String, dynamic>.from(owner))
          : null,
    );
  }
}
