import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';
import 'store_model.dart';
import 'store_service.dart';

class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen(
      {super.key, required this.api, required this.onSaved});
  final ApiClient api;
  final Future<void> Function() onSaved;

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  late final StoreService service;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  StoreModel? store;
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    service = StoreService(widget.api);
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await service.getMine();
      store = value;
      name.text = value.name;
      email.text = value.email ?? '';
      phone.text = value.phone ?? '';
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: tr('بيانات المتجر'),
      subtitle: tr('الهوية وبيانات التواصل والحالة التشغيلية'),
      icon: AppIcons.store,
      accent: const Color(0xFF0F9D83),
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: tr('تحديث'),
            icon: const Icon(Icons.refresh_rounded))
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && store == null
              ? Center(child: Text(error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  const CircleAvatar(
                                      radius: 28,
                                      child: Icon(Icons.storefront, size: 30)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(store!.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        Text(tr('المعرّف: ${store!.slug}')),
                                        Text(store!.isActive
                                            ? tr('الحالة: نشط')
                                            : tr('الحالة: موقوف')),
                                      ])),
                                ]),
                                const Divider(height: 32),
                                TextFormField(
                                  controller: name,
                                  decoration: InputDecoration(
                                      labelText: tr('اسم المتجر')),
                                  validator: (value) =>
                                      value == null || value.trim().length < 2
                                          ? tr('أدخل اسمًا صحيحًا')
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                      labelText: tr('بريد المتجر')),
                                  validator: (value) => value != null &&
                                          value.isNotEmpty &&
                                          !value.contains('@')
                                      ? tr('أدخل بريدًا صحيحًا')
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                      labelText: tr('رقم الهاتف')),
                                ),
                                if (error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                ],
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: saving ? null : _save,
                                  icon: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.save_outlined),
                                  label: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(tr('حفظ التغييرات'))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Future<void> _save() async {
    if (formKey.currentState?.validate() != true) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      store = await service.updateMine(
          name: name.text, email: email.text, phone: phone.text);
      await widget.onSaved();
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('تم حفظ بيانات المتجر.'))));
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
