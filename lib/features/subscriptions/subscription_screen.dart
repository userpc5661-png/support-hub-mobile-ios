import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = await widget.api.getMap('/subscriptions/me');
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspacePage(
        title: tr('الاشتراك والاستخدام'),
        subtitle: tr('تفاصيل الباقة والحدود والاستهلاك الحالي'),
        icon: AppIcons.subscriptions,
        accent: const Color(0xFFF59E0B),
        actions: [
          IconButton(
              onPressed: _load,
              tooltip: tr('تحديث'),
              icon: const Icon(Icons.refresh_rounded))
        ],
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_displayPlan(data!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium),
                                  Text(tr(
                                      'الحالة: ${_statusLabel(data!['status']?.toString())}')),
                                  const SizedBox(height: 8),
                                  Text(tr(
                                      'المتبقي من المدة: ${data!['remainingDays'] ?? 0} يوم')),
                                  const SizedBox(height: 18),
                                  _UsageBar(
                                    label: tr('رسائل الفترة الحالية'),
                                    value: (data!['messageUsage'] as num?)
                                            ?.toInt() ??
                                        0,
                                    limit:
                                        (data!['monthlyMessageLimit'] as num?)
                                                ?.toInt() ??
                                            0,
                                  ),
                                  const SizedBox(height: 12),
                                  _FeatureTile(
                                      icon: Icons.groups,
                                      label: tr('حد الموظفين'),
                                      value:
                                          _limitLabel(data!['employeeLimit'])),
                                  _FeatureTile(
                                      icon: Icons.smart_toy,
                                      label: tr('الذكاء الاصطناعي'),
                                      enabled: data!['aiEnabled'] == true),
                                  _FeatureTile(
                                      icon: Icons.phone,
                                      label: tr('واتساب'),
                                      enabled:
                                          data!['whatsappEnabled'] == true),
                                  _FeatureTile(
                                      icon: Icons.add_comment,
                                      label: tr('المحادثات اليدوية'),
                                      enabled:
                                          data!['manualConversationsEnabled'] ==
                                              true),
                                  _FeatureTile(
                                      icon: Icons.menu_book,
                                      label: tr('قاعدة المعرفة'),
                                      enabled: data!['knowledgeBaseEnabled'] ==
                                          true),
                                  _FeatureTile(
                                      icon: Icons.analytics,
                                      label: tr('الإحصائيات'),
                                      enabled:
                                          data!['analyticsEnabled'] == true),
                                  _FeatureTile(
                                      icon: Icons.perm_media,
                                      label: tr('رسائل الوسائط'),
                                      enabled: data!['mediaMessagesEnabled'] ==
                                          true),
                                  if (data!['currentPeriodEnd'] != null)
                                    Text(tr(
                                        'نهاية الاشتراك: ${_dateTimeLabel(data!['currentPeriodEnd'])}')),
                                ]),
                          ),
                        ),
                      ],
                    ),
                  ),
      );
}

class SubscriptionsAdminScreen extends StatefulWidget {
  const SubscriptionsAdminScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<SubscriptionsAdminScreen> createState() =>
      _SubscriptionsAdminScreenState();
}

class _SubscriptionsAdminScreenState extends State<SubscriptionsAdminScreen> {
  List<Map<String, dynamic>> items = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      items = await widget.api.getList('/subscriptions');
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspacePage(
        title: tr('اشتراكات المتاجر'),
        subtitle: tr('إدارة الباقات والحدود والمزايا لكل متجر'),
        icon: AppIcons.subscriptions,
        accent: const Color(0xFFF59E0B),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: tr('تحديث'))
        ],
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final store = item['store'] is Map
                            ? Map<String, dynamic>.from(item['store'] as Map)
                            : <String, dynamic>{};
                        final expired = item['expired'] == true;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  CircleAvatar(
                                      child: Icon(expired
                                          ? Icons.warning_amber
                                          : Icons.workspace_premium)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            store['name']?.toString() ??
                                                item['storeId']?.toString() ??
                                                '',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        Text(
                                            '${_displayPlan(item)} • ${_statusLabel(item['status']?.toString())}'),
                                      ])),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _edit(item),
                                    icon: const Icon(Icons.tune),
                                    label: Text(tr('تحكم كامل')),
                                  ),
                                ]),
                                const Divider(height: 22),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Text(tr(
                                        'المدة المتبقية: ${item['remainingDays'] ?? 0} يوم')),
                                    Text(tr(
                                        'الرسائل: ${item['messageUsage']}/${_limitLabel(item['monthlyMessageLimit'])}')),
                                    Text(tr(
                                        'الموظفون: ${_limitLabel(item['employeeLimit'])}')),
                                    Text(tr(
                                        'AI: ${item['aiEnabled'] == true ? 'نعم' : 'لا'}')),
                                    Text(tr(
                                        'واتساب: ${item['whatsappEnabled'] == true ? 'نعم' : 'لا'}')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      );

  Future<void> _edit(Map<String, dynamic> item) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SubscriptionEditor(api: widget.api, initial: item),
    );
    if (updated == null || !mounted) return;
    setState(() => items = [
          for (final current in items)
            if (current['storeId'] == updated['storeId']) updated else current
        ]);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تم حفظ الاشتراك والحدود بنجاح.'))));
  }
}

class _SubscriptionEditor extends StatefulWidget {
  const _SubscriptionEditor({required this.api, required this.initial});
  final ApiClient api;
  final Map<String, dynamic> initial;

  @override
  State<_SubscriptionEditor> createState() => _SubscriptionEditorState();
}

class _SubscriptionEditorState extends State<_SubscriptionEditor> {
  final formKey = GlobalKey<FormState>();
  late String plan;
  late String status;
  late DateTime periodEnd;
  late bool aiEnabled;
  late bool whatsappEnabled;
  late bool manualConversationsEnabled;
  late bool knowledgeBaseEnabled;
  late bool analyticsEnabled;
  late bool mediaMessagesEnabled;
  late bool autoRenew;
  bool resetUsage = false;
  bool saving = false;
  String? error;

  late final TextEditingController customName;
  late final TextEditingController employeeLimit;
  late final TextEditingController messageLimit;
  late final TextEditingController messageUsage;
  late final TextEditingController maxKnowledgeItems;
  late final TextEditingController dataRetentionDays;
  late final TextEditingController adminNotes;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    plan = value['plan']?.toString() ?? 'free';
    status = value['status']?.toString() ?? 'active';
    periodEnd = DateTime.tryParse(value['currentPeriodEnd']?.toString() ?? '')
            ?.toLocal() ??
        DateTime.now().add(const Duration(days: 30));
    aiEnabled = value['aiEnabled'] == true;
    whatsappEnabled = value['whatsappEnabled'] != false;
    manualConversationsEnabled = value['manualConversationsEnabled'] != false;
    knowledgeBaseEnabled = value['knowledgeBaseEnabled'] != false;
    analyticsEnabled = value['analyticsEnabled'] != false;
    mediaMessagesEnabled = value['mediaMessagesEnabled'] == true;
    autoRenew = value['autoRenew'] == true;
    customName =
        TextEditingController(text: value['customName']?.toString() ?? '');
    employeeLimit =
        TextEditingController(text: '${value['employeeLimit'] ?? 2}');
    messageLimit =
        TextEditingController(text: '${value['monthlyMessageLimit'] ?? 500}');
    messageUsage = TextEditingController(text: '${value['messageUsage'] ?? 0}');
    maxKnowledgeItems =
        TextEditingController(text: '${value['maxKnowledgeItems'] ?? 100}');
    dataRetentionDays =
        TextEditingController(text: '${value['dataRetentionDays'] ?? 365}');
    adminNotes =
        TextEditingController(text: value['adminNotes']?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      customName,
      employeeLimit,
      messageLimit,
      messageUsage,
      maxKnowledgeItems,
      dataRetentionDays,
      adminNotes
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.initial['store'] is Map
        ? Map<String, dynamic>.from(widget.initial['store'] as Map)
        : <String, dynamic>{};
    return AlertDialog(
      title: Text(tr('إدارة اشتراك ${store['name'] ?? ''}')),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: plan,
                          decoration: InputDecoration(labelText: tr('الخطة')),
                          items: const [
                            DropdownMenuItem(
                                value: 'free', child: Text('Free')),
                            DropdownMenuItem(
                                value: 'basic', child: Text('Basic')),
                            DropdownMenuItem(value: 'pro', child: Text('Pro')),
                            DropdownMenuItem(
                                value: 'enterprise', child: Text('Enterprise')),
                          ],
                          onChanged: (value) {
                            if (value != null) _applyPlanPreset(value);
                          },
                        )),
                    SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: InputDecoration(labelText: tr('الحالة')),
                          items: [
                            DropdownMenuItem(
                                value: 'trial', child: Text(tr('تجريبية'))),
                            DropdownMenuItem(
                                value: 'active', child: Text(tr('نشطة'))),
                            DropdownMenuItem(
                                value: 'past_due',
                                child: Text(tr('منتهية/متأخرة'))),
                            DropdownMenuItem(
                                value: 'cancelled', child: Text(tr('ملغية'))),
                          ],
                          onChanged: (value) =>
                              setState(() => status = value ?? status),
                        )),
                    SizedBox(
                        width: 220,
                        child: TextFormField(
                            controller: customName,
                            decoration: InputDecoration(
                                labelText: tr('اسم مخصص للخطة')))),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('المدة والاستخدام'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: Text(tr(
                                    'نهاية الاشتراك: ${_simpleDate(periodEnd)}'))),
                            OutlinedButton.icon(
                                onPressed: _pickEndDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(tr('اختيار تاريخ'))),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            ActionChip(
                                label: Text(tr('+7 أيام')),
                                onPressed: () => setState(() => periodEnd =
                                    periodEnd.add(const Duration(days: 7)))),
                            ActionChip(
                                label: Text(tr('+30 يوم')),
                                onPressed: () => setState(() => periodEnd =
                                    periodEnd.add(const Duration(days: 30)))),
                            ActionChip(
                                label: Text(tr('+365 يوم')),
                                onPressed: () => setState(() => periodEnd =
                                    periodEnd.add(const Duration(days: 365)))),
                            ActionChip(
                                label: Text(tr('30 يوم من الآن')),
                                onPressed: () => setState(() => periodEnd =
                                    DateTime.now()
                                        .add(const Duration(days: 30)))),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 12, runSpacing: 12, children: [
                            SizedBox(
                                width: 200,
                                child: _intField(employeeLimit,
                                    tr('حد الموظفين (0 غير محدود)'))),
                            SizedBox(
                                width: 220,
                                child: _intField(messageLimit,
                                    tr('حد رسائل الفترة (0 غير محدود)'))),
                            SizedBox(
                                width: 200,
                                child: _intField(
                                    messageUsage, tr('الرسائل المستخدمة'))),
                          ]),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: resetUsage,
                              onChanged: (value) =>
                                  setState(() => resetUsage = value),
                              title: Text(tr('تصفير عداد الرسائل عند الحفظ'))),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: autoRenew,
                              onChanged: (value) =>
                                  setState(() => autoRenew = value),
                              title:
                                  Text(tr('تجديد الفترة تلقائيًا بنفس مدتها'))),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('المزايا المتاحة للمتجر'),
                              style: Theme.of(context).textTheme.titleMedium),
                          _switch(tr('الذكاء الاصطناعي'), aiEnabled,
                              (v) => aiEnabled = v),
                          _switch(tr('ربط واتساب الحقيقي'), whatsappEnabled,
                              (v) => whatsappEnabled = v),
                          _switch(
                              tr('إنشاء محادثات يدوية'),
                              manualConversationsEnabled,
                              (v) => manualConversationsEnabled = v),
                          _switch(tr('قاعدة المعرفة'), knowledgeBaseEnabled,
                              (v) => knowledgeBaseEnabled = v),
                          _switch(tr('الإحصائيات والتقارير'), analyticsEnabled,
                              (v) => analyticsEnabled = v),
                          _switch(tr('رسائل الوسائط'), mediaMessagesEnabled,
                              (v) => mediaMessagesEnabled = v),
                          const SizedBox(height: 8),
                          Wrap(spacing: 12, runSpacing: 12, children: [
                            SizedBox(
                                width: 220,
                                child: _intField(maxKnowledgeItems,
                                    tr('حد عناصر المعرفة (0 غير محدود)'))),
                            SizedBox(
                                width: 220,
                                child: _intField(dataRetentionDays,
                                    tr('حفظ البيانات بالأيام (0 دائم)'))),
                          ]),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: adminNotes,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: tr('ملاحظات الإدارة الداخلية'))),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error))
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
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(tr('حفظ الاشتراك')),
        ),
      ],
    );
  }

  void _applyPlanPreset(String value) {
    const presets = <String, Map<String, Object>>{
      'free': {
        'employees': 2,
        'messages': 500,
        'knowledge': 0,
        'retention': 90,
        'ai': false,
        'whatsapp': true,
        'manual': true,
        'kb': false,
        'analytics': true,
        'media': false,
      },
      'basic': {
        'employees': 5,
        'messages': 5000,
        'knowledge': 50,
        'retention': 365,
        'ai': false,
        'whatsapp': true,
        'manual': true,
        'kb': true,
        'analytics': true,
        'media': true,
      },
      'pro': {
        'employees': 20,
        'messages': 50000,
        'knowledge': 500,
        'retention': 1095,
        'ai': true,
        'whatsapp': true,
        'manual': true,
        'kb': true,
        'analytics': true,
        'media': true,
      },
      'enterprise': {
        'employees': 0,
        'messages': 0,
        'knowledge': 0,
        'retention': 0,
        'ai': true,
        'whatsapp': true,
        'manual': true,
        'kb': true,
        'analytics': true,
        'media': true,
      },
    };
    final preset = presets[value]!;
    setState(() {
      plan = value;
      employeeLimit.text = '${preset['employees']}';
      messageLimit.text = '${preset['messages']}';
      maxKnowledgeItems.text = '${preset['knowledge']}';
      dataRetentionDays.text = '${preset['retention']}';
      aiEnabled = preset['ai'] == true;
      whatsappEnabled = preset['whatsapp'] == true;
      manualConversationsEnabled = preset['manual'] == true;
      knowledgeBaseEnabled = preset['kb'] == true;
      analyticsEnabled = preset['analytics'] == true;
      mediaMessagesEnabled = preset['media'] == true;
    });
  }

  Widget _intField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final parsed = int.tryParse(value ?? '');
          return parsed == null || parsed < 0
              ? tr('أدخل رقمًا صحيحًا 0 أو أكبر')
              : null;
        },
      );

  Widget _switch(String label, bool value, ValueChanged<bool> update) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        title: Text(label),
        onChanged: (next) => setState(() => update(next)),
      );

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          periodEnd.isBefore(DateTime.now()) ? DateTime.now() : periodEnd,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) {
      setState(() => periodEnd =
          DateTime(selected.year, selected.month, selected.day, 23, 59, 59));
    }
  }

  Future<void> _save() async {
    if (formKey.currentState?.validate() != true) return;
    if (!periodEnd.isAfter(DateTime.now())) {
      setState(() => error = tr('اختر تاريخ نهاية مستقبليًا.'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await widget.api
          .patchMap('/subscriptions/${widget.initial['storeId']}', {
        'plan': plan,
        'customName': customName.text.trim(),
        'status': status,
        'employeeLimit': int.parse(employeeLimit.text),
        'monthlyMessageLimit': int.parse(messageLimit.text),
        'messageUsage': int.parse(messageUsage.text),
        'aiEnabled': aiEnabled,
        'whatsappEnabled': whatsappEnabled,
        'manualConversationsEnabled': manualConversationsEnabled,
        'knowledgeBaseEnabled': knowledgeBaseEnabled,
        'analyticsEnabled': analyticsEnabled,
        'mediaMessagesEnabled': mediaMessagesEnabled,
        'maxKnowledgeItems': int.parse(maxKnowledgeItems.text),
        'dataRetentionDays': int.parse(dataRetentionDays.text),
        'currentPeriodEnd': periodEnd.toUtc().toIso8601String(),
        'autoRenew': autoRenew,
        'resetUsage': resetUsage,
        'adminNotes': adminNotes.text.trim(),
      });
      if (mounted) Navigator.pop(context, updated);
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

class _UsageBar extends StatelessWidget {
  const _UsageBar(
      {required this.label, required this.value, required this.limit});
  final String label;
  final int value;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final unlimited = limit == 0;
    final ratio = unlimited ? 0.0 : (value / limit).clamp(0.0, 1.0).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label)),
        Text(unlimited ? tr('$value / غير محدود') : '$value / $limit')
      ]),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: unlimited ? null : ratio),
    ]);
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile(
      {required this.icon, required this.label, this.enabled, this.value});
  final IconData icon;
  final String label;
  final bool? enabled;
  final String? value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        trailing: value != null
            ? Text(value!)
            : Icon(enabled == true ? Icons.check_circle : Icons.cancel),
      );
}

String _displayPlan(Map<String, dynamic> data) {
  final custom = data['customName']?.toString().trim();
  return custom != null && custom.isNotEmpty
      ? custom
      : _planLabel(data['plan']?.toString());
}

String _planLabel(String? value) => switch (value) {
      'free' => tr('الخطة المجانية'),
      'basic' => 'Basic',
      'pro' => 'Pro',
      'enterprise' => 'Enterprise',
      _ => value ?? '',
    };
String _statusLabel(String? value) => switch (value) {
      'trial' => tr('تجريبية'),
      'active' => tr('نشطة'),
      'past_due' => tr('منتهية/متأخرة'),
      'cancelled' => tr('ملغية'),
      _ => value ?? '',
    };
String _limitLabel(Object? value) {
  final number = (value as num?)?.toInt() ?? 0;
  return number == 0 ? tr('غير محدود') : '$number';
}

String _simpleDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _dateTimeLabel(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return date == null
      ? '-'
      : '${_simpleDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
