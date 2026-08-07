import 'dart:async';

import '../../core/network/api_client.dart';
import '../employees/employee_model.dart';
import 'conversation_model.dart';
import 'conversation_collaboration_model.dart';

class ChatCache {
  static final Map<String, ConversationModel> _conversations = {};
  static final Map<String, List<ConversationModel>> _lists = {};
  static final StreamController<ConversationModel> _changes =
      StreamController<ConversationModel>.broadcast();

  static Stream<ConversationModel> get changes => _changes.stream;

  static void setList(String key, List<ConversationModel> items) {
    final snapshot = List<ConversationModel>.unmodifiable(items);
    _lists[key] = snapshot;
    for (final item in snapshot) {
      _conversations[item.id] = item;
    }
  }

  static List<ConversationModel>? getList(String key) => _lists[key];

  static void set(
    ConversationModel item, {
    bool notify = true,
    bool promote = true,
  }) {
    _conversations[item.id] = item;
    for (final entry in _lists.entries.toList()) {
      final index = entry.value.indexWhere((value) => value.id == item.id);
      if (index < 0) continue;
      final updated = [...entry.value]..[index] = item;
      if (promote && index > 0) {
        updated
          ..removeAt(index)
          ..insert(0, item);
      }
      _lists[entry.key] = List<ConversationModel>.unmodifiable(updated);
    }
    if (notify) _changes.add(item);
  }

  static ConversationModel? get(String id) => _conversations[id];
}

class ConversationService {
  ConversationService(this.api);
  final ApiClient api;

  Future<List<ConversationModel>> list({
    String? status,
    String search = '',
    String tag = '',
    bool unreadOnly = false,
    bool assignedToMe = false,
    bool followUpDue = false,
    String? inbox,
  }) async {
    final query = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (tag.trim().isNotEmpty) 'tag': tag.trim(),
      if (unreadOnly) 'unreadOnly': 'true',
      if (assignedToMe) 'assignedToMe': 'true',
      if (followUpDue) 'followUpDue': 'true',
      if (inbox != null && inbox.isNotEmpty) 'inbox': inbox,
    };
    final suffix = query.isEmpty
        ? ''
        : '?${query.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return (await api.getList('/conversations$suffix'))
        .map(ConversationModel.fromJson)
        .toList();
  }

  Future<ConversationModel> get(String id) async =>
      ConversationModel.fromJson(await api.getMap('/conversations/$id'));

  Future<List<EmployeeModel>> assignees() async {
    final data = await api.getList('/conversations/assignees');
    return data.map(EmployeeModel.fromJson).toList();
  }

  Future<List<QuickReplyModel>> quickReplies() async {
    final data = await api.getList('/conversations/quick-replies');
    return data.map(QuickReplyModel.fromJson).toList();
  }

  Future<QuickReplyModel> createQuickReply({
    required String title,
    required String body,
    String shortcut = '',
  }) async {
    return QuickReplyModel.fromJson(
        await api.postMap('/conversations/quick-replies', {
      'title': title.trim(),
      'body': body.trim(),
      if (shortcut.trim().isNotEmpty) 'shortcut': shortcut.trim(),
    }));
  }

  Future<void> deleteQuickReply(String id) =>
      api.deleteMap('/conversations/quick-replies/$id');

  Future<ConversationModel> create(
      {required String name,
      required String phone,
      required String message,
      String priority = 'normal'}) async {
    return ConversationModel.fromJson(await api.postMap('/conversations', {
      'customerName': name.trim(),
      'customerPhone': phone.trim(),
      'initialMessage': message.trim(),
      'priority': priority,
    }));
  }

  Future<MessageModel> send(String id, String body) async =>
      MessageModel.fromJson(await api
          .postMap('/conversations/$id/messages', {'body': body.trim()}));

  Future<MessageModel> sendMedia(
    String id, {
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String caption = '',
  }) async =>
      MessageModel.fromJson(await api.postMultipart(
        '/conversations/$id/media',
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        fields: {
          if (caption.trim().isNotEmpty) 'caption': caption.trim(),
        },
      ));
  Future<void> note(String id, String body) =>
      api.postMap('/conversations/$id/notes', {'body': body.trim()});
  Future<void> markRead(String id) => api.postMap('/conversations/$id/read');

  Future<ConversationCollaborationModel> collaboration(String id) async =>
      ConversationCollaborationModel.fromJson(
          await api.getMap('/conversations/$id/collaboration'));
  Future<ConversationCollaborationModel> enter(
          String id, String sessionId) async =>
      ConversationCollaborationModel.fromJson(await api.postMap(
          '/conversations/$id/presence/enter', {'sessionId': sessionId}));
  Future<ConversationCollaborationModel> heartbeat(
          String id, String sessionId) async =>
      ConversationCollaborationModel.fromJson(await api.postMap(
          '/conversations/$id/presence/heartbeat', {'sessionId': sessionId}));
  Future<void> leave(String id, String sessionId) => api
      .postMap('/conversations/$id/presence/leave', {'sessionId': sessionId});
  Future<ConversationCollaborationModel> overrideLock(
          String id, String sessionId) async =>
      ConversationCollaborationModel.fromJson(await api.postMap(
          '/conversations/$id/lock/override', {'sessionId': sessionId}));
  Future<void> close(String id, {String? reason}) => api.postMap(
      '/conversations/$id/close',
      {if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim()});
  Future<void> reopen(String id) => api.postMap('/conversations/$id/reopen');

  Future<void> assign(String id, String? employeeId) =>
      api.patchMap('/conversations/$id/assign', {
        'assignedToId': employeeId,
      });

  Future<void> update(
    String id, {
    String? status,
    String? priority,
    List<String>? tags,
    DateTime? followUpAt,
    String? followUpNote,
    bool clearFollowUp = false,
  }) =>
      api.patchMap('/conversations/$id', {
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (tags != null) 'tags': tags,
        if (followUpAt != null)
          'followUpAt': followUpAt.toUtc().toIso8601String(),
        if (followUpNote != null) 'followUpNote': followUpNote,
        if (clearFollowUp) 'followUpAt': null,
        if (clearFollowUp) 'followUpNote': null,
      });

  Future<String> aiDraft(String id) async =>
      (await api.postMap('/ai/draft/$id'))['text']?.toString() ?? '';
}
