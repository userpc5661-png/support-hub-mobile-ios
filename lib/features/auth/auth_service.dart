import 'package:flutter/foundation.dart';

import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/notifications/push_notification_service.dart';
import 'user_model.dart';

class AuthService {
  AuthService(this.api, this.storage, this.pushNotifications);
  final ApiClient api;
  final TokenStorage storage;
  final PushNotificationService pushNotifications;

  Future<UserModel> login(String username, String password) async {
    final response = await api.postMap('/auth/login',
        {'username': username.trim().toLowerCase(), 'password': password});
    final token = response['accessToken'] as String;
    final user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
    await storage.write(token);
    await storage.saveAccount(
      account: SavedAccount(
        id: user.id,
        name: user.name,
        username: user.username,
        avatarUrl: user.avatarUrl,
      ),
      token: token,
    );
    await _activatePushSafely();
    return user;
  }

  Future<UserModel?> restoreSession() async {
    if (await storage.read() == null) return null;
    try {
      final user = UserModel.fromJson(await api.getMap('/auth/me'));
      await _activatePushSafely();
      return user;
    } catch (_) {
      await storage.clear();
      return null;
    }
  }

  Future<UserModel> refreshProfile() async =>
      UserModel.fromJson(await api.getMap('/auth/me'));

  Future<List<SavedAccount>> savedAccounts() => storage.savedAccounts();

  Future<UserModel> switchAccount(String id) async {
    await pushNotifications.deactivate();
    if (!await storage.activateAccount(id)) {
      throw StateError(tr('انتهت جلسة هذا الحساب. سجّل الدخول من جديد.'));
    }
    try {
      final user = await refreshProfile();
      final token = await storage.read();
      if (token != null) {
        await storage.saveAccount(
          account: SavedAccount(
            id: user.id,
            name: user.name,
            username: user.username,
            avatarUrl: user.avatarUrl,
          ),
          token: token,
        );
      }
      await _activatePushSafely();
      return user;
    } catch (_) {
      await storage.clear();
      rethrow;
    }
  }

  Future<void> removeSavedAccount(String id) => storage.removeAccount(id);

  Future<UserModel> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final response = await api.postMultipart(
      '/auth/avatar',
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    final user = UserModel.fromJson(response);
    final token = await storage.read();
    if (token != null) {
      await storage.saveAccount(
        account: SavedAccount(
          id: user.id,
          name: user.name,
          username: user.username,
          avatarUrl: user.avatarUrl,
        ),
        token: token,
      );
    }
    return user;
  }

  Future<UserModel> changePassword(
      String currentPassword, String newPassword) async {
    final response = await api.postMap('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    await storage.write(response['accessToken'] as String);
    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<UserModel> changeUsername(
      String username, String currentPassword) async {
    final response = await api.postMap('/auth/change-username', {
      'username': username.trim().toLowerCase(),
      'currentPassword': currentPassword,
    });
    await storage.write(response['accessToken'] as String);
    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<void> useSupportAccessToken(String token) =>
      storage.beginSupportSession(token);

  Future<UserModel> endSupportSession() async {
    try {
      await api.postMap('/support-access/session/end');
    } catch (_) {}
    final restored = await storage.restorePlatformSession();
    if (!restored) throw StateError(tr('تعذر استعادة جلسة مدير المنصة.'));
    return refreshProfile();
  }

  Future<void> logout() async {
    try {
      await pushNotifications.deactivate();
    } catch (error) {
      debugPrint('Wasl push deactivation skipped: $error');
    } finally {
      await storage.clear();
    }
  }

  Future<void> _activatePushSafely() async {
    try {
      await pushNotifications.activate();
    } catch (error) {
      // Push is helpful but must never block login or session restoration.
      debugPrint('Wasl push activation skipped: $error');
    }
  }
}
