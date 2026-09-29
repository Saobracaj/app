import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/db/answer_repository.dart';
import 'package:saobracaj/db/db.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/home/data/home_preferences_repository.dart';
import 'package:saobracaj/home/presentation/activity_card.dart';
import 'package:saobracaj/home/presentation/category_coverage_card.dart';
import 'package:saobracaj/home/presentation/continue_konspekt_card.dart';
import 'package:saobracaj/home/presentation/daily_question_card.dart';
import 'package:saobracaj/home/presentation/exam_countdown_card.dart';
import 'package:saobracaj/home/presentation/exam_trend_card.dart';
import 'package:saobracaj/home/presentation/home_card.dart';
import 'package:saobracaj/home/presentation/home_insights_section.dart';
import 'package:saobracaj/home/presentation/readiness_card.dart';
import 'package:saobracaj/home/presentation/summary_card.dart';
import 'package:saobracaj/home/presentation/weak_topics_card.dart';
import 'package:saobracaj/home/state_management/daily_question_bloc.dart';
import 'package:saobracaj/home/state_management/daily_sign_bloc.dart';
import 'package:saobracaj/home/state_management/home_insights_bloc.dart';
import 'package:saobracaj/home/state_management/home_insights_events.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/question_features/data/question_analytics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Карточки прогресса на главной: каждая под своим фича-флагом, все считаются
/// из локальной БД и банка вопросов и обновляются сами после записи ответа.

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

/// Веса из схемы экзамена: все вопросы по единице, кроме 12 — его экзамен не
/// выносит.
class _FakeAnalytics extends QuestionAnalyticsRepository {
  @override
  Future<Map<int, double>> weights() async => {
    for (final q in _questions) q.id: q.id == 12 ? 0.0 : 1.0,
  };
}

class _FakeKonspekts extends KonspektRepository {
  _FakeKonspekts(super.client, {this.last});

  final String? last;

  @override
  Future<String?> lastOpened() async => last;
}

Question _q(int id, {String category = '25', int subcategory = 91}) => Question(
  id: id,
  imageId: id,
  text: 'Питање $id',
  choicesReq: 1,
  hasImage: false,
  points: 1,
  choices: const [
    Choice(text: 'тачно', isCorrect: true),
    Choice(text: 'нетачно', isCorrect: false),
  ],
  categoryId: category,
  subcategoryId: subcategory,
);

final _questions = [
  for (var i = 1; i <= 6; i++) _q(i),
  for (var i = 7; i <= 8; i++) _q(i, subcategory: 93),
  for (var i = 9; i <= 12; i++) _q(i, category: '30', subcategory: 120),
];

final _data = QuestionsData(
  categories: const [
    Category(
      id: '25',
      name: 'Основе безбедности',
      subcategories: [
        Subcategory(id: 91, description: 'Основне одредбе'),
        Subcategory(id: 93, description: 'Незгоде'),
      ],
    ),
    Category(
      id: '30',
      name: 'Правила саобраћаја',
      subcategories: [Subcategory(id: 120, description: 'Раскрснице')],
    ),
  ],
  questions: _questions,
  practice: const [],
);

final _now = DateTime(2026, 9, 28, 15);

late AppDatabase _db;
late AnswerRepository _answers;

Future<void> _answer(int questionId, {required bool wrong, DateTime? at}) =>
    _db.insertAnswer(
      AnswerRecordsCompanion(
        questionId: Value(questionId),
        date: Value(at ?? _now),
        isWrong: Value(wrong),
      ),
    );

Future<void> _register({String? lastKonspekt}) async {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final prefs = HomePreferencesRepository();
  getIt.registerFactory<HomeInsightsBloc>(
    () => HomeInsightsBloc(
      _answers,
      _FakeAnalytics(),
      prefs,
      _FakeKonspekts(client, last: lastKonspekt),
    ),
  );
  getIt.registerFactory<DailyQuestionBloc>(
    () => DailyQuestionBloc(prefs, _answers),
  );
  getIt.registerFactory<DailySignBloc>(DailySignBloc.new);
}

/// Флаги с локальными тумблерами из prefs: `bootstrap()` их и читает (в
/// приложении его зовёт `main()`), без него тумблеры не действуют.
Future<FeatureFlagsRepository> _flags() async {
  final storage = TokenStorage();
  final flags = FeatureFlagsRepository(
    _FakeClient(storage),
    storage,
    deviceLanguage: 'ru',
  );
  await flags.bootstrap();
  return flags;
}

Widget _app(FeatureFlagsRepository flags, {bool wide = false}) {
  return EasyLocalization(
    useOnlyLangCode: true,
    supportedLocales: const [Locale('ru')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('ru'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  FeatureFlagsBloc(flags)..add(FeatureFlagsStarted()),
            ),
            BlocProvider<AllQuestionsBloc>(
              create: (_) => _StubAllQuestionsBloc(_data),
            ),
          ],
          child: Scaffold(
            body: SingleChildScrollView(child: HomeInsightsSection(wide: wide)),
          ),
        ),
      ),
    ),
  );
}

/// Локальные тумблеры флагов на этот тест. Знак дня читает правилник из
/// ассетов — у него отдельный тест, здесь он всегда выключен. Значения надо
/// задать до первого `SharedPreferences.getInstance()` (его делает и
/// EasyLocalization), иначе экземпляр с прежними значениями переживёт замену.
Future<void> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues({
    'feature.${AppFeature.homeDailySign.key}.enabled': false,
    ...values,
  });
  await EasyLocalization.ensureInitialized();
  _featureFlags = await _flags();
}

late FeatureFlagsRepository _featureFlags;

/// Кадры на загрузку флагов, чтение БД и дебаунс пересчёта.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _db = AppDatabase.forTesting(NativeDatabase.memory());
    _answers = AnswerRepository(_db);
  });

  tearDown(() async {
    await getIt.reset();
    await _db.close();
  });

  testWidgets('без истории — карточки с приглашениями', (tester) async {
    await _prefs();
    await _register();
    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_app(_featureFlags));
      await _settle(tester);
    });

    expect(find.byType(ReadinessCard), findsOneWidget);
    expect(
      find.text(LocaleKeys.homeInsights_readiness_empty.tr()),
      findsOneWidget,
    );
    expect(
      find.text(LocaleKeys.homeInsights_examTrend_empty.tr()),
      findsOneWidget,
    );
    expect(
      find.text(LocaleKeys.homeInsights_activity_noStreak.tr()),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('countdown_set')), findsOneWidget);
    expect(find.byType(SummaryCard), findsOneWidget);
    expect(
      find.text(LocaleKeys.homeInsights_weakTopics_empty.tr(args: ['5'])),
      findsOneWidget,
    );
    // Покрытие: обе категории, ещё не открывались.
    expect(find.text('Основе безбедности'), findsOneWidget);
    expect(find.text('Правила саобраћаја'), findsOneWidget);
    expect(
      find.text(LocaleKeys.homeInsights_coverage_untouched.tr()),
      findsNWidgets(2),
    );
    // Вопрос дня выбран из банка.
    expect(find.byType(DailyQuestionCard), findsOneWidget);
    expect(find.textContaining('Питање '), findsOneWidget);
    // Конспект не открывали — карточки нет.
    expect(find.byType(HomeCard), findsNWidgets(8));
    expect(
      find.text(LocaleKeys.homeInsights_konspekt_title.tr()),
      findsNothing,
    );
  });

  testWidgets('с историей — цифры, и они обновляются после ответа', (
    tester,
  ) async {
    await _prefs();
    await _register(lastKonspekt: '30');
    // Вчера и сегодня; из 91 знает 4 из 6, из 120 — 1 из 4.
    await _answer(1, wrong: false, at: DateTime(2026, 9, 27, 10));
    await _answer(2, wrong: false, at: DateTime(2026, 9, 27, 10));
    await _answer(3, wrong: false);
    await _answer(4, wrong: false);
    await _answer(5, wrong: true);
    await _answer(6, wrong: true);
    await _answer(9, wrong: false);
    await _answer(10, wrong: true);
    await _answer(11, wrong: true);
    await _answer(12, wrong: true);
    await _db.insertPractice(
      PracticeRecordsCompanion(
        points: const Value(90),
        time: Value(DateTime(2026, 9, 20)),
        mistakes: const Value(2),
        durationSeconds: const Value(1500),
      ),
    );

    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_app(_featureFlags));
      await _settle(tester);

      // Готовность: 5 известных из 11 выносимых (12 не в счёт) → 45 %.
      expect(find.text('45%'), findsOneWidget);
      expect(
        find.text(
          LocaleKeys.homeInsights_readiness_known.tr(args: ['5', '11']),
        ),
        findsOneWidget,
      );
      expect(
        find.text(LocaleKeys.homeInsights_readiness_practiceWeakest.tr()),
        findsOneWidget,
      );
      // Серия: вчера и сегодня.
      expect(
        find.text(LocaleKeys.homeInsights_activity_streak.plural(2)),
        findsOneWidget,
      );
      expect(
        find.text(LocaleKeys.homeInsights_activity_today.tr(args: ['8', '30'])),
        findsOneWidget,
      );
      // Симуляции: одна, сдана.
      expect(
        find.text(
          LocaleKeys.homeInsights_examTrend_passedOfRecent.tr(args: ['1', '1']),
        ),
        findsOneWidget,
      );
      // Слабые темы: только 91 (6 ответов) и 120 (4 — ниже порога 5).
      expect(find.text('Основне одредбе'), findsOneWidget);
      expect(find.text('Раскрснице'), findsNothing);
      // Сводка: 10 ответов, 5 неверных за неделю → 50 %, 25 минут.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(
        find.text(LocaleKeys.homeInsights_summary_minutes.tr(args: ['25'])),
        findsOneWidget,
      );
      // Конспект последней категории.
      expect(find.byType(ContinueKonspektCard), findsOneWidget);
      expect(find.text('Правила саобраћаја'), findsNWidgets(2));

      // Новые ответы — карточки пересчитываются сами (сигнал БД + дебаунс):
      // готовность 7 из 11 → 64 %, за неделю 7 из 12 → 58 %.
      await _answer(7, wrong: false);
      await _answer(8, wrong: false);
      await _settle(tester);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('58%'), findsOneWidget);
      expect(
        find.text(
          LocaleKeys.homeInsights_activity_today.tr(args: ['10', '30']),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('вопрос дня: выбор, проверка, запись в историю', (tester) async {
    await _prefs();
    await _register();
    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_app(_featureFlags));
      await _settle(tester);

      final check = find.byKey(const ValueKey('daily_question_check'));
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      final choice = find.byKey(const ValueKey('daily_question_choice_1'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
      await tester.ensureVisible(check);
      await tester.tap(check);
      await _settle(tester);

      expect(
        find.text(LocaleKeys.homeInsights_dailyQuestion_wrong.tr()),
        findsOneWidget,
      );
      expect(
        find.text(LocaleKeys.homeInsights_dailyQuestion_open.tr()),
        findsOneWidget,
      );
      expect(check, findsNothing);
      final last = await _answers.getLastAnswers();
      expect(last.length, 1);
      expect(last.values.single, isTrue, reason: 'неверный ответ записан');

      // Перезапуск в тот же день — вердикт помнится.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(_featureFlags));
      await _settle(tester);
      expect(
        find.text(LocaleKeys.homeInsights_dailyQuestion_wrong.tr()),
        findsOneWidget,
      );
    });
  });

  testWidgets('дата экзамена: отсчёт и прогноз', (tester) async {
    await _prefs();
    await _register();
    for (var i = 0; i < 14; i++) {
      await _answer(1, wrong: false, at: DateTime(2026, 9, 15 + i, 9));
    }
    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_app(_featureFlags));
      await _settle(tester);
      final context = tester.element(find.byType(ExamCountdownCard));
      context.read<HomeInsightsBloc>().add(
        HomeExamDateChanged(DateTime(2026, 10, 8)),
      );
      await _settle(tester);

      expect(
        find.text(LocaleKeys.homeInsights_countdown_days.plural(10)),
        findsOneWidget,
      );
      // Темп 1 в день, пройден 1 из 12, за 10 дней ≈ 11 из 12 → 92 %.
      expect(
        find.text(
          LocaleKeys.homeInsights_countdown_forecast.tr(args: ['1', '92']),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('countdown_menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('countdown_set')), findsNothing);
    });
  });

  testWidgets('флаги выключены — блока нет', (tester) async {
    await _prefs({
      for (final feature in AppFeature.homeCards)
        'feature.${feature.key}.enabled': false,
    });
    await _register();
    await tester.pumpWidget(_app(_featureFlags));
    await _settle(tester);

    expect(find.byType(HomeCard), findsNothing);
    expect(find.byType(ActivityCard), findsNothing);
    expect(find.byType(ExamTrendCard), findsNothing);
    expect(find.byType(WeakTopicsCard), findsNothing);
    expect(find.byType(CategoryCoverageCard), findsNothing);
  });

  testWidgets('один флаг — одна карточка', (tester) async {
    await _prefs({
      for (final feature in AppFeature.homeCards)
        if (feature != AppFeature.homeActivity)
          'feature.${feature.key}.enabled': false,
    });
    await _register();
    await tester.pumpWidget(_app(_featureFlags));
    await _settle(tester);

    expect(find.byType(HomeCard), findsOneWidget);
    expect(find.byType(ActivityCard), findsOneWidget);
  });

  testWidgets('широкий экран — заголовок раздела и сетка', (tester) async {
    await _prefs();
    await _register();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_app(_featureFlags, wide: true));
      await _settle(tester);
    });

    expect(find.text(LocaleKeys.homeInsights_section.tr()), findsOneWidget);
    expect(find.byType(ReadinessCard), findsOneWidget);
    expect(find.byType(CategoryCoverageCard), findsOneWidget);
  });
}
