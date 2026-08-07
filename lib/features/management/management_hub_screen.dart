import 'package:flutter/material.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/support_hub_design.dart';
import '../../core/widgets/support_hub_widgets.dart';
import '../ai/ai_settings_screen.dart';
import '../audit/audit_logs_screen.dart';
import '../auth/auth_controller.dart';
import '../employees/employees_screen.dart';
import '../meta_usage/meta_usage_screen.dart';
import '../overview/overview_screen.dart';
import '../stores/store_profile_screen.dart';
import '../stores/stores_admin_screen.dart';
import '../subscriptions/subscription_screen.dart';
import '../support/support_screen.dart';
import '../support_access/support_access_screen.dart';
import '../whatsapp/whatsapp_settings_screen.dart';

class ManagementHubScreen extends StatelessWidget {
  const ManagementHubScreen({
    super.key,
    required this.api,
    required this.controller,
  });

  final ApiClient api;
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user!;
    final platformAdmin =
        user.role == 'super_admin' && user.supportSessionId == null;
    final actions =
        platformAdmin ? _platformActions(context) : _storeActions(context);
    return Scaffold(
      backgroundColor: context.hubScheme.surfaceContainerLowest,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: HubPageHeader(
                title: platformAdmin ? tr('إدارة المنصة') : tr('الإدارة'),
                subtitle: platformAdmin
                    ? tr('المتاجر والاشتراكات وحالة النظام')
                    : user.storeName ?? tr('أدوات مساحة العمل'),
                leading: const SupportHubMark(size: 44),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    HubSpace.md, 0, HubSpace.md, HubSpace.lg),
                child: Container(
                  padding: const EdgeInsets.all(HubSpace.lg),
                  decoration: BoxDecoration(
                    color: context.hubScheme.primary,
                    borderRadius: BorderRadius.circular(HubRadius.xl),
                  ),
                  child: Row(
                    children: [
                      HubAvatar(
                          name: user.name,
                          size: 58,
                          online: true,
                          color: Colors.white),
                      const SizedBox(width: HubSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.roleLabel,
                                style: TextStyle(
                                    color: context.hubScheme.onPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(
                              tr('تظهر هنا الأدوات المسموحة لهذا الحساب فقط.'),
                              style: TextStyle(
                                  color: context.hubScheme.onPrimary
                                      .withValues(alpha: .74),
                                  height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (user.supportSessionId != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                      HubSpace.md, 0, HubSpace.md, HubSpace.lg),
                  padding: const EdgeInsets.all(HubSpace.md),
                  decoration: BoxDecoration(
                    color: context.hubColors.warningSoft,
                    borderRadius: BorderRadius.circular(HubRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          color: context.hubColors.warning),
                      const SizedBox(width: HubSpace.sm),
                      Expanded(
                          child: Text(tr('جلسة دعم نشطة داخل هذا المتجر'))),
                      TextButton(
                          onPressed: controller.exitSupportSession,
                          child: Text(tr('إنهاء الجلسة'))),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(HubSpace.md, 0, HubSpace.md, 120),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent:
                      MediaQuery.sizeOf(context).width < 600 ? 260 : 340,
                  mainAxisExtent: 154,
                  crossAxisSpacing: HubSpace.sm,
                  mainAxisSpacing: HubSpace.sm,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, index) => _ManagementCard(action: actions[index]),
                  childCount: actions.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ManagementAction> _platformActions(BuildContext context) => [
        _ManagementAction(
          label: tr('نظرة عامة'),
          description: tr('الأرقام وحالة المنصة'),
          icon: Icons.monitor_heart_outlined,
          open: () =>
              _open(context, OverviewScreen(api: api, user: controller.user!)),
        ),
        _ManagementAction(
          label: tr('المتاجر'),
          description: tr('إنشاء المتاجر وإدارتها'),
          icon: Icons.storefront_outlined,
          open: () => _open(
              context, StoresAdminScreen(api: api, controller: controller)),
        ),
        _ManagementAction(
          label: tr('الاشتراكات'),
          description: tr('الباقات والحدود والمزايا'),
          icon: Icons.credit_card_outlined,
          open: () => _open(context, SubscriptionsAdminScreen(api: api)),
        ),
        _ManagementAction(
          label: tr('سجل التدقيق'),
          description: tr('عمليات الإدارة وجلسات الدعم'),
          icon: Icons.fact_check_outlined,
          open: () => _open(context, AuditLogsScreen(api: api)),
        ),
        _ManagementAction(
          label: tr('الدعم الفني'),
          description: tr('حالة النظام وحل المشكلات'),
          icon: Icons.support_agent_rounded,
          open: () => _open(context, SupportScreen(api: api)),
        ),
      ];

  List<_ManagementAction> _storeActions(BuildContext context) {
    final user = controller.user!;
    final actions = <_ManagementAction>[];
    if (user.hasPermission('reports.read')) {
      actions.add(_ManagementAction(
        label: tr('نظرة عامة'),
        description: tr('الأرقام وحالة العمل'),
        icon: Icons.query_stats_rounded,
        open: () => _open(context, OverviewScreen(api: api, user: user)),
      ));
    }
    if (user.hasPermission('employees.read')) {
      actions.add(_ManagementAction(
        label: tr('الفريق والصلاحيات'),
        description: tr('المديرون والمشرفون والموظفون'),
        icon: Icons.groups_2_outlined,
        open: () => _open(context, EmployeesScreen(api: api)),
      ));
    }
    if (user.hasPermission('store.update')) {
      actions.add(_ManagementAction(
        label: tr('بيانات المتجر'),
        description: tr('الهوية وبيانات التواصل'),
        icon: Icons.store_outlined,
        open: () => _open(
            context, StoreProfileScreen(api: api, onSaved: controller.refresh)),
      ));
    }
    if (user.hasPermission('whatsapp.read')) {
      actions.add(_ManagementAction(
        label: tr('اتصال واتساب'),
        description: tr('إدارة الربط الرسمي عبر Meta'),
        icon: Icons.chat_outlined,
        open: () => _open(context, WhatsAppSettingsScreen(api: api)),
      ));
    }
    if (user.hasPermission('reports.read')) {
      actions.add(_ManagementAction(
        label: tr('استخدام Meta'),
        description: tr('الرسائل والتكلفة والتنبيهات'),
        icon: Icons.data_usage_rounded,
        open: () => _open(context, MetaUsageScreen(api: api)),
      ));
    }
    if (user.hasPermission('ai.read')) {
      actions.add(_ManagementAction(
        label: tr('الذكاء الاصطناعي'),
        description: tr('المزود وقاعدة المعرفة'),
        icon: Icons.auto_awesome_outlined,
        open: () => _open(context, AiSettingsScreen(api: api)),
      ));
    }
    if (user.hasPermission('subscription.read')) {
      actions.add(_ManagementAction(
        label: tr('الاشتراك'),
        description: tr('الباقة والحدود والاستخدام'),
        icon: Icons.workspace_premium_outlined,
        open: () => _open(context, SubscriptionScreen(api: api)),
      ));
    }
    if (user.hasPermission('support_access.manage')) {
      actions.add(_ManagementAction(
        label: tr('خصوصية الدعم'),
        description: tr('التحكم في وصول مدير المنصة'),
        icon: Icons.shield_outlined,
        open: () => _open(context, SupportAccessScreen(api: api)),
      ));
    }
    actions.add(_ManagementAction(
      label: tr('الدعم الفني'),
      description: tr('حالة النظام وحل المشكلات'),
      icon: Icons.support_agent_rounded,
      open: () => _open(context, SupportScreen(api: api)),
    ));
    return actions;
  }

  void _open(BuildContext context, Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen));
}

class _ManagementAction {
  const _ManagementAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.open,
  });
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback open;
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({required this.action});
  final _ManagementAction action;

  @override
  Widget build(BuildContext context) => Material(
        color: context.hubScheme.surface,
        borderRadius: BorderRadius.circular(HubRadius.lg),
        child: InkWell(
          onTap: action.open,
          borderRadius: BorderRadius.circular(HubRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(HubSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HubRadius.lg),
              border: Border.all(
                  color:
                      context.hubScheme.outlineVariant.withValues(alpha: .36)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.hubScheme.primary,
                    borderRadius: BorderRadius.circular(HubRadius.md),
                  ),
                  child: Icon(action.icon,
                      color: context.hubScheme.onPrimary, size: 21),
                ),
                const Spacer(),
                Text(action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(action.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.hubScheme.onSurfaceVariant,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}
