import 'package:flutter/material.dart';

import '../../core/localization/app_locale_controller.dart';
import '../../core/theme/chat_appearance_controller.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/theme/support_hub_design.dart';

class ChatAppearanceScreen extends StatelessWidget {
  const ChatAppearanceScreen({super.key});

  static const sentColors = [
    Color(0xFFDDF3EC),
    Color(0xFF173A32),
    Color(0xFFD8F4EE),
    Color(0xFFE7E1FF),
    Color(0xFFFFE7CE),
    Color(0xFF005C4B),
  ];
  static const receivedColors = [
    Color(0xFFFFFFFF),
    Color(0xFF16181B),
    Color(0xFFEAF4F1),
    Color(0xFFF0ECFA),
    Color(0xFFFFF5EA),
    Color(0xFF202C33),
  ];
  static const backgroundColors = [
    Color(0xFFF7FAF9),
    Color(0xFFE8F1EE),
    Color(0xFFE9EEF4),
    Color(0xFFF2EEE9),
    Color(0xFF0B0C0E),
    Color(0xFF121417),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ChatAppearanceController.instance;
    return Scaffold(
      appBar: AppBar(title: Text(tr('مظهر الدردشة'))),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final brightness = Theme.of(context).brightness;
            final themeColors =
                Theme.of(context).extension<SupportHubThemeColors>()!;
            final themeBackground = context.hubScheme.surfaceContainerLowest;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                HubSpace.md,
                HubSpace.sm,
                HubSpace.md,
                HubSpace.xl,
              ),
              children: [
                _Preview(
                  controller: controller,
                  brightness: brightness,
                  sentFallback: themeColors.sentMessageBubble,
                  receivedFallback: themeColors.receivedMessageBubble,
                  backgroundFallback: themeBackground,
                ),
                const SizedBox(height: HubSpace.lg),
                _ColorSection(
                  title: tr('لون الرسائل المرسلة'),
                  colors: sentColors,
                  selected: controller.sent(brightness, fallback: themeColors.sentMessageBubble),
                  onSelected: controller.setSent,
                ),
                _ColorSection(
                  title: tr('لون الرسائل المستلمة'),
                  colors: receivedColors,
                  selected: controller.received(brightness, fallback: themeColors.receivedMessageBubble),
                  onSelected: controller.setReceived,
                ),
                _ColorSection(
                  title: tr('خلفية الدردشة'),
                  colors: backgroundColors,
                  selected: controller.background(brightness, fallback: themeBackground),
                  onSelected: controller.setBackground,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(HubSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('حجم خط الرسائل'),
                          style: context.hubText.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: HubSpace.sm),
                        SegmentedButton<double>(
                          segments: [
                            ButtonSegment(value: .9, label: Text(tr('صغير'))),
                            ButtonSegment(value: 1, label: Text(tr('متوسط'))),
                            ButtonSegment(value: 1.12, label: Text(tr('كبير'))),
                          ],
                          selected: {controller.fontScale},
                          onSelectionChanged: (value) =>
                              controller.setFontScale(value.first),
                        ),
                        const SizedBox(height: HubSpace.sm),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: controller.patternEnabled,
                          onChanged: controller.setPatternEnabled,
                          title: Text(tr('نمط خفيف في الخلفية')),
                          subtitle: Text(tr('إظهار رسومات بسيطة وغير مزعجة')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: HubSpace.sm),
                OutlinedButton.icon(
                  onPressed: controller.reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(tr('استعادة الإعدادات الافتراضية')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorSection extends StatelessWidget {
  const _ColorSection({
    required this.title,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: HubSpace.sm),
        child: Padding(
          padding: const EdgeInsets.all(HubSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.hubText.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: HubSpace.md),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in colors)
                    InkWell(
                      onTap: () => onSelected(color),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected.toARGB32() == color.toARGB32()
                                ? context.hubScheme.primary
                                : context.hubScheme.outlineVariant,
                            width: selected.toARGB32() == color.toARGB32()
                                ? 3
                                : 1,
                          ),
                        ),
                        child: selected.toARGB32() == color.toARGB32()
                            ? Icon(
                                Icons.check_rounded,
                                color: color.computeLuminance() > .55
                                    ? Colors.black87
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.controller,
    required this.brightness,
    required this.sentFallback,
    required this.receivedFallback,
    required this.backgroundFallback,
  });

  final ChatAppearanceController controller;
  final Brightness brightness;
  final Color sentFallback;
  final Color receivedFallback;
  final Color backgroundFallback;

  @override
  Widget build(BuildContext context) => Container(
        height: 210,
        padding: const EdgeInsets.all(HubSpace.md),
        decoration: BoxDecoration(
          color: controller.background(brightness, fallback: backgroundFallback),
          borderRadius: BorderRadius.circular(HubRadius.lg),
          border: Border.all(color: context.hubScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _PreviewBubble(
                color: controller.received(brightness, fallback: receivedFallback),
                text: tr('مرحبًا، كيف أقدر أخدمك؟'),
                scale: controller.fontScale,
              ),
            ),
            const SizedBox(height: HubSpace.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _PreviewBubble(
                color: controller.sent(brightness, fallback: sentFallback),
                text: tr('أهلًا! أنا معك الآن.'),
                scale: controller.fontScale,
              ),
            ),
          ],
        ),
      );
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({
    required this.color,
    required this.text,
    required this.scale,
  });

  final Color color;
  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15 * scale,
            color: color.computeLuminance() > .5 ? Colors.black87 : Colors.white,
          ),
        ),
      );
}
