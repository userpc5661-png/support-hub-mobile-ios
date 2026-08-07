import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'theme_contrast_validator.dart';
import 'theme_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this.api);
  static const _key = 'appearance_preferences';
  final ApiClient api;
  ThemePreferences preferences = const ThemePreferences();
  String? _boundUserId;
  bool saving = false;

  ThemeMode get mode => preferences.mode;
  String get _activeCacheKey =>
      _boundUserId == null ? _key : '${_key}_${_boundUserId!}';

  Future<void> initialize() async {
    preferences = await _readCached(_key) ?? preferences;
    notifyListeners();
  }

  Future<ThemePreferences?> _readCached(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw != null) {
      try {
        return ThemePreferences.fromApi(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    return null;
  }

  Future<void> bindUser(String? userId) async {
    if (_boundUserId == userId) return;
    _boundUserId = userId;
    // Keep the last authenticated appearance on the login screen. The app
    // cannot know the next account before authentication, so the last local
    // appearance is the safest non-flashing choice.
    if (userId != null) {
      preferences = const ThemePreferences();
    }
    final cacheKey = _activeCacheKey;
    final cached = await _readCached(cacheKey);
    if (_boundUserId != userId) return;
    if (cached != null) preferences = cached;
    notifyListeners();
    if (userId == null) return;
    try {
      final remote = ThemePreferences.fromApi(await api.getMap('/appearance'));
      if (_boundUserId != userId) return;
      preferences = remote;
      await _cache();
      notifyListeners();
    } catch (_) {
      // Keep the cached appearance while offline.
    }
  }

  Future<void> setMode(ThemeMode value) =>
      save(preferences.copyWith(mode: value));
  Future<void> setPreset(SupportHubThemePreset value) =>
      save(preferences.copyWith(preset: value, customColors: const {}));

  Future<void> setCustomColor(String key, Color color) {
    final colors = Map<String, String>.from(preferences.customColors)
      ..[key] = ThemeContrastValidator.toHex(color);
    return save(preferences.copyWith(customColors: colors));
  }

  Future<void> clearCustomColor(String key) {
    final colors = Map<String, String>.from(preferences.customColors)
      ..remove(key);
    return save(preferences.copyWith(customColors: colors));
  }

  Future<void> clearCustomColors() =>
      save(preferences.copyWith(customColors: const {}));

  Future<void> save(ThemePreferences value) async {
    preferences = value;
    await _cache();
    notifyListeners();
    if (_boundUserId == null) return;
    saving = true;
    notifyListeners();
    try {
      preferences = ThemePreferences.fromApi(
          await api.putMap('/appearance/me', value.toApi()));
      await _cache();
    } catch (_) {
      // Local selection remains active when the server is temporarily offline
      // or still running a version without appearance persistence.
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> saveStore(ThemePreferences value,
      {required bool enforced}) async {
    saving = true;
    notifyListeners();
    try {
      preferences = ThemePreferences.fromApi(await api.putMap(
          '/appearance/store', {...value.toApi(), 'enforced': enforced}));
      await _cache();
    } catch (_) {
      // Keep the locally selected store palette until synchronization resumes.
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _cache() async {
    final storage = await SharedPreferences.getInstance();
    final encoded = jsonEncode(preferences.toApi());
    await storage.setString(_activeCacheKey, encoded);
    if (_activeCacheKey != _key) {
      await storage.setString(_key, encoded);
    }
  }
}
