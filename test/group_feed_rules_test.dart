import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/groups/models/group_event.dart';

GroupEvent _event({
  GroupEventKind kind = GroupEventKind.memberJoined,
  SubcategoryCompletedDetails? subcategory,
  PracticeFinishedDetails? practice,
}) {
  return GroupEvent(
    id: 'e1',
    kind: kind,
    occurredAt: DateTime(2026, 1, 1),
    subcategory: subcategory,
    practice: practice,
  );
}

void main() {
  group('что попадает в ленту группы', () {
    test('блок с четырьмя верными ответами в ленту не идёт', () {
      final event = _event(
        kind: GroupEventKind.subcategoryCompleted,
        subcategory: const SubcategoryCompletedDetails(
          subcategory: '91',
          rightAnswers: 4,
          allAnswers: 20,
        ),
      );
      expect(groupEventIsWorthShowing(event), isFalse);
    });

    test('пяти верных ответов уже достаточно', () {
      final event = _event(
        kind: GroupEventKind.subcategoryCompleted,
        subcategory: const SubcategoryCompletedDetails(
          subcategory: '91',
          rightAnswers: 5,
          allAnswers: 20,
        ),
      );
      expect(groupEventIsWorthShowing(event), isTrue);
    });

    test('брошенная симуляция (37 ошибок из 41) в ленту не идёт', () {
      final event = _event(
        kind: GroupEventKind.practiceFinished,
        practice: const PracticeFinishedDetails(points: 5, mistakes: 37),
      );
      expect(groupEventIsWorthShowing(event), isFalse);
    });

    test('пройденная симуляция показывается', () {
      final event = _event(
        kind: GroupEventKind.practiceFinished,
        practice: const PracticeFinishedDetails(points: 90, mistakes: 2),
      );
      expect(groupEventIsWorthShowing(event), isTrue);
    });

    test('события про участников порогом не отсекаются', () {
      expect(groupEventIsWorthShowing(_event()), isTrue);
    });
  });

  group('разбор деталей симуляции', () {
    test('длительность читается из ответа сервера', () {
      final details = PracticeFinishedDetails.fromJson(const {
        'points': 90,
        'mistakes': 1,
        'passed': true,
        'durationSeconds': 754,
        'wrongAnswers': [7, 21],
      });
      expect(details.durationSeconds, 754);
      expect(details.wrongAnswers, [7, 21]);
    });

    test('событие без длительности остаётся читаемым', () {
      final details = PracticeFinishedDetails.fromJson(const {
        'points': 90,
        'mistakes': 1,
        'passed': true,
      });
      expect(details.durationSeconds, isNull);
    });
  });
}
