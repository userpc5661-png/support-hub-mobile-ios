import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/features/auth/user_model.dart';
import 'package:support_hub/features/shell/workspace_capabilities.dart';

UserModel user({
  required String role,
  String? storeId,
  String? supportSessionId,
  List<String> permissions = const [],
}) =>
    UserModel(
      id: role,
      name: role,
      username: role,
      role: role,
      permissions: permissions,
      mustChangePassword: false,
      storeId: storeId,
      supportSessionId: supportSessionId,
    );

void main() {
  test('platform admin receives no store-only mobile capabilities', () {
    final capabilities = WorkspaceCapabilities.forUser(user(
      role: 'super_admin',
      permissions: const ['platform.stores.read'],
    ));
    expect(capabilities.platformAdmin, isTrue);
    expect(capabilities.management, isTrue);
    expect(capabilities.conversations, isFalse);
    expect(capabilities.customers, isFalse);
    expect(user(role: 'super_admin').canUseSupportMobile, isFalse);
  });

  test('store manager is kept on the web dashboard', () {
    final capabilities = WorkspaceCapabilities.forUser(user(
      role: 'store_admin',
      storeId: 'store-1',
      permissions: const [
        'conversations.read',
        'customers.read',
        'employees.read',
        'subscription.read',
      ],
    ));
    expect(capabilities.platformAdmin, isFalse);
    expect(capabilities.conversations, isTrue);
    expect(capabilities.customers, isTrue);
    expect(capabilities.management, isTrue);
    expect(
        user(
          role: 'store_admin',
          storeId: 'store-1',
          permissions: const [
            'conversations.read',
            'conversations.reply',
            'customers.read'
          ],
        ).canUseSupportMobile,
        isFalse);
  });

  test('employee only receives explicitly assigned capabilities', () {
    final capabilities = WorkspaceCapabilities.forUser(user(
      role: 'employee',
      storeId: 'store-1',
      permissions: const ['conversations.read'],
    ));
    expect(capabilities.conversations, isTrue);
    expect(capabilities.notifications, isTrue);
    expect(capabilities.customers, isFalse);
    expect(
        user(
          role: 'employee',
          storeId: 'store-1',
          permissions: const [
            'conversations.read',
            'conversations.reply',
            'customers.read'
          ],
        ).canUseSupportMobile,
        isTrue);
  });

  test('employee without reply permission cannot use support mobile', () {
    expect(
        user(
          role: 'employee',
          storeId: 'store-1',
          permissions: const ['conversations.read'],
        ).canUseSupportMobile,
        isFalse);
  });

  test('support supervisor can use support mobile', () {
    expect(
        user(
          role: 'supervisor',
          storeId: 'store-1',
          permissions: const [
            'conversations.read',
            'conversations.reply',
            'customers.read'
          ],
        ).canUseSupportMobile,
        isTrue);
  });

  test('platform support session switches into store context', () {
    final capabilities = WorkspaceCapabilities.forUser(user(
      role: 'super_admin',
      storeId: 'store-1',
      supportSessionId: 'session-1',
      permissions: const ['conversations.read', 'customers.read'],
    ));
    expect(capabilities.platformAdmin, isFalse);
    expect(capabilities.storeContext, isTrue);
    expect(capabilities.conversations, isTrue);
  });
}
