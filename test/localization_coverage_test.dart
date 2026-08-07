import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_hub/core/localization/app_locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every Arabic tr literal has an English result', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final controller = AppLocaleController();
    await controller.initialize();

    final untranslated = <String>[];
    final callPattern = RegExp(r"""tr\(\s*'((?:\\.|[^'\\])*)'\s*\)""");
    final arabicPattern = RegExp(r'[\u0600-\u06FF]');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in callPattern.allMatches(source)) {
        final value = _decodeDartString(match.group(1)!);
        if (!arabicPattern.hasMatch(value)) continue;
        final translated = tr(value);
        if (arabicPattern.hasMatch(translated)) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          untranslated.add('${entity.path}:$line — $value');
        }
      }
    }

    expect(
      untranslated,
      isEmpty,
      reason:
          'Arabic text would leak into the English interface:\n${untranslated.join('\n')}',
    );
    await controller.setLanguage('ar');
  });

  test('dynamic dashboard and inbox values translate', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final controller = AppLocaleController();
    await controller.initialize();

    expect(tr('رسالة جديدة من Ahmed'), 'New message from Ahmed');
    expect(tr('4 محادثة · متابعة موحّدة لرسائل العملاء'),
        contains('4 conversations'));
    expect(tr('3 رسالة في 2 محادثة تحتاج انتباهك'),
        contains('3 messages in 2 conversations'));
    expect(tr('12 من 100 رسالة'), '12 of 100 messages');
    expect(
        tr('التغير عن الشهر السابق: 15.5%'), 'Change from last month: 15.5%');

    await controller.setLanguage('ar');
  });
}

String _decodeDartString(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r"\'", "'")
    .replaceAll(r'\\', '\\');
