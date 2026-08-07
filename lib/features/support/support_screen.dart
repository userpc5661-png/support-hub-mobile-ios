import 'package:flutter/material.dart';

import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map<String, dynamic>? health;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      health = await widget.api.getMap('/health');
    } catch (exception) {
      error = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthy = health?['status'] == 'ok';
    return WorkspacePage(
      title: tr('الدعم الفني'),
      subtitle: tr('تشخيص حالة المنصة وخطوات حل المشكلات'),
      icon: Icons.support_agent_outlined,
      accent: const Color(0xFF7C3AED),
      actions: [
        IconButton(
          onPressed: loading ? null : _checkHealth,
          tooltip: tr('فحص الحالة'),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: loading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3))
                  : Icon(
                      healthy
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: healthy
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                      size: 32,
                    ),
              title: Text(
                loading
                    ? tr('جاري فحص حالة الخادم')
                    : healthy
                        ? tr('الخادم يعمل بصورة طبيعية')
                        : tr('تعذر الوصول إلى الخادم'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                error ?? tr('إصدار API: ${health?['version'] ?? '—'}'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _HelpCard(
            icon: Icons.sync_problem_rounded,
            title: tr('التحديث المباشر يعيد الاتصال'),
            body: tr(
                'تأكد من اتصال الإنترنت ثم حدّث الصفحة. إذا استمرت المشكلة راجع صحة API ووسيط HTTPS.'),
          ),
          const SizedBox(height: 14),
          _HelpCard(
            icon: Icons.notifications_none_rounded,
            title: tr('إشعارات الرسائل لا تظهر'),
            body: tr(
                'افتح الإعدادات وفعّل إشعارات المتصفح، ثم اسمح بها من إعدادات الموقع.'),
          ),
          const SizedBox(height: 14),
          _HelpCard(
            icon: Icons.chat_outlined,
            title: tr('اتصال Meta يحتاج إجراء'),
            body: tr(
                'افتح اتصال واتساب، نفّذ المزامنة واختبار الاتصال، ثم أعد الربط إذا انتهى تفويض Meta.'),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(body, style: const TextStyle(height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
