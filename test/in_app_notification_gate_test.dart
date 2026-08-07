import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/core/notifications/in_app_notification_gate.dart';

void main() {
  test('deduplicates the same conversation while allowing another one', () {
    expect(InAppNotificationGate.shouldShow('conversation-a-unique'), isTrue);
    expect(InAppNotificationGate.shouldShow('conversation-a-unique'), isFalse);
    expect(InAppNotificationGate.shouldShow('conversation-b-unique'), isTrue);
  });
}
