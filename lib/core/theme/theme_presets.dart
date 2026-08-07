import 'package:flutter/material.dart';
import 'theme_contrast_validator.dart';
import 'theme_preferences.dart';

@immutable
class SupportHubThemeColors extends ThemeExtension<SupportHubThemeColors> {
  const SupportHubThemeColors(
      {required this.sentMessageBubble, required this.receivedMessageBubble});
  final Color sentMessageBubble;
  final Color receivedMessageBubble;

  @override
  SupportHubThemeColors copyWith(
          {Color? sentMessageBubble, Color? receivedMessageBubble}) =>
      SupportHubThemeColors(
        sentMessageBubble: sentMessageBubble ?? this.sentMessageBubble,
        receivedMessageBubble:
            receivedMessageBubble ?? this.receivedMessageBubble,
      );

  @override
  SupportHubThemeColors lerp(
          covariant SupportHubThemeColors? other, double t) =>
      other == null
          ? this
          : SupportHubThemeColors(
              sentMessageBubble:
                  Color.lerp(sentMessageBubble, other.sentMessageBubble, t)!,
              receivedMessageBubble: Color.lerp(
                  receivedMessageBubble, other.receivedMessageBubble, t)!,
            );
}

class SupportHubPalette {
  const SupportHubPalette({
    required this.primary,
    required this.accent,
    required this.sent,
    required this.received,
    required this.background,
    required this.surface,
    required this.navigation,
  });
  final Color primary;
  final Color accent;
  final Color sent;
  final Color received;
  final Color background;
  final Color surface;
  final Color navigation;

  factory SupportHubPalette.resolve(
      ThemePreferences preferences, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = switch (preferences.preset) {
      SupportHubThemePreset.obsidianBlue => SupportHubPalette(
          primary: dark ? const Color(0xFF7C8DFF) : const Color(0xFF4C63FF),
          accent: dark ? const Color(0xFF72D9B8) : const Color(0xFF55B99B),
          sent: dark ? const Color(0xFF252B52) : const Color(0xFFE9ECFF),
          received: dark ? const Color(0xFF171A25) : const Color(0xFFFFFFFF),
          background: dark ? const Color(0xFF0B0D14) : const Color(0xFFF6F7FB),
          surface: dark ? const Color(0xFF141722) : const Color(0xFFFFFFFF),
          navigation: dark ? const Color(0xFF171A25) : const Color(0xFFFFFFFF),
        ),
      SupportHubThemePreset.midnightViolet => SupportHubPalette(
          primary: dark ? const Color(0xFFA786FF) : const Color(0xFF7848E8),
          accent: dark ? const Color(0xFF75D7BE) : const Color(0xFF58BCA2),
          sent: dark ? const Color(0xFF352252) : const Color(0xFFEFE7FF),
          received: dark ? const Color(0xFF1A1524) : const Color(0xFFFFFFFF),
          background: dark ? const Color(0xFF0F0C16) : const Color(0xFFF8F6FC),
          surface: dark ? const Color(0xFF18121F) : const Color(0xFFFFFFFF),
          navigation: dark ? const Color(0xFF1A1524) : const Color(0xFFFFFFFF),
        ),
      SupportHubThemePreset.graphiteCopper => SupportHubPalette(
          primary: dark ? const Color(0xFFE08A5F) : const Color(0xFFB85F35),
          accent: dark ? const Color(0xFF79D2B8) : const Color(0xFF4BA78E),
          sent: dark ? const Color(0xFF45291F) : const Color(0xFFF7E2D6),
          received: dark ? const Color(0xFF1D1A18) : const Color(0xFFFFFFFF),
          background: dark ? const Color(0xFF11100F) : const Color(0xFFF7F5F2),
          surface: dark ? const Color(0xFF1A1715) : const Color(0xFFFFFFFF),
          navigation: dark ? const Color(0xFF201B18) : const Color(0xFFFFFFFF),
        ),
      SupportHubThemePreset.defaultTheme => SupportHubPalette(
          // Wasl keeps its mint brand color for actions and selection, while
          // dark mode itself stays genuinely neutral (charcoal/black) instead
          // of tinting the whole application green.
          primary: const Color(0xFF7FC1AC),
          accent: dark ? const Color(0xFF8BCDB9) : const Color(0xFF5FA88F),
          sent: dark ? const Color(0xFF173A32) : const Color(0xFFDDF3EC),
          received: dark ? const Color(0xFF15171A) : const Color(0xFFFFFFFF),
          // Default Wasl uses one neutral page/surface foundation. Components
          // are separated with borders/elevation, not mismatched green/black
          // panels. The floating dock remains one deliberate capsule layer.
          background: dark ? const Color(0xFF0B0C0E) : const Color(0xFFF8FAF9),
          surface: dark ? const Color(0xFF0B0C0E) : const Color(0xFFF8FAF9),
          navigation: dark ? const Color(0xFF171A1D) : const Color(0xFFFFFFFF),
        ),
    };
    Color custom(String key, Color fallback) =>
        ThemeContrastValidator.parse(preferences.customColors[key]) ?? fallback;
    return SupportHubPalette(
      primary: custom('primaryColor', base.primary),
      accent: custom('accentColor', base.accent),
      sent: custom('sentMessageBubble', base.sent),
      received: custom('receivedMessageBubble', base.received),
      background: custom('backgroundColor', base.background),
      surface: custom('surfaceColor', base.surface),
      navigation: custom('navigationColor', base.navigation),
    );
  }
}
