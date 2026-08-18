import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat_target.dart';
import 'package:saobracaj/chat/presentation/linked_text.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/chat/state_management/chat_events.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/question_lists/models/question_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Правки чата по задаче 1217567372723196: удаление и жалоба из меню
/// сообщения, список вопросов, приложенный ссылкой шаринга, и разбор ссылок на
/// вопрос и на список внутри текста.
///
/// Жесты и меню проверяются руками (см. сабтаску тестирования): виджет-тест
/// экрана чата здесь виснет на бесконечной анимации индикатора загрузки, а
/// проверять правила вместо жестов честнее в Bloc'е.

/// Сервер: одна переписка, ответы на всё, что чат спрашивает.
class _FakeApi implements HttpClientAdapter {
  _FakeApi({required this.chatMessages});

  List<Map<String, dynamic>> chatMessages;

  final List<String> operations = [];
  final List<Map<String, dynamic>> variables = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final raw = options.data;
    final body = raw is String
        ? json.decode(raw) as Map<String, dynamic>
        : (raw as Map).cast<String, dynamic>();
    final query = body['query'].toString();
    final vars = (body['variables'] as Map?)?.cast<String, dynamic>() ?? {};
    final operation = RegExp(
      r'(?:query|mutation)\s+(\w+)',
    ).firstMatch(query)!.group(1)!;
    operations.add(operation);
    variables.add(vars);

    final Map<String, dynamic> data;
    switch (operation) {
      case 'MySupportChat':
      case 'Chat':
        data = {operation == 'Chat' ? 'chat' : 'mySupportChat': _chat()};
      case 'OpenMessageThread':
        data = {'openMessageThread': _thread()};
      case 'Me':
        data = {
          'me': const {'id': 'u1', 'email': 'u@e', 'permissions': []},
        };
      case 'ChatMessages':
        final nodes = vars['chatId'] == 'thread-1'
            ? const <Map<String, dynamic>>[]
            : chatMessages;
        data = {
          'chatMessages': {
            'totalCount': nodes.length,
            'hasNextPage': false,
            'nodes': nodes,
          },
        };
      case 'ChatMessage':
        data = {
          'chatMessage': chatMessages.firstWhere(
            (m) => m['id'] == vars['messageId'],
          ),
        };
      case 'DeleteChatMessage':
        chatMessages = chatMessages
            .where((m) => m['id'] != vars['messageId'])
            .toList();
        data = {'deleteChatMessage': true};
      case 'ReportChatMessage':
        data = {'reportChatMessage': true};
      case 'ShareQuestionList':
        data = {
          'shareQuestionList': {
            'code': 'X94CC64J',
            'url': 'https://saobracaj.gleb.at/shared/X94CC64J',
            'listId': vars['listId'],
          },
        };
      case 'MarkChatRead':
        data = {'markChatRead': 0};
      default:
        data = {};
    }
    return ResponseBody.fromString(
      json.encode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _chat() => {
    'id': 't1',
    'entityType': 'SUPPORT',
    'userId': 'u1',
    'userDisplayName': 'Ана',
    'createdAt': '2026-08-18T09:00:00Z',
    'unreadCount': 0,
    'messagesCount': chatMessages.length,
  };

  Map<String, dynamic> _thread() => {
    'id': 'thread-1',
    'entityType': 'MESSAGE_THREAD',
    'entityId': 'm1',
    'parentMessageId': 'm1',
    'createdAt': '2026-08-18T09:30:00Z',
    'unreadCount': 0,
    'messagesCount': 0,
  };

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _message(
  String id, {
  String body = 'привет',
  String authorId = 'u1',
  int minute = 0,
}) => {
  'id': id,
  'threadId': 't1',
  'authorId': authorId,
  'authorDisplayName': authorId == 'u1' ? 'Ана' : 'Разработчик',
  'fromStaff': authorId != 'u1',
  'body': body,
  'createdAt': DateTime.utc(2026, 8, 18, 10, minute).toIso8601String(),
  'readAt': null,
  'replyCount': 0,
  'attachments': const [],
};

ChatBloc _bloc(_FakeApi api, {ChatTarget? target}) {
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = api);
  final repository = ChatRepository(
    client,
    GraphqlSubscriptionClient(
      client,
      storage,
      endpoint: Uri.parse('ws://localhost:1/ws'),
      retryDelay: (_) => const Duration(days: 1),
    ),
  );
  return ChatBloc(
    repository,
    const NotificationPermissions(),
    AuthRepository(client, storage, AnalyticsService()),
    SharedListsRepository(client),
    target,
  );
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'support_chat_notifications_asked': true,
    });
  });

  tearDown(() => getIt.reset());

  group('меню сообщения', () {
    test(
      'удаление убирает сообщение и не воскрешает его при перечитывании',
      () async {
        final api = _FakeApi(chatMessages: [_message('m1', body: 'ошибся')]);
        final bloc = _bloc(api);
        bloc.add(ChatOpened());
        await _until(() => bloc.state.messages.isNotEmpty);

        bloc.add(ChatMessageDeleted(bloc.state.messages.single));
        await _until(() => bloc.state.messages.isEmpty);

        expect(api.operations, contains('DeleteChatMessage'));
        expect(bloc.state.messages, isEmpty);

        // Страница с сервера сохраняет всё, чего в ней нет; удалённое сообщение
        // не должно возвращаться на экран при следующем чтении.
        api.chatMessages = [_message('m1', body: 'ошибся')];
        bloc.add(ChatRefreshed());
        await _until(() => bloc.state.loading == false);
        expect(bloc.state.messages, isEmpty);
        await bloc.close();
      },
    );

    test('жалоба уходит с причиной и подтверждается снекбаром', () async {
      final api = _FakeApi(
        chatMessages: [
          _message('m1', body: 'чужое слово', authorId: 'staff-1'),
        ],
      );
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.messages.isNotEmpty);

      bloc.add(ChatMessageReported(bloc.state.messages.single, 'spam'));
      await _until(() => bloc.state.notice != null);

      final vars = api.variables[api.operations.indexOf('ReportChatMessage')];
      expect(vars['messageId'], 'm1');
      expect(vars['reason'], 'spam');
      expect(bloc.state.notice, 'support.reportSent');
      await bloc.close();
    });

    test('удалить можно только своё сообщение', () async {
      final api = _FakeApi(
        chatMessages: [_message('m1', body: 'чужое', authorId: 'staff-1')],
      );
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.messages.isNotEmpty);

      bloc.add(ChatMessageDeleted(bloc.state.messages.single));
      await _until(() => api.operations.contains('DeleteChatMessage'));

      expect(
        api.operations,
        isNot(contains('DeleteChatMessage')),
        reason: 'чужое сообщение снимает только жалоба',
      );
      expect(bloc.state.messages, hasLength(1));
      await bloc.close();
    });
  });

  group('список вопросов', () {
    test('прикладывается ссылкой шаринга, а не отдельным вложением', () async {
      final api = _FakeApi(chatMessages: []);
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.loaded);

      bloc.add(
        ChatListShared(
          const QuestionList(id: 'l1', name: 'Иллюстрации', questionIds: [1]),
        ),
      );
      await _until(() => bloc.state.body.isNotEmpty);

      expect(api.operations, contains('ShareQuestionList'));
      expect(
        bloc.state.body,
        'https://saobracaj.gleb.at/shared/X94CC64J',
        reason: 'ссылка попадает в строку ввода, откуда её видно до отправки',
      );
      await bloc.close();
    });
  });

  group('ссылки в тексте', () {
    test('вопрос и список узнаются, чужой домен — нет', () {
      expect(
        questionIdIn(Uri.parse('https://saobracaj.gleb.at/question/1234')),
        1234,
      );
      expect(
        questionIdIn(Uri.parse('https://example.com/question/1234')),
        isNull,
      );
      expect(
        sharedListCodeIn(
          Uri.parse('https://saobracaj.gleb.at/shared/X94CC64J'),
        ),
        'X94CC64J',
      );
      expect(
        sharedListCodeIn(Uri.parse('https://saobracaj.gleb.at/lists')),
        isNull,
      );
    });
  });
}
