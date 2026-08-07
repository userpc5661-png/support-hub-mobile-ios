import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

@pragma('vm:entry-point')
Future<void> waslFirebaseBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb || !_FirebaseBuildConfig.isConfigured) return;
  if (Firebase.apps.isEmpty) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(options: _FirebaseBuildConfig.options);
    }
  }
}

/// Backwards-compatible entry point for builds that still reference the old
/// generated handler name.
@pragma('vm:entry-point')
Future<void> supportHubFirebaseBackgroundHandler(RemoteMessage message) =>
    waslFirebaseBackgroundHandler(message);

enum PushPermissionState {
  unavailable,
  notDetermined,
  denied,
  provisional,
  granted,
}

class PushNotificationService {
  PushNotificationService(this.api);

  final ApiClient api;
  final _openedConversations = StreamController<String>.broadcast();

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _pendingConversationId;
  String? _lastOpenedConversationId;
  DateTime? _lastOpenedAt;
  bool _initialized = false;
  bool _active = false;

  Stream<String> get openedConversations => _openedConversations.stream;
  bool get isConfigured => _FirebaseBuildConfig.isConfigured;

  Future<void> initialize() async {
    if (_initialized || !_FirebaseBuildConfig.isConfigured || kIsWeb) return;

    if (Firebase.apps.isEmpty) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: _FirebaseBuildConfig.options);
      }
    }

    FirebaseMessaging.onBackgroundMessage(waslFirebaseBackgroundHandler);
    _initialized = true;

    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_captureOpen);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _captureOpen(initial);
  }

  Future<PushPermissionState> permissionState() async {
    if (!_initialized || !_FirebaseBuildConfig.isConfigured || kIsWeb) {
      return PushPermissionState.unavailable;
    }
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _mapPermission(settings.authorizationStatus);
  }

  Future<bool> requestPermissionAndRegister() async {
    if (!_initialized || !_FirebaseBuildConfig.isConfigured || kIsWeb) {
      return false;
    }
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final state = _mapPermission(permission.authorizationStatus);
    if (state != PushPermissionState.granted &&
        state != PushPermissionState.provisional) {
      return false;
    }
    _active = true;
    await _suppressForegroundPresentation(messaging);
    await _registerCurrentTokenAndWatch(messaging);
    return true;
  }

  Future<void> activate() async {
    if (!_initialized) return;
    _active = true;
    final messaging = FirebaseMessaging.instance;
    await _suppressForegroundPresentation(messaging);

    // Do not interrupt login with a permission prompt. The user explicitly
    // enables notifications from Settings. Existing grants are registered
    // automatically so background/terminated delivery keeps working.
    final state = _mapPermission(
      (await messaging.getNotificationSettings()).authorizationStatus,
    );
    if (state == PushPermissionState.granted ||
        state == PushPermissionState.provisional) {
      await _registerCurrentTokenAndWatch(messaging);
    }

    final pending = _pendingConversationId;
    if (pending != null) {
      _pendingConversationId = null;
      _emitOpen(pending);
    }
  }

  Future<void> _suppressForegroundPresentation(
      FirebaseMessaging messaging) async {
    // Foreground messages update the inbox/realtime counters only. Wasl never
    // shows a system banner or an in-app popup while the user is actively in
    // the application. Background and terminated notifications remain enabled.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
  }

  Future<void> _registerCurrentTokenAndWatch(
      FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (error) {
      debugPrint('Wasl device registration will retry later: $error');
    }
    await _tokenRefresh?.cancel();
    _tokenRefresh = messaging.onTokenRefresh.listen((value) async {
      try {
        await _register(value);
      } catch (error) {
        debugPrint('Wasl token refresh registration failed: $error');
      }
    });
  }

  PushPermissionState _mapPermission(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized => PushPermissionState.granted,
        AuthorizationStatus.provisional => PushPermissionState.provisional,
        AuthorizationStatus.denied => PushPermissionState.denied,
        AuthorizationStatus.notDetermined => PushPermissionState.notDetermined,
      };

  Future<void> deactivate() async {
    if (!_initialized) return;
    _active = false;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token != null) {
      try {
        await api.deleteMap('/notifications/devices', {'token': token});
      } catch (_) {
        // Logout must still complete when the server is temporarily offline.
      }
    }
    try {
      await messaging.deleteToken();
    } catch (_) {
      // Firebase may be unavailable while logging out; a future token is still
      // registered again after the next authenticated activation.
    }
  }

  Future<void> _register(String token) async {
    await api.postMap('/notifications/devices', {
      'token': token,
      'platform':
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
  }


  void _captureOpen(RemoteMessage message) {
    final id = _conversationId(message);
    if (id == null) return;
    _pendingConversationId = id;
    if (_active) {
      _pendingConversationId = null;
      _emitOpen(id);
    }
  }

  void _emitOpen(String id) {
    final now = DateTime.now();
    if (_lastOpenedConversationId == id &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastOpenedConversationId = id;
    _lastOpenedAt = now;
    _openedConversations.add(id);
  }

  String? _conversationId(RemoteMessage message) {
    String? fromMap(Map<dynamic, dynamic> data) {
      for (final key in const [
        'conversationId',
        'conversation_id',
        'chatId',
        'chat_id',
      ]) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty && value != 'null') return value;
      }
      for (final nestedKey in const ['data', 'payload', 'notification']) {
        final nested = data[nestedKey];
        if (nested is Map) {
          final value = fromMap(nested);
          if (value != null) return value;
        }
        if (nested is String && nested.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(nested);
            if (decoded is Map) {
              final value = fromMap(decoded);
              if (value != null) return value;
            }
          } catch (_) {
            // Ignore malformed optional payloads and continue with other keys.
          }
        }
      }
      return null;
    }

    return fromMap(message.data);
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _openedSubscription?.cancel();
    await _openedConversations.close();
  }
}

abstract final class _FirebaseBuildConfig {
  static const commonApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const commonAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const iosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static String get apiKey => defaultTargetPlatform == TargetPlatform.iOS
      ? (iosApiKey.isNotEmpty ? iosApiKey : commonApiKey)
      : (androidApiKey.isNotEmpty ? androidApiKey : commonApiKey);

  static String get appId => defaultTargetPlatform == TargetPlatform.iOS
      ? (iosAppId.isNotEmpty ? iosAppId : commonAppId)
      : (androidAppId.isNotEmpty ? androidAppId : commonAppId);

  static bool get hasExplicitOptions =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static bool get isConfigured {
    if (kIsWeb) return false;

    // Android reads Firebase configuration from
    // android/app/google-services.json via the Google Services Gradle plugin.
    if (defaultTargetPlatform == TargetPlatform.android) return true;

    // iOS will use explicit Firebase options until GoogleService-Info.plist
    // is added to the native iOS project.
    return hasExplicitOptions;
  }

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        iosBundleId: defaultTargetPlatform == TargetPlatform.iOS &&
                iosBundleId.isNotEmpty
            ? iosBundleId
            : null,
      );
}

