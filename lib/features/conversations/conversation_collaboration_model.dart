class ConversationCollaborationModel {
  const ConversationCollaborationModel(
      {required this.presences, required this.canReply, this.lock});
  final List<ConversationPresenceModel> presences;
  final ConversationLockModel? lock;
  final bool canReply;

  factory ConversationCollaborationModel.fromJson(Map<String, dynamic> json) =>
      ConversationCollaborationModel(
        presences: (json['presences'] as List? ?? const [])
            .map((item) => ConversationPresenceModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        lock: json['lock'] is Map
            ? ConversationLockModel.fromJson(
                Map<String, dynamic>.from(json['lock'] as Map))
            : null,
        canReply: json['canReply'] == true,
      );
}

class ConversationPresenceModel {
  const ConversationPresenceModel(
      {required this.userId, required this.userName, required this.sessionId});
  final String userId;
  final String userName;
  final String sessionId;

  factory ConversationPresenceModel.fromJson(Map<String, dynamic> json) =>
      ConversationPresenceModel(
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        sessionId: json['sessionId']?.toString() ?? '',
      );
}

class ConversationLockModel {
  const ConversationLockModel(
      {required this.userId, required this.userName, required this.ownedByMe});
  final String userId;
  final String userName;
  final bool ownedByMe;

  factory ConversationLockModel.fromJson(Map<String, dynamic> json) =>
      ConversationLockModel(
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        ownedByMe: json['ownedByMe'] == true,
      );
}
