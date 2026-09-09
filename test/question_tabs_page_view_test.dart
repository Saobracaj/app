import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/question_feedback/presentation/report_problem_button.dart';
import 'package:saobracaj/subscription/presentation/paywall.dart';
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/quest/comment/data/comment_repository.dart';
import 'package:saobracaj/test/quest/comment/state_management/comment_bloc.dart';
import 'package:saobracaj/test/quest/question_features/presentation/question_features_tabs.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_bloc.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_konspekt_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Вкладки под вопросом переключаются листалкой ([PageView]): тап по пилюле
/// уезжает на страницу с анимацией, свайп по содержимому переводит вкладку
/// в блоке, а высота листалки следует за содержимым открытой вкладки.

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

class _StubCommentRepository extends CommentRepository {
  _StubCommentRepository(super.client, super.flags);

  @override
  Future<QuestionCommentDetails> fetchComment(
    int questionId, {
    String? categoryId,
  }) async => const QuestionCommentDetails(status: 'READY', text: 'Објашњење.');
}

/// Конспект с одним разделом про вопрос 7001; отдаётся, когда тест решит
/// ([release]) — так вкладка «Конспект» появляется на панели с задержкой.
/// Completer заводит сам тест, внутри своей FakeAsync-зоны: созданный в
/// `setUp` завершался бы в чужой зоне, и `pumpAndSettle` его не дождался бы.
class _StubKonspektRepository extends KonspektRepository {
  _StubKonspektRepository(super.client);

  late Completer<void> release;

  @override
  Future<Set<String>> availableCategories() async => {'27'};

  @override
  Future<Konspekt?> load(String categoryId) async {
    await release.future;
    return Konspekt(
      categoryId: categoryId,
      categoryName: const KonspektText(sr: 'Прописи'),
      sections: const [
        KonspektSection(
          id: 'osnove',
          title: KonspektText(sr: 'Основе'),
          content: KonspektText(sr: 'Конспект.'),
          questionIds: [7001],
        ),
      ],
    );
  }
}

class _FakeAuthBloc extends AuthBloc {
  _FakeAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

/// Объяснение и конспект — с грантом, анализ — без него: в платной категории
/// он остаётся на панели закрытым, третьей вкладкой без сетевых зависимостей.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository(super.client, super.storage);

  static const _enabled = {
    AppFeature.questionComments,
    AppFeature.categorySummaries,
    AppFeature.questionAnalysis,
  };

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in AppFeature.values)
        if (!_enabled.contains(f)) f.key: false,
    },
    grants: const {'question_comments', 'category_summaries'},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late _FakeClient client;
  late _StubKonspektRepository konspekt;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage();
    client = _FakeClient(storage);
    konspekt = _StubKonspektRepository(client);
    getIt.registerLazySingleton<QuizPreferencesRepository>(
      QuizPreferencesRepository.new,
    );
    getIt.registerFactoryParam<CommentBloc, int, String?>(
      (questionId, _) => CommentBloc(
        _StubCommentRepository(
          client,
          _StubFeatureFlagsRepository(client, storage),
        ),
        NetworkStatus(),
        questionId,
      ),
    );
    getIt.registerFactoryParam<QuestionFeaturesBloc, AppFeature?, int?>(
      (initial, questionId) =>
          QuestionFeaturesBloc(getIt(), initial, questionId),
    );
    getIt.registerFactoryParam<QuestionKonspektBloc, int, String>(
      (questionId, categoryId) => QuestionKonspektBloc(
        konspekt,
        NetworkStatus(),
        questionId,
        categoryId,
      ),
    );
  });

  tearDown(() => getIt.reset());

  Widget wrap() => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              FeatureFlagsBloc(_StubFeatureFlagsRepository(client, storage)),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => _FakeAuthBloc(
            AuthRepository(client, storage, AnalyticsService()),
            GraphqlSubscriptionClient(client, storage),
          ),
        ),
      ],
      child: const Scaffold(
        body: QuestionFeaturesTabs(questionId: 7001, categoryId: '27'),
      ),
    ),
  );

  final explanation = find.textContaining('Објашњење.', findRichText: true);
  final konspektText = find.textContaining('Конспект.', findRichText: true);

  /// Высота листалки равна высоте открытой страницы: её низ совпадает с низом
  /// содержимого (кнопка «Сообщить об ошибке» плюс отступ страницы в 8).
  void expectFitsContent(WidgetTester tester) {
    final pager = tester.getRect(find.byType(PageView));
    final button = tester.getRect(find.byType(ReportProblemButton));
    expect(pager.height, greaterThan(0));
    expect(pager.bottom, closeTo(button.bottom + 8, 0.01));
  }

  testWidgets('тап по пилюле уезжает на вкладку с анимацией', (tester) async {
    konspekt.release = Completer()..complete();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(explanation, findsOneWidget);
    expect(konspektText, findsNothing);
    expectFitsContent(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    // На полпути видны обе страницы — содержимое едет, а не подменяется.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(explanation, findsOneWidget);
    expect(konspektText, findsOneWidget);

    await tester.pumpAndSettle();
    expect(explanation, findsNothing);
    expect(konspektText, findsOneWidget);
    expectFitsContent(tester);
  });

  testWidgets('свайп по содержимому переводит вкладку в блоке', (tester) async {
    konspekt.release = Completer()..complete();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(explanation, findsNothing);
    expect(konspektText, findsOneWidget);
    // Блок узнал о свайпе и запомнил вкладку, как после тапа по пилюле.
    expect(
      getIt<QuizPreferencesRepository>().questionTab,
      AppFeature.categorySummaries,
    );
    // Пилюля конспекта раскрылась в подпись.
    expect(find.text('questionTabs.konspekt'), findsOneWidget);
  });

  testWidgets('появившаяся вкладка сдвигает номера, но не открытую вкладку', (
    tester,
  ) async {
    konspekt.release = Completer();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    // Конспект ещё грузится: на панели объяснение и закрытый анализ.
    expect(find.byTooltip('questionTabs.konspekt'), findsNothing);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(LockedContentCard), findsOneWidget);

    // Конспект подъехал и встал второй вкладкой — перед открытым анализом.
    konspekt.release.complete();
    await tester.pumpAndSettle();

    expect(find.byTooltip('questionTabs.konspekt'), findsOneWidget);
    expect(find.byType(LockedContentCard), findsOneWidget);
    expect(konspektText, findsNothing);
    expect(
      getIt<QuizPreferencesRepository>().questionTab,
      AppFeature.questionAnalysis,
    );
  });
}
