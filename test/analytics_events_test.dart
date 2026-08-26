import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/quest/state_management/quest_bloc.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';

/// Записывает вызовы вместо отправки в Firebase: события фиксируются строками
/// «имя:параметры», чтобы тест мог проверить и сам факт, и содержимое вызова.
class _RecordingAnalytics extends AnalyticsService {
  final events = <String>[];

  @override
  void logTestStarted({required int questionCount, String? subcategory}) =>
      events.add('test_started:$questionCount');

  @override
  void logQuestionViewed({required int questionId}) =>
      events.add('question_viewed:$questionId');

  @override
  void logTranslationToggled({required bool enabled}) =>
      events.add('translation_toggled:${enabled ? 1 : 0}');
}

void main() {
  late _RecordingAnalytics recorded;

  setUp(() {
    recorded = _RecordingAnalytics();
    getIt.registerSingleton<AnalyticsService>(recorded);
  });

  tearDown(() => getIt.reset());

  QuestBloc bloc({bool presentation = false}) => QuestBloc(
    const QuestionsData(categories: [], questions: [], practice: []),
    [11, 22, 33],
    null,
    presentation: presentation,
  );

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('question_viewed', () {
    test('старт прогона логирует первый вопрос', () {
      bloc();
      expect(recorded.events, contains('question_viewed:11'));
    });

    test('листание вперёд и назад логирует каждый показанный вопрос',
        () async {
      final quest = bloc()..add(NextQuestion());
      await pump();
      quest.add(PrevQuestion());
      await pump();
      expect(
        recorded.events.where((e) => e.startsWith('question_viewed')),
        ['question_viewed:11', 'question_viewed:22', 'question_viewed:11'],
      );
    });

    test('переход к вопросу логируется, повтор того же вопроса — нет',
        () async {
      final quest = bloc()..add(MoveToQuestion(33));
      await pump();
      quest.add(MoveToQuestion(33));
      await pump();
      expect(
        recorded.events.where((e) => e.startsWith('question_viewed')),
        ['question_viewed:11', 'question_viewed:33'],
      );
    });

    test('режим презентации не отправляет ничего', () async {
      bloc(presentation: true).add(NextQuestion());
      await pump();
      expect(recorded.events, isEmpty);
    });
  });

  test('переключатель перевода логирует новое состояние', () async {
    final translations = TranslationsBloc()..add(ToggleShowTranslation());
    await pump();
    translations.add(ToggleShowTranslation());
    await pump();
    expect(
      recorded.events,
      ['translation_toggled:1', 'translation_toggled:0'],
    );
  });
}
