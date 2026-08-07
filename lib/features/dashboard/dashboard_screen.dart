import '../../core/localization/app_locale_controller.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/browser_notification_service.dart';
import '../../core/theme/theme_controller.dart';
import '../account/account_screen.dart';
import '../ai/ai_settings_screen.dart';
import '../audit/audit_logs_screen.dart';
import '../auth/auth_controller.dart';
import '../conversations/conversations_screen.dart';
import '../conversations/conversation_service.dart';
import '../conversations/conversation_realtime_client.dart';
import '../customers/customers_screen.dart';
import '../employees/employees_screen.dart';
import '../overview/overview_screen.dart';
import '../meta_usage/meta_usage_screen.dart';
import '../settings/settings_screen.dart';
import '../stores/store_profile_screen.dart';
import '../stores/stores_admin_screen.dart';
import '../subscriptions/subscription_screen.dart';
import '../support_access/support_access_screen.dart';
import '../support/support_screen.dart';
import '../whatsapp/whatsapp_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.api,
    required this.themeController,
  });
  final AuthController controller;
  final ApiClient api;
  final ThemeController themeController;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? entitlements;
  String? entitlementError;
  bool loadingEntitlements = false;
  Timer? inboxTimer;
  Timer? realtimeDebounce;
  int unreadMessages = 0;
  int unreadConversations = 0;
  bool inboxBaselineReady = false;
  bool inboxRefreshing = false;
  final notifications = BrowserNotificationService();
  ConversationRealtimeClient? realtime;
  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadEntitlements();
    _refreshInbox();
    final user = widget.controller.user;
    if (user?.storeId != null && user!.hasPermission('conversations.read')) {
      realtime = ConversationRealtimeClient(widget.api);
      realtimeSubscription = realtime!.events.listen((event) {
        if (event['type'] != 'heartbeat' && event['type'] != 'connected') {
          realtimeDebounce?.cancel();
          realtimeDebounce =
              Timer(const Duration(milliseconds: 350), _refreshInbox);
        }
      });
      realtime!.start();
    }
    inboxTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _refreshInbox());
  }

  @override
  void dispose() {
    inboxTimer?.cancel();
    realtimeDebounce?.cancel();
    realtimeSubscription?.cancel();
    realtime?.dispose();
    super.dispose();
  }

  Future<void> _refreshInbox() async {
    if (inboxRefreshing) return;
    final user = widget.controller.user;
    if (user == null ||
        user.storeId == null ||
        !user.hasPermission('conversations.read')) {
      return;
    }
    inboxRefreshing = true;
    try {
      final items =
          await ConversationService(widget.api).list(unreadOnly: true);
      final nextMessages =
          items.fold<int>(0, (sum, item) => sum + item.unreadCount);
      if (inboxBaselineReady &&
          nextMessages > unreadMessages &&
          items.isNotEmpty) {
        final latest = items.first;
        notifications.show(
          title: tr('رسالة جديدة من ${latest.customer.name}'),
          body: latest.lastMessagePreview ??
              tr('لديك رسالة جديدة في Wasl'),
          tag: 'support-hub-inbox',
        );
      }
      if (mounted) {
        setState(() {
          unreadMessages = nextMessages;
          unreadConversations = items.length;
          inboxBaselineReady = true;
        });
      }
    } catch (_) {
      // Inbox polling is a convenience and must not block the dashboard.
    } finally {
      inboxRefreshing = false;
    }
  }

  Future<void> _loadEntitlements() async {
    final user = widget.controller.user;
    if (user == null ||
        (user.role == 'super_admin' && user.supportSessionId == null)) {
      return;
    }
    if (mounted) {
      setState(() {
        loadingEntitlements = true;
        entitlementError = null;
      });
    }
    try {
      final value = await widget.api.getMap('/subscriptions/entitlements');
      if (mounted) setState(() => entitlements = value);
    } catch (e) {
      if (mounted) setState(() => entitlementError = e.toString());
    } finally {
      if (mounted) setState(() => loadingEntitlements = false);
    }
  }

  bool _enabled(String key) => entitlements?[key] == true;

  Future<void> _refreshAll() async {
    await widget.controller.refresh();
    await _loadEntitlements();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final items = _itemsFor(context);
    final scheme = Theme.of(context).colorScheme;
    if (kIsWeb) {
      return _buildModernDashboard(context, user, items, scheme);
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary,
              child:
                  Icon(Icons.support_agent, size: 20, color: scheme.onPrimary)),
          const SizedBox(width: 10),
          const Text('Wasl 2.5.3'),
        ]),
        actions: [
          if (realtime != null)
            AnimatedBuilder(
              animation: realtime!,
              builder: (_, __) => Tooltip(
                message: realtime!.state == RealtimeConnectionState.connected
                    ? tr('التحديث المباشر متصل')
                    : tr('جارٍ إعادة الاتصال بالتحديث المباشر'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    realtime!.state == RealtimeConnectionState.connected
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
                    color: realtime!.state == RealtimeConnectionState.connected
                        ? Colors.green
                        : scheme.tertiary,
                  ),
                ),
              ),
            ),
          const LanguageSwitcherButton(showLabel: true),
          IconButton(
              onPressed: _refreshAll,
              tooltip: tr('تحديث'),
              icon: const Icon(Icons.refresh)),
          PopupMenuButton<ThemeMode>(
            tooltip: tr('المظهر'),
            icon: const Icon(Icons.contrast),
            onSelected: widget.themeController.setMode,
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: ThemeMode.system, child: Text(tr('حسب النظام'))),
              PopupMenuItem(value: ThemeMode.light, child: Text(tr('فاتح'))),
              PopupMenuItem(value: ThemeMode.dark, child: Text(tr('داكن'))),
            ],
          ),
          IconButton(
              onPressed: widget.controller.logout,
              tooltip: tr('تسجيل الخروج'),
              icon: const Icon(Icons.logout)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth > 900 ? 36 : 18, vertical: 20),
            children: [
              if (user.supportSessionId != null) ...[
                Card(
                  color: scheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: Text(
                        tr('جلسة دعم نشطة داخل ${user.storeName ?? 'المتجر'}')),
                    subtitle: Text(tr(
                        'كل قراءة للدردشات مسجلة. اخرج عند انتهاء الصيانة.')),
                    trailing: FilledButton.tonalIcon(
                        onPressed: widget.controller.exitSupportSession,
                        icon: const Icon(Icons.exit_to_app),
                        label: Text(tr('إنهاء الجلسة'))),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (unreadMessages > 0) ...[
                Card(
                  color: scheme.primaryContainer,
                  child: ListTile(
                    leading: Badge(
                      label: Text('$unreadMessages'),
                      child: const Icon(Icons.mark_email_unread_outlined),
                    ),
                    title: Text(tr('لديك $unreadMessages رسالة غير مقروءة')),
                    subtitle: Text(
                        tr('في $unreadConversations دردشة تحتاج انتباهك.')),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        if (notifications.isSupported &&
                            !notifications.isGranted)
                          IconButton(
                            onPressed: _enableNotifications,
                            tooltip: tr('تفعيل إشعارات المتصفح'),
                            icon:
                                const Icon(Icons.notifications_active_outlined),
                          ),
                        FilledButton(
                          onPressed: () => _openInbox(context, user),
                          child: Text(tr('فتح الدردشات')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _WelcomeCard(
                  user: user,
                  onAccount: () => _open(
                      context,
                      AccountScreen(
                          controller: widget.controller, api: widget.api))),
              if (user.role != 'super_admin' ||
                  user.supportSessionId != null) ...[
                const SizedBox(height: 14),
                if (loadingEntitlements) const LinearProgressIndicator(),
                if (entitlementError != null)
                  Card(
                    color: scheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber),
                      title: Text(tr('تعذر تحميل مزايا الاشتراك')),
                      subtitle: Text(entitlementError!),
                      trailing: IconButton(
                          onPressed: _loadEntitlements,
                          icon: const Icon(Icons.refresh)),
                    ),
                  ),
                if (entitlements != null)
                  _SubscriptionBanner(data: entitlements!),
              ],
              const SizedBox(height: 24),
              Text(
                  user.role == 'super_admin' && user.supportSessionId == null
                      ? tr('إدارة المنصة')
                      : tr('مساحة العمل'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 330,
                  childAspectRatio: 1.45,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _SectionCard(item: items[index]),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Icon(Icons.verified_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(tr(
                            'Wasl — دردشات أسرع، تنبيهات للرسائل، وعزل آمن للمتاجر.'))),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDashboard(
    BuildContext context,
    dynamic user,
    List<_DashboardItem> items,
    ColorScheme scheme,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1050;
    final platformAdmin =
        user.role == 'super_admin' && user.supportSessionId == null;
    final pageTitle =
        platformAdmin ? tr('مركز إدارة المنصة') : tr('مركز العمل');
    final pageSubtitle = platformAdmin
        ? tr('إدارة المتاجر والاشتراكات وحالة النظام من مكان واحد')
        : tr('تابع العملاء والرسائل وأعمال فريقك لحظة بلحظة');

    final content = RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding:
            EdgeInsets.fromLTRB(desktop ? 34 : 18, 22, desktop ? 34 : 18, 36),
        children: [
          _ModernTopBar(
            title: pageTitle,
            subtitle: pageSubtitle,
            realtime: realtime,
            unreadMessages: unreadMessages,
            onRefresh: _refreshAll,
            onTheme: widget.themeController.setMode,
            onLogout: widget.controller.logout,
          ),
          const SizedBox(height: 24),
          _DashboardHero(
            user: user,
            unreadMessages: unreadMessages,
            unreadConversations: unreadConversations,
            isPlatformAdmin: platformAdmin,
            onPrimaryAction: platformAdmin
                ? () => _open(
                    context,
                    StoresAdminScreen(
                        api: widget.api, controller: widget.controller))
                : () => _openInbox(context, user),
            onAccount: () => _open(context,
                AccountScreen(controller: widget.controller, api: widget.api)),
          ),
          if (user.supportSessionId != null) ...[
            const SizedBox(height: 16),
            _ModernNotice(
              icon: Icons.admin_panel_settings_outlined,
              title: tr('جلسة دعم نشطة داخل ${user.storeName ?? 'المتجر'}'),
              body: tr('الوصول مسجل ومحمي. أنهِ الجلسة عند اكتمال الصيانة.'),
              actionLabel: tr('إنهاء الجلسة'),
              onAction: widget.controller.exitSupportSession,
            ),
          ],
          if (!platformAdmin) ...[
            const SizedBox(height: 18),
            _RealtimeStrip(
              realtime: realtime,
              notifications: notifications,
              unreadMessages: unreadMessages,
              unreadConversations: unreadConversations,
              onInbox: () => _openInbox(context, user),
              onEnableNotifications: _enableNotifications,
            ),
          ],
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platformAdmin
                          ? tr('أدوات إدارة المنصة')
                          : tr('مساحة العمل'),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('اختر القسم الذي تريد متابعته'),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text('${items.length} ${tr('أقسام')}',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: desktop ? 390 : 420,
              mainAxisExtent: 142,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) => _ModernSectionCard(
              item: items[index],
              index: index,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  _ModernSidebar(
                    user: user,
                    items: items,
                    onAccount: () => _open(
                      context,
                      AccountScreen(
                          controller: widget.controller, api: widget.api),
                    ),
                    onLogout: widget.controller.logout,
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
    );
  }

  List<_DashboardItem> _itemsFor(BuildContext context) {
    final user = widget.controller.user!;
    void open(Widget screen) => _open(context, screen);
    if (user.role == 'super_admin' && user.supportSessionId == null) {
      return [
        _DashboardItem(
            tr('نظرة عامة'),
            tr('الأرقام وحالة المنصة'),
            AppIcons.overview,
            () => open(OverviewScreen(api: widget.api, user: user))),
        _DashboardItem(
            tr('المتاجر'),
            tr('إنشاء وإدارة المتاجر وأصحابها'),
            AppIcons.platformStores,
            () => open(StoresAdminScreen(
                api: widget.api, controller: widget.controller))),
        _DashboardItem(
            tr('الاشتراكات'),
            tr('الباقات والحدود والمزايا'),
            AppIcons.subscriptions,
            () => open(SubscriptionsAdminScreen(api: widget.api))),
        _DashboardItem(tr('سجل التدقيق'), tr('عمليات الإدارة وجلسات الدعم'),
            AppIcons.audit, () => open(AuditLogsScreen(api: widget.api))),
        _DashboardItem(tr('الدعم الفني'), tr('حالة النظام وحل المشكلات'),
            AppIcons.support, () => open(SupportScreen(api: widget.api))),
        _DashboardItem(
            tr('الإعدادات'),
            tr('اللغة والمظهر والإشعارات'),
            AppIcons.settings,
            () =>
                open(SettingsScreen(themeController: widget.themeController))),
        _DashboardItem(
            tr('حسابي'),
            tr('اسم المستخدم وكلمة المرور'),
            AppIcons.account,
            () => open(
                AccountScreen(controller: widget.controller, api: widget.api))),
      ];
    }

    final items = <_DashboardItem>[];
    if (_enabled('analyticsEnabled') && user.hasPermission('reports.read')) {
      items.add(_DashboardItem(
          tr('نظرة عامة'),
          tr('الأرقام وحالة العمل'),
          AppIcons.overview,
          () => open(OverviewScreen(api: widget.api, user: user))));
    }
    if (user.hasPermission('conversations.read')) {
      items.add(_DashboardItem(
          tr('الدردشات'),
          tr('الرد والتوزيع والمتابعة'),
          AppIcons.conversations,
          () => open(ConversationsScreen(
                api: widget.api,
                user: user,
                manualConversationsEnabled:
                    _enabled('manualConversationsEnabled'),
                aiEnabled: _enabled('aiEnabled'),
                realtime: realtime,
              )),
          badge: unreadMessages));
    }
    if (user.hasPermission('customers.read')) {
      items.add(_DashboardItem(
          tr('العملاء'),
          tr('البيانات والوسوم والملاحظات'),
          AppIcons.customers,
          () => open(CustomersScreen(api: widget.api, user: user))));
    }
    if (user.role == 'store_owner' ||
        user.role == 'store_admin' ||
        user.supportSessionId != null) {
      if (user.hasPermission('employees.read')) {
        items.add(_DashboardItem(
            tr('الفريق والصلاحيات'),
            tr('مديرون ومشرفون وموظفون'),
            AppIcons.team,
            () => open(EmployeesScreen(api: widget.api))));
      }
      if (user.hasPermission('store.update')) {
        items.add(_DashboardItem(
            tr('بيانات المتجر'),
            tr('الهوية وبيانات التواصل'),
            AppIcons.store,
            () => open(StoreProfileScreen(
                api: widget.api, onSaved: widget.controller.refresh))));
      }
      if (_enabled('whatsappEnabled') && user.hasPermission('whatsapp.read')) {
        items.add(_DashboardItem(
            tr('اتصال واتساب'),
            tr('ربط رسمي وآمن عبر Meta'),
            AppIcons.whatsApp,
            () => open(WhatsAppSettingsScreen(api: widget.api))));
      }
      if (user.hasPermission('reports.read')) {
        items.add(_DashboardItem(
            tr('استخدام Meta'),
            tr('الرسائل والتكلفة التقديرية والتنبيهات'),
            AppIcons.metaUsage,
            () => open(MetaUsageScreen(api: widget.api))));
      }
      if ((_enabled('aiEnabled') || _enabled('knowledgeBaseEnabled')) &&
          user.hasPermission('ai.read')) {
        items.add(_DashboardItem(
            tr('الذكاء الاصطناعي'),
            tr('المزود وقاعدة المعرفة'),
            AppIcons.ai,
            () => open(AiSettingsScreen(api: widget.api))));
      }
      if (user.hasPermission('subscription.read')) {
        items.add(_DashboardItem(
            tr('الاشتراك'),
            tr('الحدود والاستخدام'),
            AppIcons.subscriptions,
            () => open(SubscriptionScreen(api: widget.api))));
      }
      if (user.role == 'store_owner' &&
          user.hasPermission('support_access.manage')) {
        items.add(_DashboardItem(
            tr('خصوصية الدعم'),
            tr('تحكم مؤقت في وصول مدير المنصة'),
            AppIcons.privacy,
            () => open(SupportAccessScreen(api: widget.api))));
      }
    }
    items.add(_DashboardItem(tr('الدعم الفني'), tr('حالة النظام وحل المشكلات'),
        AppIcons.support, () => open(SupportScreen(api: widget.api))));
    items.add(_DashboardItem(
        tr('الإعدادات'),
        tr('اللغة والمظهر والإشعارات'),
        AppIcons.settings,
        () => open(SettingsScreen(themeController: widget.themeController))));
    items.add(_DashboardItem(
        tr('حسابي'),
        tr('بيانات الدخول والصلاحيات'),
        AppIcons.account,
        () => open(
            AccountScreen(controller: widget.controller, api: widget.api))));
    return items;
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openInbox(BuildContext context, dynamic user) {
    _open(
        context,
        ConversationsScreen(
          api: widget.api,
          user: user,
          manualConversationsEnabled: _enabled('manualConversationsEnabled'),
          aiEnabled: _enabled('aiEnabled'),
          realtime: realtime,
        ));
  }

  Future<void> _enableNotifications() async {
    final granted = await notifications.requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(granted
          ? tr('تم تفعيل إشعارات المتصفح.')
          : tr('لم يتم السماح بالإشعارات. فعّلها من إعدادات الموقع.')),
    ));
    setState(() {});
  }
}

class _ModernTopBar extends StatelessWidget {
  const _ModernTopBar({
    required this.title,
    required this.subtitle,
    required this.realtime,
    required this.unreadMessages,
    required this.onRefresh,
    required this.onTheme,
    required this.onLogout,
  });

  final String title;
  final String subtitle;
  final ConversationRealtimeClient? realtime;
  final int unreadMessages;
  final Future<void> Function() onRefresh;
  final ValueChanged<ThemeMode> onTheme;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (realtime != null)
          AnimatedBuilder(
            animation: realtime!,
            builder: (_, __) {
              final connected =
                  realtime!.state == RealtimeConnectionState.connected;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFFE7F8EE)
                      : scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(connected ? Icons.wifi_tethering : Icons.sync,
                        size: 18,
                        color: connected ? const Color(0xFF138A50) : null),
                    const SizedBox(width: 7),
                    Text(connected ? tr('متصل مباشر') : tr('جاري الاتصال'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            },
          ),
        if (unreadMessages > 0) ...[
          const SizedBox(width: 8),
          Badge(
              label: Text('$unreadMessages'),
              child: const Icon(Icons.notifications_none_rounded)),
        ],
        const SizedBox(width: 8),
        const LanguageSwitcherButton(showLabel: false),
        IconButton(
            onPressed: onRefresh,
            tooltip: tr('تحديث'),
            icon: const Icon(Icons.refresh_rounded)),
        PopupMenuButton<ThemeMode>(
          tooltip: tr('المظهر'),
          icon: const Icon(Icons.palette_outlined),
          onSelected: onTheme,
          itemBuilder: (_) => [
            PopupMenuItem(
                value: ThemeMode.system, child: Text(tr('حسب النظام'))),
            PopupMenuItem(value: ThemeMode.light, child: Text(tr('فاتح'))),
            PopupMenuItem(value: ThemeMode.dark, child: Text(tr('داكن'))),
          ],
        ),
        IconButton(
            onPressed: onLogout,
            tooltip: tr('تسجيل الخروج'),
            icon: const Icon(Icons.logout_rounded)),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.user,
    required this.unreadMessages,
    required this.unreadConversations,
    required this.isPlatformAdmin,
    required this.onPrimaryAction,
    required this.onAccount,
  });

  final dynamic user;
  final int unreadMessages;
  final int unreadConversations;
  final bool isPlatformAdmin;
  final VoidCallback onPrimaryAction;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF172554), Color(0xFF2447A7), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF172554).withValues(alpha: .22),
              blurRadius: 28,
              offset: const Offset(0, 14)),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 720;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  isPlatformAdmin
                      ? tr('إدارة موحّدة وآمنة')
                      : tr('لوحة خدمة العملاء'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('أهلًا ${user.name}'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                isPlatformAdmin
                    ? tr('كل ما تحتاجه لإدارة Wasl في لوحة واحدة واضحة.')
                    : tr(
                        'ابدأ يومك من هنا، وتابع الرسائل التي تحتاج إلى انتباهك.'),
                style: const TextStyle(
                    color: Color(0xFFDCE7FF), fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF17306F)),
                    onPressed: onPrimaryAction,
                    icon: Icon(isPlatformAdmin
                        ? Icons.storefront_rounded
                        : Icons.forum_rounded),
                    label: Text(isPlatformAdmin
                        ? tr('إدارة المتاجر')
                        : tr('فتح الدردشات')),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: .45))),
                    onPressed: onAccount,
                    icon: const Icon(Icons.person_outline_rounded),
                    label: Text(tr('حسابي')),
                  ),
                ],
              ),
            ],
          );

          final metrics = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeroMetric(
                  value: isPlatformAdmin ? '2.1' : '$unreadMessages',
                  label: isPlatformAdmin
                      ? tr('الإصدار الحالي')
                      : tr('رسائل جديدة')),
              Container(
                  width: 1,
                  height: 52,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 20)),
              _HeroMetric(
                  value: isPlatformAdmin ? tr('نشط') : '$unreadConversations',
                  label: isPlatformAdmin
                      ? tr('حالة النظام')
                      : tr('دردشات تنتظر')),
            ],
          );

          if (compact) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 28), metrics]);
          }
          return Row(children: [Expanded(child: intro), metrics]);
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Color(0xFFC9D7F5))),
        ],
      );
}

class _ModernSidebar extends StatelessWidget {
  const _ModernSidebar({
    required this.user,
    required this.items,
    required this.onAccount,
    required this.onLogout,
  });
  final dynamic user;
  final List<_DashboardItem> items;
  final VoidCallback onAccount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 266,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF2E5BFF), Color(0xFF11A68B)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 11),
              const Expanded(
                  child: Text('Wasl',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  leading: Icon(item.icon, size: 21),
                  title: Text(item.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: item.badge > 0
                      ? Badge(label: Text('${item.badge}'))
                      : Icon(AppIcons.forward(context), size: 18),
                  onTap: item.onTap,
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: CircleAvatar(
                child:
                    Text(user.name.isEmpty ? '?' : user.name.substring(0, 1))),
            title:
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(user.roleLabel, maxLines: 1),
            onTap: onAccount,
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(tr('تسجيل الخروج'))),
          ),
        ],
      ),
    );
  }
}

class _RealtimeStrip extends StatelessWidget {
  const _RealtimeStrip({
    required this.realtime,
    required this.notifications,
    required this.unreadMessages,
    required this.unreadConversations,
    required this.onInbox,
    required this.onEnableNotifications,
  });
  final ConversationRealtimeClient? realtime;
  final BrowserNotificationService notifications;
  final int unreadMessages;
  final int unreadConversations;
  final VoidCallback onInbox;
  final VoidCallback onEnableNotifications;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: realtime ?? Listenable.merge([]),
      builder: (_, __) {
        final connected = realtime?.state == RealtimeConnectionState.connected;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: connected
                    ? const Color(0xFF46B881)
                    : scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFFE7F8EE)
                      : scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(connected ? Icons.bolt_rounded : Icons.sync_rounded,
                    color: connected ? const Color(0xFF138A50) : null),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        connected
                            ? tr('التحديث المباشر متصل')
                            : tr('جاري استعادة الاتصال المباشر'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      unreadMessages > 0
                          ? tr(
                              '$unreadMessages رسالة في $unreadConversations دردشة تحتاج انتباهك')
                          : tr('لا توجد رسائل جديدة الآن'),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (notifications.isSupported && !notifications.isGranted)
                IconButton(
                    onPressed: onEnableNotifications,
                    tooltip: tr('تفعيل الإشعارات'),
                    icon: const Icon(Icons.notifications_active_outlined)),
              FilledButton.tonalIcon(
                  onPressed: onInbox,
                  icon: Icon(AppIcons.forward(context)),
                  label: Text(tr('الصندوق'))),
            ],
          ),
        );
      },
    );
  }
}

class _ModernNotice extends StatelessWidget {
  const _ModernNotice(
      {required this.icon,
      required this.title,
      required this.body,
      required this.actionLabel,
      required this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(body),
          trailing:
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ),
      );
}

class _ModernSectionCard extends StatelessWidget {
  const _ModernSectionCard({required this.item, required this.index});
  final _DashboardItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const accents = [
      Color(0xFF2E5BFF),
      Color(0xFF0F9D83),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEF5B72)
    ];
    final accent = accents[index % accents.length];
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .6)),
              borderRadius: BorderRadius.circular(22)),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(17)),
                child: Icon(item.icon, color: accent, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(item.label,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800))),
                      if (item.badge > 0) Badge(label: Text('${item.badge}')),
                    ]),
                    const SizedBox(height: 6),
                    Text(item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.forward(context), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user, required this.onAccount});
  final dynamic user;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [
            scheme.primaryContainer.withValues(alpha: .8),
            scheme.surfaceContainerLow
          ]),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 14,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                  radius: 30,
                  backgroundColor: scheme.primary,
                  child: Text(
                      user.name.isEmpty ? '?' : user.name.substring(0, 1),
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('مرحبًا، ${user.name}'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                    '@${user.username} • ${user.roleLabel}${user.storeName == null ? '' : ' • ${user.storeName}'}',
                    textDirection: TextDirection.ltr),
              ]),
            ]),
            FilledButton.tonalIcon(
                onPressed: onAccount,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: Text(tr('إدارة الحساب'))),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.item});
  final _DashboardItem item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                    backgroundColor: scheme.primary,
                    child: Icon(item.icon, color: scheme.onPrimary)),
                const SizedBox(height: 12),
                Text(item.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item.description,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (item.badge > 0) ...[
                  const SizedBox(height: 8),
                  Badge(label: Text(tr('${item.badge} غير مقروءة'))),
                ],
              ]),
        ),
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem(this.label, this.description, this.icon, this.onTap,
      {this.badge = 0});
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final plan = data['plan']?.toString() ?? '-';
    final status = data['status']?.toString() ?? '-';
    final used = data['messagesUsed'] ?? data['usage']?['messagesUsed'] ?? 0;
    final limit = data['messageLimit'] ?? data['limits']?['messageLimit'] ?? 0;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(tr('الاشتراك: $plan')),
        subtitle: Text(tr('الحالة: $status • الرسائل: $used / $limit')),
      ),
    );
  }
}
