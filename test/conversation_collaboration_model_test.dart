import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/features/conversations/conversation_collaboration_model.dart';

void main() {
  test('parses read-only state owned by another employee', () {
    final model = ConversationCollaborationModel.fromJson({
      'canReply': false,
      'presences': [
        {'userId': 'user-2', 'userName': 'محمد', 'sessionId': 'device-2'},
      ],
      'lock': {'userId': 'user-2', 'userName': 'محمد', 'ownedByMe': false},
    });

    expect(model.canReply, false);
    expect(model.lock?.userName, 'محمد');
    expect(model.presences.single.sessionId, 'device-2');
  });
}
