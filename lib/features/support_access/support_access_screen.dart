import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';

class SupportAccessScreen extends StatefulWidget {
  const SupportAccessScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<SupportAccessScreen> createState() => _SupportAccessScreenState();
}

class _SupportAccessScreenState extends State<SupportAccessScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  bool busy = false;
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
      data = await widget.api.getMap('/support-access');
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = data?['enabled'] == true;
    final grant = data?['grant'] is Map
        ? Map<String, dynamic>.from(data!['grant'] as Map)
        : null;
    return WorkspacePage(
      title: tr('خصوصية دعم المنصة'),
      subtitle: tr('تحكم كامل في وصول مدير المنصة للمحادثات'),
      icon: AppIcons.privacy,
      accent: enabled ? const Color(0xFFF59E0B) : const Color(0xFF0F766E),
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: tr('تحديث'),
            icon: const Icon(Icons.refresh_rounded))
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(
                                child: Icon(
                                    enabled ? Icons.lock_open : Icons.lock)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      enabled
                                          ? tr('الوصول المؤقت مفعّل')
                                          : tr('المحادثات خاصة'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  Text(enabled
                                      ? tr(
                                          'يمكن لمدير المنصة بدء جلسة دعم مسجلة خلال المدة المحددة.')
                                      : tr(
                                          'مدير المنصة لا يستطيع قراءة محادثات المتجر.')),
                                ])),
                          ]),
                          if (grant != null) ...[
                            const Divider(height: 30),
                            Text(tr(
                                'المدة: ${_durationLabel(grant['duration']?.toString())}')),
                            if (grant['expiresAt'] != null)
                              Text(tr('ينتهي: ${grant['expiresAt']}')),
                            if ((grant['reason']?.toString() ?? '').isNotEmpty)
                              Text(tr('السبب: ${grant['reason']}')),
                          ],
                        ]),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('كيف تعمل الحماية؟'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Text(tr(
                              '• الإعداد الافتراضي مغلق.\n• كل جلسة دعم لها سبب ووقت انتهاء.\n• قراءة أي محادثة أثناء جلسة الدعم تُسجل في سجل التدقيق.\n• يمكنك إلغاء الصلاحية فورًا في أي وقت.')),
                        ]),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error))
                ],
                const SizedBox(height: 18),
                if (enabled)
                  FilledButton.tonalIcon(
                      onPressed: busy ? null : _revoke,
                      icon: const Icon(Icons.block),
                      label: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(tr('إلغاء وصول الدعم الآن'))))
                else
                  FilledButton.icon(
                      onPressed: busy ? null : _grant,
                      icon: const Icon(Icons.admin_panel_settings),
                      label: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(tr('منح وصول مؤقت للدعم')))),
              ],
            ),
    );
  }

  String _durationLabel(String? value) => switch (value) {
        'one_hour' => tr('ساعة واحدة'),
        'twenty_four_hours' => tr('24 ساعة'),
        'until_revoked' => tr('حتى يتم الإلغاء'),
        _ => value ?? '-',
      };

  Future<void> _grant() async {
    String duration = 'one_hour';
    final reason = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: Text(tr('منح صلاحية دعم مؤقتة')),
                content: SizedBox(
                    width: 460,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                        initialValue: duration,
                        decoration: InputDecoration(labelText: tr('المدة')),
                        items: [
                          DropdownMenuItem(
                              value: 'one_hour', child: Text(tr('ساعة واحدة'))),
                          DropdownMenuItem(
                              value: 'twenty_four_hours',
                              child: Text(tr('24 ساعة'))),
                          DropdownMenuItem(
                              value: 'until_revoked',
                              child: Text(tr('حتى ألغيها بنفسي'))),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => duration = value ?? duration),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                          controller: reason,
                          maxLines: 3,
                          decoration: InputDecoration(
                              labelText: tr('سبب الدعم (اختياري)'))),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('إلغاء'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context,
                          {'duration': duration, 'reason': reason.text.trim()}),
                      child: Text(tr('موافقة'))),
                ],
              )),
    );
    reason.dispose();
    if (result == null) return;
    setState(() => busy = true);
    try {
      await widget.api.postMap('/support-access/grant', result);
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _revoke() async {
    setState(() => busy = true);
    try {
      await widget.api.postMap('/support-access/revoke');
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
