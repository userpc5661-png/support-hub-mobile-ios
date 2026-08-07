import '../../core/localization/app_locale_controller.dart';

class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.status,
    required this.permissions,
    required this.mustChangePassword,
    this.email,
  });
  final String id;
  final String name;
  final String username;
  final String? email;
  final String role;
  final String status;
  final List<String> permissions;
  final bool mustChangePassword;
  bool get isActive => status == 'active';
  String get statusLabel => isActive ? tr('نشط') : tr('موقوف');
  String get roleLabel => switch (role) {
        'store_admin' => tr('مدير متجر'),
        'supervisor' => tr('مشرف'),
        _ => tr('موظف دعم'),
      };

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
        id: json['id'] as String,
        name: json['name']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        email: json['email']?.toString(),
        role: json['role']?.toString() ?? 'employee',
        status: json['status']?.toString() ?? '',
        permissions: (json['permissions'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        mustChangePassword: json['mustChangePassword'] == true,
      );
}

class EmployeePermissionOption {
  const EmployeePermissionOption(this.key, this.label, this.description);
  final String key;
  final String label;
  final String description;
}

List<EmployeePermissionOption> get employeePermissionOptions =>
    <EmployeePermissionOption>[
      EmployeePermissionOption('customers.read', tr('مشاهدة العملاء'),
          tr('عرض بيانات العملاء داخل المتجر.')),
      EmployeePermissionOption('customers.create', tr('إضافة العملاء'),
          tr('إنشاء سجلات عملاء جديدة.')),
      EmployeePermissionOption('customers.update', tr('تعديل العملاء'),
          tr('تعديل البيانات والوسوم والملاحظات.')),
      EmployeePermissionOption('conversations.read', tr('مشاهدة المحادثات'),
          tr('فتح صندوق المحادثات.')),
      EmployeePermissionOption('conversations.reply', tr('الرد على العملاء'),
          tr('إرسال الردود وإضافة الملاحظات الداخلية.')),
      EmployeePermissionOption('conversations.assign', tr('توزيع المحادثات'),
          tr('إسناد المحادثات لفريق الدعم.')),
      EmployeePermissionOption(
          'conversations.manage',
          tr('إدارة الحالة والأولوية'),
          tr('إغلاق المحادثات وتغيير حالتها وأولويتها.')),
      EmployeePermissionOption('ai.draft', tr('اقتراحات الذكاء الاصطناعي'),
          tr('إنشاء مسودة رد من المساعد.')),
      EmployeePermissionOption('reports.read', tr('مشاهدة التقارير'),
          tr('عرض نظرة عامة على أداء المتجر.')),
    ];

String permissionLabel(String key) {
  for (final option in employeePermissionOptions) {
    if (option.key == key) return option.label;
  }
  return key;
}
