import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/theme/support_hub_design.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/support_hub_widgets.dart';
import '../auth/auth_controller.dart';
import '../employees/employee_model.dart';
import '../settings/settings_screen.dart';
import '../settings/chat_appearance_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.controller,
    required this.api,
    this.themeController,
    this.pushNotifications,
  });

  final AuthController controller;
  final ApiClient api;
  final ThemeController? themeController;
  final PushNotificationService? pushNotifications;

  @override
  Widget build(BuildContext context) {
    final user = controller.user!;
    return Scaffold(
      backgroundColor: context.hubScheme.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            HubPageHeader(
              title: tr('الحساب'),
              subtitle: user.storeName ?? tr('مساحة العمل'),
              leading: _RoundPageIcon(
                icon: Icons.manage_accounts_rounded,
                color: context.hubScheme.primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HubSpace.md),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.hubScheme.primary, context.hubScheme.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: context.hubScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _EditableProfileAvatar(
                      controller: controller,
                      api: api,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      textAlign: TextAlign.center,
                      style: context.hubText.headlineSmall?.copyWith(
                        color: context.hubScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.roleLabel}  •  @${user.username}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: context.hubScheme.onPrimary.withValues(alpha: .85),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HubSpace.lg),
            _SectionLabel(tr('التفضيلات')),
            _AccountGroup(children: [
              if (themeController != null)
                _AccountTile(
                  icon: Icons.palette_outlined,
                  title: tr('المظهر والتخصيص'),
                  subtitle: tr('الألوان والوضع الداكن واللغة'),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        SettingsScreen(
                          themeController: themeController!,
                          pushNotifications: pushNotifications,
                        ),
                  )),
                ),
              _AccountTile(
                icon: Icons.wallpaper_rounded,
                title: tr('مظهر الدردشة'),
                subtitle: tr('خلفية الدردشة وألوان الرسائل وحجم الخط'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChatAppearanceScreen(),
                  ),
                ),
              ),
              if (user.role != 'employee') ...[
                _AccountTile(
                  icon: Icons.alternate_email_rounded,
                  title: tr('تغيير اسم المستخدم'),
                  subtitle: '@${user.username}',
                  onTap: () => _changeUsername(context),
                ),
                _AccountTile(
                  icon: Icons.lock_outline_rounded,
                  title: tr('تغيير كلمة المرور'),
                  subtitle: tr('حافظ على أمان حسابك'),
                  onTap: () => _changePassword(context),
                ),
              ],
            ]),
            const SizedBox(height: HubSpace.lg),
            _SectionLabel(tr('معلومات الحساب')),
            _AccountGroup(children: [
              if ((user.email ?? '').isNotEmpty)
                _AccountTile(
                  icon: Icons.mail_outline_rounded,
                  title: tr('البريد الإلكتروني'),
                  subtitle: user.email!,
                ),
              _AccountTile(
                icon: Icons.verified_user_outlined,
                title: tr('الدور والصلاحيات'),
                subtitle: tr('${user.permissions.length} صلاحية مفعلة'),
                onTap: () => _showPermissions(context),
              ),
            ]),
            const SizedBox(height: HubSpace.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HubSpace.md),
              child: OutlinedButton.icon(
                onPressed: controller.logout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(tr('تسجيل الخروج')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.hubScheme.error,
                  side: BorderSide(
                      color: context.hubScheme.error.withValues(alpha: .35)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissions(BuildContext context) {
    final permissions = controller.user!.permissions;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              HubSpace.lg, 0, HubSpace.lg, HubSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('الصلاحيات المفعلة'),
                  style: context.hubText.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: HubSpace.md),
              if (permissions.isEmpty)
                Text(tr('لا توجد صلاحيات مخصصة لهذا الحساب.'))
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .55),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: HubSpace.xs,
                      runSpacing: HubSpace.xs,
                      children: permissions
                          .map((permission) => Chip(
                                avatar: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 17),
                                label: Text(permissionLabel(permission)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeUsername(BuildContext context) async {
    final username = TextEditingController(text: controller.user!.username);
    final password = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('تغيير اسم المستخدم')),
        content: SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: username,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: tr('اسم المستخدم الجديد')),
            ),
            const SizedBox(height: HubSpace.sm),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('كلمة المرور الحالية')),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, [username.text, password.text]),
              child: Text(tr('حفظ'))),
        ],
      ),
    );
    username.dispose();
    password.dispose();
    if (result == null || result[0].trim().length < 3 || result[1].isEmpty) {
      return;
    }
    final ok = await controller.changeUsername(result[0], result[1]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? tr('تم تغيير اسم المستخدم.')
              : controller.error ?? tr('تعذر التغيير.'))));
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('تغيير كلمة المرور')),
        content: SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: current,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: tr('كلمة المرور الحالية'))),
            const SizedBox(height: HubSpace.sm),
            TextField(
                controller: next,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: tr('كلمة المرور الجديدة'))),
            const SizedBox(height: HubSpace.sm),
            TextField(
                controller: confirm,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: tr('تأكيد كلمة المرور'))),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(
                  context, [current.text, next.text, confirm.text]),
              child: Text(tr('حفظ'))),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (result == null) return;
    if (result[1].length < 8 || result[1] != result[2]) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('تحقق من طول كلمة المرور وتطابق التأكيد.'))));
      }
      return;
    }
    final ok = await controller.changePassword(result[0], result[1]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? tr('تم تغيير كلمة المرور.')
              : controller.error ?? tr('تعذر التغيير.'))));
    }
  }
}


class _EditableProfileAvatar extends StatefulWidget {
  const _EditableProfileAvatar({required this.controller, required this.api});

  final AuthController controller;
  final ApiClient api;

  @override
  State<_EditableProfileAvatar> createState() =>
      _EditableProfileAvatarState();
}

class _EditableProfileAvatarState extends State<_EditableProfileAvatar> {
  final picker = ImagePicker();
  bool uploading = false;

  Future<void> _pick() async {
    if (uploading) return;
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1440,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError(tr('حجم الصورة يتجاوز 5 ميجابايت.'));
      }
      setState(() => uploading = true);
      final ok = await widget.controller.uploadAvatar(
        bytes: bytes,
        fileName: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? tr('تم تحديث الصورة الشخصية.')
              : widget.controller.error ?? tr('تعذر تحديث الصورة الشخصية.')),
        ),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    return Semantics(
      button: true,
      label: tr('تغيير الصورة الشخصية'),
      child: GestureDetector(
        onTap: _pick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            HubAvatar(
              name: user.name,
              imageUrl: user.avatarUrl,
              api: widget.api,
              size: 88,
              online: true,
              color: Colors.white,
            ),
            PositionedDirectional(
              end: -3,
              bottom: 1,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.hubScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.hubScheme.primary.withValues(alpha: .3),
                  ),
                ),
                child: uploading
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.camera_alt_rounded,
                        size: 17,
                        color: context.hubScheme.primary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundPageIcon extends StatelessWidget {
  const _RoundPageIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.fromLTRB(HubSpace.lg, 0, HubSpace.lg, HubSpace.xs),
        child: Text(label,
            style: TextStyle(
                color: context.hubScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700)),
      );
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: HubSpace.md),
        decoration: BoxDecoration(
          color: context.hubScheme.surface,
          borderRadius: BorderRadius.circular(HubRadius.lg),
          border: Border.all(
              color: context.hubScheme.outlineVariant.withValues(alpha: .38)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: HubSpace.md,
                  color:
                      context.hubScheme.outlineVariant.withValues(alpha: .38),
                ),
            ],
          ],
        ),
      );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: HubSpace.md, vertical: 5),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.hubScheme.primary,
            borderRadius: BorderRadius.circular(HubRadius.sm),
          ),
          child: Icon(icon, color: context.hubScheme.onPrimary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: subtitle.startsWith('@') || subtitle.contains('@')
                ? TextDirection.ltr
                : null),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded, size: 21),
      );
}
