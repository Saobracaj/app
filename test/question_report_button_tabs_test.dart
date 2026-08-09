import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/question_feedback/presentation/report_problem_button.dart';
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/quest/comment/data/comment_repository.dart';
import 'package:saobracaj/test/quest/comment/state_management/comment_bloc.dart';
import 'package:saobracaj/test/quest/question_features/presentation/question_features_tabs.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Вкладка «Объяснение» — такой же чужой текст, как конспект и обсуждение,
/// поэтому пожаловаться на него надо уметь прямо оттуда.

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
  Future<QuestionCommentDetails> fetchComment(int questionId) async =>
      const QuestionCommentDetails(status: 'READY', text: 'Објашњење.');
}

class _FakeAuthBloc extends AuthBloc {
  _FakeAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

/// Включает вкладку объяснения и саму обратную связь — больше ничего.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository(super.client, super.storage);

  static const _enabled = {
    AppFeature.questionComments,
    AppFeature.questionFeedback,
  };

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in AppFeature.values)
        if (!_enabled.contains(f)) f.key: false,
    },
    // Объяснение — премиальная фича, без гранта вкладки просто нет.
    grants: const {'question_comments'},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late _FakeClient client;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage();
    client = _FakeClient(storage);
    getIt.registerLazySingleton<QuizPreferencesRepository>(
      QuizPreferencesRepository.new,
    );
    getIt.registerFactoryParam<CommentBloc, int, void>(
      (questionId, _) => CommentBloc(
        _StubCommentRepository(client, _StubFeatureFlagsRepository(client, storage)),
        questionId,
      ),
    );
    getIt.registerFactoryParam<QuestionFeaturesBloc, AppFeature?, void>(
      (initial, _) => QuestionFeaturesBloc(getIt(), initial),
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
            AuthRepository(client, storage),
            GraphqlSubscriptionClient(client, storage),
          ),
        ),
      ],
      child: const Scaffold(
        body: QuestionFeaturesTabs(questionId: 7001, categoryId: '25'),
      ),
    ),
  );

  testWidgets('под объяснением есть кнопка «Сообщить об ошибке»', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Markdown рисует текст через RichText, отсюда findRichText.
    expect(
      find.textContaining('Објашњење.', findRichText: true),
      findsOneWidget,
    );
    // Без EasyLocalization в дереве tr() отдаёт сам ключ.
    expect(find.byType(ReportProblemButton), findsOneWidget);
    expect(find.text('questionFeedback.report'), findsOneWidget);
  });
}
