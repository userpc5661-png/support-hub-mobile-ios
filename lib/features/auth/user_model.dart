import '../../core/localization/app_locale_controller.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.permissions,
    required this.mustChangePassword,
    this.email,
    this.avatarUrl,
    this.storeId,
    this.storeName,
    this.supportSessionId,
  });

  final String id;
  final String name;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String role;
  final String? storeId;
  final String? storeName;
  final String? supportSessionId;
  final List<String> permissions;
  final bool mustChangePassword;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final store = json['store'];
    return UserModel(
      id: json['id'] as String,
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      role: json['role']?.toString() ?? '',
      storeId: json['storeId']?.toString(),
      storeName: store is Map ? store['name']?.toString() : null,
      supportSessionId: json['supportSessionId']?.toString(),
      permissions: (json['permissions'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      mustChangePassword: json['mustChangePassword'] == true,
    );
  }

  String get roleLabel => switch (role) {
        'super_admin' => tr('مدير المنصة'),
        'store_owner' => tr('صاحب المتجر'),
        'store_admin' => tr('مدير المتجر'),
        'supervisor' => tr('مشرف'),
        'employee' => tr('موظف دعم'),
        _ => role,
      };

  bool hasPermission(String permission) => permissions.contains(permission);
  bool get isStoreManagement => role == 'store_owner' || role == 'store_admin';
  bool get canUseSupportMobile =>
      storeId != null &&
      (role == 'employee' || role == 'supervisor') &&
      hasPermission('conversations.read') &&
      hasPermission('conversations.reply') &&
      hasPermission('customers.read');
}
