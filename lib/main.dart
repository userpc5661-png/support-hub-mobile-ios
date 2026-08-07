import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/chat_appearance_controller.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = TokenStorage();
  final apiClient = ApiClient(storage);
  final pushNotifications = PushNotificationService(apiClient);
  try {
    await pushNotifications.initialize();
  } catch (error) {
    debugPrint('Wasl push initialization skipped: $error');
  }
  final controller =
      AuthController(AuthService(apiClient, storage, pushNotifications));
  final themeController = ThemeController(apiClient);
  final localeController = AppLocaleController();
  final chatAppearance = ChatAppearanceController.instance;
  await Future.wait([
    themeController.initialize(),
    localeController.initialize(),
    chatAppearance.initialize(),
  ]);
  runApp(SupportHubApp(
    controller: controller,
    api: apiClient,
    themeController: themeController,
    localeController: localeController,
    pushNotifications: pushNotifications,
  ));
  await controller.initialize();
}
