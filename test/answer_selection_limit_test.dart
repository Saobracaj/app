import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/practice/state_management/practice_content_bloc.dart'
    as practice;
import 'package:saobracaj/test/quest/state_management/quest_content_bloc.dart'
    as quest;

/// Ограничение выбора: в обоих режимах (тренировка и симуляция экзамена)
/// нельзя выбрать больше вариантов, чем требует вопрос, а отклонённый тап
/// поднимает счётчик `limitHits` — по нему экран показывает подсказку с
/// вибрацией.
List<Choice> _choices({int correct = 2, int options = 4}) => [
  for (var i = 0; i < options; i++)
    Choice(text: 'Одговор број $i', isCorrect: i < correct),
];

/// Блок обрабатывает события по одному за оборот цикла событий — тесту нужно
/// отдать управление между тапами.
Future<void> _settle() => Future.delayed(Duration.zero);

void main() {
  group('QuestContentBloc', () {
    test('лишний выбор отклоняется и увеличивает limitHits', () async {
      final choices = _choices();
      final bloc = quest.QuestContentBloc(choices.toSet(), {}, 1);

      for (final c in [choices[0], choices[1], choices[2]]) {
        bloc.add(quest.AddChoice(c));
        await _settle();
      }

      expect(bloc.state.selectedChoices, {choices[0], choices[1]});
      expect(bloc.state.limitHits, 1);
    });

    test('после снятия выбора новый вариант выбирается', () async {
      final choices = _choices();
      final bloc = quest.QuestContentBloc(choices.toSet(), {}, 1);

      for (final c in [choices[0], choices[1], choices[0], choices[2]]) {
        bloc.add(quest.AddChoice(c));
        await _settle();
      }

      expect(bloc.state.selectedChoices, {choices[1], choices[2]});
      expect(bloc.state.limitHits, 0);
    });

    test('вопрос с одним верным вариантом просто переключает выбор', () async {
      final choices = _choices(correct: 1);
      final bloc = quest.QuestContentBloc(choices.toSet(), {}, 1);

      for (final c in [choices[0], choices[3]]) {
        bloc.add(quest.AddChoice(c));
        await _settle();
      }

      expect(bloc.state.selectedChoices, {choices[3]});
      expect(bloc.state.limitHits, 0);
    });

    test('смена вопроса сбрасывает счётчик подсказок', () async {
      final choices = _choices();
      final bloc = quest.QuestContentBloc(choices.toSet(), {}, 1);

      for (final c in [choices[0], choices[1], choices[2]]) {
        bloc.add(quest.AddChoice(c));
        await _settle();
      }
      expect(bloc.state.limitHits, 1);

      bloc.add(quest.QuestionChanged(choices.toSet(), {}, 2));
      await _settle();

      expect(bloc.state.limitHits, 0);
      expect(bloc.state.selectedChoices, isEmpty);
    });
  });

  group('PracticeContentBloc', () {
    test('лишний выбор отклоняется и увеличивает limitHits', () async {
      final choices = _choices();
      final bloc = practice.PracticeContentBloc(choices.toSet(), {}, 1);

      for (final c in choices) {
        bloc.add(practice.AddChoice(c));
        await _settle();
      }

      expect(bloc.state.selectedChoices, {choices[0], choices[1]});
      expect(bloc.state.limitHits, 2);
    });
  });
}
