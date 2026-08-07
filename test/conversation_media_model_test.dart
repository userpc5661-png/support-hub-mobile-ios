import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/features/conversations/conversation_model.dart';

void main() {
  test('message model keeps media type and authenticated media path', () {
    final message = MessageModel.fromJson({
      'id': 'message-1',
      'senderType': 'customer',
      'direction': 'inbound',
      'type': 'audio',
      'status': 'received',
      'mediaUrl': '/conversations/c-1/messages/message-1/media',
      'createdAt': '2026-08-03T10:00:00Z',
    });

    expect(message.type, 'audio');
    expect(message.inbound, isTrue);
    expect(
      message.mediaUrl,
      '/conversations/c-1/messages/message-1/media',
    );
  });

  test('pending message can become failed without losing its content', () {
    final pending = MessageModel(
      id: 'local-1',
      senderType: 'employee',
      direction: 'outbound',
      type: 'text',
      status: 'queued',
      body: 'hello',
      createdAt: DateTime.utc(2026, 8, 3),
    );

    final failed = pending.copyWith(status: 'failed', error: 'offline');
    expect(failed.status, 'failed');
    expect(failed.body, 'hello');
    expect(failed.error, 'offline');
  });
}
