import '../auth/user_model.dart';

class WorkspaceCapabilities {
  const WorkspaceCapabilities._({
    required this.platformAdmin,
    required this.storeContext,
    required this.conversations,
    required this.customers,
    required this.notifications,
    required this.management,
  });

  final bool platformAdmin;
  final bool storeContext;
  final bool conversations;
  final bool customers;
  final bool notifications;
  final bool management;

  factory WorkspaceCapabilities.forUser(UserModel user) {
    final platformAdmin =
        user.role == 'super_admin' && user.supportSessionId == null;
    final storeContext = user.storeId != null || user.supportSessionId != null;
    final conversations =
        storeContext && user.hasPermission('conversations.read');
    final customers = storeContext && user.hasPermission('customers.read');
    final management =
        platformAdmin || user.permissions.any(_managementPermissions.contains);
    return WorkspaceCapabilities._(
      platformAdmin: platformAdmin,
      storeContext: storeContext,
      conversations: conversations,
      customers: customers,
      notifications: conversations,
      management: management,
    );
  }

  static const _managementPermissions = <String>{
    'platform.stores.read',
    'platform.subscriptions.read',
    'platform.audit.read',
    'platform.support_access',
    'store.update',
    'employees.read',
    'whatsapp.read',
    'ai.read',
    'subscription.read',
    'reports.read',
    'support_access.manage',
  };
}
