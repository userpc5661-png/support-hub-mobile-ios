abstract final class InAppNotificationGate {
  static String? _lastConversationId;
  static DateTime? _lastShownAt;

  static bool shouldShow(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return false;
    final now = DateTime.now();
    if (_lastConversationId == id &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 4)) {
      return false;
    }
    _lastConversationId = id;
    _lastShownAt = now;
    return true;
  }
}
