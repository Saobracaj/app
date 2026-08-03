import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/profile/domain/display_name_rules.dart';
import 'package:saobracaj/public_comments/models/public_comment.dart';
import 'package:saobracaj/public_comments/presentation/relative_time.dart';

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

  group('Относительное время (русские формы множественного числа)', () {
    final now = DateTime(2026, 8, 3, 12, 0, 0);

    test('только что для свежих меток', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 10)), now: now),
          'только что');
    });

    test('минуты склоняются правильно', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 1)), now: now),
          '1 минуту назад');
      expect(relativeTime(now.subtract(const Duration(minutes: 2)), now: now),
          '2 минуты назад');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
          '5 минут назад');
    });

    test('часы склоняются правильно', () {
      expect(relativeTime(now.subtract(const Duration(hours: 2)), now: now),
          '2 часа назад');
    });

    test('будущие метки (перекос часов) не дают отрицательное время', () {
      expect(relativeTime(now.add(const Duration(minutes: 5)), now: now),
          'только что');
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
