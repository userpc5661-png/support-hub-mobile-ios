import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/features/whatsapp/whatsapp_settings_screen.dart';

void main() {
  Widget subject({
    Map<String, dynamic>? connection,
    VoidCallback? onConnect,
    String? connectionStage,
    String? failureCode,
    String? failureMessage,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: MetaConnectionView(
            connection: connection,
            busyAction: null,
            connectionStage: connectionStage,
            failureCode: failureCode,
            failureMessage: failureMessage,
            onConnect: onConnect ?? () {},
            onConnectManually: () {},
            onSubmitPin: (_) async {},
            onSync: () {},
            onTest: () {},
            onSendTest: () {},
            onOpenManager: () async {},
            onDisconnect: () {},
          ),
        ),
      );

  testWidgets('disconnected onboarding exposes both Meta signup paths',
      (tester) async {
    var starts = 0;
    await tester.pumpWidget(subject(onConnect: () => starts++));

    expect(find.byKey(const Key('meta-disconnected-view')), findsOneWidget);
    expect(find.byKey(const Key('meta-new-account-guide')), findsOneWidget);
    expect(
      find.byKey(const Key('meta-existing-account-guide')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('meta-create-account-button')), findsNothing);

    tester
        .widget<OutlinedButton>(
          find.byKey(const Key('meta-new-account-guide')),
        )
        .onPressed!();
    await tester.pump();
    expect(find.byKey(const Key('meta-create-account-button')), findsOneWidget);
    expect(find.byKey(const Key('meta-existing-account-button')), findsNothing);
    tester
        .widget<FilledButton>(
          find.byKey(const Key('meta-create-account-button')),
        )
        .onPressed!();
    expect(starts, 1);
  });

  testWidgets('disconnected hero fits a narrow phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(find.byKey(const Key('meta-disconnected-view')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected view shows public connection details', (tester) async {
    await tester.pumpWidget(
      subject(
        connection: {
          'status': 'connected',
          'businessPortfolioId': 'business-1',
          'wabaId': 'waba-1',
          'displayName': 'Acme Store',
          'webhookStatus': 'active',
          'connectedAt': '2026-07-29T10:00:00.000Z',
          'lastSyncedAt': '2026-07-29T11:00:00.000Z',
          'phoneNumbers': [
            {
              'phoneNumberId': 'phone-1',
              'displayPhoneNumber': '+966500000000',
              'verifiedName': 'Acme',
              'qualityRating': 'GREEN',
              'isDefault': true,
            },
          ],
        },
      ),
    );

    expect(find.byKey(const Key('meta-connected-view')), findsOneWidget);
    expect(find.text('+966500000000'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.byKey(const Key('meta-create-account-button')), findsNothing);
    expect(find.byKey(const Key('meta-send-test-message')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('meta-connected-view')),
      const Offset(0, -900),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('meta-open-manager')), findsOneWidget);
  });

  testWidgets('connected account warns when webhook is still pending',
      (tester) async {
    await tester.pumpWidget(
      subject(
        connection: {
          'status': 'connected',
          'wabaId': 'waba-1',
          'displayName': 'Acme Store',
          'webhookStatus': 'pending',
          'phoneNumbers': [
            {
              'phoneNumberId': 'phone-1',
              'displayPhoneNumber': '+966500000000',
              'isDefault': true,
            },
          ],
        },
      ),
    );

    expect(find.byKey(const Key('meta-connected-view')), findsOneWidget);
    expect(
        find.byKey(const Key('meta-webhook-pending-notice')), findsOneWidget);
    expect(
        find.byKey(const Key('meta-webhook-pending-message')), findsOneWidget);
  });

  testWidgets('a disconnected database record returns to onboarding',
      (tester) async {
    await tester.pumpWidget(
      subject(
        connection: {
          'status': 'disconnected',
          'wabaId': 'deleted-waba',
          'phoneNumbers': const [],
        },
      ),
    );

    expect(find.byKey(const Key('meta-disconnected-view')), findsOneWidget);
    expect(find.byKey(const Key('meta-connected-view')), findsNothing);
    expect(find.byKey(const Key('meta-open-manager')), findsNothing);
  });

  testWidgets('an incomplete stale connection returns to onboarding',
      (tester) async {
    await tester.pumpWidget(
      subject(
        connection: {
          'status': 'needs_action',
          'businessPortfolioId': 'business-1',
          'wabaId': 'deleted-waba',
          'phoneNumbers': const [],
        },
      ),
    );

    expect(find.byKey(const Key('meta-disconnected-view')), findsOneWidget);
    expect(find.byKey(const Key('meta-connected-view')), findsNothing);
    expect(find.byKey(const Key('meta-open-manager')), findsNothing);
  });

  testWidgets('signup progress exposes all eight onboarding stages',
      (tester) async {
    await tester.pumpWidget(
      subject(connectionStage: 'phone_registration'),
    );

    for (final stage in [
      'creating_session',
      'opening_meta',
      'waiting_for_user',
      'account_verification',
      'phone_registration',
      'webhook_subscription',
      'connection_test',
      'completed',
    ]) {
      expect(find.byKey(Key('meta-progress-$stage')), findsOneWidget);
    }
  });

  testWidgets('a precise signup failure is shown with retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      subject(
        connectionStage: 'account_verification',
        failureCode: 'permission_denied',
        failureMessage: 'Business Admin permission is required.',
        onConnect: () => retried = true,
      ),
    );

    expect(find.byKey(const Key('meta-failure-card')), findsOneWidget);
    expect(find.text('Business Admin permission is required.'), findsOneWidget);
    tester
        .widget<FilledButton>(
          find.byKey(const Key('meta-retry-button')),
        )
        .onPressed!();
    expect(retried, isTrue);
  });

  testWidgets('missing platform Meta settings disable useless retry',
      (tester) async {
    await tester.pumpWidget(
      subject(
        connectionStage: 'creating_session',
        failureCode: 'platform_configuration_missing',
        failureMessage:
            'The platform owner must configure Meta before linking WhatsApp.',
      ),
    );

    expect(find.text('Could not finish signup'), findsNothing);
    final retry = tester.widget<FilledButton>(
      find.byKey(const Key('meta-retry-button')),
    );
    expect(retry.onPressed, isNull);
  });

  testWidgets('connect action is disabled while a fresh session is starting',
      (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetaConnectionView(
            connection: null,
            busyAction: 'connect',
            connectionStage: 'creating_session',
            failureCode: null,
            failureMessage: null,
            onConnect: () => starts++,
            onConnectManually: () {},
            onSubmitPin: (_) async {},
            onSync: () {},
            onTest: () {},
            onSendTest: () {},
            onOpenManager: () async {},
            onDisconnect: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('meta-new-account-guide')),
    );
    expect(button.onPressed, isNull);

    expect(starts, 0);
  });

  testWidgets('PIN-required connection validates and clears the one-time PIN',
      (tester) async {
    String? submittedPin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetaConnectionView(
            connection: {
              'status': 'pin_required',
              'pinAttemptsRemaining': 2,
            },
            busyAction: null,
            connectionStage: null,
            failureCode: null,
            failureMessage: null,
            onConnect: () {},
            onConnectManually: () {},
            onSubmitPin: (pin) async => submittedPin = pin,
            onSync: () {},
            onTest: () {},
            onSendTest: () {},
            onOpenManager: () async {},
            onDisconnect: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meta-pin-required-view')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('meta-pin-field')), '123456');
    await tester.tap(find.byKey(const Key('meta-pin-submit')));
    await tester.pump();

    expect(submittedPin, '123456');
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('meta-pin-field')),
    );
    expect(field.controller?.text, isEmpty);
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('PIN attempt limit offers a fresh Meta signup', (tester) async {
    var restarted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetaConnectionView(
            connection: {
              'status': 'error',
              'lastErrorCode': 'pin_attempt_limit',
              'pinAttemptsRemaining': 0,
            },
            busyAction: null,
            connectionStage: null,
            failureCode: null,
            failureMessage: null,
            onConnect: () => restarted = true,
            onConnectManually: () {},
            onSubmitPin: (_) async {},
            onSync: () {},
            onTest: () {},
            onSendTest: () {},
            onOpenManager: () async {},
            onDisconnect: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meta-pin-field')), findsNothing);
    await tester.tap(find.byKey(const Key('meta-pin-restart')));
    expect(restarted, isTrue);
  });
}
