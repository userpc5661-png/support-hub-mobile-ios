import 'package:flutter/material.dart';
import '../icons/app_icons.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.accent = const Color(0xFF2447A7),
    this.maxContentWidth = 1440,
    this.showBackButton = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final Color accent;
  final double maxContentWidth;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pageAccent = Color.lerp(scheme.primary, accent, .12)!;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(
                  compact ? 12 : 22, 14, compact ? 12 : 22, 0),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: .65)),
              ),
              child: Row(
                children: [
                  if (showBackButton && canPop)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(AppIcons.back(context)),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          pageAccent,
                          Color.lerp(pageAccent, scheme.secondary, .52)!
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: pageAccent.withValues(alpha: .22),
                            blurRadius: 12,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 17 : 20,
                              fontWeight: FontWeight.w900),
                        ),
                        Text(
                          subtitle,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Container(
                    margin: EdgeInsets.all(compact ? 12 : 22),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: .58)),
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkspacePageIntro extends StatelessWidget {
  const WorkspacePageIntro({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.trailing,
    this.accent = const Color(0xFF2447A7),
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pageAccent = Color.lerp(scheme.primary, accent, .12)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pageAccent.withValues(alpha: .13),
            scheme.surfaceContainerLow
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: pageAccent, borderRadius: BorderRadius.circular(17)),
            child: Icon(icon, color: scheme.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(description,
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
