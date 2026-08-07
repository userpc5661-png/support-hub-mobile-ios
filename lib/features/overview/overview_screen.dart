import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';
import '../auth/user_model.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, required this.api, required this.user});
  final ApiClient api;
  final UserModel user;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;

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
      data = await widget.api.getMap('/dashboard/summary');
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = widget.user.role == 'super_admin' &&
        widget.user.supportSessionId == null;
    return WorkspacePage(
      title: platform ? tr('إحصائيات المنصة') : tr('نظرة عامة'),
      subtitle: platform
          ? tr('قراءة سريعة لنمو المنصة ونشاط المتاجر')
          : tr('ملخص أداء المتجر وحركة المحادثات'),
      icon: AppIcons.overview,
      accent: const Color(0xFF2E5BFF),
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: tr('تحديث'),
            icon: const Icon(Icons.refresh_rounded))
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(children: [
                    const SizedBox(height: 140),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Center(
                        child: FilledButton(
                            onPressed: _load,
                            child: Text(tr('إعادة المحاولة')))),
                  ])
                : _content(context, data!),
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> value) {
    final platform = value['scope'] == 'platform';
    final cards = platform
        ? <_Metric>[
            _Metric(tr('المتاجر'), value['stores'], Icons.storefront),
            _Metric(tr('المتاجر النشطة'), value['activeStores'],
                Icons.check_circle),
            _Metric(tr('المستخدمون'), value['users'], Icons.people),
            _Metric(tr('الموظفون'), value['employees'], Icons.support_agent),
            _Metric(tr('المحادثات'), value['conversations'], Icons.forum),
            _Metric(tr('الرسائل'), value['messages'], Icons.message),
            _Metric(tr('خطط تدعم AI'), value['aiPlans'], Icons.smart_toy),
          ]
        : <_Metric>[
            _Metric(tr('العملاء'), value['customers'], Icons.contacts),
            _Metric(tr('المحادثات المفتوحة'), value['openConversations'],
                Icons.forum),
            _Metric(tr('بانتظار الرد'), value['waitingConversations'],
                Icons.hourglass_bottom),
            _Metric(tr('غير مقروءة'), value['unreadConversations'],
                Icons.mark_chat_unread),
            _Metric(
                tr('المغلقة'), value['closedConversations'], Icons.task_alt),
            _Metric(tr('رسائل اليوم'), value['messagesToday'], Icons.today),
            _Metric(tr('الموظفون'), value['employees'], Icons.groups),
          ];
    final recent = (value['recentConversations'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 132,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: cards.length,
          itemBuilder: (_, index) => _MetricCard(metric: cards[index]),
        ),
        if (!platform) ...[
          const SizedBox(height: 24),
          Text(tr('أحدث المحادثات'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            Card(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(tr('لا توجد محادثات حتى الآن.'))))
          else
            ...recent.map((item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child:
                            Text(_initial(item['customerName']?.toString()))),
                    title: Text(item['customerName']?.toString() ?? tr('عميل')),
                    subtitle: Text(item['lastMessagePreview']?.toString() ??
                        tr('بدون رسائل')),
                    trailing: item['unreadCount'] == 0
                        ? Text(_statusLabel(item['status']?.toString()))
                        : Badge(label: Text('${item['unreadCount']}')),
                  ),
                )),
        ],
      ],
    );
  }

  String _initial(String? value) =>
      value == null || value.isEmpty ? '?' : value.substring(0, 1);

  String _statusLabel(String? status) => switch (status) {
        'new' => tr('جديدة'),
        'open' => tr('مفتوحة'),
        'waiting' => tr('انتظار'),
        'closed' => tr('مغلقة'),
        _ => status ?? '',
      };
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final Object? value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          scheme.primary.withValues(alpha: .10),
          scheme.surfaceContainerLow
        ]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(metric.icon, color: scheme.onPrimary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${metric.value ?? 0}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  Text(metric.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.25)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
