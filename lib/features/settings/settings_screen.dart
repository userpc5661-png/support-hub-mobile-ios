import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_locale_controller.dart';
import '../../core/notifications/browser_notification_service.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/settings/dock_settings_controller.dart';
import '../../core/theme/theme_contrast_validator.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/theme_preferences.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/theme/support_hub_design.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    this.pushNotifications,
  });

  final ThemeController themeController;
  final PushNotificationService? pushNotifications;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final browserNotifications = BrowserNotificationService();
  PushPermissionState pushPermission = PushPermissionState.unavailable;
  bool checkingPushPermission = false;

  bool get usesNativePush => !kIsWeb && widget.pushNotifications != null;

  @override
  void initState() {
    super.initState();
    if (usesNativePush) _refreshPushPermission();
  }

  Future<void> _refreshPushPermission() async {
    final service = widget.pushNotifications;
    if (service == null) return;
    final value = await service.permissionState();
    if (mounted) setState(() => pushPermission = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hubScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(tr('المظهر والتخصيص')),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: widget.themeController,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
                HubSpace.md, HubSpace.sm, HubSpace.md, HubSpace.xl),
            children: [
              _SettingsCard(
                title: tr('اللغة'),
                subtitle: tr('اختر لغة الواجهة واتجاهها'),
                icon: Icons.language_rounded,
                trailing: const LanguageSwitcherButton(showLabel: true),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.contrast_rounded),
                          const SizedBox(width: 10),
                          Text(tr('المظهر'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                              value: ThemeMode.system,
                              icon: const Icon(Icons.computer_rounded),
                              label: Text(tr('النظام'))),
                          ButtonSegment(
                              value: ThemeMode.light,
                              icon: const Icon(Icons.light_mode_outlined),
                              label: Text(tr('فاتح'))),
                          ButtonSegment(
                              value: ThemeMode.dark,
                              icon: const Icon(Icons.dark_mode_outlined),
                              label: Text(tr('داكن'))),
                        ],
                        selected: {widget.themeController.mode},
                        onSelectionChanged: (value) =>
                            widget.themeController.setMode(value.single),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('اختر لوحة الألوان'),
                        style: TextStyle(
                            color: context.hubScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: HubSpace.sm),
                      _PaletteSelector(
                        selected: widget.themeController.preferences.preset,
                        enabled: !widget.themeController.saving,
                        onSelected: widget.themeController.setPreset,
                      ),
                      const SizedBox(height: HubSpace.lg),
                      Divider(color: context.hubScheme.outlineVariant),
                      const SizedBox(height: HubSpace.sm),
                      _CustomColorEditor(controller: widget.themeController),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _DockSettingsEditor(),
              const SizedBox(height: 14),
              _SettingsCard(
                title: usesNativePush
                    ? tr('إشعارات الجهاز')
                    : tr('إشعارات المتصفح'),
                subtitle: usesNativePush
                    ? (widget.pushNotifications!.isConfigured
                        ? (pushPermission == PushPermissionState.granted ||
                                pushPermission ==
                                    PushPermissionState.provisional
                            ? tr('الإشعارات مفعلة خارج التطبيق.')
                            : tr(
                                'فعّل الإشعارات لتظهر رسائل العملاء عندما يكون التطبيق في الخلفية أو مغلقًا.'))
                        : tr(
                            'Firebase غير مهيأ لهذا الإصدار. أضف إعدادات Firebase أولًا.'))
                    : (browserNotifications.isGranted
                        ? tr('الإشعارات مفعلة للرسائل الجديدة.')
                        : tr(
                            'فعّل التنبيهات حتى تظهر الرسائل الجديدة خارج اللوحة.')),
                icon: (usesNativePush
                        ? pushPermission == PushPermissionState.granted ||
                            pushPermission == PushPermissionState.provisional
                        : browserNotifications.isGranted)
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                trailing: FilledButton.tonal(
                  onPressed: checkingPushPermission
                      ? null
                      : (usesNativePush
                          ? (widget.pushNotifications!.isConfigured
                              ? _enableNotifications
                              : null)
                          : (browserNotifications.isSupported
                              ? _enableNotifications
                              : null)),
                  child: Text((usesNativePush
                          ? pushPermission == PushPermissionState.granted ||
                              pushPermission == PushPermissionState.provisional
                          : browserNotifications.isGranted)
                      ? tr('مفعلة')
                      : tr('تفعيل')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enableNotifications() async {
    if (usesNativePush) {
      setState(() => checkingPushPermission = true);
      var granted = false;
      try {
        granted =
            await widget.pushNotifications!.requestPermissionAndRegister();
        pushPermission = await widget.pushNotifications!.permissionState();
      } catch (_) {
        granted = false;
      }
      if (!mounted) return;
      setState(() => checkingPushPermission = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? tr('تم تفعيل إشعارات الجهاز.')
                : tr('لم يتم السماح بالإشعارات. فعّلها من إعدادات الجهاز.'),
          ),
        ),
      );
      return;
    }

    final granted = await browserNotifications.requestPermission();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? tr('تم تفعيل إشعارات المتصفح للرسائل الجديدة.')
              : tr('لم يتم السماح بالإشعارات. فعّلها من إعدادات الموقع.'),
        ),
      ),
    );
  }
}

class _DockSettingsEditor extends StatelessWidget {
  const _DockSettingsEditor();

  @override
  Widget build(BuildContext context) {
    final controller = DockSettingsController.instance;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String text(String ar, String en) => isArabic ? ar : en;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.space_bar_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text(
                        '\u062A\u062E\u0635\u064A\u0635 \u0627\u0644\u0634\u0631\u064A\u0637 \u0627\u0644\u0633\u0641\u0644\u064A',
                        'Customize bottom dock',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.reset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: Text(
                      text(
                        '\u0625\u0639\u0627\u062F\u0629 \u0627\u0644\u0636\u0628\u0637',
                        'Reset',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                text(
                  '\u063A\u064A\u0651\u0631 \u0627\u0644\u0634\u0641\u0627\u0641\u064A\u0629 \u0648\u0627\u0644\u062D\u062C\u0645 \u0648\u0645\u0648\u0636\u0639 \u0627\u0644\u062F\u0648\u0643 \u0645\u0628\u0627\u0634\u0631\u0629.',
                  'Adjust opacity, size, and dock position directly.',
                ),
                style: TextStyle(
                  color: context.hubScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              _DockSlider(
                label: text(
                  '\u0627\u0644\u0634\u0641\u0627\u0641\u064A\u0629',
                  'Opacity',
                ),
                valueLabel: '${(controller.opacity * 100).round()}%',
                value: controller.opacity,
                min: .30,
                max: 1,
                divisions: 70,
                onChanged: controller.setOpacity,
                onChangeEnd: (_) => controller.save(),
              ),
              _DockSlider(
                label: text(
                  '\u062D\u062C\u0645 \u0627\u0644\u062F\u0648\u0643',
                  'Dock size',
                ),
                valueLabel: '${controller.height.round()}',
                value: controller.height,
                min: 46,
                max: 72,
                divisions: 26,
                onChanged: controller.setHeight,
                onChangeEnd: (_) => controller.save(),
              ),
              _DockSlider(
                label: text(
                  '\u0631\u0641\u0639 \u0627\u0644\u062F\u0648\u0643',
                  'Raise dock',
                ),
                valueLabel: '${controller.bottomOffset.round()} px',
                value: controller.bottomOffset,
                min: 0,
                max: 32,
                divisions: 32,
                onChanged: controller.setBottomOffset,
                onChangeEnd: (_) => controller.save(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockSlider extends StatelessWidget {
  const _DockSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  valueLabel,
                  style: TextStyle(
                    color: context.hubScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ],
        ),
      );
}

class _PaletteSelector extends StatelessWidget {
  const _PaletteSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final SupportHubThemePreset selected;
  final bool enabled;
  final ValueChanged<SupportHubThemePreset> onSelected;

  static const choices = <_PaletteChoice>[
    _PaletteChoice(
      preset: SupportHubThemePreset.defaultTheme,
      label: 'Wasl',
      colors: [Color(0xFF7FC1AC), Color(0xFF5FA88F), Color(0xFFDDF3EC)],
    ),
    _PaletteChoice(
      preset: SupportHubThemePreset.obsidianBlue,
      label: 'Obsidian',
      colors: [Color(0xFF4C63FF), Color(0xFF55B99B), Color(0xFFE9ECFF)],
    ),
    _PaletteChoice(
      preset: SupportHubThemePreset.midnightViolet,
      label: 'Violet',
      colors: [Color(0xFF7848E8), Color(0xFF58BCA2), Color(0xFFEFE7FF)],
    ),
    _PaletteChoice(
      preset: SupportHubThemePreset.graphiteCopper,
      label: 'Copper',
      colors: [Color(0xFFB85F35), Color(0xFF4BA78E), Color(0xFFF7E2D6)],
    ),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: HubSpace.md,
        runSpacing: HubSpace.md,
        children: choices.map((choice) {
          final active = choice.preset == selected;
          return Semantics(
            selected: active,
            button: true,
            label: choice.label,
            child: InkWell(
              onTap: enabled ? () => onSelected(choice.preset) : null,
              borderRadius: BorderRadius.circular(HubRadius.md),
              child: AnimatedContainer(
                duration: HubMotion.standard,
                width: 82,
                padding: const EdgeInsets.symmetric(
                    horizontal: HubSpace.xs, vertical: HubSpace.sm),
                decoration: BoxDecoration(
                  color: active
                      ? context.hubScheme.primaryContainer
                      : context.hubScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(HubRadius.md),
                  border: Border.all(
                    color: active
                        ? context.hubScheme.primary
                        : context.hubScheme.outlineVariant
                            .withValues(alpha: .42),
                    width: active ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 34,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (var index = 0;
                              index < choice.colors.length;
                              index++)
                            PositionedDirectional(
                              start: index * 12,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: choice.colors[index],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: context.hubScheme.surface,
                                      width: 2),
                                ),
                              ),
                            ),
                          if (active)
                            Align(
                              alignment: AlignmentDirectional.bottomEnd,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: context.hubScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check_rounded,
                                    size: 13,
                                    color: context.hubScheme.onPrimary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(choice.label,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
}

class _PaletteChoice {
  const _PaletteChoice({
    required this.preset,
    required this.label,
    required this.colors,
  });
  final SupportHubThemePreset preset;
  final String label;
  final List<Color> colors;
}

class _CustomColorEditor extends StatelessWidget {
  const _CustomColorEditor({required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final palette = SupportHubPalette.resolve(
        controller.preferences, Theme.of(context).brightness);
    final fields = [
      _CustomColorField('primaryColor', tr('اللون الأساسي'), palette.primary),
      _CustomColorField('accentColor', tr('اللون المساعد'), palette.accent),
      _CustomColorField(
          'sentMessageBubble', tr('فقاعة الرسائل المرسلة'), palette.sent),
      _CustomColorField('receivedMessageBubble', tr('فقاعة الرسائل المستلمة'),
          palette.received),
      _CustomColorField(
          'backgroundColor', tr('خلفية التطبيق'), palette.background),
      _CustomColorField(
          'surfaceColor', tr('البطاقات والأسطح'), palette.surface),
      _CustomColorField(
          'navigationColor', tr('شريط التنقل السفلي'), palette.navigation),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('تخصيص الألوان'),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(tr('اختياري — اختر بصريًا بدون أكواد أو أرقام.'),
                      style: TextStyle(
                          color: context.hubScheme.onSurfaceVariant,
                          fontSize: 12.5)),
                ],
              ),
            ),
            if (controller.preferences.customColors.isNotEmpty)
              TextButton(
                onPressed: controller.saving
                    ? null
                    : () => controller.clearCustomColors(),
                child: Text(tr('إعادة الضبط')),
              ),
          ],
        ),
        const SizedBox(height: HubSpace.sm),
        for (final field in fields)
          _ColorFieldTile(
            field: field,
            customized:
                controller.preferences.customColors.containsKey(field.key),
            enabled: !controller.saving,
            onTap: () => _pickColor(context, field),
          ),
      ],
    );
  }

  Future<void> _pickColor(BuildContext context, _CustomColorField field) async {
    final brightness = Theme.of(context).brightness;
    final colors = _colorChoices(field.key, brightness);
    final selected = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.label,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(tr('اختر اللون المناسب وسيُطبّق مباشرة.'),
                  style: TextStyle(
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 18),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in colors)
                      Semantics(
                        button: true,
                        selected: color.toARGB32() == field.color.toARGB32(),
                        label: field.label,
                        child: InkWell(
                          onTap: () => Navigator.pop(sheetContext, color),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Theme.of(sheetContext)
                                      .colorScheme
                                      .outlineVariant,
                                  width: 2),
                            ),
                            child: color.toARGB32() == field.color.toARGB32()
                                ? Icon(Icons.check_rounded,
                                    color: ThemeContrastValidator.readableText(
                                        color))
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (controller.preferences.customColors
                  .containsKey(field.key)) ...[
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      controller.clearCustomColor(field.key);
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(tr('استخدام لون اللوحة الجاهزة')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await controller.setCustomColor(field.key, selected);
    }
  }

  List<Color> _colorChoices(String key, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (key == 'backgroundColor' ||
        key == 'surfaceColor' ||
        key == 'navigationColor') {
      return dark
          ? const [
              Color(0xFF0B0C0E),
              Color(0xFF121417),
              Color(0xFF16181B),
              Color(0xFF1A1C20),
              Color(0xFF202226),
              Color(0xFF15121C),
              Color(0xFF191411),
              Color(0xFF141820),
            ]
          : const [
              Color(0xFFFFFFFF),
              Color(0xFFF7F7F9),
              Color(0xFFF4F2FA),
              Color(0xFFF1F8F5),
              Color(0xFFFAF4F0),
              Color(0xFFF3F6FB),
              Color(0xFFFFF8E8),
              Color(0xFFF5F5F5),
            ];
    }
    if (key == 'sentMessageBubble' || key == 'receivedMessageBubble') {
      return dark
          ? const [
              Color(0xFF203D36),
              Color(0xFF252B52),
              Color(0xFF352252),
              Color(0xFF45291F),
              Color(0xFF17354A),
              Color(0xFF3A2430),
              Color(0xFF202126),
              Color(0xFF2B3038),
            ]
          : const [
              Color(0xFFE2F6EF),
              Color(0xFFE9ECFF),
              Color(0xFFEFE7FF),
              Color(0xFFF7E2D6),
              Color(0xFFE3F3FF),
              Color(0xFFFFE7F0),
              Color(0xFFFFFFFF),
              Color(0xFFF0F1F4),
            ];
    }
    return const [
      Color(0xFF7FC1AC),
      Color(0xFF5FA88F),
      Color(0xFF4C63FF),
      Color(0xFF1677D2),
      Color(0xFF36A886),
      Color(0xFF087A5B),
      Color(0xFFB85F35),
      Color(0xFFE07A48),
      Color(0xFFD84A68),
      Color(0xFFB33EA4),
      Color(0xFF334155),
      Color(0xFF111827),
    ];
  }
}

class _CustomColorField {
  const _CustomColorField(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;
}

class _ColorFieldTile extends StatelessWidget {
  const _ColorFieldTile({
    required this.field,
    required this.customized,
    required this.enabled,
    required this.onTap,
  });
  final _CustomColorField field;
  final bool customized;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: context.hubScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(HubRadius.md),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(HubRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: field.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.hubScheme.outlineVariant, width: 2),
                    ),
                    child: customized
                        ? Icon(Icons.check_rounded,
                            size: 18,
                            color: ThemeContrastValidator.readableText(
                                field.color))
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(field.label,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  Icon(Icons.chevron_right_rounded,
                      color: context.hubScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
      );
}
