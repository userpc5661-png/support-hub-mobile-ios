import 'package:flutter/material.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';

class MetaUsageScreen extends StatefulWidget {
  const MetaUsageScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<MetaUsageScreen> createState() => _MetaUsageScreenState();
}

class _MetaUsageScreenState extends State<MetaUsageScreen> {
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> alerts = const [];
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
      final values = await Future.wait([
        widget.api.getMap('/usage/summary'),
        widget.api.getList('/usage/alerts'),
      ]);
      summary = values.first as Map<String, dynamic>;
      alerts = values.last as List<Map<String, dynamic>>;
    } catch (exception) {
      error = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      title: tr('استخدام واتساب وفوترة Meta'),
      subtitle: tr('متابعة الرسائل والحدود والتكلفة التقديرية لدى Meta'),
      icon: Icons.query_stats_rounded,
      accent: const Color(0xFF0F9D83),
      actions: [
        IconButton(
          onPressed: loading ? null : _load,
          tooltip: tr('تحديث بيانات الاستخدام'),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: loading
          ? const _UsageSkeleton()
          : error != null
              ? _UsageError(message: error!, onRetry: _load)
              : _UsageContent(
                  summary: summary ?? const {},
                  alerts: alerts,
                  onEditLimits: _editLimits,
                  onReadAlert: _readAlert,
                ),
    );
  }

  Future<void> _readAlert(String id) async {
    await widget.api.patchMap('/usage/alerts/$id/read', const {});
    await _load();
  }

  Future<void> _editLimits() async {
    final current =
        Map<String, dynamic>.from(summary?['limits'] as Map? ?? const {});
    final messages = TextEditingController(
        text: current['monthlyMessageLimit']?.toString() ?? '');
    final cost = TextEditingController(
        text: current['monthlyEstimatedCostLimit']?.toString() ?? '');
    final marketing = TextEditingController(
        text: current['monthlyMarketingLimit']?.toString() ?? '');
    var pauseMarketing = current['pauseMarketingAtLimit'] == true;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('حدود الاستخدام الشهرية')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: messages,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('الحد الأقصى للرسائل'),
                      prefixIcon: const Icon(Icons.mark_chat_unread_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: marketing,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('حد الرسائل التسويقية'),
                      prefixIcon: const Icon(Icons.campaign_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cost,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('حد التكلفة التقديرية'),
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: pauseMarketing,
                    onChanged: (value) =>
                        setDialogState(() => pauseMarketing = value),
                    title: Text(
                        tr('إيقاف الرسائل التسويقية الجديدة عند بلوغ الحد')),
                    subtitle: Text(tr('لا تتوقف رسائل خدمة العملاء الضرورية.')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('إلغاء'))),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'monthlyMessageLimit': int.tryParse(messages.text.trim()),
                'monthlyMarketingLimit': int.tryParse(marketing.text.trim()),
                'monthlyEstimatedCostLimit': double.tryParse(cost.text.trim()),
                'pauseMarketingAtLimit': pauseMarketing,
                'alertThresholds': [50, 75, 90, 100],
              }),
              child: Text(tr('حفظ الحدود')),
            ),
          ],
        ),
      ),
    );
    messages.dispose();
    marketing.dispose();
    cost.dispose();
    if (result == null) return;
    try {
      await widget.api.putMap('/usage/limits', result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('تم حفظ حدود الاستخدام.'))),
        );
      }
      await _load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.toString())),
        );
      }
    }
  }
}

class _UsageContent extends StatelessWidget {
  const _UsageContent({
    required this.summary,
    required this.alerts,
    required this.onEditLimits,
    required this.onReadAlert,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> alerts;
  final VoidCallback onEditLimits;
  final ValueChanged<String> onReadAlert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current =
        Map<String, dynamic>.from(summary['current'] as Map? ?? const {});
    final previous =
        Map<String, dynamic>.from(summary['previous'] as Map? ?? const {});
    final limits =
        Map<String, dynamic>.from(summary['limits'] as Map? ?? const {});
    final daily = (summary['daily'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('اشتراك Wasl منفصل عن رسوم Meta. الأرقام المعروضة تقديرية من سجلات الرسائل وليست فاتورة Meta النهائية.'),
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                    width: width,
                    icon: Icons.call_received_rounded,
                    label: tr('الرسائل الواردة'),
                    value: '${current['inbound'] ?? 0}'),
                _MetricCard(
                    width: width,
                    icon: Icons.call_made_rounded,
                    label: tr('الرسائل الصادرة'),
                    value: '${current['outbound'] ?? 0}'),
                _MetricCard(
                    width: width,
                    icon: Icons.campaign_outlined,
                    label: tr('الرسائل التسويقية'),
                    value: '${current['marketing'] ?? 0}'),
                _MetricCard(
                  width: width,
                  icon: Icons.payments_outlined,
                  label: tr('التكلفة التقديرية'),
                  value: (current['estimatedCost'] as num? ?? 0)
                      .toStringAsFixed(2),
                  caption: tr('تقدير فقط'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _UsageTrend(daily: daily),
        const SizedBox(height: 18),
        _LimitsCard(
          current: current,
          previous: previous,
          limits: limits,
          changePercent: summary['changePercent'] as num?,
          onEdit: onEditLimits,
        ),
        const SizedBox(height: 18),
        _AlertsCard(alerts: alerts, onRead: onReadAlert),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 18),
              Text(value,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w900)),
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
              if (caption != null)
                Text(caption!,
                    style: TextStyle(color: scheme.tertiary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageTrend extends StatelessWidget {
  const _UsageTrend({required this.daily});

  final List<Map<String, dynamic>> daily;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxMessages = daily.fold<num>(1, (current, item) {
      final value = item['messages'] as num? ?? 0;
      return value > current ? value : current;
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('الاستخدام اليومي'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            if (daily.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text(tr('لا توجد سجلات استخدام في هذه الفترة.'))),
              )
            else
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: daily.map((item) {
                    final value = item['messages'] as num? ?? 0;
                    return Expanded(
                      child: Tooltip(
                        message: '${item['date']}: $value',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 12 + (value / maxMessages) * 120,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LimitsCard extends StatelessWidget {
  const _LimitsCard({
    required this.current,
    required this.previous,
    required this.limits,
    required this.changePercent,
    required this.onEdit,
  });

  final Map<String, dynamic> current;
  final Map<String, dynamic> previous;
  final Map<String, dynamic> limits;
  final num? changePercent;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final used = (current['messages'] as num? ?? 0).toDouble();
    final limit = (limits['monthlyMessageLimit'] as num?)?.toDouble();
    final progress =
        limit == null || limit <= 0 ? null : (used / limit).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(tr('الحدود والتنبيهات'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900))),
                OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(tr('تعديل الحدود'))),
              ],
            ),
            const SizedBox(height: 16),
            if (progress == null)
              Text(tr('لم يتم تحديد حد شهري مخصص للرسائل.'))
            else ...[
              LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10)),
              const SizedBox(height: 8),
              Text(tr('$used من $limit رسالة')),
            ],
            const SizedBox(height: 12),
            Text(
              changePercent == null
                  ? tr('لا توجد فترة سابقة كافية للمقارنة.')
                  : tr(
                      'التغير عن الشهر السابق: ${changePercent!.toStringAsFixed(1)}%'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.alerts, required this.onRead});

  final List<Map<String, dynamic>> alerts;
  final ValueChanged<String> onRead;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('تنبيهات الاستخدام'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: Text(tr('لا توجد تنبيهات استخدام حاليًا.')),
              )
            else
              ...alerts.map((alert) => ListTile(
                    leading: Icon(alert['readAt'] == null
                        ? Icons.notification_important_rounded
                        : Icons.notifications_none_rounded),
                    title: Text(alert['title']?.toString() ?? ''),
                    subtitle: Text(alert['message']?.toString() ?? ''),
                    trailing: alert['readAt'] == null
                        ? IconButton(
                            onPressed: () => onRead(alert['id'].toString()),
                            tooltip: tr('تحديد كمقروء'),
                            icon: const Icon(Icons.done_rounded),
                          )
                        : null,
                  )),
          ],
        ),
      ),
    );
  }
}

class _UsageSkeleton extends StatelessWidget {
  const _UsageSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: List.generate(
        4,
        (index) => Container(
          height: index == 0 ? 74 : 130,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

class _UsageError extends StatelessWidget {
  const _UsageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(tr('تعذر تحميل بيانات الاستخدام.'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('إعادة المحاولة'))),
          ],
        ),
      ),
    );
  }
}
