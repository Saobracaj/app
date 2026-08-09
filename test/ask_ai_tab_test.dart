import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/ask_ai_chat_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/presentation/question_features_tabs.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Чат с заранее заданной историей: вкладке этого достаточно, чтобы отрисовать
/// либо пустое состояние с подсказками, либо переписку.
class _StubChatRepository extends AskAiChatRepository {
  _StubChatRepository()
    : super(
        GraphqlClient(TokenStorage()),
        GraphqlSubscriptionClient(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  List<AskAiChatMessage> historyMessages = const [];

  @override
  Future<List<AskAiChatMessage>> history(AskAiChatScope scope, String scopeId) async =>
      historyMessages;

  @override
  Stream<AskAiStreamUpdate> replyStream(AskAiChatScope scope, String scopeId) =>
      const Stream.empty();

  @override
  Future<AskAiQuota> quota() async => const AskAiQuota(limit: 40, used: 0, remaining: 40);

  @override
  Future<AskAiChatMessage> ask(AskAiChatScope scope, String scopeId, String message) async =>
      AskAiChatMessage(id: '1', role: AskAiChatRole.assistant, content: 'ok', createdAt: DateTime.now());
}

/// Выдаёт ровно вкладку «Спросить AI», чтобы панель отрисовала её одну.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository() : super(GraphqlClient(TokenStorage()), TokenStorage());

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in AppFeature.values)
        if (f != AppFeature.askAi) f.key: false,
    },
    grants: const {'ask_ai'},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late _StubChatRepository chat;

  setUp(() {
    chat = _StubChatRepository();
    getIt.registerLazySingleton<QuizPreferencesRepository>(QuizPreferencesRepository.new);
    getIt.registerFactoryParam<QuestionFeaturesBloc, AppFeature?, void>(
      (initial, _) => QuestionFeaturesBloc(getIt(), initial),
    );
    getIt.registerLazySingleton<AskAiChatRepository>(() => chat);
    getIt.registerFactoryParam<AskAiChatBloc, AskAiChatScope, String>(
      (scope, scopeId) => AskAiChatBloc(getIt(), scope, scopeId),
    );
  });

  tearDown(() => getIt.reset());

  Widget wrap() => MaterialApp(
    home: BlocProvider(
      create: (_) => FeatureFlagsBloc(_StubFeatureFlagsRepository()),
      child: const Scaffold(
        body: SingleChildScrollView(
          child: QuestionFeaturesTabs(questionId: 7921, categoryId: '25'),
        ),
      ),
    ),
  );

  testWidgets('вкладка показывает только чат: ни разбора, ни источников, ни второго заголовка', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Поле ввода и пустое состояние чата на месте.
    // Без EasyLocalization в дереве tr() отдаёт сам ключ.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('askAi.emptyHint'), findsOneWidget);
    expect(find.text('askAi.suggestWhy'), findsOneWidget);

    // Статичное объяснение с вкладки убрано целиком — оно есть в «Объяснении»
    // и «Конспекте».
    expect(find.text('askAi.chatTitle'), findsNothing);
    expect(find.text('askAi.wrongChoices'), findsNothing);
    expect(find.text('askAi.sources'), findsNothing);
    expect(find.text('askAi.noExplanation'), findsNothing);
    expect(find.text('askAi.loadFailed'), findsNothing);
  });

  testWidgets('тап по любой области вне поля ввода снимает фокус', (tester) async {
    chat.historyMessages = [
      AskAiChatMessage(
        id: '1',
        role: AskAiChatRole.user,
        content: 'Почему Б?',
        createdAt: DateTime(2026, 8, 9),
      ),
    ];
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    // Тап по сообщению переписки — область, у которой своего обработчика нет.
    await tester.tap(find.text('Почему Б?'));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
  });
}
