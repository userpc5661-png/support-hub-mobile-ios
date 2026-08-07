import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';
import '../auth/auth_controller.dart';
import 'store_model.dart';
import 'store_service.dart';

class StoresAdminScreen extends StatefulWidget {
  const StoresAdminScreen(
      {super.key, required this.api, required this.controller});
  final ApiClient api;
  final AuthController controller;

  @override
  State<StoresAdminScreen> createState() => _StoresAdminScreenState();
}

class _StoresAdminScreenState extends State<StoresAdminScreen> {
  late final StoreService service;
  List<StoreModel> stores = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    service = StoreService(widget.api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      stores = await service.listStores();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: tr('إدارة المتاجر'),
      subtitle: tr('إنشاء المتاجر ومتابعة حالتها ووصول الدعم وواتساب'),
      icon: AppIcons.platformStores,
      accent: const Color(0xFF0F9D83),
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: tr('تحديث'),
            icon: const Icon(Icons.refresh_rounded))
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createStore,
        icon: const Icon(Icons.add_business),
        label: Text(tr('متجر جديد')),
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
                : stores.isEmpty
                    ? ListView(children: [
                        SizedBox(height: 140),
                        Center(child: Text(tr('لا توجد متاجر حتى الآن.')))
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: stores.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _StoreCard(
                          store: stores[index],
                          onStatusChanged: (value) =>
                              _setStatus(stores[index], value),
                          onDelete: () => _deleteStore(stores[index]),
                          onResetOwnerPassword: () =>
                              _resetOwnerPassword(stores[index]),
                          onSupport: () => _enterSupport(stores[index]),
                        ),
                      ),
      ),
    );
  }

  Future<void> _enterSupport(StoreModel store) async {
    try {
      final access =
          await widget.api.getMap('/support-access/stores/${store.id}');
      if (!mounted) return;
      if (access['enabled'] != true) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.lock_outline, size: 44),
              title: Text(tr('الوصول غير مسموح')),
              content: Text(tr(
                  'صاحب المتجر لم يمنح مدير المنصة صلاحية مؤقتة لقراءة المحادثات. يمكن إدارة المتجر، لكن لا يمكن دخول جلسة الدعم الخاصة.')),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('تم')))
              ],
            ),
          );
        }
        return;
      }
      final reason =
          TextEditingController(text: tr('فحص وصيانة بطلب صاحب المتجر'));
      final value = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('بدء جلسة دعم — ${store.name}')),
          content: SizedBox(
              width: 460,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr(
                    'سيتم تسجيل وقت الجلسة وسببها وكل محادثة تُفتح أثناءها.')),
                const SizedBox(height: 12),
                TextField(
                    controller: reason,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: tr('سبب الدخول'))),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('إلغاء'))),
            FilledButton(
                onPressed: () => Navigator.pop(context, reason.text.trim()),
                child: Text(tr('بدء الجلسة'))),
          ],
        ),
      );
      reason.dispose();
      if (value == null || value.length < 3) return;
      final session = await widget.api.postMap(
          '/support-access/stores/${store.id}/session', {'reason': value});
      await widget.controller
          .enterSupportSession(session['accessToken'] as String);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _setStatus(StoreModel store, bool value) async {
    try {
      final updated = await service.setStatus(store.id, value);
      if (!mounted) return;
      setState(() => stores = [
            for (final item in stores)
              if (item.id == updated.id) updated else item
          ]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(value ? tr('تم تفعيل المتجر.') : tr('تم إيقاف المتجر.'))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _resetOwnerPassword(StoreModel store) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    bool saving = false;
    String? dialogError;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('تغيير كلمة مرور صاحب المتجر')),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.owner == null
                    ? tr('لا يوجد حساب مالك مرتبط بهذا المتجر.')
                    : tr(
                        'سيتم تغيير كلمة مرور @${store.owner!.username} وتفعيل الحساب.')),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: tr('كلمة المرور الجديدة'),
                      helperText: tr('8 أحرف على الأقل')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: tr('تأكيد كلمة المرور'),
                      errorText: dialogError),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext, false),
                child: Text(tr('إلغاء'))),
            FilledButton.icon(
              onPressed: saving || store.owner == null
                  ? null
                  : () async {
                      if (password.text.length < 8) {
                        setDialogState(() => dialogError =
                            tr('كلمة المرور يجب أن تكون 8 أحرف على الأقل.'));
                        return;
                      }
                      if (password.text != confirmation.text) {
                        setDialogState(() =>
                            dialogError = tr('كلمتا المرور غير متطابقتين.'));
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await service.resetOwnerPassword(
                            store.id, password.text);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          dialogError = e.toString();
                        });
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.password),
              label: Text(tr('حفظ كلمة المرور')),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    confirmation.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('تم تغيير كلمة مرور صاحب المتجر وتفعيل حسابه.'))));
      await _load();
    }
  }

  Future<void> _deleteStore(StoreModel store) async {
    final confirmation = TextEditingController();
    bool deleting = false;
    String? dialogError;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error, size: 44),
          title: Text(tr('حذف المتجر نهائيًا')),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(
                    'سيتم حذف متجر «${store.name}» وجميع الموظفين والعملاء والمحادثات والرسائل والإعدادات المرتبطة به. لا يمكن التراجع عن هذه العملية.')),
                const SizedBox(height: 14),
                Text(tr('للتأكيد اكتب المعرّف التالي: ${store.slug}'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmation,
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: tr('معرّف المتجر'), errorText: dialogError),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed:
                    deleting ? null : () => Navigator.pop(dialogContext, false),
                child: Text(tr('إلغاء'))),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: deleting
                  ? null
                  : () async {
                      if (confirmation.text.trim().toLowerCase() !=
                          store.slug.toLowerCase()) {
                        setDialogState(() =>
                            dialogError = tr('اكتب ${store.slug} بالضبط.'));
                        return;
                      }
                      setDialogState(() {
                        deleting = true;
                        dialogError = null;
                      });
                      try {
                        await service.deleteStore(
                            store.id, confirmation.text.trim());
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() {
                          deleting = false;
                          dialogError = e.toString();
                        });
                      }
                    },
              icon: deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_forever),
              label: Text(tr('حذف نهائي')),
            ),
          ],
        ),
      ),
    );
    confirmation.dispose();
    if (approved != true || !mounted) return;
    setState(
        () => stores = stores.where((item) => item.id != store.id).toList());
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تم حذف المتجر وجميع بياناته نهائيًا.'))));
  }

  Future<void> _createStore() async {
    final created = await showDialog<StoreModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateStoreDialog(service: service),
    );
    if (created == null || !mounted) return;
    setState(() => stores = [...stores, created]);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تم إنشاء المتجر وصاحب المتجر.'))));
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.onStatusChanged,
    required this.onDelete,
    required this.onResetOwnerPassword,
    required this.onSupport,
  });
  final StoreModel store;
  final ValueChanged<bool> onStatusChanged;
  final VoidCallback onDelete;
  final VoidCallback onResetOwnerPassword;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 760;
          final identity = Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: (store.isActive
                          ? const Color(0xFF0F9D83)
                          : scheme.outline)
                      .withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  store.isActive
                      ? Icons.storefront_rounded
                      : Icons.storefront_outlined,
                  color:
                      store.isActive ? const Color(0xFF0F9D83) : scheme.outline,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text(store.slug,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      (store.isActive ? const Color(0xFF20B65A) : scheme.error)
                          .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  store.isActive ? tr('نشط') : tr('موقوف'),
                  style: TextStyle(
                      color: store.isActive
                          ? const Color(0xFF138A50)
                          : scheme.error,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
          final details = Wrap(
            spacing: 18,
            runSpacing: 9,
            children: [
              _StoreFact(
                  icon: Icons.groups_outlined,
                  text: tr('${store.employeeCount} موظفين')),
              if (store.owner != null)
                _StoreFact(
                    icon: Icons.person_outline_rounded,
                    text: '${store.owner!.name} · @${store.owner!.username}'),
              if ((store.email ?? '').isNotEmpty)
                _StoreFact(
                    icon: Icons.mail_outline_rounded, text: store.email!),
              if ((store.phone ?? '').isNotEmpty)
                _StoreFact(icon: Icons.phone_outlined, text: store.phone!),
            ],
          );
          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                  onPressed: onSupport,
                  icon: const Icon(Icons.support_agent_rounded),
                  label: Text(tr('جلسة دعم'))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('نشط'),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                Switch(value: store.isActive, onChanged: onStatusChanged),
              ]),
              PopupMenuButton<String>(
                tooltip: tr('خيارات المتجر'),
                onSelected: (value) {
                  if (value == 'reset-password') onResetOwnerPassword();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'reset-password',
                      child: Row(children: [
                        const Icon(Icons.password_rounded),
                        const SizedBox(width: 8),
                        Text(tr('تغيير كلمة مرور المالك'))
                      ])),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_forever_rounded),
                        const SizedBox(width: 8),
                        Text(tr('حذف المتجر نهائيًا'))
                      ])),
                ],
              ),
            ],
          );
          if (compact) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 16),
                  details,
                  const SizedBox(height: 16),
                  controls,
                ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: identity),
                  const SizedBox(width: 20),
                  controls
                ]),
                const SizedBox(height: 15),
                details,
              ]);
        },
      ),
    );
  }
}

class _StoreFact extends StatelessWidget {
  const _StoreFact({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _CreateStoreDialog extends StatefulWidget {
  const _CreateStoreDialog({required this.service});
  final StoreService service;

  @override
  State<_CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<_CreateStoreDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final slug = TextEditingController();
  final storeEmail = TextEditingController();
  final phone = TextEditingController();
  final ownerName = TextEditingController();
  final ownerUsername = TextEditingController();
  final ownerEmail = TextEditingController();
  final ownerPassword = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [
      name,
      slug,
      storeEmail,
      phone,
      ownerName,
      ownerUsername,
      ownerEmail,
      ownerPassword
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('إنشاء متجر جديد')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(children: [
              TextFormField(
                  controller: name,
                  decoration: InputDecoration(labelText: tr('اسم المتجر')),
                  validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                  controller: slug,
                  decoration: InputDecoration(
                      labelText: tr('المعرّف الإنجليزي (اختياري)'),
                      hintText: 'riyadh-store')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: storeEmail,
                  decoration:
                      InputDecoration(labelText: tr('بريد المتجر (اختياري)'))),
              const SizedBox(height: 12),
              TextFormField(
                  controller: phone,
                  decoration:
                      InputDecoration(labelText: tr('هاتف المتجر (اختياري)'))),
              const Divider(height: 30),
              TextFormField(
                  controller: ownerName,
                  decoration: InputDecoration(labelText: tr('اسم صاحب المتجر')),
                  validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                  controller: ownerUsername,
                  textDirection: TextDirection.ltr,
                  decoration:
                      InputDecoration(labelText: tr('اسم مستخدم صاحب المتجر')),
                  validator: (value) => value == null || value.trim().length < 3
                      ? tr('3 أحرف على الأقل')
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: ownerEmail,
                  decoration: InputDecoration(
                      labelText: tr('بريد صاحب المتجر (اختياري)')),
                  validator: (value) => value != null &&
                          value.trim().isNotEmpty &&
                          !value.contains('@')
                      ? tr('أدخل بريدًا صحيحًا أو اتركه فارغًا')
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: ownerPassword,
                  obscureText: true,
                  decoration:
                      InputDecoration(labelText: tr('كلمة المرور المؤقتة')),
                  validator: (value) => value == null || value.length < 8
                      ? tr('8 أحرف على الأقل')
                      : null),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))
              ],
            ]),
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
                : Text(tr('إنشاء'))),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().length < 2 ? tr('هذا الحقل مطلوب') : null;

  Future<void> _submit() async {
    if (formKey.currentState?.validate() != true) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.service.createStore(
        name: name.text,
        slug: slug.text,
        email: storeEmail.text,
        phone: phone.text,
        ownerName: ownerName.text,
        ownerUsername: ownerUsername.text,
        ownerEmail: ownerEmail.text,
        ownerPassword: ownerPassword.text,
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
