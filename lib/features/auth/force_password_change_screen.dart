import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/workspace_page.dart';
import 'auth_controller.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  final key = GlobalKey<FormState>();
  bool obscure = true;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorkspacePage(
        title: tr('تأمين الحساب'),
        subtitle: tr('عيّن كلمة مرور قوية قبل متابعة استخدام النظام'),
        icon: Icons.security_rounded,
        accent: const Color(0xFF0F766E),
        showBackButton: false,
        maxContentWidth: 760,
        actions: [
          const LanguageSwitcherButton(),
          IconButton(
              onPressed: widget.controller.logout,
              tooltip: tr('تسجيل الخروج'),
              icon: const Icon(Icons.logout_rounded))
        ],
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: key,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.security, size: 58),
                          const SizedBox(height: 16),
                          Text(tr('غيّر كلمة المرور الافتراضية'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                              tr('لن تظهر بقية لوحة التحكم قبل تعيين كلمة مرور قوية خاصة بك.'),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          TextFormField(
                              controller: current,
                              obscureText: true,
                              decoration: InputDecoration(
                                  labelText: tr('كلمة المرور الحالية')),
                              validator: (v) =>
                                  v == null || v.isEmpty ? tr('مطلوبة') : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: next,
                              obscureText: obscure,
                              decoration: InputDecoration(
                                  labelText: tr('كلمة المرور الجديدة'),
                                  suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(obscure
                                          ? Icons.visibility
                                          : Icons.visibility_off))),
                              validator: (v) => v == null || v.length < 8
                                  ? tr('8 أحرف على الأقل')
                                  : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: confirm,
                              obscureText: obscure,
                              decoration: InputDecoration(
                                  labelText: tr('تأكيد كلمة المرور')),
                              validator: (v) => v != next.text
                                  ? tr('التأكيد غير مطابق')
                                  : null),
                          if (widget.controller.error != null) ...[
                            const SizedBox(height: 12),
                            Text(widget.controller.error!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                                textAlign: TextAlign.center)
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                              onPressed:
                                  widget.controller.busy ? null : _submit,
                              icon: const Icon(Icons.check),
                              label: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(tr('حفظ والمتابعة')))),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _submit() async {
    if (key.currentState?.validate() != true) return;
    await widget.controller.changePassword(current.text, next.text);
  }
}
