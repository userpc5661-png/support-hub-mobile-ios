import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/settings/dock_settings_controller.dart';
import '../../core/theme/support_hub_design.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/support_hub_widgets.dart';
import '../account/account_screen.dart';
import '../auth/auth_controller.dart';
import '../auth/user_model.dart';
import '../conversations/conversation_realtime_client.dart';
import '../conversations/conversation_service.dart';
import '../conversations/conversations_screen.dart';
import '../customers/customers_screen.dart';
import '../management/management_hub_screen.dart';
import '../notifications/notifications_screen.dart';
import 'workspace_capabilities.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.controller,
    required this.api,
    required this.themeController,
    required this.pushNotifications,
  });

  final AuthController controller;
  final ApiClient api;
  final ThemeController themeController;
  final PushNotificationService pushNotifications;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int index = 0;
  int unreadCount = 0;
  late final WorkspaceCapabilities capabilities;
  late final List<_ShellDestination> destinations;
  ConversationRealtimeClient? realtime;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Timer? debounce;
  final dockSettingsController = DockSettingsController.instance;

  @override
  void initState() {
    super.initState();
    dockSettingsController.addListener(_onDockSettingsChanged);
    dockSettingsController.initialize();
    final user = widget.controller.user!;
    capabilities = WorkspaceCapabilities.forUser(user);
    destinations = _destinations(user);
    if (capabilities.notifications) {
      realtime = ConversationRealtimeClient(widget.api);
      subscription = realtime!.events.listen((event) {
        final type = event['type']?.toString();
        if (type == 'heartbeat' || type == 'connected') return;
        debounce?.cancel();
        debounce = Timer(
          const Duration(milliseconds: 350),
          _refreshUnread,
        );
      });
      realtime!.start();
      _refreshUnread();
    }
  }

  void _onDockSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    debounce?.cancel();
    subscription?.cancel();
    realtime?.dispose();
    dockSettingsController.removeListener(_onDockSettingsChanged);
    super.dispose();
  }

  List<_ShellDestination> _destinations(UserModel user) {
    final items = <_ShellDestination>[];
    if (kIsWeb && capabilities.platformAdmin) {
      items.add(_ShellDestination(
        label: 'المنصة',
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
        page:
            ManagementHubScreen(api: widget.api, controller: widget.controller),
      ));
    } else {
      if (capabilities.conversations) {
        items.add(_ShellDestination(
          label: 'الرئيسية',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          page: ConversationsScreen(
            api: widget.api,
            user: user,
            manualConversationsEnabled: false,
            aiEnabled: user.hasPermission('ai.draft'),
          ),
        ));
      }
      if (capabilities.customers) {
        items.add(_ShellDestination(
          label: 'العملاء',
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          page: CustomersScreen(api: widget.api, user: user),
        ));
      }
      if (capabilities.notifications) {
        items.add(_ShellDestination(
          label: 'التنبيهات',
          icon: Icons.notifications_none_rounded,
          selectedIcon: Icons.notifications_rounded,
          badge: true,
          page: NotificationsScreen(
            api: widget.api,
            user: user,
            onCountChanged: _setUnreadCount,
          ),
        ));
      }
      if (kIsWeb && capabilities.management) {
        items.add(_ShellDestination(
          label: 'الإدارة',
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard_rounded,
          page: ManagementHubScreen(
              api: widget.api, controller: widget.controller),
        ));
      }
    }
    items.add(_ShellDestination(
      label: 'الإعدادات',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      page: AccountScreen(
        controller: widget.controller,
        api: widget.api,
        themeController: widget.themeController,
        pushNotifications: widget.pushNotifications,
      ),
    ));
    return items;
  }

  void _setUnreadCount(int value) {
    if (mounted && unreadCount != value) {
      setState(() => unreadCount = value);
    }
  }

  Future<void> _refreshUnread() async {
    try {
      final conversations =
          await ConversationService(widget.api).list(unreadOnly: true);
      _setUnreadCount(
        conversations.fold<int>(0, (sum, item) => sum + item.unreadCount),
      );
    } catch (_) {
      // Realtime reconnects without blocking navigation. New-message details
      // stay in the inbox and Notifications tab; no foreground popup is shown.
    }
  }

  Widget _icon(_ShellDestination destination, {required bool selected}) {
    Widget icon = Icon(selected ? destination.selectedIcon : destination.icon);
    if (selected) {
      icon = Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.hubColors.navigationSelected,
          border: Border.all(
            color: context.hubScheme.primary.withValues(alpha: .45),
          ),
        ),
        child: icon,
      );
    }
    if (!destination.badge || unreadCount == 0) return icon;
    return Badge(
      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: index,
      children: destinations.map((destination) => destination.page).toList(),
    );
    if (MediaQuery.sizeOf(context).width >= 980) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (value) => setState(() => index = value),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -.35,
                leading: Padding(
                  padding: const EdgeInsets.only(top: HubSpace.md),
                  child: SupportHubMark(size: 38),
                ),
                destinations: destinations
                    .map((destination) => NavigationRailDestination(
                          icon: _icon(destination, selected: false),
                          selectedIcon: _icon(destination, selected: true),
                          label: Text(tr(destination.label)),
                        ))
                    .toList(),
              ),
            ),
            VerticalDivider(width: 1, color: context.hubScheme.outlineVariant),
            Expanded(child: body),
          ],
        ),
      );
    }

    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final dockRadius = BorderRadius.circular(36);
    final navigation = SizedBox(
      height: dockSettingsController.height,
      child: Row(
        children: List.generate(destinations.length, (itemIndex) {
          final destination = destinations[itemIndex];
          final selected = index == itemIndex;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => setState(() => index = itemIndex),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _icon(destination, selected: selected),
                  const SizedBox(height: 2),
                  Text(
                    tr(destination.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? context.hubScheme.primary
                          : context.hubScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );

    Widget dockSurface({required double opacity}) => Container(
          decoration: BoxDecoration(
            color: context.hubColors.navigation.withValues(alpha: opacity),
            borderRadius: dockRadius,
            border: Border.all(
              color: context.hubScheme.outlineVariant.withValues(alpha: .58),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? .30
                      : .10,
                ),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: navigation,
        );

    final navigationDock = SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: isIos
          ? ClipRRect(
              borderRadius: dockRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: dockSurface(opacity: dockSettingsController.opacity),
              ),
            )
          : dockSurface(opacity: dockSettingsController.opacity),
    );

    return Scaffold(
      backgroundColor: context.hubScheme.surfaceContainerLowest,
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          Positioned(
            left: 0,
            right: 0,
            bottom: dockSettingsController.bottomOffset,
            child: navigationDock,
          ),
        ],
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.badge = false,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool badge;
}
