import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/support_hub_design.dart';
import '../../core/widgets/support_hub_widgets.dart';
import '../auth/user_model.dart';
import '../conversations/conversation_service.dart';
import '../conversations/conversations_screen.dart';
import 'customer_model.dart';
import 'customer_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.api, required this.user});
  final ApiClient api;
  final UserModel user;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomerService service;
  final search = TextEditingController();
  Timer? debounce;
  List<CustomerModel> customers = const [];
  bool loading = true;
  String? error;

  bool get canCreate => widget.user.hasPermission('customers.create');
  bool get canStartChat => widget.user.hasPermission('conversations.reply');
  bool get canUpdate => widget.user.hasPermission('customers.update');

  @override
  void initState() {
    super.initState();
    service = CustomerService(widget.api);
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      customers = await service.list(search.text);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.hubScheme.surfaceContainerLowest,
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => _edit(),
                tooltip: tr('عميل جديد'),
                child: const Icon(Icons.person_add_alt_1_rounded),
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              HubPageHeader(
                title: tr('العملاء'),
                subtitle: tr('${customers.length} عميل في مساحة العمل'),
                leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.hubScheme.primary.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people_alt_rounded, color: context.hubScheme.primary),
              ),
                actions: [
                  HubIconButton(
                    icon: Icons.refresh_rounded,
                    onPressed: _load,
                    tooltip: tr('تحديث'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    HubSpace.md, 0, HubSpace.md, HubSpace.sm),
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    hintText: tr('ابحث بالاسم أو رقم الهاتف'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              search.clear();
                              setState(() {});
                              _load();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 350), _load);
                  },
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return HubEmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr('تعذر تحميل العملاء'),
        body: error!,
        action:
            FilledButton(onPressed: _load, child: Text(tr('إعادة المحاولة'))),
      );
    }
    if (customers.isEmpty) {
      return HubEmptyState(
        icon: Icons.people_outline_rounded,
        title: tr('لا يوجد عملاء'),
        body: search.text.isEmpty
            ? tr('سيظهر العملاء هنا عند بدء المحادثات معهم.')
            : tr('لم نجد عميلًا مطابقًا لبحثك.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(HubSpace.md, 4, HubSpace.md, 120),
        itemCount: customers.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 76,
          color: context.hubScheme.outlineVariant.withValues(alpha: .35),
        ),
        itemBuilder: (_, index) {
          final customer = customers[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(HubRadius.md),
              onTap: () => _showCustomer(customer),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                child: Row(
                  children: [
                    HubAvatar(name: customer.name, size: 52),
                    const SizedBox(width: HubSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15.5)),
                          const SizedBox(height: 3),
                          Text(
                            customer.phone,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                color: context.hubScheme.onSurfaceVariant),
                          ),
                          if (customer.tags.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              customer.tags.take(3).join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.hubScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 21),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCustomer(CustomerModel customer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              HubSpace.lg, 0, HubSpace.lg, HubSpace.xl),
          child: Column(
            children: [
              HubAvatar(name: customer.name, size: 76),
              const SizedBox(height: HubSpace.md),
              Text(customer.name,
                  style: context.hubText.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: HubSpace.xxs),
              SelectableText(customer.phone,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: context.hubScheme.onSurfaceVariant)),
              if ((customer.email ?? '').isNotEmpty) ...[
                const SizedBox(height: HubSpace.xxs),
                SelectableText(customer.email!,
                    textDirection: TextDirection.ltr),
              ],
              if (customer.tags.isNotEmpty) ...[
                const SizedBox(height: HubSpace.md),
                Wrap(
                  spacing: HubSpace.xs,
                  runSpacing: HubSpace.xs,
                  alignment: WrapAlignment.center,
                  children: customer.tags
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
              ],
              if ((customer.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: HubSpace.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(HubSpace.md),
                  decoration: BoxDecoration(
                    color: context.hubScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(HubRadius.md),
                  ),
                  child: Text(customer.notes!,
                      style: const TextStyle(height: 1.6)),
                ),
              ],
              if (canStartChat) ...[
                const SizedBox(height: HubSpace.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _startChat(customer);
                    },
                    icon: const Icon(Icons.chat_rounded),
                    label: Text(tr('ابدأ دردشة مع هذا العميل')),
                  ),
                ),
              ],
              if (canUpdate) ...[
                const SizedBox(height: HubSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _edit(customer);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(tr('تعديل بيانات العميل')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit([CustomerModel? customer]) async {
    final result = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerForm(service: service, customer: customer),
    );
    if (result == null || !mounted) return;
    await _load();
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(customer == null
            ? tr('تمت إضافة العميل.')
            : tr('تم تحديث العميل.')),
        action: customer == null && canStartChat
            ? SnackBarAction(
                label: tr('بدء دردشة'),
                onPressed: () => _startChat(result),
              )
            : null,
      ));
    }
  }

  Future<void> _startChat(CustomerModel customer) async {
    final message = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('بدء دردشة')),
        content: TextField(
          controller: message,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: tr('اكتب الرسالة الأولى'),
            hintText: tr('ابدأ المحادثة برسالة للعميل'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            onPressed: () {
              if (message.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text(tr('بدء دردشة')),
          ),
        ],
      ),
    );
    final body = message.text.trim();
    message.dispose();
    if (confirmed != true || body.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final progress = messenger.showSnackBar(SnackBar(
      duration: const Duration(minutes: 1),
      content: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(tr('جارٍ الإرسال…')),
        ],
      ),
    ));
    try {
      final created = await ConversationService(widget.api).create(
        name: customer.name,
        phone: customer.phone,
        message: body,
      );
      ChatCache.set(created);
      progress.close();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        settings: RouteSettings(name: '/chats/${created.id}'),
        builder: (_) => ConversationsScreen(
          api: widget.api,
          user: widget.user,
          manualConversationsEnabled: true,
          aiEnabled: widget.user.hasPermission('ai.draft'),
          initialConversationId: created.id,
        ),
      ));
    } catch (error) {
      progress.close();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${tr('تعذر بدء الدردشة')}: $error'),
      ));
    }
  }
}

class _CustomerForm extends StatefulWidget {
  const _CustomerForm({required this.service, this.customer});
  final CustomerService service;
  final CustomerModel? customer;

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController notes;
  late final TextEditingController tags;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.customer?.name ?? '');
    phone = TextEditingController(text: widget.customer?.phone ?? '');
    email = TextEditingController(text: widget.customer?.email ?? '');
    notes = TextEditingController(text: widget.customer?.notes ?? '');
    tags = TextEditingController(text: widget.customer?.tags.join('، ') ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    notes.dispose();
    tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            HubSpace.lg,
            0,
            HubSpace.lg,
            MediaQuery.viewInsetsOf(context).bottom + HubSpace.lg,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.customer == null
                        ? tr('إضافة عميل')
                        : tr('تعديل العميل'),
                    style: context.hubText.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: HubSpace.lg),
                  TextFormField(
                    controller: name,
                    decoration: InputDecoration(labelText: tr('الاسم')),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                            ? tr('أدخل اسمًا صحيحًا')
                            : null,
                  ),
                  const SizedBox(height: HubSpace.sm),
                  TextFormField(
                    controller: phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: tr('رقم الهاتف')),
                    validator: (value) => value == null ||
                            value.replaceAll(RegExp(r'\D'), '').length < 6
                        ? tr('أدخل رقمًا صحيحًا')
                        : null,
                  ),
                  const SizedBox(height: HubSpace.sm),
                  TextFormField(
                    controller: email,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                        labelText: tr('البريد الإلكتروني — اختياري')),
                  ),
                  const SizedBox(height: HubSpace.sm),
                  TextFormField(
                    controller: tags,
                    decoration:
                        InputDecoration(labelText: tr('الوسوم مفصولة بفاصلة')),
                  ),
                  const SizedBox(height: HubSpace.sm),
                  TextFormField(
                    controller: notes,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: tr('ملاحظات')),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: HubSpace.sm),
                    Text(error!,
                        style: TextStyle(color: context.hubScheme.error)),
                  ],
                  const SizedBox(height: HubSpace.lg),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(tr('حفظ')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _save() async {
    if (key.currentState?.validate() != true) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = widget.customer == null
          ? await widget.service.create(
              name: name.text,
              phone: phone.text,
              email: email.text,
              notes: notes.text,
              tags: CustomerService.parseTags(tags.text),
            )
          : await widget.service.update(
              widget.customer!.id,
              name: name.text,
              phone: phone.text,
              email: email.text,
              notes: notes.text,
              tags: CustomerService.parseTags(tags.text),
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
