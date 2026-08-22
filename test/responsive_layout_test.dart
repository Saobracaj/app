import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/core/presentation/app_sidebar.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/home_page.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/question_lists/data/question_lists_repository.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/presentation/quest_bottom_bar.dart';
import 'package:saobracaj/test/quest/question_features/data/question_difficulty_repository.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:saobracaj/theme/state_management/theme_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guest_flags_without_discussion.dart';

/// Тесты адаптивной вёрстки: на телефоне остаётся прежняя мобильная вёрстка,
/// на широких экранах (планшет/web) — рельса навигации вместо нижней панели и
/// двухколоночный экран вопроса.

/// Клиент-заглушка: сеть в этих тестах не используется.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

/// Данные вопросов задаются напрямую, без загрузки ассетов.
class _FakeAllQuestionsBloc extends AllQuestionsBloc {
  _FakeAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

Question _question(int id) => Question(
  id: id,
  imageId: id,
  text: 'Како треба да поступи возач?',
  choicesReq: 1,
  hasImage: false,
  points: 2,
  choices: [
    for (var i = 0; i < 4; i++)
      Choice(text: 'Одговор број $i', isCorrect: i == 0),
  ],
  categoryId: 'c',
  subcategoryId: 1,
);

/// Оборачивает [child] в локализацию с настоящими переводами и тему приложения.
Widget _localized({required Widget Function(BuildContext) builder}) {
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('sr'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(builder: builder),
  );
}

/// Полный экран вопроса ([Quest]) со всеми нужными ему блоками-заглушками.
Widget _questApp() {
  final data = QuestionsData(
    categories: [],
    questions: [_question(1), _question(2)],
    practice: [],
  );
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  return _localized(
    builder: (context) => MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AllQuestionsBloc>(
            create: (_) => _FakeAllQuestionsBloc(data),
          ),
          BlocProvider<FeatureFlagsBloc>(
            create: (_) => GuestFlagsWithoutDiscussionBloc(),
          ),
          BlocProvider(
            create: (_) => QuestionListsBloc(
              QuestionListsRepository(client),
              SharedListsRepository(client),
              AuthBloc(
                AuthRepository(client, storage, AnalyticsService()),
                GraphqlSubscriptionClient(client, storage),
              ),
              AnalyticsService(),
              QuestionDifficultyRepository(client),
              NetworkStatus(),
            ),
          ),
        ],
        child: Quest(
          questions: const [1, 2],
          options: const StartTestState(
            random: false,
            randomOptionsOrder: false,
          ),
        ),
      ),
    ),
  );
}

/// Оболочка вкладок ([HomePage]) на минимальной карте маршрутов Routemaster.
Widget _homeApp() {
  Page<void> stub(_) => const MaterialPage(child: SizedBox());
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final delegate = RoutemasterDelegate(
    routesBuilder: (_) => RouteMap(
      routes: {
        '/': (_) => IndexedPage(
          child: const HomePage(),
          paths: const ['/a', '/b', '/c', '/d', '/e'],
        ),
        '/a': stub,
        '/b': stub,
        '/c': stub,
        '/d': stub,
        '/e': stub,
      },
    ),
  );
  return _localized(
    builder: (context) => MaterialApp.router(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
      routerDelegate: delegate,
      routeInformationParser: const RoutemasterParser(),
      // Боковая колонка широкого экрана показывает аккаунт и переключатель
      // темы, поэтому оболочке нужны оба блока.
      builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(
              AuthRepository(client, storage, AnalyticsService()),
              GraphqlSubscriptionClient(client, storage),
            ),
          ),
          BlocProvider(create: (_) => ThemeBloc()),
        ],
        child: child!,
      ),
    ),
  );
}

/// Выставляет размер «окна» теста и возвращает его обратно после прогона.
void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('ReadableWidth', () {
    testWidgets('на узком экране не меняет ширину содержимого', (tester) async {
      _setScreenSize(tester, const Size(400, 800));
      await tester.pumpWidget(
        const MaterialApp(home: ReadableWidth(child: SizedBox.expand())),
      );
      expect(tester.getSize(find.byType(SizedBox)).width, 400);
    });

    testWidgets('на широком экране ограничивает и центрирует колонку', (
      tester,
    ) async {
      _setScreenSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        const MaterialApp(home: ReadableWidth(child: SizedBox.expand())),
      );
      expect(tester.getSize(find.byType(SizedBox)).width, 720);
      expect(tester.getCenter(find.byType(SizedBox)).dx, 640);
    });
  });

  group('Оболочка вкладок', () {
    testWidgets('телефон: нижняя панель навигации, рельсы нет', (tester) async {
      _setScreenSize(tester, const Size(400, 800));
      await tester.pumpWidget(_homeApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('планшет: рельса слева вместо нижней панели', (tester) async {
      _setScreenSize(tester, const Size(800, 1000));
      await tester.pumpWidget(_homeApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
    });

    testWidgets('широкий экран: боковая колонка вместо рельсы', (tester) async {
      _setScreenSize(tester, const Size(1440, 900));
      await tester.pumpWidget(_homeApp());
      await tester.pumpAndSettle();

      // На вебе и десктопе рельсу сменяет колонка макета: логотип, подписанные
      // разделы и блок аккаунта внизу.
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.text('Saobraćaj'), findsOneWidget);
    });

    testWidgets('рельса переключает вкладки', (tester) async {
      _setScreenSize(tester, const Size(1000, 800));
      await tester.pumpWidget(_homeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      // «Настройки» — последняя вкладка; «История» временно скрыта, поэтому
      // это индекс 3, а не 4.
      expect(rail.selectedIndex, 3);
    });
  });

  group('Экран вопроса', () {
    testWidgets('телефон: одна колонка и прибитая нижняя панель', (
      tester,
    ) async {
      // 599 — ещё «телефон» (брейкпоинт 600), но достаточно широкий для
      // квадратных глифов тестового шрифта Ahem в нижней панели.
      _setScreenSize(tester, const Size(599, 900));
      await tester.pumpWidget(_questApp());
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);
      final bar = tester.widget<QuestBottomBar>(find.byType(QuestBottomBar));
      expect(bar.inline, isFalse);
      // Правой панели с заглушкой вкладок нет.
      expect(
        find.textContaining('појавиће се овде након одговора'),
        findsNothing,
      );
    });

    testWidgets('широкий экран: две колонки, действия под ответами, '
        'вкладки справа после ответа', (tester) async {
      _setScreenSize(tester, const Size(1280, 800));
      await tester.pumpWidget(_questApp());
      await tester.pumpAndSettle();

      // Нижняя панель не прибита к Scaffold — она инлайном под ответами.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNull);
      final bar = tester.widget<QuestBottomBar>(find.byType(QuestBottomBar));
      expect(bar.inline, isTrue);

      // До ответа в правой панели — подсказка-заглушка.
      final placeholder = find.textContaining(
        'појавиће се овде након одговора',
      );
      expect(placeholder, findsOneWidget);

      // Кнопка «Прикажи одговор» раскрывает ответы, заглушка исчезает.
      await tester.tap(find.text('Прикажи одговор'));
      await tester.pumpAndSettle();
      expect(placeholder, findsNothing);

      // Колонка вопроса ограничена читабельной шириной, а не всем окном.
      final content = tester.getSize(find.byType(QuestionContent));
      expect(content.width, lessThanOrEqualTo(640));
    });
  });
}
