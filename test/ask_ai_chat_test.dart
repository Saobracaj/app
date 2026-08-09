import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/ask_ai_chat_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/presentation/ask_ai_chat_section.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_events.dart';

/// Управляемый транспорт чата: история и квота задаются тестом, отправка
/// может падать сетью или ответом сервера (текст ошибки — как настоящий).
class _StubChatRepository extends AskAiChatRepository {
  _StubChatRepository() : super(GraphqlClient(TokenStorage()));

  List<AskAiChatMessage> historyMessages = [];
  int historyFailures = 0;
  AskAiQuota quotaValue = const AskAiQuota(limit: 40, used: 0, remaining: 40);
  GraphqlException? askError;
  final askedMessages = <String>[];

  @override
  Future<List<AskAiChatMessage>> history(AskAiChatScope scope, String scopeId) async {
    if (historyFailures > 0) {
      historyFailures--;
      throw GraphqlException('offline', network: true);
    }
    return historyMessages;
  }

  @override
  Future<AskAiQuota> quota() async => quotaValue;

  @override
  Future<AskAiChatMessage> ask(AskAiChatScope scope, String scopeId, String message) async {
    final error = askError;
    if (error != null) throw error;
    askedMessages.add(message);
    return AskAiChatMessage(
      id: 'srv-${askedMessages.length}',
      role: AskAiChatRole.assistant,
      content: 'Ответ на: $message',
      createdAt: DateTime.now(),
    );
  }
}

AskAiChatMessage _message(String id, AskAiChatRole role, String content) =>
    AskAiChatMessage(id: id, role: role, content: content, createdAt: DateTime(2026, 8, 9));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubChatRepository repository;

  setUp(() {
    repository = _StubChatRepository();
  });

  AskAiChatBloc bloc() => AskAiChatBloc(repository, AskAiChatScope.question, '7921');

  group('AskAiChatBloc', () {
    test('открытие загружает историю и квоту', () async {
      repository.historyMessages = [
        _message('1', AskAiChatRole.user, 'Почему Б?'),
        _message('2', AskAiChatRole.assistant, 'Потому что…'),
      ];
      final b = bloc();
      await pumpEventQueue();

      expect(b.state.loading, isFalse);
      expect(b.state.messages, hasLength(2));
      expect(b.state.quota?.remaining, 40);
      expect(b.state.isEmpty, isFalse);
      await b.close();
    });

    test('сбой истории даёт historyFailed, а повторное открытие восстанавливает чат', () async {
      repository.historyFailures = 1;
      final b = bloc();
      await pumpEventQueue();
      expect(b.state.historyFailed, isTrue);

      b.add(AskAiChatOpened());
      await pumpEventQueue();
      expect(b.state.historyFailed, isFalse);
      expect(b.state.isEmpty, isTrue);
      await b.close();
    });

    test('успешная отправка добавляет обе реплики, чистит черновик и перечитывает квоту', () async {
      final b = bloc();
      await pumpEventQueue();

      b.add(AskAiChatBodyChanged('Почему этот ответ правильный?'));
      await pumpEventQueue();
      expect(b.state.canSend, isTrue);

      repository.quotaValue = const AskAiQuota(limit: 40, used: 1, remaining: 39);
      b.add(AskAiChatSendPressed());
      await pumpEventQueue();

      expect(b.state.sending, isFalse);
      expect(b.state.pendingUserText, isNull);
      expect(b.state.body, isEmpty);
      expect(b.state.messages.map((m) => m.role), [AskAiChatRole.user, AskAiChatRole.assistant]);
      expect(b.state.messages.first.content, 'Почему этот ответ правильный?');
      expect(b.state.quota?.remaining, 39);
      await b.close();
    });

    test('сбой отправки сохраняет черновик и показывает ошибку сервера как есть', () async {
      final b = bloc();
      await pumpEventQueue();

      b.add(AskAiChatBodyChanged('Сравни с билетом 8033'));
      repository.askError = GraphqlException('Дневной лимит сообщений исчерпан');
      b.add(AskAiChatSendPressed());
      await pumpEventQueue();

      expect(b.state.messages, isEmpty);
      expect(b.state.pendingUserText, isNull);
      // Черновик не потерян — можно поправить и отправить снова.
      expect(b.state.body, 'Сравни с билетом 8033');
      expect(b.state.errorMessage, 'Дневной лимит сообщений исчерпан');
      await b.close();
    });

    test('сетевой сбой отправки показывает переводимый ключ, а не техническое сообщение', () async {
      final b = bloc();
      await pumpEventQueue();

      b.add(AskAiChatBodyChanged('Вопрос'));
      repository.askError = GraphqlException('connection refused', network: true);
      b.add(AskAiChatSendPressed());
      await pumpEventQueue();

      expect(b.state.errorMessage, 'askAi.sendFailed');
      await b.close();
    });

    test('исчерпанная квота блокирует отправку', () async {
      repository.quotaValue = const AskAiQuota(limit: 40, used: 40, remaining: 0);
      final b = bloc();
      await pumpEventQueue();

      b.add(AskAiChatBodyChanged('Ещё вопрос'));
      await pumpEventQueue();
      expect(b.state.quotaExhausted, isTrue);
      expect(b.state.canSend, isFalse);

      b.add(AskAiChatSendPressed());
      await pumpEventQueue();
      expect(repository.askedMessages, isEmpty);
      await b.close();
    });

    test('подсказка отправляется как готовый вопрос, не трогая черновик', () async {
      final b = bloc();
      await pumpEventQueue();

      b.add(AskAiChatBodyChanged('черновик'));
      b.add(AskAiChatSendPressed(text: 'Разбери мои ошибки'));
      await pumpEventQueue();

      expect(repository.askedMessages, ['Разбери мои ошибки']);
      expect(b.state.body, 'черновик');
      expect(b.state.messages.first.content, 'Разбери мои ошибки');
      await b.close();
    });
  });

  group('AskAiChatSection', () {
    setUp(() {
      getIt.registerLazySingleton<AskAiChatRepository>(() => repository);
      getIt.registerFactoryParam<AskAiChatBloc, AskAiChatScope, String>(
        (scope, scopeId) => AskAiChatBloc(getIt(), scope, scopeId),
      );
    });

    tearDown(() => getIt.reset());

    Widget wrap() => const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: AskAiChatSection(questionId: 7921)),
      ),
    );

    testWidgets('пустой чат показывает подсказки и композер', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Без EasyLocalization в дереве tr() отдаёт сам ключ.
      expect(find.text('askAi.emptyHint'), findsOneWidget);
      expect(find.text('askAi.suggestWhy'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('askAi.quotaExhausted'), findsNothing);
    });

    testWidgets('история отрисовывается пузырями с обеих сторон', (tester) async {
      repository.historyMessages = [
        _message('1', AskAiChatRole.user, 'Почему Б?'),
        _message('2', AskAiChatRole.assistant, 'Потому что закон.'),
      ];
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Почему Б?'), findsOneWidget);
      expect(find.textContaining('Потому что закон', findRichText: true), findsWidgets);
      expect(find.text('askAi.emptyHint'), findsNothing);
    });

    testWidgets('исчерпанная квота меняет композер на понятную заглушку', (tester) async {
      repository.quotaValue = const AskAiQuota(limit: 40, used: 40, remaining: 0);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('askAi.quotaExhausted'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('тап по подсказке отправляет её и рисует ответ ассистента', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('askAi.suggestWhy'));
      await tester.pumpAndSettle();

      expect(repository.askedMessages, ['askAi.suggestWhy']);
      expect(find.text('askAi.suggestWhy'), findsOneWidget); // теперь как пузырь пользователя
      expect(find.textContaining('Ответ на', findRichText: true), findsWidgets);
    });
  });
}
