import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_hub/core/icons/app_icons.dart';

void main() {
  test('every navigation destination uses a bundled Material icon', () {
    const icons = <IconData>[
      AppIcons.overview,
      AppIcons.conversations,
      AppIcons.customers,
      AppIcons.team,
      AppIcons.store,
      AppIcons.whatsApp,
      AppIcons.metaUsage,
      AppIcons.subscriptions,
      AppIcons.ai,
      AppIcons.audit,
      AppIcons.privacy,
      AppIcons.support,
      AppIcons.settings,
      AppIcons.account,
      AppIcons.platformStores,
    ];

    expect(icons, hasLength(15));
    for (final icon in icons) {
      expect(icon.fontFamily, 'MaterialIcons');
      expect(icon.codePoint, greaterThan(0));
    }
  });

  testWidgets('directional navigation icons follow RTL and LTR',
      (tester) async {
    Future<IconData> resolve(TextDirection direction, bool forward) async {
      late IconData result;
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: Builder(
            builder: (context) {
              result =
                  forward ? AppIcons.forward(context) : AppIcons.back(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    expect(
      await resolve(TextDirection.rtl, true),
      Icons.chevron_left_rounded,
    );
    expect(
      await resolve(TextDirection.ltr, true),
      Icons.chevron_right_rounded,
    );
    expect(
      await resolve(TextDirection.rtl, false),
      Icons.arrow_forward_rounded,
    );
    expect(
      await resolve(TextDirection.ltr, false),
      Icons.arrow_back_rounded,
    );
  });
}
