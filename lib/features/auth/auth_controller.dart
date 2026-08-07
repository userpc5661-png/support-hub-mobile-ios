import 'package:flutter/foundation.dart';
import '../../core/storage/token_storage.dart';
import '../../core/localization/app_locale_controller.dart';
import 'auth_service.dart';
import 'user_model.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.service);
  final AuthService service;

  UserModel? user;
  bool initializing = true;
  bool busy = false;
  String? error;
  List<SavedAccount> savedAccounts = const [];

  Future<void> initialize() async {
    savedAccounts = await service.savedAccounts();
    final restored = await service.restoreSession();
    if (!kIsWeb && restored != null && !restored.canUseSupportMobile) {
      await service.logout();
      error = tr(
          'تطبيق الجوال مخصص لموظفي ومشرفي الدعم الذين لديهم صلاحيات الدردشات والعملاء. استخدم لوحة الويب للإدارة.');
      user = null;
    } else {
      user = restored;
    }
    initializing = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final authenticated = await service.login(username, password);
      if (!kIsWeb && !authenticated.canUseSupportMobile) {
        await service.logout();
        error = tr(
            'تطبيق الجوال مخصص لموظفي ومشرفي الدعم الذين لديهم صلاحيات الدردشات والعملاء. استخدم لوحة الويب للإدارة.');
        return false;
      }
      user = authenticated;
      savedAccounts = await service.savedAccounts();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await service.changePassword(currentPassword, newPassword);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> changeUsername(String username, String currentPassword) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await service.changeUsername(username, currentPassword);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (user == null) return;
    user = await service.refreshProfile();
    notifyListeners();
  }

  Future<bool> switchAccount(String id) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await service.switchAccount(id);
      savedAccounts = await service.savedAccounts();
      return true;
    } catch (e) {
      error = e.toString();
      savedAccounts = await service.savedAccounts();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> removeSavedAccount(String id) async {
    await service.removeSavedAccount(id);
    savedAccounts = await service.savedAccounts();
    notifyListeners();
  }

  Future<bool> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await service.uploadAvatar(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      savedAccounts = await service.savedAccounts();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> enterSupportSession(String accessToken) async {
    await service.useSupportAccessToken(accessToken);
    user = await service.refreshProfile();
    notifyListeners();
  }

  Future<void> exitSupportSession() async {
    user = await service.endSupportSession();
    notifyListeners();
  }

  Future<void> logout() async {
    await service.logout();
    user = null;
    error = null;
    savedAccounts = await service.savedAccounts();
    notifyListeners();
  }
}
