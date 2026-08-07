import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  const SavedAccount({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        avatarUrl: json['avatarUrl']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        if (avatarUrl?.isNotEmpty == true) 'avatarUrl': avatarUrl,
      };
}

class TokenStorage {
  static const _key = 'access_token';
  static const _platformKey = 'platform_access_token';
  static const _accountsKey = 'saved_accounts_v1';
  static const _accountTokenPrefix = 'saved_account_token_';
  static const _storage = FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<List<SavedAccount>> savedAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => SavedAccount.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.id.isNotEmpty && item.username.isNotEmpty)
          .take(4)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAccount({
    required SavedAccount account,
    required String token,
  }) async {
    final existing = [...await savedAccounts()]
      ..removeWhere((item) =>
          item.id == account.id ||
          item.username.toLowerCase() == account.username.toLowerCase())
      ..insert(0, account);
    if (existing.length > 4) {
      final removed = existing.sublist(4);
      existing.removeRange(4, existing.length);
      for (final item in removed) {
        await _storage.delete(key: '$_accountTokenPrefix${item.id}');
      }
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _accountsKey,
      jsonEncode(existing.map((item) => item.toJson()).toList()),
    );
    await _storage.write(
      key: '$_accountTokenPrefix${account.id}',
      value: token,
    );
  }

  Future<bool> activateAccount(String id) async {
    final token = await _storage.read(key: '$_accountTokenPrefix$id');
    if (token == null || token.isEmpty) return false;
    await write(token);
    return true;
  }

  Future<void> removeAccount(String id) async {
    final accounts = [...await savedAccounts()]
      ..removeWhere((item) => item.id == id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _accountsKey,
      jsonEncode(accounts.map((item) => item.toJson()).toList()),
    );
    await _storage.delete(key: '$_accountTokenPrefix$id');
  }

  Future<void> beginSupportSession(String token) async {
    final current = await _storage.read(key: _key);
    if (current != null && await _storage.read(key: _platformKey) == null) {
      await _storage.write(key: _platformKey, value: current);
    }
    await _storage.write(key: _key, value: token);
  }

  Future<bool> restorePlatformSession() async {
    final platformToken = await _storage.read(key: _platformKey);
    if (platformToken == null) return false;
    await _storage.write(key: _key, value: platformToken);
    await _storage.delete(key: _platformKey);
    return true;
  }

  Future<void> clear({bool removeSavedAccounts = false}) async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _platformKey);
    if (!removeSavedAccounts) return;
    for (final account in await savedAccounts()) {
      await _storage.delete(key: '$_accountTokenPrefix${account.id}');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_accountsKey);
  }
}
