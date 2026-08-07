import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/quest/question_features/data/question_analytics_repository.dart';
import 'package:saobracaj/test/quest/question_features/data/question_difficulty_repository.dart';
import 'package:saobracaj/test/quest/question_features/models/question_analytics.dart';
import 'package:saobracaj/test/quest/question_features/presentation/question_analysis_tab.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_analytics_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The analysis tab against the real `assets/question_analytics.json` and the
/// real Serbian translations — the numbers on screen are the ones the asset
/// carries, so a broken lookup or a missing translation key shows up here.
///
/// Only the difficulty half is stubbed: it is the one figure that comes from the
/// backend.

/// Difficulty that answers with a fixed record, or with none at all.
class _StubDifficultyRepository extends QuestionDifficultyRepository {
  _StubDifficultyRepository() : super(GraphqlClient(TokenStorage()));

  QuestionDifficulty? answer;
  bool fail = false;

  @override
  Future<QuestionDifficulty?> forQuestion(int questionId) async {
    if (fail) throw GraphqlException('offline', network: true);
    return answer;
  }
}

/// A session holder pinned to one status. Built over a real [AuthRepository]
/// (the same way the other Bloc tests do) but with the state fixed, because the
/// only thing the analysis tab asks it is "is somebody signed in".
class _StubAuthBloc extends AuthBloc {
  _StubAuthBloc(this._status, TokenStorage storage, GraphqlClient client)
    : super(
        AuthRepository(client, storage),
        GraphqlSubscriptionClient(client, storage),
      );

  final AuthStatus _status;

  @override
  AuthState get state => AuthState(status: _status);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late _StubDifficultyRepository difficulty;

  setUp(() {
    // The attempt history at the bottom of the tab is Drift-backed, and Drift
    // asks path_provider where to put the file. Point it at a scratch directory
    // instead of leaving the plugin unimplemented.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp
              .createTempSync('saobracaj_analysis_tab')
              .path,
        );

    difficulty = _StubDifficultyRepository();
    getIt.registerLazySingleton<TokenStorage>(TokenStorage.new);
    getIt.registerLazySingleton<QuestionAnalyticsRepository>(
      QuestionAnalyticsRepository.new,
    );
    getIt.registerLazySingleton<QuestionDifficultyRepository>(() => difficulty);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    return getIt.reset();
  });

  Widget wrap(int questionId, {bool authenticated = true}) => EasyLocalization(
    useOnlyLangCode: true,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('sr'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) {
        final storage = TokenStorage();
        final auth = _StubAuthBloc(
          authenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated,
          storage,
          GraphqlClient(storage),
        );
        if (!getIt.isRegistered<QuestionAnalyticsBloc>()) {
          getIt.registerFactoryParam<QuestionAnalyticsBloc, int, void>(
            (id, _) => QuestionAnalyticsBloc(getIt(), getIt(), auth, id),
          );
        }
        return MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestionAnalysisTab(questionId: questionId),
            ),
          ),
        );
      },
    ),
  );


  /// Mounts the tab and waits for its data.
  ///
  /// The offline analytics are decoded on a background isolate, which fake time
  /// cannot drive, so the whole load has to run inside `runAsync` — and both
  /// loading states render a spinner, which would make `pumpAndSettle` spin
  /// forever anyway.
  Future<void> show(WidgetTester tester, Widget widget) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      // EasyLocalization loads its translations before the tab is even built,
      // and the tab's own load follows — hence pumping between real delays.
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  testWidgets('shows the value, the probability and its pool', (tester) async {
    // qId 7921 is in category 25: one of 109 questions sharing a single slot,
    // worth 1 point — see tool/question_analytics.py.
    await show(tester, wrap(7921));

    expect(find.text('Вредност питања'), findsOneWidget);
    expect(find.text('Вероватноћа на испиту'), findsOneWidget);
    // 1 of 109 → 0.9%, i.e. one exam in 109.
    expect(find.text('0.9%'), findsOneWidget);
    expect(
      find.textContaining('109', findRichText: true),
      findsWidgets,
      reason: 'the pool the question is drawn from must be stated',
    );
  });

  testWidgets('a question the exam never draws is called out', (tester) async {
    // Category 38 has no slot in any of the 699 sampled variants.
    const qId = 8223;
    await show(tester, wrap(qId));

    expect(find.text('Не појављује се'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('difficulty is rendered with the evidence under it', (
    tester,
  ) async {
    difficulty.answer = const QuestionDifficulty(
      attempts: 500,
      wrongAttempts: 300,
      learners: 120,
      wrongRate: 0.6,
      difficulty: 0.6,
      baseline: 0.3,
    );
    await show(tester, wrap(7921));

    expect(find.text('60% грешака'), findsOneWidget);
    expect(find.text('Теже од просека базе (30%)'), findsOneWidget);
    expect(find.text('Одговора: 500 · Корисника: 120'), findsOneWidget);
  });

  testWidgets('a thin sample is labelled rather than quoted as measured', (
    tester,
  ) async {
    difficulty.answer = const QuestionDifficulty(
      attempts: 3,
      wrongAttempts: 2,
      learners: 3,
      wrongRate: 0.667,
      difficulty: 0.35,
      baseline: 0.3,
    );
    await show(tester, wrap(7921));

    expect(
      find.text('Података је још мало, па је процена приближена просеку базе.'),
      findsOneWidget,
    );
  });

  testWidgets('a guest gets the offline blocks and no difficulty', (
    tester,
  ) async {
    await show(tester, wrap(7921, authenticated: false));

    expect(find.text('Вредност питања'), findsOneWidget);
    expect(
      find.text(
        'Пријавите се да видите колико често други греше на овом питању.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed difficulty request does not break the tab', (
    tester,
  ) async {
    difficulty.fail = true;
    await show(tester, wrap(7921));

    expect(find.text('Вредност питања'), findsOneWidget);
    expect(
      find.text('Није могуће преузети податке о тежини.'),
      findsOneWidget,
    );
  });
}
