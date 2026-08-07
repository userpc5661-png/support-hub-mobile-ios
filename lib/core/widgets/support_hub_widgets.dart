import 'package:flutter/material.dart';
import '../theme/support_hub_design.dart';
import '../network/api_client.dart';

/// Primary Wasl brand mark. It uses the approved artwork supplied for the app
/// and keeps the old [SupportHubMark] name as a compatibility alias so existing
/// screens do not break while the product is being rebranded.
class WaslLogoMark extends StatelessWidget {
  const WaslLogoMark({
    super.key,
    this.size = 48,
    this.onDark = false,
    this.circular = false,
  });

  final double size;
  final bool onDark;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final asset = circular
        ? 'assets/branding/wasl_logo_circle.png'
        : 'assets/branding/wasl_logo.png';
    final radius = circular ? size / 2 : size * .22;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
          semanticLabel: 'Wasl',
        ),
      ),
    );
  }
}

class SupportHubMark extends WaslLogoMark {
  const SupportHubMark({
    super.key,
    super.size = 48,
    super.onDark = false,
    super.circular = false,
  });
}

class HubAvatar extends StatelessWidget {
  const HubAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.online = false,
    this.color,
    this.imageUrl,
    this.api,
  });

  final String name;
  final double size;
  final bool online;
  final Color? color;
  final String? imageUrl;
  final ApiClient? api;

  @override
  Widget build(BuildContext context) {
    final seed = name.runes.fold<int>(0, (sum, rune) => sum + rune);
    final tones = [
      const Color(0xFF7FC1AC),
      const Color(0xFF007AFF),
      const Color(0xFF58BCA2),
      const Color(0xFF7D64C8),
      const Color(0xFFE08A5F),
    ];
    final tone = color ?? tones[seed % tones.length];
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _AvatarFace(
          name: name,
          letter: letter,
          size: size,
          tone: tone,
          imageUrl: imageUrl,
          api: api,
        ),
        if (online)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: size * .28,
              height: size * .28,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                shape: BoxShape.circle,
                border: Border.all(
                    color: context.hubScheme.surface, width: size * .06),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarFace extends StatefulWidget {
  const _AvatarFace({
    required this.name,
    required this.letter,
    required this.size,
    required this.tone,
    this.imageUrl,
    this.api,
  });

  final String name;
  final String letter;
  final double size;
  final Color tone;
  final String? imageUrl;
  final ApiClient? api;

  @override
  State<_AvatarFace> createState() => _AvatarFaceState();
}

class _AvatarFaceState extends State<_AvatarFace> {
  Future<AuthenticatedMediaRequest>? source;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _AvatarFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.api != widget.api) {
      _prepare();
    }
  }

  void _prepare() {
    final value = widget.imageUrl?.trim();
    source = value == null || value.isEmpty
        ? null
        : widget.api?.mediaRequest(value) ??
            Future.value(AuthenticatedMediaRequest(url: value, headers: const {}));
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.tone.withValues(alpha: .1),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.tone.withValues(alpha: .15),
          width: 1.5,
        ),
      ),
      child: Text(
        widget.letter,
        style: TextStyle(
          color: widget.tone,
          fontSize: widget.size * .42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (source == null) return fallback;
    return FutureBuilder<AuthenticatedMediaRequest>(
      future: source,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return fallback;
        final request = snapshot.data!;
        return ClipOval(
          child: Image.network(
            request.url,
            headers: request.headers,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: (widget.size * 3).round(),
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      },
    );
  }
}

class HubPageHeader extends StatelessWidget {
  const HubPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            HubSpace.md, HubSpace.lg, HubSpace.md, HubSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.hubText.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  if (subtitle?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.hubText.bodySmall?.copyWith(
                            color: context.hubScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
}

class HubIconButton extends StatelessWidget {
  const HubIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: context.hubScheme.surfaceContainerLow,
          foregroundColor: context.hubScheme.onSurface,
          fixedSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HubRadius.md)),
        ),
        icon: Icon(icon, size: 21),
      );
}

class HubEmptyState extends StatelessWidget {
  const HubEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HubSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.hubScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: context.hubScheme.onPrimary, size: 30),
              ),
              const SizedBox(height: HubSpace.lg),
              Text(title,
                  textAlign: TextAlign.center,
                  style: context.hubText.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: HubSpace.xs),
              Text(body,
                  textAlign: TextAlign.center,
                  style: context.hubText.bodyMedium?.copyWith(
                      color: context.hubScheme.onSurfaceVariant, height: 1.6)),
              if (action != null) ...[
                const SizedBox(height: HubSpace.lg),
                action!,
              ],
            ],
          ),
        ),
      );
}
