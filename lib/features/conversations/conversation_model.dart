class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.channel,
    required this.status,
    required this.priority,
    required this.customer,
    required this.unreadCount,
    required this.tags,
    this.assignedToId,
    this.assignedToName,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.followUpAt,
    this.followUpNote,
    this.aiHandled = false,
    this.closedAt,
    this.closedByUserId,
    this.closedByName,
    this.closeReason,
    this.reopenedAt,
    this.messages = const [],
  });

  final String id;
  final String channel;
  final String status;
  final String priority;
  final ConversationCustomer customer;
  final String? assignedToId;
  final String? assignedToName;
  final int unreadCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? followUpAt;
  final String? followUpNote;
  final bool aiHandled;
  final DateTime? closedAt;
  final String? closedByUserId;
  final String? closedByName;
  final String? closeReason;
  final DateTime? reopenedAt;
  final List<String> tags;
  final List<MessageModel> messages;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final assigned = json['assignedTo'];
    final closedBy = json['closedBy'];
    return ConversationModel(
      id: json['id'] as String,
      channel: json['channel']?.toString() ?? 'manual',
      status: json['status']?.toString() ?? 'new',
      priority: json['priority']?.toString() ?? 'normal',
      customer: ConversationCustomer.fromJson(
          Map<String, dynamic>.from(json['customer'] as Map)),
      assignedToId: json['assignedToId']?.toString(),
      assignedToName: assigned is Map ? assigned['name']?.toString() : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
      followUpAt: DateTime.tryParse(json['followUpAt']?.toString() ?? ''),
      followUpNote: json['followUpNote']?.toString(),
      aiHandled: json['aiHandled'] == true,
      closedAt: DateTime.tryParse(json['closedAt']?.toString() ?? ''),
      closedByUserId: json['closedByUserId']?.toString(),
      closedByName: closedBy is Map ? closedBy['name']?.toString() : null,
      closeReason: json['closeReason']?.toString(),
      reopenedAt: DateTime.tryParse(json['reopenedAt']?.toString() ?? ''),
      tags: (json['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      messages: (json['messages'] as List? ?? const [])
          .map((item) =>
              MessageModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  ConversationModel copyWith({
    String? status,
    int? unreadCount,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    List<MessageModel>? messages,
  }) =>
      ConversationModel(
        id: id,
        channel: channel,
        status: status ?? this.status,
        priority: priority,
        customer: customer,
        assignedToId: assignedToId,
        assignedToName: assignedToName,
        unreadCount: unreadCount ?? this.unreadCount,
        lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        followUpAt: followUpAt,
        followUpNote: followUpNote,
        aiHandled: aiHandled,
        closedAt: closedAt,
        closedByUserId: closedByUserId,
        closedByName: closedByName,
        closeReason: closeReason,
        reopenedAt: reopenedAt,
        tags: tags,
        messages: messages ?? this.messages,
      );
}

class QuickReplyModel {
  const QuickReplyModel({
    required this.id,
    required this.title,
    required this.body,
    this.shortcut,
  });

  final String id;
  final String title;
  final String body;
  final String? shortcut;

  factory QuickReplyModel.fromJson(Map<String, dynamic> json) =>
      QuickReplyModel(
        id: json['id'] as String,
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        shortcut: json['shortcut']?.toString(),
      );
}

class ConversationCustomer {
  const ConversationCustomer(
      {required this.id,
      required this.name,
      required this.phone,
      this.email,
      this.avatarUrl,
      this.tags = const []});
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final List<String> tags;

  factory ConversationCustomer.fromJson(Map<String, dynamic> json) =>
      ConversationCustomer(
        id: json['id'] as String,
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email']?.toString(),
        avatarUrl: json['avatarUrl']?.toString(),
        tags: (json['tags'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
      );
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderType,
    required this.direction,
    required this.type,
    required this.status,
    required this.createdAt,
    this.senderName,
    this.body,
    this.mediaUrl,
    this.error,
  });

  final String id;
  final String senderType;
  final String direction;
  final String type;
  final String status;
  final String? senderName;
  final String? body;
  final String? mediaUrl;
  final String? error;
  final DateTime createdAt;

  bool get internal => direction == 'internal';
  bool get inbound => direction == 'inbound';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return MessageModel(
      id: json['id'] as String,
      senderType: json['senderType']?.toString() ?? 'system',
      direction: json['direction']?.toString() ?? 'internal',
      type: json['type']?.toString() ?? 'text',
      status: json['status']?.toString() ?? 'sent',
      senderName: sender is Map ? sender['name']?.toString() : null,
      body: json['body']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      error: json['error']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  MessageModel copyWith({
    String? id,
    String? status,
    String? body,
    String? mediaUrl,
    String? error,
  }) =>
      MessageModel(
        id: id ?? this.id,
        senderType: senderType,
        direction: direction,
        type: type,
        status: status ?? this.status,
        senderName: senderName,
        body: body ?? this.body,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        error: error,
        createdAt: createdAt,
      );
}
