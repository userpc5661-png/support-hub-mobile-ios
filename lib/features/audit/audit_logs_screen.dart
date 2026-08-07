import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
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
      items = await widget.api.getList('/audit-logs?limit=200');
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspacePage(
        title: tr('سجل التدقيق'),
        subtitle: tr('تتبّع عمليات الإدارة والتغييرات الحساسة زمنيًا'),
        icon: AppIcons.audit,
        accent: const Color(0xFF6D4ED8),
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
                : items.isEmpty
                    ? Center(child: Text(tr('لا توجد عمليات مسجلة حتى الآن.')))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final date = DateTime.tryParse(
                                  item['createdAt']?.toString() ?? '')
                              ?.toLocal();
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.history)),
                              title: Text(
                                  _actionLabel(item['action']?.toString())),
                              subtitle: Text(tr(
                                  '${item['actorUsername'] ?? 'النظام'}\n${item['targetType'] ?? ''}: ${item['targetId'] ?? '-'}')),
                              trailing: Text(date == null
                                  ? '-'
                                  : '${date.year}-${date.month}-${date.day}\n${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
      );

  String _actionLabel(String? action) => switch (action) {
        'store.deleted' => tr('حذف متجر نهائيًا'),
        'subscription.updated' => tr('تعديل اشتراك متجر'),
        _ => action ?? tr('عملية إدارية'),
      };
}
