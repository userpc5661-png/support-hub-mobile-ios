import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_contrast_validator.dart';
import 'core/theme/theme_presets.dart';
import 'core/theme/support_hub_design.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/force_password_change_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/conversations/conversations_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/shell/workspace_shell.dart';

class SupportHubApp extends StatefulWidget {
  const SupportHubApp({
    super.key,
    required this.controller,
    required this.api,
    required this.themeController,
    required this.localeController,
    required this.pushNotifications,
  });

  final AuthController controller;
  final ApiClient api;
  final ThemeController themeController;
  final AppLocaleController localeController;
  final PushNotificationService pushNotifications;

  @override
  State<SupportHubApp> createState() => _SupportHubAppState();
}

class _SupportHubAppState extends State<SupportHubApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? pushOpenSubscription;
  String? _currentPushConversationId;
  String? _pendingPushConversationId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncAppearance);
    _syncAppearance();
    pushOpenSubscription =
        widget.pushNotifications.openedConversations.listen(_openConversation);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncAppearance);
    pushOpenSubscription?.cancel();
    super.dispose();
  }

  void _syncAppearance() {
    widget.themeController.bindUser(widget.controller.user?.id);
    final pending = _pendingPushConversationId;
    if (pending != null && widget.controller.user != null) {
      _pendingPushConversationId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openConversation(pending);
      });
    }
  }


  void _openConversation(String conversationId) {
    final normalizedId = conversationId.trim();
    if (normalizedId.isEmpty) return;
    final user = widget.controller.user;
    if (user == null) {
      _pendingPushConversationId = normalizedId;
      return;
    }
    conversationId = normalizedId;
    if (_currentPushConversationId == conversationId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        _pendingPushConversationId = conversationId;
        return;
      }
      _currentPushConversationId = conversationId;
      await navigator.push(MaterialPageRoute<void>(
        settings: RouteSettings(name: '/chats/$conversationId'),
        builder: (_) => ConversationsScreen(
          api: widget.api,
          user: user,
          manualConversationsEnabled: false,
          aiEnabled: user.hasPermission('ai.draft'),
          initialConversationId: conversationId,
        ),
      ));
      if (_currentPushConversationId == conversationId) {
        _currentPushConversationId = null;
      }
    });
  }

  ThemeData _theme(Brightness brightness) {
    final palette = SupportHubPalette.resolve(
        widget.themeController.preferences, brightness);
    final generated = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final primaryContainer = Color.alphaBlend(
      palette.primary
          .withValues(alpha: brightness == Brightness.dark ? .24 : .12),
      palette.surface,
    );
    final secondaryContainer = Color.alphaBlend(
      palette.accent
          .withValues(alpha: brightness == Brightness.dark ? .22 : .11),
      palette.surface,
    );
    final scheme = generated.copyWith(
      primary: palette.primary,
      onPrimary: ThemeContrastValidator.readableText(palette.primary),
      primaryContainer: primaryContainer,
      onPrimaryContainer: ThemeContrastValidator.readableText(primaryContainer),
      secondary: palette.accent,
      onSecondary: ThemeContrastValidator.readableText(palette.accent),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer:
          ThemeContrastValidator.readableText(secondaryContainer),
      tertiary: palette.accent,
      onTertiary: ThemeContrastValidator.readableText(palette.accent),
      surface: palette.surface,
      onSurface: ThemeContrastValidator.readableText(palette.surface),
      surfaceDim: palette.surface,
      surfaceBright: palette.surface,
      surfaceTint: Colors.transparent,
      // Material 3 generates several tinted surface layers from the seed.
      // For Wasl those layers caused the dark UI to look like multiple
      // mismatched panels. Keep the page base separate, but make all actual
      // surfaces consistent with the selected/custom surface color.
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surface,
      surfaceContainerHighest: palette.surface,
      surfaceVariant: palette.surface,
      onSurfaceVariant: brightness == Brightness.dark
          ? const Color(0xFFB8BCC3)
          : generated.onSurfaceVariant,
      outline: brightness == Brightness.dark
          ? const Color(0xFF747880)
          : generated.outline,
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF2B2E33)
          : generated.outlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
    );
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    final textTheme = AppLocaleController.isArabic
        ? GoogleFonts.tajawalTextTheme(baseTextTheme)
        : GoogleFonts.interTextTheme(baseTextTheme);
    final primaryTextTheme = AppLocaleController.isArabic
        ? GoogleFonts.tajawalTextTheme(
            ThemeData(brightness: brightness).primaryTextTheme,
          )
        : GoogleFonts.interTextTheme(
            ThemeData(brightness: brightness).primaryTextTheme,
          );
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      fontFamilyFallback: const ['Tajawal', 'Inter', 'Segoe UI', 'Roboto', 'Arial'],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: scheme.outlineVariant.withValues(alpha: .42),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _HubPageTransitionsBuilder(),
        TargetPlatform.iOS: _HubPageTransitionsBuilder(),
        TargetPlatform.windows: _HubPageTransitionsBuilder(),
      }),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HubRadius.lg),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .38)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HubRadius.md),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HubRadius.md),
            borderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: .42))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HubRadius.md),
            borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontFamily: textTheme.titleLarge?.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HubRadius.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HubRadius.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HubRadius.md)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HubRadius.md)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HubRadius.pill)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: const CircleBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: textTheme.labelMedium?.fontFamily,
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HubRadius.xl)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HubRadius.md)),
      ),
      navigationRailTheme: NavigationRailThemeData(
          indicatorShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      extensions: [
        SupportHubThemeColors(
            sentMessageBubble: palette.sent,
            receivedMessageBubble: palette.received),
        HubDesignColors.forBrightness(brightness).copyWith(
          navigation: palette.navigation,
          navigationSelected: Color.alphaBlend(
            scheme.primary.withValues(alpha: brightness == Brightness.dark ? .22 : .12),
            palette.navigation,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [widget.controller, widget.themeController, widget.localeController]),
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Wasl',
        locale: widget.localeController.locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: widget.themeController.mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        builder: (context, child) => AppLocaleScope(
            controller: widget.localeController,
            child: child ?? const SizedBox.shrink()),
        home: widget.controller.initializing
            ? const SplashScreen()
            : widget.controller.user == null
                ? LoginScreen(controller: widget.controller)
                : widget.controller.user!.mustChangePassword
                    ? ForcePasswordChangeScreen(controller: widget.controller)
                    : kIsWeb
                        ? DashboardScreen(
                            key: ValueKey(
                                'web:${widget.controller.user!.id}:${widget.controller.user!.storeId}:${widget.controller.user!.supportSessionId}'),
                            controller: widget.controller,
                            api: widget.api,
                            themeController: widget.themeController,
                          )
                        : WorkspaceShell(
                            key: ValueKey(
                                '${widget.controller.user!.id}:${widget.controller.user!.storeId}:${widget.controller.user!.supportSessionId}'),
                            controller: widget.controller,
                            api: widget.api,
                            themeController: widget.themeController,
                            pushNotifications: widget.pushNotifications),
      ),
    );
  }
}

class _HubPageTransitionsBuilder extends PageTransitionsBuilder {
  const _HubPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
        parent: animation, curve: HubMotion.curve, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .025), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
