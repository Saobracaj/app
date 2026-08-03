import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/profile/domain/display_name_rules.dart';
import 'package:saobracaj/public_comments/models/public_comment.dart';
import 'package:saobracaj/public_comments/presentation/relative_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Поднимает EasyLocalization с настоящими переводами (CodegenLoader, без
/// ассетов) на локали [locale], чтобы relativeTime резолвил ключи и плюралы.
Future<void> _pumpLocalized(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      useOnlyLangCode: true,
      ignorePluralRules: false,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: locale,
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SizedBox(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Валидация отображаемого имени', () {
    test('слишком короткое имя отклоняется', () {
      expect(validateDisplayName('a'), DisplayNameError.tooShort);
      expect(validateDisplayName('   '), DisplayNameError.tooShort);
    });

    test('слишком длинное имя отклоняется', () {
      expect(validateDisplayName('a' * 41), DisplayNameError.tooLong);
    });

    test('слишком много слов отклоняется', () {
      expect(
        validateDisplayName('one two three four five six'),
        DisplayNameError.tooManyWords,
      );
    });

    test('управляющие символы отклоняются', () {
      expect(validateDisplayName('имя'), DisplayNameError.controlChars);
    });

    test('корректное имя проходит валидацию', () {
      expect(validateDisplayName('  Иван Петров  '), isNull);
    });
  });

  group('Относительное время (локализованное)', () {
    final now = DateTime(2026, 8, 3, 12, 0, 0);

    testWidgets('русская локаль: только что, минуты, часы, годы', (
      tester,
    ) async {
      await _pumpLocalized(tester, const Locale('ru'));
      expect(
        relativeTime(now.subtract(const Duration(seconds: 10)), now: now),
        'только что',
      );
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 мин назад',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 2)), now: now),
        '2 ч назад',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 800)), now: now),
        '2 года назад',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 2000)), now: now),
        '5 лет назад',
      );
    });

    testWidgets('сербская локаль: CLDR few/other на месяцах', (tester) async {
      await _pumpLocalized(tester, const Locale('sr'));
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        'пре 5 мин',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 65)), now: now),
        'пре 2 месеца',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 160)), now: now),
        'пре 5 месеци',
      );
    });

    testWidgets('будущие метки (перекос часов) не дают отрицательное время', (
      tester,
    ) async {
      await _pumpLocalized(tester, const Locale('ru'));
      expect(
        relativeTime(now.add(const Duration(minutes: 5)), now: now),
        'только что',
      );
    });
  });

  group('Парсинг комментария из JSON', () {
    test('ответы разбираются, флаги по умолчанию false', () {
      final comment = PublicComment.fromJson({
        'id': 1,
        'questionId': 42,
        'authorDisplayName': 'Аноним',
        'body': 'текст',
        'createdAt': '2026-08-03T10:00:00Z',
        'likesCount': 3,
        'replies': [
          {
            'id': 2,
            'questionId': 42,
            'parentId': '1',
            'body': 'ответ',
            'createdAt': '2026-08-03T11:00:00Z',
          },
        ],
      });

      expect(comment.id, '1');
      expect(comment.likesCount, 3);
      expect(comment.likedByMe, isFalse);
      expect(comment.isReply, isFalse);
      expect(comment.replies, hasLength(1));
      expect(comment.replies.first.isReply, isTrue);
      expect(comment.replies.first.parentId, '1');
    });
  });
}
