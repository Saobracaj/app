import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/analytics/question_navigation.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/practice/data/paused_simulation_repository.dart';
import 'package:saobracaj/test/practice/domain/paused_simulation.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart'
    as practice;
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
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
  void logQuestionViewed({
    required int questionId,
    required QuestionNavigation navigation,
    QuestionDirection? direction,
    String mode = 'quiz',
  }) => events.add(
    'question_viewed:$questionId:${navigation.key}:${direction?.key}:$mode',
  );

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

  Iterable<String> viewed() =>
      recorded.events.where((e) => e.startsWith('question_viewed'));

  group('question_viewed', () {
    test('старт прогона логирует первый вопрос без направления', () {
      bloc();
      expect(viewed(), ['question_viewed:11:run_start:null:quiz']);
    });

    test('кнопки «дальше» и «назад» логируют способ и направление', () async {
      final quest = bloc()..add(NextQuestion());
      await pump();
      quest.add(PrevQuestion());
      await pump();
      expect(viewed(), [
        'question_viewed:11:run_start:null:quiz',
        'question_viewed:22:next_button:forward:quiz',
        'question_viewed:11:back_button:back:quiz',
      ]);
    });

    test('клавиши ← / → приходят как keyboard', () async {
      final quest = bloc()..add(NextQuestion(QuestionNavigation.keyboard));
      await pump();
      quest.add(PrevQuestion(QuestionNavigation.keyboard));
      await pump();
      expect(viewed().skip(1), [
        'question_viewed:22:keyboard:forward:quiz',
        'question_viewed:11:keyboard:back:quiz',
      ]);
    });

    test('переход к вопросу логируется со способом и направлением, повтор '
        'того же вопроса — нет', () async {
      final quest = bloc()
        ..add(MoveToQuestion(33, via: QuestionNavigation.navigator));
      await pump();
      quest.add(MoveToQuestion(33, via: QuestionNavigation.navigator));
      await pump();
      quest.add(MoveToQuestion(22, via: QuestionNavigation.swipe));
      await pump();
      expect(viewed().skip(1), [
        'question_viewed:33:navigator:forward:quiz',
        'question_viewed:22:swipe:back:quiz',
      ]);
    });

    test('режим презентации не отправляет ничего', () async {
      bloc(presentation: true).add(NextQuestion());
      await pump();
      expect(recorded.events, isEmpty);
    });
  });

  group('question_viewed в симуляции', () {
    QuestionsData data() => QuestionsData(
      categories: const [],
      questions: [
        for (var id = 1; id <= 3; id++)
          Question(
            id: id,
            imageId: id,
            text: 'Питање број $id',
            choicesReq: 1,
            hasImage: false,
            points: 2,
            choices: const [
              Choice(text: 'да', isCorrect: true),
              Choice(text: 'не', isCorrect: false),
            ],
            categoryId: 'c',
            subcategoryId: 1,
          ),
      ],
      practice: const [
        [1, 2, 3],
      ],
    );

    late PausedSimulationRepository snapshots;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      snapshots = PausedSimulationRepository();
    });

    practice.PracticeBloc exam({
      PausedSimulation? snapshot,
      bool resume = false,
    }) => practice.PracticeBloc(
      data(),
      const PracticeParams(showRightAnswers: true),
      snapshots: snapshots,
      snapshot: snapshot,
      resume: resume,
      idleTimeout: null,
      watchLifecycle: false,
    );

    test('старт, кнопки, клавиши и отчёт — со способом, направлением и '
        'mode=exam', () async {
      final bloc = exam()..add(practice.Init());
      await pump();
      bloc.add(practice.NextQuestion());
      await pump();
      bloc.add(practice.PrevQuestion(QuestionNavigation.keyboard));
      await pump();
      bloc.add(practice.NavigateToQuestion(2, via: QuestionNavigation.report));
      await pump();
      bloc.add(practice.NavigateToQuestion(1, via: QuestionNavigation.swipe));
      await pump();
      expect(viewed(), [
        'question_viewed:1:run_start:null:exam',
        'question_viewed:2:next_button:forward:exam',
        'question_viewed:1:keyboard:back:exam',
        'question_viewed:3:report:forward:exam',
        'question_viewed:2:swipe:back:exam',
      ]);
      await bloc.close();
    });

    test('продолжение из снимка — resume, а снимок с тем же вопросом '
        'повторного показа не даёт', () async {
      final snapshot = PausedSimulation(
        startedAt: DateTime(2026, 10, 8, 21, 5),
        elapsedSeconds: 600,
        savedAt: DateTime(2026, 10, 8, 21, 15),
        questions: const [1, 2, 3],
        currentQuestionIndex: 1,
        showRightAnswers: true,
      );
      await snapshots.save(snapshot);
      final bloc = exam(snapshot: snapshot, resume: true)..add(practice.Init());
      await pump();
      bloc.add(
        practice.RemoteChangeReceived(
          PausedSimulationChange(snapshot: snapshot, remote: true),
        ),
      );
      await pump();
      expect(viewed(), ['question_viewed:2:resume:null:exam']);

      // Там перешли на другой вопрос — здесь он показан как remote.
      bloc.add(
        practice.RemoteChangeReceived(
          PausedSimulationChange(
            snapshot: snapshot.copyWith(currentQuestionIndex: 2),
            remote: true,
          ),
        ),
      );
      await pump();
      expect(viewed().skip(1), ['question_viewed:3:remote:forward:exam']);
      await bloc.close();
    });
  });

  test('переключатель перевода логирует новое состояние', () async {
    final translations = TranslationsBloc()..add(ToggleShowTranslation());
    await pump();
    translations.add(ToggleShowTranslation());
    await pump();
    expect(recorded.events, ['translation_toggled:1', 'translation_toggled:0']);
  });
}
