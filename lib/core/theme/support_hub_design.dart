import 'package:flutter/material.dart';

/// Shared visual language for the mobile product. These tokens intentionally
/// stay independent from any admin-panel layout.
abstract final class HubSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class HubRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

abstract final class HubMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;
}

class HubDesignColors extends ThemeExtension<HubDesignColors> {
  const HubDesignColors({
    required this.success,
    required this.onSuccess,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.whatsapp,
    required this.navigation,
    required this.navigationSelected,
  });

  final Color success;
  final Color onSuccess;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color whatsapp;
  final Color navigation;
  final Color navigationSelected;

  static HubDesignColors forBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return HubDesignColors(
      success: dark ? const Color(0xFF64D5AD) : const Color(0xFF168B68),
      onSuccess: dark ? const Color(0xFF06251D) : Colors.white,
      successSoft: dark ? const Color(0xFF15372F) : const Color(0xFFE6F7F1),
      warning: dark ? const Color(0xFFF3C56B) : const Color(0xFF9A6813),
      warningSoft: dark ? const Color(0xFF3A301C) : const Color(0xFFFFF4D8),
      whatsapp: const Color(0xFF25B86F),
      navigation: dark ? const Color(0xFF0F1114) : const Color(0xFFF7FAF9),
      navigationSelected:
          dark ? const Color(0xFF1D2926) : const Color(0xFFE7F4F0),
    );
  }

  @override
  HubDesignColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? whatsapp,
    Color? navigation,
    Color? navigationSelected,
  }) =>
      HubDesignColors(
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
        successSoft: successSoft ?? this.successSoft,
        warning: warning ?? this.warning,
        warningSoft: warningSoft ?? this.warningSoft,
        whatsapp: whatsapp ?? this.whatsapp,
        navigation: navigation ?? this.navigation,
        navigationSelected: navigationSelected ?? this.navigationSelected,
      );

  @override
  HubDesignColors lerp(ThemeExtension<HubDesignColors>? other, double t) {
    if (other is! HubDesignColors) return this;
    return HubDesignColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      whatsapp: Color.lerp(whatsapp, other.whatsapp, t)!,
      navigation: Color.lerp(navigation, other.navigation, t)!,
      navigationSelected:
          Color.lerp(navigationSelected, other.navigationSelected, t)!,
    );
  }
}

extension HubThemeContext on BuildContext {
  ColorScheme get hubScheme => Theme.of(this).colorScheme;
  HubDesignColors get hubColors => Theme.of(this).extension<HubDesignColors>()!;
  TextTheme get hubText => Theme.of(this).textTheme;
}
