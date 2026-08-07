import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';
import 'meta_embedded_signup.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({
    super.key,
    required this.api,
  });

  final ApiClient api;

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

String _metaText(String arabic, String english) =>
    AppLocaleController.isArabic ? arabic : english;

String _safeMetaIdSuffix(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return 'missing';
  return text.substring(text.length > 6 ? text.length - 6 : 0);
}

class _MetaFailure {
  const _MetaFailure(this.code, this.title, this.message);

  final String code;
  final String title;
  final String message;
}

_MetaFailure _metaFailureFor(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();
  if (normalized.contains('platform_configuration_missing') ||
      normalized.contains('not configured') ||
      normalized.contains('meta is not fully configured')) {
    return _MetaFailure(
      'platform_configuration_missing',
      _metaText(
        'إعداد Meta غير مكتمل',
        'Meta setup is incomplete',
      ),
      _metaText(
        'ربط واتساب غير متاح حتى يضيف مالك المنصة App ID وApp Secret وConfiguration ID ورمز تحقق Webhook الصالحة.',
        'WhatsApp linking is unavailable until the platform owner adds a valid App ID, App Secret, Configuration ID, and webhook verification token.',
      ),
    );
  }
  if (normalized.contains('cancel')) {
    return _MetaFailure(
      'user_cancelled',
      _metaText('تم إلغاء الربط', 'Signup was cancelled'),
      _metaText(
        'ألغيت نافذة Meta قبل اكتمال الخطوات. يمكنك المحاولة مرة أخرى.',
        'The Meta window was closed before completion. You can try again.',
      ),
    );
  }
  if (normalized.contains('expired')) {
    return _MetaFailure(
      'session_expired',
      _metaText('انتهت جلسة الربط', 'Signup session expired'),
      _metaText(
        'انتهت مهلة جلسة Meta. ابدأ جلسة جديدة وأكمل الخطوات خلال عشر دقائق.',
        'The Meta session expired. Start a new session and finish within ten minutes.',
      ),
    );
  }
  if (normalized.contains('already active')) {
    return _MetaFailure(
      'session_active',
      _metaText('توجد جلسة ربط نشطة', 'A signup session is already active'),
      _metaText(
        'أكمل نافذة Meta المفتوحة أو انتظر انتهاء الجلسة الحالية قبل بدء جلسة جديدة.',
        'Finish the open Meta window or wait for the current session to end before starting again.',
      ),
    );
  }
  if (normalized.contains('permission') ||
      normalized.contains('grant access') ||
      normalized.contains('authorization')) {
    return _MetaFailure(
      'permission_denied',
      _metaText('الصلاحية غير كافية', 'Permission is missing'),
      _metaText(
        'لم يمنح الحساب صلاحية إدارة واتساب المطلوبة. استخدم حسابًا يملك صلاحية Admin ثم وافق على جميع الصلاحيات المطلوبة.',
        'The account did not grant WhatsApp management access. Use a Business Admin account and approve the requested permissions.',
      ),
    );
  }
  if (normalized.contains('business portfolio') ||
      normalized.contains('business_mismatch') ||
      normalized.contains('does not belong')) {
    return _MetaFailure(
      'business_mismatch',
      _metaText('Business Portfolio غير صحيح', 'Business Portfolio mismatch'),
      _metaText(
        'حساب واتساب أو الرقم لا يتبع Business Portfolio المختار. أعد المحاولة واختر الأصول التابعة لنفس النشاط.',
        'The WABA or phone does not belong to the selected Business Portfolio. Retry with assets from the same business.',
      ),
    );
  }
  if (normalized.contains('already connected') ||
      normalized.contains('already linked') ||
      normalized.contains('already used') ||
      normalized.contains('resource_in_use')) {
    return _MetaFailure(
      'resource_in_use',
      _metaText('الحساب أو الرقم مستخدم', 'Account or number is already used'),
      _metaText(
        'حساب واتساب أو الرقم مرتبط بمتجر آخر ولا يمكن مشاركته بين متجرين.',
        'The WABA or phone is already connected to another store and cannot be shared.',
      ),
    );
  }
  if (normalized.contains('pin')) {
    return _MetaFailure(
      'pin_required',
      _metaText('مطلوب PIN', 'PIN required'),
      _metaText(
        'يتطلب الرقم رمز التحقق بخطوتين المكوّن من 6 أرقام لإكمال التسجيل.',
        'This number requires its 6-digit two-step verification PIN.',
      ),
    );
  }
  return _MetaFailure(
    'meta_request_failed',
    _metaText('تعذر إكمال الربط', 'Could not finish signup'),
    _metaText(
      'لم تؤكد Meta عملية الربط. تحقق من الحساب والرقم ثم أعد المحاولة.',
      'Meta did not confirm the connection. Check the account and number, then retry.',
    ),
  );
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  Map<String, dynamic>? connection;
  bool loading = true;
  String? busyAction;
  String? connectionStage;
  String? error;
  String? connectionFailureCode;
  String? connectionFailureMessage;
  StreamSubscription<Map<String, dynamic>>? connectionStatusSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    connectionStatusSubscription =
        widget.api.eventStream('/meta/connection/events').listen((event) {
      if (event['type']?.toString() == 'connection.updated') {
        _load();
      }
    });
  }

  @override
  void dispose() {
    connectionStatusSubscription?.cancel();
    super.dispose();
  }

  bool get busy => busyAction != null;

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      connection = await widget.api.getOptionalMap('/meta/connection');
    } catch (exception) {
      error = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _connect() async {
    if (!isMetaEmbeddedSignupSupported) {
      _showMessage(
        _metaText(
          'الربط الرسمي متاح من لوحة الويب الآمنة.',
          'Official signup is available from the secure web dashboard.',
        ),
        error: true,
      );
      return;
    }

    await _perform('connect', () async {
      Map<String, dynamic>? session;
      var completed = false;
      try {
        setState(() {
          connectionFailureCode = null;
          connectionFailureMessage = null;
        });
        _setConnectionStage('creating_session');
        session = await widget.api.postMap('/meta/signup/sessions');
        final appId = session['appId']?.toString() ?? '';
        final configurationId = session['configurationId']?.toString() ?? '';
        final graphVersion = session['graphVersion']?.toString() ?? '';
        final state = session['state']?.toString() ?? '';
        debugPrint(
          '[Meta signup] Fresh session created: '
          'session=${_safeMetaIdSuffix(session['sessionId'])}, '
          'appId=…${_safeMetaIdSuffix(appId)}, '
          'configurationId=…${_safeMetaIdSuffix(configurationId)}, '
          'createdAt=${session['createdAt'] ?? 'unknown'}, '
          'expiresAt=${session['expiresAt'] ?? 'unknown'}',
        );
        if (appId.isEmpty ||
            configurationId.isEmpty ||
            graphVersion.isEmpty ||
            state.isEmpty) {
          throw StateError(
            _metaText(
              'إعداد Meta غير مكتمل في الخادم.',
              'Meta is not fully configured on the server.',
            ),
          );
        }

        _setConnectionStage('opening_meta');
        debugPrint('[Meta signup] Starting FB.login.');
        _setConnectionStage('waiting_for_user');
        final result = await startMetaEmbeddedSignup(
          appId: appId,
          configurationId: configurationId,
          graphVersion: graphVersion,
        );
        debugPrint(
          '[Meta signup] Meta callback received: '
          'authorizationCodeReceived=${result.code.isNotEmpty}.',
        );
        _setConnectionStage('account_verification');
        connection = await _completeSignupWithProgress(
          session['sessionId'].toString(),
          {
            'code': result.code,
            'state': state,
            'wabaId': result.wabaId,
            'phoneNumberId': result.phoneNumberId,
            'businessId': result.businessId,
          },
        );
        if (connection?['status'] == 'pin_required') {
          _setConnectionStage('pin_required');
          _showMessage(
            _metaText(
              'أدخل رمز التحقق بخطوتين المكوّن من 6 أرقام لإكمال الربط.',
              'Enter the 6-digit two-step verification PIN to finish connecting.',
            ),
          );
          completed = true;
          return;
        }
        _setConnectionStage('completed');
        completed = true;
        _showMessage(
          _metaText(
            'تم ربط واتساب عبر Meta بنجاح.',
            'WhatsApp was connected through Meta.',
          ),
        );
      } finally {
        if (!completed && session != null) {
          await widget.api
              .postMap('/meta/signup/sessions/${session['sessionId']}/cancel')
              .catchError((_) => <String, dynamic>{});
        }
        session = null;
        debugPrint('[Meta signup] Local signup session cleared.');
      }
    });
  }

  Future<void> _connectManually() async {
    final credentials = await _showManualMetaDialog();
    if (credentials == null) return;
    try {
      await _perform('manual_connect', () async {
        connection =
            await widget.api.postMap('/meta/manual/connect', credentials);
        final webhookPending =
            connection?['webhookStatus']?.toString() == 'pending';
        _showMessage(
          webhookPending
              ? _metaText(
                  'تم ربط حساب واتساب، لكن استقبال الرسائل لن يعمل حتى يتم إعداد Webhook عام.',
                  'WhatsApp is connected, but incoming messages will not work until a public webhook is configured.',
                )
              : _metaText(
                  'تم التحقق من البيانات وربط WhatsApp عبر Meta بنجاح.',
                  'The credentials were verified and WhatsApp was connected through Meta.',
                ),
        );
      });
    } finally {
      credentials['accessToken'] = '';
    }
  }

  Future<Map<String, String>?> _showManualMetaDialog() async {
    final waba = TextEditingController();
    final phone = TextEditingController();
    final token = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscureToken = true;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.settings_ethernet_rounded),
          title: Text(
              _metaText('الربط اليدوي عبر Meta', 'Manual connection via Meta')),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _metaText(
                        'جهّز البيانات من Meta Business قبل المتابعة:',
                        'Prepare these items in Meta Business before continuing:',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ...[
                      _metaText('أنشئ Meta App ثم أضف منتج WhatsApp.',
                          'Create a Meta App and add the WhatsApp product.'),
                      _metaText(
                          'أنشئ WhatsApp Business Account أو اختر حسابًا موجودًا.',
                          'Create or select a WhatsApp Business Account.'),
                      _metaText(
                          'أنشئ System User عند الحاجة وامنحه صلاحيات الحساب.',
                          'Create a System User if needed and grant it access.'),
                      _metaText(
                          'أنشئ Permanent Access Token بصلاحيتي إدارة ومراسلة WhatsApp.',
                          'Create a permanent token with WhatsApp management and messaging permissions.'),
                    ].map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    size: 18, color: Color(0xFF087A5B)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(step)),
                              ]),
                        )),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phone,
                      key: const Key('meta-manual-phone-id'),
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Phone Number ID',
                        helperText: _metaText(
                            'معرّف الرقم من WhatsApp Manager، وليس رقم الهاتف نفسه.',
                            'The ID shown in WhatsApp Manager, not the phone number itself.'),
                      ),
                      validator: _metaIdValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: waba,
                      key: const Key('meta-manual-waba-id'),
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp Business Account ID',
                        helperText: _metaText(
                            'معرّف WABA الذي يتبع له الرقم أعلاه.',
                            'The WABA ID that owns the phone number above.'),
                      ),
                      validator: _metaIdValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: token,
                      key: const Key('meta-manual-token'),
                      textDirection: TextDirection.ltr,
                      obscureText: obscureToken,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Permanent Access Token',
                        helperText: _metaText(
                            'يُشفّر الرمز قبل حفظه ولا يُعرض مرة أخرى.',
                            'The token is encrypted before storage and is never shown again.'),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                              () => obscureToken = !obscureToken),
                          icon: Icon(obscureToken
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => (value ?? '').trim().length < 20
                          ? _metaText('أدخل Access Token صالحًا.',
                              'Enter a valid access token.')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _metaText(
                        'سيقوم Wasl بالتحقق من الرمز والحساب والرقم عبر Graph API، ثم الاشتراك في Webhook قبل إنشاء الاتصال.',
                        'Wasl will verify the token, account, and number through Graph API, then subscribe the webhook before connecting.',
                      ),
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_metaText('إلغاء', 'Cancel'))),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, {
                  'phoneNumberId': phone.text.trim(),
                  'wabaId': waba.text.trim(),
                  'accessToken': token.text.trim(),
                });
              },
              icon: const Icon(Icons.verified_outlined),
              label: Text(_metaText('تحقق واربط', 'Verify and connect')),
            ),
          ],
        ),
      ),
    );
    waba.clear();
    phone.clear();
    token.clear();
    waba.dispose();
    phone.dispose();
    token.dispose();
    return result;
  }

  String? _metaIdValidator(String? value) {
    return RegExp(r'^\d{3,160}$').hasMatch((value ?? '').trim())
        ? null
        : _metaText('أدخل معرّفًا رقميًا صحيحًا من Meta.',
            'Enter a valid numeric ID from Meta.');
  }

  Future<Map<String, dynamic>> _completeSignupWithProgress(
    String sessionId,
    Map<String, dynamic> payload,
  ) async {
    var polling = false;
    final timer = Timer.periodic(const Duration(milliseconds: 450), (_) async {
      if (polling || !mounted) return;
      polling = true;
      try {
        final status = await widget.api.getMap(
          '/meta/signup/sessions/$sessionId/status',
        );
        final stage = status['stage']?.toString();
        if (stage != null && stage.isNotEmpty) _setConnectionStage(stage);
      } catch (_) {
        // The completion request remains authoritative.
      } finally {
        polling = false;
      }
    });
    try {
      return await widget.api.postMap('/meta/signup/complete', payload);
    } finally {
      timer.cancel();
    }
  }

  Future<void> _sync() => _perform('sync', () async {
        connection = await widget.api.postMap('/meta/sync');
        _showMessage(
          _metaText(
            'تم تحديث بيانات الاتصال.',
            'Connection details were refreshed.',
          ),
        );
      });

  Future<void> _submitPin(String pin) async {
    var oneTimePin = pin;
    try {
      await _perform('pin', () async {
        connection = await widget.api.postMap(
          '/meta/signup/pin',
          {'pin': oneTimePin},
        );
        _showMessage(
          _metaText(
            'تم التحقق من PIN وربط واتساب بنجاح.',
            'The PIN was verified and WhatsApp is now connected.',
          ),
        );
      });
    } finally {
      oneTimePin = '';
    }
  }

  Future<void> _test() => _perform('test', () async {
        final result = await widget.api.postMap('/meta/test');
        final next = result['connection'];
        if (next is Map) connection = Map<String, dynamic>.from(next);
        _showMessage(
          result['success'] == true
              ? _metaText(
                  'الاتصال يعمل بصورة صحيحة.',
                  'The connection is working correctly.',
                )
              : _metaText(
                  'يحتاج الاتصال إلى مراجعة.',
                  'The connection needs attention.',
                ),
          error: result['success'] != true,
        );
      });

  Future<void> _sendTestMessage() async {
    final recipient = TextEditingController();
    final message = TextEditingController(
      text: _metaText(
        'رسالة اختبار من Wasl',
        'Test message from Wasl',
      ),
    );
    final formKey = GlobalKey<FormState>();
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.send_rounded),
        title: Text(_metaText('إرسال رسالة اختبار', 'Send a test message')),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('meta-test-recipient'),
                  controller: recipient,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _metaText(
                      'رقم المستلم مع رمز الدولة',
                      'Recipient with country code',
                    ),
                    hintText: '9665XXXXXXXX',
                  ),
                  validator: (value) {
                    final normalized =
                        (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    return normalized.length >= 8 && normalized.length <= 30
                        ? null
                        : _metaText(
                            'أدخل رقمًا صحيحًا مع رمز الدولة.',
                            'Enter a valid number with its country code.',
                          );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: message,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _metaText('نص الرسالة', 'Message'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_metaText('إلغاء', 'Cancel')),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, {
                'to': recipient.text.replaceAll(RegExp(r'[^0-9]'), ''),
                'body': message.text.trim(),
              });
            },
            icon: const Icon(Icons.send_rounded),
            label: Text(_metaText('إرسال', 'Send')),
          ),
        ],
      ),
    );
    recipient.clear();
    message.clear();
    recipient.dispose();
    message.dispose();
    if (payload == null) return;
    await _perform('send_test', () async {
      await widget.api.postMap('/whatsapp/send-test', payload);
      _showMessage(
        _metaText(
          'تم إرسال رسالة الاختبار بنجاح.',
          'The test message was sent successfully.',
        ),
      );
    });
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.link_off_rounded),
        title: Text(
          _metaText(
            'فصل حساب Meta؟',
            'Disconnect Meta?',
          ),
        ),
        content: Text(
          _metaText(
            'سيتوقف استقبال وإرسال الرسائل الجديدة. لن تُحذف المحادثات أو الرسائل المحفوظة.',
            'New messages will stop. Existing conversations and messages will remain.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_metaText('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_metaText('تأكيد الفصل', 'Disconnect')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform('disconnect', () async {
      await widget.api.postMap('/meta/disconnect', {'confirm': true});
      connection = null;
      _showMessage(
        _metaText(
          'تم فصل حساب Meta بأمان.',
          'Meta was disconnected safely.',
        ),
      );
    });
  }

  Future<void> _perform(
    String action,
    Future<void> Function() operation,
  ) async {
    if (busy) return;
    setState(() {
      busyAction = action;
      error = null;
    });
    try {
      await operation();
    } catch (exception) {
      if (!mounted) return;
      if (action == 'connect') {
        final failure = _metaFailureFor(exception);
        setState(() {
          connectionFailureCode = failure.code;
          connectionFailureMessage = failure.message;
        });
        _showMessage(failure.message, error: true);
      } else if (action == 'manual_connect') {
        _showMessage(_manualConnectionError(exception), error: true);
      } else {
        _showMessage(exception.toString(), error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          busyAction = null;
          if (action == 'connect' &&
              connectionFailureCode == null &&
              connection?['status'] != 'pin_required') {
            connectionStage = null;
          }
        });
      }
    }
  }

  String _manualConnectionError(Object exception) {
    final message = exception.toString();
    final normalized = message.toLowerCase();
    if (normalized.contains('authorization is not valid') ||
        normalized.contains('error validating access token') ||
        normalized.contains('invalid oauth')) {
      return _metaText(
        'رمز Access Token غير صالح أو منتهي. أنشئ رمزًا دائمًا جديدًا من System User.',
        'The access token is invalid or expired. Create a new permanent System User token.',
      );
    }
    if (normalized.contains('missing required permissions') ||
        normalized.contains('permission')) {
      return _metaText(
        'الرمز لا يملك الصلاحيات المطلوبة. فعّل whatsapp_business_management وwhatsapp_business_messaging.',
        'The token is missing required permissions. Enable whatsapp_business_management and whatsapp_business_messaging.',
      );
    }
    if (normalized.contains('does not belong')) {
      return _metaText(
        'Phone Number ID لا يتبع WhatsApp Business Account ID المدخل. راجع المعرّفين في WhatsApp Manager.',
        'The Phone Number ID does not belong to the supplied WhatsApp Business Account. Check both IDs in WhatsApp Manager.',
      );
    }
    if (normalized.contains('already connected') ||
        normalized.contains('already in use')) {
      return _metaText(
        'حساب WhatsApp أو الرقم مرتبط بمتجر آخر ولا يمكن استخدامه مرتين.',
        'This WhatsApp account or number is already connected to another store.',
      );
    }
    if (normalized.contains('not configured')) {
      return _metaText(
        'إعداد Meta في Wasl غير مكتمل. توصل مع مسؤول المنصة.',
        'Meta is not fully configured in Wasl. Contact the platform administrator.',
      );
    }
    if (normalized.contains('temporarily unavailable') ||
        normalized.contains('تعذر الاتصال')) {
      return _metaText(
        'تعذر الوصول إلى Meta حاليًا. تحقق من الاتصال وحاول مرة أخرى.',
        'Meta is currently unavailable. Check the connection and try again.',
      );
    }
    return _metaText(
      'لم تقبل Meta البيانات المدخلة. راجع المعرّفات والرمز والصلاحيات ثم حاول مرة أخرى.',
      'Meta rejected the supplied credentials. Check the IDs, token, and permissions, then try again.',
    );
  }

  void _setConnectionStage(String stage) {
    if (!mounted) return;
    setState(() => connectionStage = stage);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? scheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => WorkspacePage(
        title: _metaText('اتصال واتساب', 'WhatsApp connection'),
        subtitle: _metaText(
          'ربط رسمي وآمن مباشرةً عبر Meta',
          'Secure, official connection directly through Meta',
        ),
        icon: AppIcons.whatsApp,
        accent: const Color(0xFF16A46D),
        actions: [
          IconButton(
            onPressed: loading || busy ? null : _load,
            tooltip: _metaText('تحديث', 'Refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        body: loading
            ? const _MetaLoadingState()
            : error != null && connection == null
                ? _MetaErrorState(error: error!, onRetry: _load)
                : MetaConnectionView(
                    connection: connection,
                    busyAction: busyAction,
                    connectionStage: connectionStage,
                    failureCode: connectionFailureCode,
                    failureMessage: connectionFailureMessage,
                    onConnect: _connect,
                    onConnectManually: _connectManually,
                    onSubmitPin: _submitPin,
                    onSync: _sync,
                    onTest: _test,
                    onSendTest: _sendTestMessage,
                    onOpenManager: () => openWhatsAppManager(
                      businessId:
                          connection?['businessPortfolioId']?.toString() ?? '',
                      wabaId: connection?['wabaId']?.toString() ?? '',
                    ),
                    onDisconnect: _disconnect,
                  ),
      );
}

class MetaConnectionView extends StatelessWidget {
  const MetaConnectionView({
    super.key,
    required this.connection,
    required this.busyAction,
    required this.connectionStage,
    required this.failureCode,
    required this.failureMessage,
    required this.onConnect,
    required this.onConnectManually,
    required this.onSubmitPin,
    required this.onSync,
    required this.onTest,
    required this.onSendTest,
    required this.onOpenManager,
    required this.onDisconnect,
  });

  final Map<String, dynamic>? connection;
  final String? busyAction;
  final String? connectionStage;
  final String? failureCode;
  final String? failureMessage;
  final VoidCallback onConnect;
  final VoidCallback onConnectManually;
  final Future<void> Function(String pin) onSubmitPin;
  final VoidCallback onSync;
  final VoidCallback onTest;
  final VoidCallback onSendTest;
  final Future<void> Function() onOpenManager;
  final VoidCallback onDisconnect;

  bool get connected =>
      connection != null && connection!['status'] == 'connected';

  bool get _hasRequiredAssets {
    if (connection == null) return false;
    final wabaId = connection!['wabaId']?.toString().trim() ?? '';
    final phones = connection!['phoneNumbers'] as List? ?? const [];
    return wabaId.isNotEmpty &&
        phones.whereType<Map>().any(
              (phone) =>
                  (phone['phoneNumberId']?.toString().trim() ?? '').isNotEmpty,
            );
  }

  bool get _shouldShowOnboarding {
    if (connection == null) return true;
    final status = connection!['status']?.toString() ?? 'disconnected';
    if (status == 'disconnected') return true;
    if (status == 'pin_required') return false;
    if (status == 'error' &&
        connection!['lastErrorCode'] == 'pin_attempt_limit') {
      return false;
    }
    return !_hasRequiredAssets;
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShowOnboarding) return _buildDisconnected(context);
    final status = connection!['status']?.toString();
    if (status == 'pin_required' ||
        (status == 'error' &&
            connection!['lastErrorCode'] == 'pin_attempt_limit')) {
      return _MetaPinRequiredView(
        locked: status == 'error',
        attemptsRemaining:
            (connection!['pinAttemptsRemaining'] as num?)?.toInt() ?? 3,
        busy: busyAction != null,
        onSubmit: onSubmitPin,
        onRestart: onConnect,
        onDisconnect: onDisconnect,
      );
    }
    return _buildConnection(context);
  }

  Widget _buildDisconnected(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      key: const Key('meta-disconnected-view'),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF075E54).withValues(alpha: .16),
                scheme.surfaceContainerLow,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mark = Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF087A5B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusPill(
                    icon: Icons.verified_user_outlined,
                    label: _metaText(
                      'إعداد رسمي وآمن من Meta',
                      'Official, secure Meta setup',
                    ),
                    color: const Color(0xFF087A5B),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _metaText(
                      'لنبدأ ربط WhatsApp Business',
                      'Let’s connect WhatsApp Business',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _metaText(
                      'اختر المسار المناسب لك. ستتم جميع خطوات الحساب والرقم داخل نافذة Meta الرسمية ثم تعود تلقائيًا إلى Wasl.',
                      'Choose the path that fits you. Account and phone setup happens in Meta’s official window, then you return automatically.',
                    ),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [mark, const SizedBox(height: 18), details],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mark,
                  const SizedBox(width: 18),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ),
        if (connectionStage != null) ...[
          const SizedBox(height: 18),
          _MetaSignupProgress(
            stage: connectionStage!,
            failed: failureCode != null,
          ),
        ],
        if (failureCode != null) ...[
          const SizedBox(height: 18),
          _MetaFailureCard(
            code: failureCode!,
            message: failureMessage ?? '',
            onRetry: failureCode == 'platform_configuration_missing'
                ? null
                : busyAction == null
                    ? onConnect
                    : null,
          ),
        ],
        const SizedBox(height: 20),
        _OnboardingOptions(
          busy: busyAction == 'connect',
          onStart: onConnect,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('meta-manual-connect'),
          onPressed: busyAction == null ? onConnectManually : null,
          icon: const Icon(Icons.settings_ethernet_rounded),
          label: Text(
              _metaText('الربط اليدوي عبر Meta', 'Manual connection via Meta')),
        ),
        const SizedBox(height: 20),
        _SafetyCard(),
      ],
    );
  }

  Widget _buildConnection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final numbers = (connection!['phoneNumbers'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final primaryNumber = numbers.isEmpty
        ? null
        : numbers.firstWhere(
            (item) => item['isDefault'] == true,
            orElse: () => numbers.first,
          );
    final status = connection!['status']?.toString() ?? 'disconnected';
    final healthy = status == 'connected';
    final webhookSetup = connection!['webhookSetup'] is Map
        ? Map<String, dynamic>.from(connection!['webhookSetup'] as Map)
        : null;
    final businessId =
        connection!['businessPortfolioId']?.toString().trim() ?? '';
    final wabaId = connection!['wabaId']?.toString().trim() ?? '';
    final canOpenManager =
        healthy && businessId.isNotEmpty && wabaId.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async => onSync(),
      child: ListView(
        key: const Key('meta-connected-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: healthy
                  ? const Color(0xFF087A5B).withValues(alpha: .1)
                  : scheme.errorContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: healthy
                    ? const Color(0xFF23A87A)
                    : scheme.error.withValues(alpha: .45),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 18,
              runSpacing: 16,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor:
                          healthy ? const Color(0xFF087A5B) : scheme.error,
                      child: Icon(
                        healthy
                            ? Icons.check_rounded
                            : Icons.warning_amber_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          healthy
                              ? _metaText(
                                  'تم ربط WhatsApp بنجاح',
                                  'WhatsApp connected successfully',
                                )
                              : _metaText(
                                  'الاتصال يحتاج إجراء',
                                  'Connection needs attention',
                                ),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          connection!['displayName']?.toString() ??
                              primaryNumber?['verifiedName']?.toString() ??
                              _metaText('حساب النشاط', 'Business account'),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('meta-send-test-message'),
                      onPressed: busyAction == null ? onSendTest : null,
                      icon: busyAction == 'send_test'
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _metaText(
                          'إرسال رسالة اختبار',
                          'Send test message',
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busyAction == null ? onTest : null,
                      icon: busyAction == 'test'
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.health_and_safety_outlined),
                      label: Text(_metaText('اختبار الاتصال', 'Test')),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: busyAction == null ? onSync : null,
                      icon: busyAction == 'sync'
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(_metaText('مزامنة', 'Sync')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (connection!['webhookStatus']?.toString() == 'pending') ...[
            Card(
              key: const Key('meta-webhook-pending-notice'),
              color: scheme.secondaryContainer.withValues(alpha: .55),
              child: ListTile(
                leading: const Icon(Icons.webhook_outlined),
                title: Text(
                  _metaText(
                    'تم ربط حساب واتساب',
                    'WhatsApp account connected',
                  ),
                ),
                subtitle: Text(
                  _metaText(
                    'استقبال الرسائل لن يعمل حتى يتم إعداد Webhook عام في Meta.',
                    'Incoming messages will not work until a public webhook is configured in Meta.',
                  ),
                  key: const Key('meta-webhook-pending-message'),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 620
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ConnectionFact(
                    width: cardWidth,
                    icon: Icons.phone_outlined,
                    label: _metaText('الرقم المرتبط', 'Connected number'),
                    value:
                        primaryNumber?['displayPhoneNumber']?.toString() ?? '—',
                  ),
                  _ConnectionFact(
                    width: cardWidth,
                    icon: Icons.badge_outlined,
                    label: _metaText('الاسم المعروض', 'Display name'),
                    value: primaryNumber?['verifiedName']?.toString() ??
                        connection!['displayName']?.toString() ??
                        '—',
                  ),
                  _ConnectionFact(
                    width: cardWidth,
                    icon: Icons.webhook_outlined,
                    label: _metaText('استقبال الرسائل', 'Message delivery'),
                    value: _statusLabel(
                      connection!['webhookStatus']?.toString(),
                    ),
                  ),
                  _ConnectionFact(
                    width: cardWidth,
                    icon: Icons.shield_outlined,
                    label: _metaText('جودة الرقم', 'Number quality'),
                    value: primaryNumber?['qualityRating']?.toString() ?? '—',
                  ),
                  _ConnectionFact(
                    width: cardWidth,
                    icon: Icons.verified_outlined,
                    label: _metaText('حالة التحقق', 'Verification status'),
                    value: primaryNumber?['registrationStatus']?.toString() ??
                        primaryNumber?['nameStatus']?.toString() ??
                        '—',
                  ),
                  _ConnectionFact(
                    width: cardWidth,
                    icon: Icons.schedule_outlined,
                    label: _metaText('آخر مزامنة', 'Last sync'),
                    value: _formatDate(
                      connection!['lastSyncedAt'] ??
                          primaryNumber?['lastSyncedAt'],
                    ),
                  ),
                  _ConnectionFact(
                    width: cardWidth,
                    icon: Icons.link_rounded,
                    label: _metaText('تاريخ الربط', 'Connected on'),
                    value: _formatDate(connection!['connectedAt']),
                  ),
                ],
              );
            },
          ),
          if (webhookSetup != null) ...[
            const SizedBox(height: 18),
            _MetaWebhookSetupCard(
              setup: webhookSetup,
              wabaId: wabaId,
              phoneNumberId: primaryNumber?['phoneNumberId']?.toString() ?? '',
            ),
          ],
          if ((connection!['lastErrorMessage']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                color: scheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text(
                    _metaText(
                      'مطلوب إجراء',
                      'Action required',
                    ),
                  ),
                  subtitle: Text(connection!['lastErrorMessage'].toString()),
                ),
              ),
            ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canOpenManager)
                FilledButton.tonalIcon(
                  key: const Key('meta-open-manager'),
                  onPressed: onOpenManager,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    _metaText(
                      'فتح إدارة واتساب في Meta',
                      'Open WhatsApp Manager',
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: busyAction == null ? onDisconnect : null,
                icon: const Icon(Icons.link_off_rounded),
                label: Text(_metaText('فصل الحساب', 'Disconnect')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingOptions extends StatefulWidget {
  const _OnboardingOptions({
    required this.busy,
    required this.onStart,
  });

  final bool busy;
  final VoidCallback onStart;

  @override
  State<_OnboardingOptions> createState() => _OnboardingOptionsState();
}

class _OnboardingOptionsState extends State<_OnboardingOptions> {
  String? selectedPath;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 840
              ? constraints.maxWidth
              : (constraints.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _OnboardingChoiceCard(
                width: width,
                icon: Icons.person_add_alt_1_rounded,
                title: _metaText(
                  'ليس لدي حساب Meta أو WhatsApp Business',
                  'I’m new to Meta and WhatsApp Business',
                ),
                subtitle: _metaText(
                  'أنشئ الحساب والنشاط ورقم واتساب من البداية.',
                  'Create your account, business, and WhatsApp number.',
                ),
                steps: [
                  _metaText(
                    'ستفتح نافذة Meta الرسمية.',
                    'Meta’s official window will open.',
                  ),
                  _metaText(
                    'إذا لم يكن لديك حساب Facebook، اختر إنشاء حساب جديد وأكمل بياناتك.',
                    'If you do not have Facebook, create an account and complete your details.',
                  ),
                  _metaText(
                    'أنشئ Business Portfolio ليمثل نشاطك التجاري.',
                    'Create a Business Portfolio for your business.',
                  ),
                  _metaText(
                    'أنشئ WhatsApp Business Account داخل النشاط.',
                    'Create a WhatsApp Business Account inside the business.',
                  ),
                  _metaText(
                    'أضف رقم الهاتف وأدخل رمز التحقق المرسل إليه.',
                    'Add the phone and enter the verification code sent to it.',
                  ),
                  _metaText(
                    'وافق على الصلاحيات وستعود تلقائيًا إلى Wasl.',
                    'Approve access and return automatically to Wasl.',
                  ),
                ],
                notes: [
                  _metaText(
                    'استخدم رقمًا غير مربوط حاليًا بتطبيق WhatsApp أو منصة أخرى.',
                    'Use a number that is not currently linked to WhatsApp or another platform.',
                  ),
                  _metaText(
                    'احتفظ بالهاتف بجانبك لاستلام رمز التحقق.',
                    'Keep the phone nearby for the verification code.',
                  ),
                ],
                expanded: selectedPath == 'new',
                choiceKey: const Key('meta-new-account-guide'),
                actionKey: const Key('meta-create-account-button'),
                choiceLabel: _metaText(
                  'عرض خطوات إنشاء حساب جديد',
                  'Show new-account steps',
                ),
                actionLabel: _metaText(
                  'فهمت، ابدأ الربط عبر Meta',
                  'I understand — start with Meta',
                ),
                busy: widget.busy,
                onToggle: () => setState(
                  () => selectedPath = selectedPath == 'new' ? null : 'new',
                ),
                onPressed: widget.onStart,
              ),
              _OnboardingChoiceCard(
                width: width,
                icon: Icons.business_center_rounded,
                title: _metaText(
                  'لدي حساب Meta وWhatsApp Business',
                  'I already have Meta and WhatsApp Business',
                ),
                subtitle: _metaText(
                  'اربط النشاط والرقم الموجودين لديك.',
                  'Connect your existing business and number.',
                ),
                steps: [
                  _metaText(
                    'ستفتح نافذة Meta الرسمية، ثم سجّل الدخول إلى Facebook.',
                    'Meta’s official window opens; sign in to Facebook.',
                  ),
                  _metaText(
                    'اختر Business Portfolio الصحيح الذي تملك عليه صلاحية Admin.',
                    'Choose the correct Business Portfolio where you are an Admin.',
                  ),
                  _metaText(
                    'اختر WhatsApp Business Account التابع لنفس النشاط.',
                    'Choose the WhatsApp Business Account owned by that business.',
                  ),
                  _metaText(
                    'اختر الرقم الموجود، أو أضف رقمًا جديدًا وتحقق منه.',
                    'Choose the existing number, or add and verify a new one.',
                  ),
                  _metaText(
                    'وافق على الصلاحيات المطلوبة فقط.',
                    'Approve the requested permissions.',
                  ),
                  _metaText(
                    'ستعود تلقائيًا إلى Wasl وسيتم اختبار الاتصال.',
                    'Return automatically to Wasl for connection testing.',
                  ),
                ],
                notes: [
                  _metaText(
                    'سجّل الدخول بالحساب الذي يدير النشاط والرقم فعلًا.',
                    'Sign in with the account that actually manages the business and number.',
                  ),
                  _metaText(
                    'إذا لم يظهر النشاط، تحقق من صلاحية Admin في Meta Business Settings.',
                    'If the business is missing, verify Admin access in Meta Business Settings.',
                  ),
                ],
                expanded: selectedPath == 'existing',
                choiceKey: const Key('meta-existing-account-guide'),
                actionKey: const Key('meta-existing-account-button'),
                choiceLabel: _metaText(
                  'عرض خطوات ربط حساب موجود',
                  'Show existing-account steps',
                ),
                actionLabel: _metaText(
                  'فهمت، اربط حسابي عبر Meta',
                  'I understand — connect with Meta',
                ),
                busy: widget.busy,
                onToggle: () => setState(
                  () => selectedPath =
                      selectedPath == 'existing' ? null : 'existing',
                ),
                onPressed: widget.onStart,
              ),
            ],
          );
        },
      );
}

class _OnboardingChoiceCard extends StatelessWidget {
  const _OnboardingChoiceCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.notes,
    required this.expanded,
    required this.choiceKey,
    required this.actionKey,
    required this.choiceLabel,
    required this.actionLabel,
    required this.busy,
    required this.onToggle,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> steps;
  final List<String> notes;
  final bool expanded;
  final Key choiceKey;
  final Key actionKey;
  final String choiceLabel;
  final String actionLabel;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: expanded ? const Color(0xFF087A5B) : scheme.outlineVariant,
          width: expanded ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF087A5B).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: const Color(0xFF087A5B)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: choiceKey,
              onPressed: busy ? null : onToggle,
              icon: Icon(
                expanded ? Icons.expand_less_rounded : Icons.menu_book_rounded,
              ),
              label: Text(
                expanded ? _metaText('إخفاء الشرح', 'Hide steps') : choiceLabel,
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 18),
            for (final (index, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF087A5B),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (final note in notes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                color: scheme.onTertiaryContainer,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: actionKey,
                onPressed: busy ? null : onPressed,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                label: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaFailureCard extends StatelessWidget {
  const _MetaFailureCard({
    required this.code,
    required this.message,
    required this.onRetry,
  });

  final String code;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final presentation = _metaFailureFor(code);
    return Container(
      key: const Key('meta-failure-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.error.withValues(alpha: .45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 30),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(message.isEmpty ? presentation.message : message),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('meta-retry-button'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_metaText('إعادة المحاولة', 'Try again')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaSignupProgress extends StatelessWidget {
  const _MetaSignupProgress({
    required this.stage,
    this.failed = false,
  });

  final String stage;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stages = [
      (
        'creating_session',
        _metaText('إنشاء جلسة الربط', 'Creating signup session'),
      ),
      (
        'opening_meta',
        _metaText('فتح Meta', 'Opening Meta'),
      ),
      (
        'waiting_for_user',
        _metaText('انتظار موافقة المستخدم', 'Waiting for your approval'),
      ),
      (
        'account_verification',
        _metaText('التحقق من الحساب', 'Verifying the account'),
      ),
      (
        'phone_registration',
        _metaText('تسجيل الرقم', 'Registering the number'),
      ),
      (
        'webhook_subscription',
        _metaText('الاشتراك في Webhooks', 'Subscribing to webhooks'),
      ),
      (
        'connection_test',
        _metaText(
          'اختبار الاتصال',
          'Testing the connection',
        ),
      ),
      (
        'completed',
        _metaText('اكتمل الربط', 'Connection completed'),
      ),
    ];
    final matched = stages.indexWhere((item) => item.$1 == stage);
    final current = matched < 0 ? 0 : matched;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (final (index, item) in stages.indexed)
            Padding(
              padding:
                  EdgeInsets.only(bottom: index == stages.length - 1 ? 0 : 11),
              child: Row(
                key: Key('meta-progress-${item.$1}'),
                children: [
                  if (index < current || (!failed && stage == 'completed'))
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF087A5B), size: 21)
                  else if (index == current && failed)
                    Icon(Icons.error_rounded, color: scheme.error, size: 21)
                  else if (index == current)
                    const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  else
                    Icon(Icons.radio_button_unchecked_rounded,
                        color: scheme.outline, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        fontWeight: index == current
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: index > current ? scheme.outline : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaPinRequiredView extends StatefulWidget {
  const _MetaPinRequiredView({
    required this.locked,
    required this.attemptsRemaining,
    required this.busy,
    required this.onSubmit,
    required this.onRestart,
    required this.onDisconnect,
  });

  final bool locked;
  final int attemptsRemaining;
  final bool busy;
  final Future<void> Function(String pin) onSubmit;
  final VoidCallback onRestart;
  final VoidCallback onDisconnect;

  @override
  State<_MetaPinRequiredView> createState() => _MetaPinRequiredViewState();
}

class _MetaPinRequiredViewState extends State<_MetaPinRequiredView> {
  final pinController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure = true;

  @override
  void dispose() {
    pinController.clear();
    pinController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.busy ||
        widget.locked ||
        formKey.currentState?.validate() != true) {
      return;
    }
    var oneTimePin = pinController.text.trim();
    pinController.clear();
    try {
      await widget.onSubmit(oneTimePin);
    } finally {
      oneTimePin = '';
      pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      key: const Key('meta-pin-required-view'),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.locked ? scheme.error : scheme.primary,
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.locked ? Icons.lock_reset_rounded : Icons.pin_outlined,
                  size: 42,
                  color: widget.locked ? scheme.error : scheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.locked
                      ? _metaText(
                          'تم تجاوز عدد محاولات PIN',
                          'PIN attempt limit reached',
                        )
                      : _metaText(
                          'أدخل رمز التحقق بخطوتين',
                          'Enter the two-step verification PIN',
                        ),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.locked
                      ? _metaText(
                          'ابدأ ربط Meta من جديد للحصول على محاولة آمنة جديدة.',
                          'Start Meta signup again to create a new secure attempt.',
                        )
                      : _metaText(
                          'اكتب PIN المكوّن من 6 أرقام الذي عيّنته لرقم واتساب. لن يتم حفظه.',
                          'Enter the 6-digit PIN configured for this WhatsApp number. It will not be stored.',
                        ),
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                ),
                if (!widget.locked) ...[
                  const SizedBox(height: 22),
                  TextFormField(
                    key: const Key('meta-pin-field'),
                    controller: pinController,
                    enabled: !widget.busy,
                    obscureText: obscure,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [],
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        onPressed: widget.busy
                            ? null
                            : () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                            ? null
                            : _metaText(
                                'أدخل 6 أرقام بالضبط.',
                                'Enter exactly 6 digits.',
                              ),
                    onFieldSubmitted: (_) => submit(),
                  ),
                  Text(
                    _metaText(
                      'المحاولات المتبقية: ${widget.attemptsRemaining}',
                      'Attempts remaining: ${widget.attemptsRemaining}',
                    ),
                    style: TextStyle(
                      color: widget.attemptsRemaining <= 1
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const Key('meta-pin-submit'),
                    onPressed: widget.busy ? null : submit,
                    icon: widget.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(
                      _metaText(
                          'تحقق وأكمل الربط', 'Verify and finish connecting'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const Key('meta-pin-restart'),
                    onPressed: widget.busy ? null : widget.onRestart,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(
                      _metaText('ابدأ ربط Meta من جديد', 'Restart Meta signup'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: widget.busy ? null : widget.onDisconnect,
                  icon: const Icon(Icons.link_off_rounded),
                  label: Text(_metaText('إلغاء الربط', 'Cancel connection')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final facts = [
      (
        Icons.lock_outline_rounded,
        _metaText(
          'لا تُحفظ بيانات الدخول في المتصفح',
          'Login details are never stored in the browser',
        )
      ),
      (
        Icons.verified_user_outlined,
        _metaText(
          'الصلاحيات المطلوبة فقط',
          'Only the required permissions',
        )
      ),
      (
        Icons.account_tree_outlined,
        _metaText(
          'كل متجر معزول عن المتاجر الأخرى',
          'Every store remains isolated',
        )
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: facts
            .map(
              (fact) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(fact.$1, color: const Color(0xFF087A5B)),
                  const SizedBox(width: 9),
                  Text(fact.$2),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MetaWebhookSetupCard extends StatelessWidget {
  const _MetaWebhookSetupCard({
    required this.setup,
    required this.wabaId,
    required this.phoneNumberId,
  });

  final Map<String, dynamic> setup;
  final String wabaId;
  final String phoneNumberId;

  Future<void> _copy(
    BuildContext context,
    String label,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _metaText('تم نسخ $label', '$label copied'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final callbackUrl = setup['callbackUrl']?.toString() ?? '';
    final verifyToken = setup['verifyToken']?.toString() ?? '';
    final appId = setup['appId']?.toString() ?? '';
    final subscribedField = setup['subscribedField']?.toString() ?? 'messages';
    final configured = setup['configured'] == true;
    final temporaryUrl = setup['temporaryUrl'] == true;
    final fields = <({String label, String value, Key key})>[
      (
        label: _metaText('Callback URL', 'Callback URL'),
        value: callbackUrl,
        key: const Key('meta-copy-callback-url'),
      ),
      (
        label: _metaText('Verify Token', 'Verify Token'),
        value: verifyToken,
        key: const Key('meta-copy-verify-token'),
      ),
      (
        label: _metaText('App ID', 'App ID'),
        value: appId,
        key: const Key('meta-copy-app-id'),
      ),
      (
        label: _metaText('WABA ID', 'WABA ID'),
        value: wabaId,
        key: const Key('meta-copy-waba-id'),
      ),
      (
        label: _metaText('Phone Number ID', 'Phone Number ID'),
        value: phoneNumberId,
        key: const Key('meta-copy-phone-number-id'),
      ),
      (
        label: _metaText('حقل الاشتراك', 'Subscribed field'),
        value: subscribedField,
        key: const Key('meta-copy-subscribed-field'),
      ),
    ].where((field) => field.value.isNotEmpty).toList();

    return Card(
      key: const Key('meta-webhook-setup-card'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.webhook_rounded, color: scheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _metaText(
                          'إعداد Webhook في Meta',
                          'Meta webhook setup',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _metaText(
                          'انسخ القيم التالية والصقها في إعدادات WhatsApp داخل Meta.',
                          'Copy these values into WhatsApp settings in Meta.',
                        ),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!configured) ...[
              const SizedBox(height: 14),
              Text(
                _metaText(
                  'أكمل PUBLIC_BASE_URL وMETA_WEBHOOK_VERIFY_TOKEN أولًا.',
                  'Configure PUBLIC_BASE_URL and META_WEBHOOK_VERIFY_TOKEN first.',
                ),
                style:
                    TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
              ),
            ],
            if (temporaryUrl) ...[
              const SizedBox(height: 14),
              Text(
                _metaText(
                  'هذا رابط Cloudflare مؤقت. إذا تغيّر، حدّث Callback URL في Meta.',
                  'This Cloudflare URL is temporary. Update Meta when it changes.',
                ),
                style: TextStyle(
                    color: scheme.tertiary, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 16),
            for (final field in fields) ...[
              _MetaCopyField(
                label: field.label,
                value: field.value,
                copyKey: field.key,
                onCopy: () => _copy(context, field.label, field.value),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              _metaText(
                'في Meta اضغط Verify and save، ثم اشترك في الحقل messages. لا تشارك Access Token أو App Secret.',
                'In Meta, select Verify and save, then subscribe to messages. Never share the Access Token or App Secret.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCopyField extends StatelessWidget {
  const _MetaCopyField({
    required this.label,
    required this.value,
    required this.copyKey,
    required this.onCopy,
  });

  final String label;
  final String value;
  final Key copyKey;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 14, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            key: copyKey,
            onPressed: onCopy,
            tooltip: _metaText('نسخ', 'Copy'),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class _ConnectionFact extends StatelessWidget {
  const _ConnectionFact({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF087A5B).withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF087A5B), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _MetaLoadingState extends StatelessWidget {
  const _MetaLoadingState();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _LoadingBlock(height: 210),
          SizedBox(height: 14),
          _LoadingBlock(height: 82),
          SizedBox(height: 12),
          _LoadingBlock(height: 82),
        ],
      );
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
      );
}

class _MetaErrorState extends StatelessWidget {
  const _MetaErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          Icon(
            Icons.cloud_off_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 14),
          Text(
            _metaText(
              'تعذر قراءة حالة الاتصال',
              'Could not load the connection',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_metaText('إعادة المحاولة', 'Try again')),
            ),
          ),
        ],
      );
}

String _statusLabel(String? status) => switch (status) {
      'active' ||
      'connected' ||
      'receiving' =>
        _metaText('يستقبل الأحداث', 'Receiving'),
      'subscribed' => _metaText('مشترك', 'Subscribed'),
      'pending' => _metaText('قيد الإعداد', 'Pending'),
      'error' => _metaText('توجد مشكلة', 'Needs attention'),
      _ => _metaText('غير متصل', 'Disconnected'),
    };

String _formatDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day  $hour:$minute';
}
