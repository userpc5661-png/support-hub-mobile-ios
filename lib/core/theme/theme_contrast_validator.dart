import 'package:flutter/material.dart';

class ThemeContrastValidator {
  static final hexPattern = RegExp(r'^#[0-9a-fA-F]{6}$');

  static Color? parse(String? value) {
    if (value == null || !hexPattern.hasMatch(value)) return null;
    return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
  }

  static String toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  static Color readableText(Color background) {
    final blackRatio = contrast(background, Colors.black);
    final whiteRatio = contrast(background, Colors.white);
    return whiteRatio >= blackRatio ? Colors.white : Colors.black;
  }

  static bool isReadable(Color background) =>
      contrast(background, readableText(background)) >= 4.5;

  static double contrast(Color first, Color second) {
    final lighter =
        first.computeLuminance() >= second.computeLuminance() ? first : second;
    final darker = identical(lighter, first) ? second : first;
    return (lighter.computeLuminance() + .05) /
        (darker.computeLuminance() + .05);
  }
}
