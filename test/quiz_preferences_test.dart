import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/domain/quiz_option.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_bloc.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_events.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Свежий репозиторий, поднятый из того же (замоканного) хранилища — имитирует
/// следующий запуск приложения.
Future<QuizPreferencesRepository> _restarted() async {
  final repository = QuizPreferencesRepository();
  await repository.bootstrap();
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('QuizPreferencesRepository', () {
    test('до первого выбора отдаёт значения по умолчанию', () async {
      final repository = await _restarted();

      expect(repository.isEnabled(QuizOption.shuffleQuestions), isTrue);
      expect(repository.isEnabled(QuizOption.practiceShowStats), isFalse);
      expect(repository.questionTab, isNull);
    });

    test('выбранные опции переживают перезапуск', () async {
      final repository = await _restarted();
      await repository.setEnabled(QuizOption.shuffleQuestions, false);
      await repository.setEnabled(QuizOption.practiceButtonsLikeInExam, true);

      final afterRestart = await _restarted();
      expect(afterRestart.isEnabled(QuizOption.shuffleQuestions), isFalse);
      expect(afterRestart.isEnabled(QuizOption.practiceButtonsLikeInExam), isTrue);
      // Нетронутая опция остаётся на дефолте.
      expect(afterRestart.isEnabled(QuizOption.shuffleAnswerOptions), isTrue);
    });

    test('выбранная вкладка вопроса переживает перезапуск', () async {
      final repository = await _restarted();
      await repository.setQuestionTab(AppFeature.publicQuestionComments);

      expect((await _restarted()).questionTab, AppFeature.publicQuestionComments);
    });

    test('неизвестный ключ вкладки читается как «нет выбора»', () async {
      SharedPreferences.setMockInitialValues({'quiz.question_tab': 'no_such_feature'});

      expect((await _restarted()).questionTab, isNull);
    });
  });

  group('StartTestBloc', () {
    test('стартует с запомненных опций', () async {
      final repository = await _restarted();
      await repository.setEnabled(QuizOption.shuffleQuestions, false);

      final bloc = StartTestBloc(await _restarted());
      expect(bloc.state.random, isFalse);
      expect(bloc.state.randomOptionsOrder, isTrue);
    });

    test('переключение опции сохраняется', () async {
      final bloc = StartTestBloc(await _restarted());
      bloc.add(ToggleRandomOptionsOrder());
      await bloc.stream.first;

      expect((await _restarted()).isEnabled(QuizOption.shuffleAnswerOptions), isFalse);
    });
  });

  group('QuestionFeaturesBloc', () {
    test('без deep link выбирает запомненную вкладку', () async {
      final repository = await _restarted();
      await repository.setQuestionTab(AppFeature.questionAnalysis);

      final bloc = QuestionFeaturesBloc(await _restarted(), null);
      expect(bloc.state.selected, AppFeature.questionAnalysis);
    });

    test('deep link перебивает запомненную вкладку и не сохраняется', () async {
      final repository = await _restarted();
      await repository.setQuestionTab(AppFeature.questionAnalysis);

      final bloc = QuestionFeaturesBloc(
        await _restarted(),
        AppFeature.publicQuestionComments,
      );
      expect(bloc.state.selected, AppFeature.publicQuestionComments);
      expect((await _restarted()).questionTab, AppFeature.questionAnalysis);
    });

    test('выбор вкладки сохраняется', () async {
      final bloc = QuestionFeaturesBloc(await _restarted(), null);
      bloc.add(TabSelected(AppFeature.categorySummaries));
      await bloc.stream.first;

      expect((await _restarted()).questionTab, AppFeature.categorySummaries);
    });
  });
}
