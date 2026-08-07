import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/features/auth/user_model.dart';
import 'package:support_hub/features/conversations/conversation_model.dart';
import 'package:support_hub/features/customers/customer_model.dart';
import 'package:support_hub/features/employees/employee_model.dart';
import 'package:support_hub/features/stores/store_model.dart';

void main() {
  test('username roles and permissions are parsed', () {
    final user = UserModel.fromJson({
      'id': '1',
      'name': 'Admin',
      'username': 'admin',
      'email': null,
      'role': 'super_admin',
      'permissions': ['platform.stores.read'],
      'mustChangePassword': true,
      'supportSessionId': null,
    });
    expect(user.username, 'admin');
    expect(user.roleLabel, 'مدير المنصة');
    expect(user.mustChangePassword, isTrue);
    expect(user.hasPermission('platform.stores.read'), isTrue);
  });

  test('employee and store models parse API responses', () {
    final employee = EmployeeModel.fromJson({
      'id': 'e1',
      'name': 'Agent',
      'username': 'agent1',
      'email': null,
      'role': 'supervisor',
      'status': 'active',
      'permissions': ['conversations.read'],
    });
    final store = StoreModel.fromJson({
      'id': 's1',
      'name': 'Store',
      'slug': 'store',
      'isActive': true,
      'employeeCount': 1,
      'owner': null,
    });
    expect(employee.username, 'agent1');
    expect(employee.role, 'supervisor');
    expect(employee.isActive, isTrue);
    expect(store.employeeCount, 1);
  });

  test('customer and conversation inbox models parse messages', () {
    final customer = CustomerModel.fromJson({
      'id': 'c1',
      'name': 'Customer',
      'phone': '966500000001',
      'tags': ['VIP'],
    });
    final conversation = ConversationModel.fromJson({
      'id': 'cv1',
      'channel': 'whatsapp',
      'status': 'open',
      'priority': 'high',
      'customer': {
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
        'tags': customer.tags,
      },
      'unreadCount': 1,
      'tags': ['order'],
      'messages': [
        {
          'id': 'm1',
          'senderType': 'customer',
          'direction': 'inbound',
          'type': 'text',
          'status': 'received',
          'body': 'Hello',
          'createdAt': '2026-07-27T00:00:00.000Z',
        }
      ],
    });
    expect(conversation.customer.name, 'Customer');
    expect(conversation.messages.single.inbound, isTrue);
    expect(conversation.unreadCount, 1);
  });
}
