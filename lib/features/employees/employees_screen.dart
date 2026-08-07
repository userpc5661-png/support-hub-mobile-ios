import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';
import 'employee_model.dart';
import 'employee_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  late final EmployeeService service;
  List<EmployeeModel> employees = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    service = EmployeeService(widget.api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      employees = await service.list();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: tr('الفريق والصلاحيات'),
      subtitle: tr('إدارة الموظفين والأدوار والصلاحيات التشغيلية'),
      icon: AppIcons.team,
      accent: const Color(0xFF8B5CF6),
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: tr('تحديث'),
            icon: const Icon(Icons.refresh_rounded))
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEmployee(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('إضافة موظف')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Icon(Icons.error_outline,
                        size: 56, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Center(
                        child: FilledButton(
                            onPressed: _load,
                            child: Text(tr('إعادة المحاولة')))),
                  ])
                : employees.isEmpty
                    ? ListView(children: [
                        SizedBox(height: 140),
                        Center(child: Text(tr('ما أضفت موظفين حتى الآن.')))
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: employees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final employee = employees[index];
                          return _EmployeeCard(
                            employee: employee,
                            onTap: () => _showEmployeeDetails(employee),
                            onAction: (action) =>
                                _handleAction(action, employee),
                          );
                        },
                      ),
      ),
    );
  }

  Future<void> _showEmployeeDetails(EmployeeModel employee) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('@${employee.username} • ${employee.roleLabel}',
                    textDirection: TextDirection.ltr),
                if ((employee.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(employee.email!),
                ],
                const SizedBox(height: 18),
                Text(tr('الصلاحيات'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: employee.permissions.isEmpty
                      ? [Chip(label: Text(tr('بدون صلاحيات تشغيلية')))]
                      : employee.permissions
                          .map((permission) =>
                              Chip(label: Text(permissionLabel(permission))))
                          .toList(),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _handleAction(
      _EmployeeAction action, EmployeeModel employee) async {
    switch (action) {
      case _EmployeeAction.edit:
        await _editEmployee(employee);
        break;
      case _EmployeeAction.password:
        await _resetPassword(employee);
        break;
      case _EmployeeAction.status:
        await _toggleStatus(employee);
        break;
    }
  }

  Future<void> _editEmployee([EmployeeModel? employee]) async {
    final updated = await showDialog<EmployeeModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _EmployeeDialog(service: service, employee: employee),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final exists = employees.any((item) => item.id == updated.id);
      employees = exists
          ? [
              for (final item in employees)
                if (item.id == updated.id) updated else item
            ]
          : [...employees, updated];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(employee == null
              ? tr('تمت إضافة الموظف.')
              : tr('تم تحديث الموظف.'))),
    );
  }

  Future<void> _toggleStatus(EmployeeModel employee) async {
    final target = !employee.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(target ? tr('إعادة تفعيل الموظف') : tr('إيقاف الموظف')),
        content: Text(target
            ? tr('سيتمكن الموظف من تسجيل الدخول من جديد.')
            : tr('لن يتمكن الموظف من تسجيل الدخول حتى تعيد تفعيله.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('تأكيد'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final updated = await service.setStatus(employee.id, target);
      if (!mounted) return;
      setState(() => employees = [
            for (final item in employees)
              if (item.id == updated.id) updated else item
          ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _resetPassword(EmployeeModel employee) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('تغيير كلمة مرور ${employee.name}')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: tr('كلمة المرور الجديدة')),
            validator: (value) => value == null || value.length < 8
                ? tr('8 أحرف على الأقل')
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('إلغاء'))),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, controller.text);
              }
            },
            child: Text(tr('حفظ')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null) return;
    try {
      await service.resetPassword(employee.id, password);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('تم تغيير كلمة المرور.'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.onTap,
    required this.onAction,
  });

  final EmployeeModel employee;
  final VoidCallback onTap;
  final ValueChanged<_EmployeeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = employee.permissions.take(3).toList();
    final hidden = employee.permissions.length - preview.length;
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: employee.isActive
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      employee.isActive
                          ? Icons.support_agent_rounded
                          : Icons.person_off_outlined,
                      color: employee.isActive
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('@${employee.username} • ${employee.roleLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(active: employee.isActive),
                  PopupMenuButton<_EmployeeAction>(
                    tooltip: tr('المزيد'),
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: _EmployeeAction.edit,
                          child: Text(tr('تعديل البيانات والصلاحيات'))),
                      PopupMenuItem(
                          value: _EmployeeAction.password,
                          child: Text(tr('تغيير كلمة المرور'))),
                      PopupMenuItem(
                        value: _EmployeeAction.status,
                        child: Text(employee.isActive
                            ? tr('إيقاف الموظف')
                            : tr('إعادة تفعيل الموظف')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (employee.permissions.isEmpty)
                    _PermissionPreview(label: tr('بدون صلاحيات تشغيلية')),
                  for (final permission in preview)
                    _PermissionPreview(label: permissionLabel(permission)),
                  if (hidden > 0) _PermissionPreview(label: '+$hidden'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionPreview extends StatelessWidget {
  const _PermissionPreview({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: .48)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

enum _EmployeeAction { edit, password, status }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: (active
                  ? const Color(0xFF20B486)
                  : Theme.of(context).colorScheme.outline)
              .withValues(alpha: .13),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.check_circle : Icons.pause_circle,
                size: 14,
                color: active
                    ? const Color(0xFF20B486)
                    : Theme.of(context).colorScheme.outline),
            const SizedBox(width: 4),
            Text(active ? tr('نشط') : tr('موقوف'),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({required this.service, this.employee});
  final EmployeeService service;
  final EmployeeModel? employee;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController username;
  late final TextEditingController email;
  final password = TextEditingController();
  late final Set<String> permissions;
  late String role;
  bool saving = false;
  String? error;

  bool get editing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.employee?.name ?? '');
    username = TextEditingController(text: widget.employee?.username ?? '');
    email = TextEditingController(text: widget.employee?.email ?? '');
    role = widget.employee?.role ?? 'employee';
    permissions = Set<String>.from(
      widget.employee?.permissions ??
          const [
            'customers.read',
            'conversations.read',
            'conversations.reply',
            'ai.draft'
          ],
    );
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(editing ? tr('تعديل الموظف') : tr('إضافة موظف')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(labelText: tr('اسم الموظف')),
                  validator: (value) => value == null || value.trim().length < 2
                      ? tr('أدخل اسمًا صحيحًا')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: username,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: tr('اسم المستخدم')),
                  validator: (value) => value == null || value.trim().length < 3
                      ? tr('3 أحرف على الأقل')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: tr('البريد الإلكتروني (اختياري)')),
                  validator: (value) => value != null &&
                          value.trim().isNotEmpty &&
                          !value.contains('@')
                      ? tr('أدخل بريدًا صحيحًا أو اتركه فارغًا')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: InputDecoration(labelText: tr('الدور')),
                  items: [
                    DropdownMenuItem(
                        value: 'store_admin', child: Text(tr('مدير متجر'))),
                    DropdownMenuItem(
                        value: 'supervisor', child: Text(tr('مشرف'))),
                    DropdownMenuItem(
                        value: 'employee', child: Text(tr('موظف دعم'))),
                  ],
                  onChanged: (value) => setState(() => role = value ?? role),
                ),
                if (!editing) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: tr('كلمة المرور المؤقتة')),
                    validator: (value) => value == null || value.length < 8
                        ? tr('8 أحرف على الأقل')
                        : null,
                  ),
                ],
                if (role == 'employee') ...[
                  const Divider(height: 30),
                  Text(tr('الصلاحيات'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  for (final option in employeePermissionOptions)
                    CheckboxListTile(
                      value: permissions.contains(option.key),
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.label),
                      subtitle: Text(option.description),
                      onChanged: (value) =>
                          _changePermission(option.key, value ?? false),
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(tr('إلغاء'))),
        FilledButton(
          onPressed: saving ? null : _submit,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('حفظ')),
        ),
      ],
    );
  }

  void _changePermission(String key, bool enabled) {
    setState(() {
      if (enabled) {
        permissions.add(key);
        if (key == 'conversations.reply' ||
            key == 'conversations.assign' ||
            key == 'conversations.manage') {
          permissions.add('conversations.read');
        }
        if (key == 'customers.create' || key == 'customers.update') {
          permissions.add('customers.read');
        }
      } else {
        permissions.remove(key);
        if (key == 'conversations.read') {
          permissions.remove('conversations.reply');
          permissions.remove('conversations.assign');
          permissions.remove('conversations.manage');
        }
        if (key == 'customers.read') {
          permissions.remove('customers.create');
          permissions.remove('customers.update');
        }
      }
    });
  }

  Future<void> _submit() async {
    if (formKey.currentState?.validate() != true) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = editing
          ? await widget.service.update(
              id: widget.employee!.id,
              name: name.text,
              username: username.text,
              email: email.text,
              role: role,
              permissions: permissions.toList(),
            )
          : await widget.service.create(
              name: name.text,
              username: username.text,
              email: email.text,
              role: role,
              password: password.text,
              permissions: permissions.toList(),
            );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }
}
