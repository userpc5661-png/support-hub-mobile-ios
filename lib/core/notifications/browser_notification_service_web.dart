// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class BrowserNotificationService {
  bool get isSupported => html.Notification.supported;
  bool get isGranted =>
      isSupported && html.Notification.permission == 'granted';

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    if (isGranted) return true;
    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  }

  void show({required String title, required String body, String? tag}) {
    if (!isGranted) return;
    html.Notification(title, body: body, tag: tag);
  }
}
