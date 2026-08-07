import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatAppearanceController extends ChangeNotifier {
  ChatAppearanceController._();

  static final ChatAppearanceController instance = ChatAppearanceController._();

  static const _sentKey = 'chat_sent_color';
  static const _receivedKey = 'chat_received_color';
  static const _backgroundKey = 'chat_background_color';
  static const _fontScaleKey = 'chat_font_scale';
  static const _patternKey = 'chat_pattern_enabled';

  int? _sentColor;
  int? _receivedColor;
  int? _backgroundColor;
  double fontScale = 1;
  bool patternEnabled = true;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _sentColor = preferences.getInt(_sentKey);
    _receivedColor = preferences.getInt(_receivedKey);
    _backgroundColor = preferences.getInt(_backgroundKey);
    fontScale = preferences.getDouble(_fontScaleKey) ?? 1;
    patternEnabled = preferences.getBool(_patternKey) ?? true;
  }

  Color sent(Brightness brightness, {Color? fallback}) => _sentColor == null
      ? (fallback ??
          (brightness == Brightness.dark
              ? const Color(0xFF173A32)
              : const Color(0xFFDDF3EC)))
      : Color(_sentColor!);

  Color received(Brightness brightness, {Color? fallback}) =>
      _receivedColor == null
          ? (fallback ??
              (brightness == Brightness.dark
                  ? const Color(0xFF16181B)
                  : const Color(0xFFFFFFFF)))
          : Color(_receivedColor!);

  Color background(Brightness brightness, {Color? fallback}) =>
      _backgroundColor == null
          ? (fallback ??
              (brightness == Brightness.dark
                  ? const Color(0xFF0B0C0E)
                  : const Color(0xFFF7FAF9)))
          : Color(_backgroundColor!);

  int? get sentColorValue => _sentColor;
  int? get receivedColorValue => _receivedColor;
  int? get backgroundColorValue => _backgroundColor;

  Future<void> setSent(Color color) async {
    _sentColor = color.toARGB32();
    await _writeInt(_sentKey, _sentColor!);
    notifyListeners();
  }

  Future<void> setReceived(Color color) async {
    _receivedColor = color.toARGB32();
    await _writeInt(_receivedKey, _receivedColor!);
    notifyListeners();
  }

  Future<void> setBackground(Color color) async {
    _backgroundColor = color.toARGB32();
    await _writeInt(_backgroundKey, _backgroundColor!);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(.88, 1.18).toDouble();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_fontScaleKey, fontScale);
    notifyListeners();
  }

  Future<void> setPatternEnabled(bool value) async {
    patternEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_patternKey, value);
    notifyListeners();
  }

  Future<void> reset() async {
    _sentColor = null;
    _receivedColor = null;
    _backgroundColor = null;
    fontScale = 1;
    patternEnabled = true;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_sentKey),
      preferences.remove(_receivedKey),
      preferences.remove(_backgroundKey),
      preferences.remove(_fontScaleKey),
      preferences.remove(_patternKey),
    ]);
    notifyListeners();
  }

  Future<void> _writeInt(String key, int value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(key, value);
  }
}
