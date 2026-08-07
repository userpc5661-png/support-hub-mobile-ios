class BrowserNotificationService {
  Future<bool> requestPermission() async => false;
  bool get isSupported => false;
  bool get isGranted => false;
  void show({required String title, required String body, String? tag}) {}
}
