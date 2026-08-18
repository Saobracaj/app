import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/chat/state_management/chat_events.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Реакции на сообщения чата (задача 1217568064138001).
///
/// Проверяется правило и путь до сервера, а не жесты: строка эмодзи в меню и
/// значки под пузырём смотрятся руками (см. сабтаску тестирования) — виджет-тест
/// целого экрана чата виснет на бесконечном индикаторе загрузки.

/// Сервер: одна переписка и мутация реакции, которая может отказать.
class _FakeApi implements HttpClientAdapter {
  _FakeApi({required this.chatMessages, this.reactionFails = false});

  List<Map<String, dynamic>> chatMessages;

  /// Мутация реакции отвечает ошибкой — так проверяется откат.
  bool reactionFails;

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
        data = {'mySupportChat': _chat()};
      case 'Me':
        data = {
          'me': const {'id': 'u1', 'email': 'u@e', 'permissions': []},
        };
      case 'ChatMessages':
        data = {
          'chatMessages': {
            'totalCount': chatMessages.length,
            'hasNextPage': false,
            'nodes': chatMessages,
          },
        };
      case 'ToggleChatMessageReaction':
        if (reactionFails) {
          return ResponseBody.fromString(
            json.encode({
              'errors': [
                {'message': 'reaction refused'},
              ],
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        data = {'toggleChatMessageReaction': true};
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

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _message(
  String id, {
  String body = 'привет',
  String authorId = 'u1',
  List<Map<String, dynamic>> reactions = const [],
}) => {
  'id': id,
  'threadId': 't1',
  'authorId': authorId,
  'authorDisplayName': authorId == 'u1' ? 'Ана' : 'Разработчик',
  'fromStaff': authorId != 'u1',
  'body': body,
  'createdAt': DateTime.utc(2026, 8, 18, 10).toIso8601String(),
  'readAt': null,
  'replyCount': 0,
  'attachments': const [],
  'reactions': reactions,
};

ChatBloc _bloc(_FakeApi api) {
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
    null,
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

  group('правило одной реакции', () {
    final message = ChatMessage(id: 'm1', createdAt: DateTime.utc(2026));

    test('нажатие ставит свою реакцию, повторное — снимает', () {
      final liked = message.withToggledReaction('👍');
      expect(liked.reactions.single.emoji, '👍');
      expect(liked.reactions.single.count, 1);
      expect(liked.hasMyReaction('👍'), isTrue);

      // Значок исчезает вовсе: реакция без единого голоса — не реакция.
      expect(liked.withToggledReaction('👍').reactions, isEmpty);
    });

    test('к чужой реакции присоединяются, а не заводят вторую такую же', () {
      final theirs = message.copyWith(
        reactions: const [ChatReaction(emoji: '👍', count: 2)],
      );
      final joined = theirs.withToggledReaction('👍');
      expect(joined.reactions.single.count, 3);
      expect(joined.reactions.single.mine, isTrue);

      // Снятие своей оставляет чужие на месте.
      final left = joined.withToggledReaction('👍');
      expect(left.reactions.single.count, 2);
      expect(left.reactions.single.mine, isFalse);
    });

    test('разные эмодзи от одного человека живут рядом', () {
      final both = message.withToggledReaction('👍').withToggledReaction('❤️');
      expect(both.reactions.map((r) => r.emoji), ['👍', '❤️']);
      expect(both.reactions.every((r) => r.mine && r.count == 1), isTrue);
    });
  });

  group('реакция в чате', () {
    test('видна сразу и уходит на сервер с эмодзи', () async {
      final api = _FakeApi(chatMessages: [_message('m1')]);
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.messages.isNotEmpty);

      bloc.add(ChatReactionToggled(bloc.state.messages.single, '👍'));
      await _until(
        () => api.operations.contains('ToggleChatMessageReaction'),
      );

      final vars =
          api.variables[api.operations.indexOf('ToggleChatMessageReaction')];
      expect(vars['messageId'], 'm1');
      expect(vars['emoji'], '👍');
      expect(bloc.state.messages.single.hasMyReaction('👍'), isTrue);
      expect(bloc.state.messages.single.reactions.single.count, 1);
      await bloc.close();
    });

    test('чужая реакция приезжает с сервера с числом и без пометки', () async {
      final api = _FakeApi(
        chatMessages: [
          _message(
            'm1',
            authorId: 'staff-1',
            reactions: const [
              {'emoji': '❤️', 'count': 3, 'mine': false},
            ],
          ),
        ],
      );
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.messages.isNotEmpty);

      final reaction = bloc.state.messages.single.reactions.single;
      expect(reaction.emoji, '❤️');
      expect(reaction.count, 3);
      expect(reaction.mine, isFalse);
      await bloc.close();
    });

    test('отказ сервера возвращает ленту к прежнему виду', () async {
      final api = _FakeApi(
        chatMessages: [_message('m1')],
        reactionFails: true,
      );
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.messages.isNotEmpty);

      bloc.add(ChatReactionToggled(bloc.state.messages.single, '👍'));
      await _until(() => bloc.state.errorMessage != null);

      expect(
        bloc.state.messages.single.reactions,
        isEmpty,
        reason: 'показывать реакцию, которой на сервере нет, нельзя',
      );
      expect(bloc.state.errorMessage, isNotNull);
      await bloc.close();
    });
  });
}
