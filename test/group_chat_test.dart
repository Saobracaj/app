import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:saobracaj/chat/models/chat_target.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/chat/state_management/chat_events.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/groups/models/group.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Чат группы: тот же самый экран, что и «чат с разработчиком», только цель
/// другая. Здесь проверяется всё, что у него своего, — как он открывается, чем
/// называется и как считается непрочитанное на карточке группы.

/// Сервер, отвечающий на запросы чата группы и помнящий, о чём спрашивали.
class _FakeApi implements HttpClientAdapter {
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
    // Именно этим запросом чат группы и создаётся на бэкенде.
    if (operation == 'GroupChat') {
      expect(query, contains('entityType: GROUP'));
    }

    final Map<String, dynamic> data = switch (operation) {
      'GroupChat' => {'chatFor': _chat()},
      'Chat' => {'chat': _chat()},
      'Me' => {
        'me': const {'id': 'u1', 'email': 'u@e', 'permissions': []},
      },
      'ChatMessages' => {
        'chatMessages': const {
          'totalCount': 0,
          'hasNextPage': false,
          'nodes': [],
        },
      },
      'MarkChatRead' => {'markChatRead': 0},
      _ => const {},
    };
    return ResponseBody.fromString(
      json.encode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _chat() => {
    'id': 'c1',
    'entityType': 'GROUP',
    'entityId': 'g1',
    'entityName': 'Ауто-школа',
    'isGroup': true,
    'userId': '',
    'userDisplayName': '',
    'createdAt': '2026-08-18T09:00:00Z',
    'unreadCount': 3,
    'messagesCount': 0,
  };

  @override
  void close({bool force = false}) {}
}

/// Сокет подписки, который никуда не соединяется: живое обновление проверяется
/// в тестах чата с разработчиком, здесь оно только не должно мешать.
class _DeadSocket implements GraphqlSocket {
  final _controller = StreamController<dynamic>();

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  void send(String message) {}

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

ChatBloc _bloc(_FakeApi api, {required String groupId}) {
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = api);
  final repository = ChatRepository(
    client,
    GraphqlSubscriptionClient(
      client,
      storage,
      connector: (_) async => _DeadSocket(),
      endpoint: Uri.parse('ws://localhost:8080/ws'),
      retryDelay: (_) => Duration.zero,
    ),
  );
  return ChatBloc(
    repository,
    const NotificationPermissions(),
    AuthRepository(client, storage, AnalyticsService()),
    GroupChatTarget(groupId),
  );
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('открытие чата группы', () {
    test('идёт через chatFor(GROUP) с идентификатором группы', () async {
      final api = _FakeApi();
      final bloc = _bloc(api, groupId: 'g1');
      bloc.add(ChatOpened());
      await _until(() => bloc.state.loaded);

      expect(api.operations, contains('GroupChat'));
      expect(
        api.variables[api.operations.indexOf('GroupChat')]['groupId'],
        'g1',
      );
      expect(bloc.state.thread?.isGroupChat, isTrue);
      // Заголовок экрана — название группы, вторым запросом его не берут.
      expect(bloc.state.thread?.title, 'Ауто-школа');
      unawaited(bloc.close());
    });
  });

  group('модель чата', () {
    test('чат группы называется своей группой, а обращение — собеседником', () {
      final group = Chat.parse(const {
        'id': 'c1',
        'entityType': 'GROUP',
        'entityId': 'g1',
        'entityName': 'Ауто-школа',
        'isGroup': true,
        'createdAt': '2026-08-18T09:00:00Z',
      });
      expect(group.isGroupChat, isTrue);
      expect(group.title, 'Ауто-школа');

      final support = Chat.parse(const {
        'id': 'c2',
        'entityType': 'SUPPORT',
        'userDisplayName': 'Ана',
        'userEmail': 'ana@example.com',
        'createdAt': '2026-08-18T09:00:00Z',
      });
      expect(support.isGroupChat, isFalse);
      expect(support.title, 'Ана');
    });

    test('без имени и названия остаётся почта — это список модератора', () {
      final chat = Chat.parse(const {
        'id': 'c3',
        'entityType': 'SUPPORT',
        'userEmail': 'ana@example.com',
        'createdAt': '2026-08-18T09:00:00Z',
      });
      expect(chat.title, 'ana@example.com');
    });
  });

  group('карточка группы', () {
    test('несёт число непрочитанных сообщений чата', () {
      final group = Group.fromJson(const {
        'id': 'g1',
        'name': 'Ауто-школа',
        'memberCount': 3,
        'chatUnreadCount': 5,
      });
      expect(group.chatUnreadCount, 5);
      // Старый сервер поля не отдаёт — значка просто нет.
      expect(
        Group.fromJson(const {'id': 'g2', 'name': 'Без чата'}).chatUnreadCount,
        0,
      );
    });
  });

  group('маршруты', () {
    test('чат группы лежит под её лентой — «назад» возвращает в ленту', () {
      expect(routes.get('/groups/g1/feed'), isNotNull);
      expect(routes.get('/groups/g1/feed/chat'), isNotNull);
    });
  });
}
