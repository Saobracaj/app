import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/ask_ai_chat_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/question_explanation_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/question_explanation.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_bloc.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/presentation/question_features_tabs.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Источник объяснений, который сначала падает заданное число раз («офлайн»,
/// «нет права», «икота сервера»), а потом отдаёт документ или «объяснения нет».
class _StubExplanationRepository extends QuestionExplanationRepository {
  _StubExplanationRepository()
      : super(GraphqlClient(TokenStorage()), _StubFeatureFlagsRepository());

  int failures = 0;
  bool hasExplanation = true;

  @override
  Future<QuestionExplanation?> load(int questionId) async {
    if (failures > 0) {
      failures--;
      throw GraphqlException('offline', network: true);
    }
    if (!hasExplanation) return null;
    return const QuestionExplanation(
      questionId: 7921,
      summary: 'Регулируют движение полицейские в форме.',
      // Разметка и ссылки в разборе обязаны отрисоваться, а не показаться как есть.
      explanation: 'По [чл. 2](zakon?chapter=I&chlan=2) это задача МВД.',
      wrongChoices: [
        ExplanationWrongChoice(index: 0, text: 'инспектори', why: 'Не уполномочены.'),
      ],
      sources: [
        ExplanationSource(type: 'zakon', title: 'Чл. 2 ЗОБС', uri: 'zakon?chapter=I&chlan=2'),
      ],
    );
  }
}

/// Пустой живой чат: история пуста, квота не тронута — вкладке достаточно,
/// чтобы отрисовать секцию чата под статичным объяснением.
class _StubChatRepository extends AskAiChatRepository {
  _StubChatRepository() : super(GraphqlClient(TokenStorage()));

  @override
  Future<List<AskAiChatMessage>> history(AskAiChatScope scope, String scopeId) async => const [];

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

  late _StubExplanationRepository repository;

  setUp(() {
    repository = _StubExplanationRepository();
    getIt.registerLazySingleton<QuestionExplanationRepository>(() => repository);
    getIt.registerLazySingleton<QuizPreferencesRepository>(QuizPreferencesRepository.new);
    getIt.registerFactoryParam<QuestionFeaturesBloc, AppFeature?, void>(
      (initial, _) => QuestionFeaturesBloc(getIt(), initial),
    );
    getIt.registerFactoryParam<AskAiBloc, int, void>(
      (questionId, _) => AskAiBloc(getIt(), questionId),
    );
    getIt.registerLazySingleton<AskAiChatRepository>(_StubChatRepository.new);
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

  testWidgets('загруженное объяснение отрисовано целиком: резюме, разбор, неверные варианты, источники', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Регулируют движение полицейские в форме.'), findsOneWidget);
    // Markdown-ссылка отрисована текстом, а не сырой разметкой.
    expect(find.textContaining('чл. 2', findRichText: true), findsWidgets);
    expect(find.textContaining('[', findRichText: true), findsNothing);
    expect(find.text('askAi.wrongChoices'), findsOneWidget);
    expect(find.text('инспектори'), findsOneWidget);
    expect(find.text('askAi.sources'), findsOneWidget);
    expect(find.text('askAi.noExplanation'), findsNothing);
  });

  testWidgets('сбой загрузки показывает причину, а retry восстанавливает вкладку', (tester) async {
    repository.failures = 1;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Без EasyLocalization в дереве tr() отдаёт сам ключ.
    expect(find.text('askAi.loadFailed'), findsOneWidget);
    expect(find.text('Регулируют движение полицейские в форме.'), findsNothing);

    await tester.tap(find.text('askAi.retry'));
    await tester.pumpAndSettle();

    expect(find.text('Регулируют движение полицейские в форме.'), findsOneWidget);
    expect(find.text('askAi.loadFailed'), findsNothing);
  });

  testWidgets('вопрос без объяснения получает понятную заглушку, а не пустую вкладку', (tester) async {
    repository.hasExplanation = false;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('askAi.noExplanation'), findsOneWidget);
    expect(find.text('askAi.loadFailed'), findsNothing);
  });
}
