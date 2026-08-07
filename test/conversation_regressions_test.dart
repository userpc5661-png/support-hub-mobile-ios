import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/core/network/api_client.dart';
import 'package:support_hub/core/storage/token_storage.dart';
import 'package:support_hub/features/conversations/conversation_service.dart';
import 'package:support_hub/features/conversations/message_media.dart';

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(TokenStorage());

  int mediaRequests = 0;
  String? patchedPath;
  Map<String, dynamic>? patchedBody;
  final mediaCompleter = Completer<AuthenticatedMediaRequest>();

  @override
  Future<AuthenticatedMediaRequest> mediaRequest(String value) {
    mediaRequests += 1;
    return mediaCompleter.future;
  }

  @override
  Future<Map<String, dynamic>> patchMap(
    String path,
    Map<String, dynamic> body,
  ) async {
    patchedPath = path;
    patchedBody = body;
    return <String, dynamic>{};
  }
}

void main() {
  test('unassign sends an explicit null assignee to the API', () async {
    final api = _RecordingApiClient();

    await ConversationService(api).assign('conversation-1', null);

    expect(api.patchedPath, '/conversations/conversation-1/assign');
    expect(api.patchedBody, containsPair('assignedToId', null));
  });

  testWidgets('conversation image reuses its media request across rebuilds',
      (tester) async {
    final api = _RecordingApiClient();
    Widget image() => MaterialApp(
          home: ConversationImage(
            api: api,
            mediaUrl: '/conversations/c-1/messages/m-1/media',
          ),
        );

    await tester.pumpWidget(image());
    expect(api.mediaRequests, 1);

    await tester.pumpWidget(image());
    expect(api.mediaRequests, 1);
  });
}
