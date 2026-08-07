import 'package:flutter/material.dart';

enum SupportHubThemePreset {
  defaultTheme,
  obsidianBlue,
  midnightViolet,
  graphiteCopper
}

class ThemePreferences {
  const ThemePreferences({
    this.mode = ThemeMode.system,
    this.preset = SupportHubThemePreset.defaultTheme,
    this.customColors = const {},
    this.source = 'app_default',
  });

  final ThemeMode mode;
  final SupportHubThemePreset preset;
  final Map<String, String> customColors;
  final String source;

  factory ThemePreferences.fromApi(Map<String, dynamic> json) {
    final effective =
        Map<String, dynamic>.from((json['effective'] as Map?) ?? json);
    final colors = Map<String, dynamic>.from(
        (effective['customColors'] as Map?) ?? const {});
    return ThemePreferences(
      mode: _mode(effective['mode']?.toString()),
      preset: _preset(effective['preset']?.toString()),
      customColors: colors.map((key, value) => MapEntry(key, value.toString())),
      source: json['source']?.toString() ?? 'app_default',
    );
  }

  Map<String, dynamic> toApi() => {
        'mode': mode.name,
        'preset': switch (preset) {
          SupportHubThemePreset.defaultTheme => 'default',
          SupportHubThemePreset.obsidianBlue => 'obsidian_blue',
          SupportHubThemePreset.midnightViolet => 'midnight_violet',
          SupportHubThemePreset.graphiteCopper => 'graphite_copper',
        },
        if (customColors.isNotEmpty) 'customColors': customColors,
      };

  ThemePreferences copyWith(
          {ThemeMode? mode,
          SupportHubThemePreset? preset,
          Map<String, String>? customColors,
          String? source}) =>
      ThemePreferences(
        mode: mode ?? this.mode,
        preset: preset ?? this.preset,
        customColors: customColors ?? this.customColors,
        source: source ?? this.source,
      );

  static ThemeMode _mode(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static SupportHubThemePreset _preset(String? value) => switch (value) {
        'obsidian_blue' => SupportHubThemePreset.obsidianBlue,
        'midnight_violet' => SupportHubThemePreset.midnightViolet,
        'graphite_copper' => SupportHubThemePreset.graphiteCopper,
        _ => SupportHubThemePreset.defaultTheme,
      };
}
