import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/core/theme/theme_contrast_validator.dart';
import 'package:support_hub/core/theme/theme_preferences.dart';
import 'package:support_hub/core/theme/theme_presets.dart';

void main() {
  test('parses the three modes and saved preset from the API', () {
    final preferences = ThemePreferences.fromApi({
      'source': 'user',
      'effective': {
        'mode': 'dark',
        'preset': 'midnight_violet',
        'customColors': {'primaryColor': '#A786FF'},
      },
    });

    expect(preferences.mode, ThemeMode.dark);
    expect(preferences.preset, SupportHubThemePreset.midnightViolet);
    expect(preferences.customColors['primaryColor'], '#A786FF');
  });

  test('selects readable text for every supported custom color', () {
    for (final value in [
      '#000000',
      '#FFFFFF',
      '#777777',
      '#A786FF',
      '#E08A5F'
    ]) {
      final color = ThemeContrastValidator.parse(value)!;
      final text = ThemeContrastValidator.readableText(color);
      expect(ThemeContrastValidator.contrast(color, text),
          greaterThanOrEqualTo(4.5));
    }
  });


  test('default dark palette is neutral charcoal with Wasl accent', () {
    final palette = SupportHubPalette.resolve(
      const ThemePreferences(),
      Brightness.dark,
    );

    expect(palette.background, const Color(0xFF0B0C0E));
    expect(palette.surface, const Color(0xFF0B0C0E));
    expect(palette.navigation, const Color(0xFF171A1D));
    expect(palette.primary, const Color(0xFF7FC1AC));
  });
}
