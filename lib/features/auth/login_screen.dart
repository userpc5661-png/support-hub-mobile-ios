import 'package:flutter/material.dart';

import '../../core/localization/app_locale_controller.dart';
import '../../core/theme/support_hub_design.dart';
import '../../core/widgets/support_hub_widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure = true;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.savedAccounts;
    return Scaffold(
      backgroundColor: context.hubScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Stack(
          children: [
            PositionedDirectional(
              top: 12,
              end: 18,
              child: const LanguageSwitcherButton(showLabel: true),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 84, 24, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const WaslLogoMark(size: 68, circular: true),
                          const SizedBox(width: 14),
                          Text(
                            'Wasl',
                            textDirection: TextDirection.ltr,
                            style: context.hubText.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.6,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        tr('أهلًا بك في وصل'),
                        textAlign: TextAlign.center,
                        style: context.hubText.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('ادخل إلى دردشات عملائك وابدأ العمل مباشرة.'),
                        textAlign: TextAlign.center,
                        style: context.hubText.bodyMedium?.copyWith(
                          color: context.hubScheme.onSurfaceVariant,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (accounts.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        Text(
                          tr('الحسابات المحفوظة'),
                          style: context.hubText.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...accounts.map(
                          (account) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Material(
                              color: context.hubScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: widget.controller.busy
                                    ? null
                                    : () => widget.controller
                                        .switchAccount(account.id),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 68,
                                  ),
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    13,
                                    9,
                                    7,
                                    9,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: context.hubScheme.outlineVariant
                                          .withValues(alpha: .55),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      HubAvatar(name: account.name, size: 46),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              account.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '@${account.username}',
                                              textDirection: TextDirection.ltr,
                                              style: TextStyle(
                                                color: context.hubScheme
                                                    .onSurfaceVariant,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: tr('إزالة الحساب المحفوظ'),
                                        onPressed: () => widget.controller
                                            .removeSavedAccount(account.id),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: context.hubScheme.outlineVariant,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                tr('استخدام حساب آخر'),
                                style: TextStyle(
                                  color:
                                      context.hubScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: context.hubScheme.outlineVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: username,
                              textDirection: TextDirection.ltr,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: tr('اسم المستخدم'),
                                prefixIcon:
                                    const Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 3
                                      ? tr('أدخل اسم مستخدم صالحًا')
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: password,
                              obscureText: obscure,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: tr('كلمة المرور'),
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => obscure = !obscure),
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? tr('أدخل كلمة المرور')
                                      : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (widget.controller.error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.hubScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  widget.controller.error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        context.hubScheme.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                onPressed: widget.controller.busy
                                    ? null
                                    : _submit,
                                child: widget.controller.busy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : Text(
                                        tr('تسجيل الدخول'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    await widget.controller.login(username.text, password.text);
  }
}
