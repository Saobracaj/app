import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/support_chat/data/support_chat_repository.dart';
import 'package:saobracaj/support_chat/models/support_chat_update.dart';
import 'package:saobracaj/support_chat/state_management/support_chat_bloc.dart';
import 'package:saobracaj/support_chat/state_management/support_chat_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Живое обновление чата с разработчиком: сообщения и галочки прочтения
/// приходят по подписке, без «потяните, чтобы обновить».

/// Сервер: отвечает на запросы чата и помнит, о чём его спрашивали.
class _FakeApi implements HttpClientAdapter {
  _FakeApi({this.messages = const []});

  /// Вся переписка на сервере, от старых к новым.
  List<Map<String, dynamic>> messages;

  /// Сколько сообщений в треде — по умолчанию столько же, сколько в [messages].
  int? messagesCount;
  int unreadCount = 0;

  final List<String> operations = [];
  int markReadCalls = 0;

  /// С каким offset запросили последнюю страницу сообщений.
  int? lastOffset;
  int? lastLimit;

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
    final variables = (body['variables'] as Map?)?.cast<String, dynamic>() ?? {};
    final operation = RegExp(
      r'(?:query|mutation)\s+(\w+)',
    ).firstMatch(query)!.group(1)!;
    operations.add(operation);

    final Map<String, dynamic> data;
    switch (operation) {
      case 'MySupportThread':
        data = {'mySupportThread': _thread()};
      case 'SupportThread':
        data = {'supportThread': _thread()};
      case 'MySupportMessages':
      case 'SupportMessages':
        data = {
          operation == 'MySupportMessages'
                  ? 'mySupportMessages'
                  : 'supportMessages':
              _page(variables),
        };
      case 'MarkSupportThreadRead':
        markReadCalls++;
        data = {'markSupportThreadRead': 1};
      case 'SendSupportMessage':
        data = {'sendSupportMessage': messages.last};
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

  Map<String, dynamic> _thread() => {
    'id': 't1',
    'userId': 'u1',
    'userDisplayName': 'Ана',
    'createdAt': '2026-08-07T09:00:00Z',
    'unreadCount': unreadCount,
    'messagesCount': messagesCount ?? messages.length,
  };

  Map<String, dynamic> _page(Map<String, dynamic> variables) {
    lastOffset = (variables['offset'] as num?)?.toInt() ?? 0;
    lastLimit = (variables['limit'] as num?)?.toInt() ?? 50;
    final from = lastOffset!.clamp(0, messages.length);
    final to = (from + lastLimit!).clamp(0, messages.length);
    return {
      'totalCount': messagesCount ?? messages.length,
      'hasNextPage': to < messages.length,
      'nodes': messages.sublist(from, to),
    };
  }

  @override
  void close({bool force = false}) {}
}

/// Серверный конец подписки.
class _FakeSocket implements GraphqlSocket {
  final _controller = StreamController<dynamic>();
  final List<Map<String, dynamic>> sent = [];

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  void send(String message) =>
      sent.add(json.decode(message) as Map<String, dynamic>);

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }

  void emit(Map<String, dynamic> message) {
    if (!_controller.isClosed) _controller.add(json.encode(message));
  }

  Future<void> drop() async {
    if (!_controller.isClosed) await _controller.close();
  }

  Map<String, dynamic>? get subscription =>
      sent.where((m) => m['type'] == 'subscribe').lastOrNull;

  String? get subscriptionId => subscription?['id'].toString();
}

class _Connector {
  final List<_FakeSocket> sockets = [];

  Future<GraphqlSocket> call(Uri url) async {
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }

  _FakeSocket get last => sockets.last;
}

Map<String, dynamic> _message(
  String id, {
  bool fromStaff = false,
  String body = 'привет',
  String? readAt,
  int minute = 0,
}) => {
  'id': id,
  'threadId': 't1',
  'authorId': fromStaff ? 'staff' : 'u1',
  'authorDisplayName': fromStaff ? 'Разработчик' : 'Ана',
  'fromStaff': fromStaff,
  'body': body,
  'createdAt': DateTime.utc(2026, 8, 7, 10, minute).toIso8601String(),
  'readAt': readAt,
  'attachments': const [],
};

({SupportChatBloc bloc, _FakeApi api, _Connector sockets}) _bloc(
  _FakeApi api, {
  String? threadId,
}) {
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = api);
  final connector = _Connector();
  final repository = SupportChatRepository(
    client,
    GraphqlSubscriptionClient(
      client,
      storage,
      connector: connector.call,
      endpoint: Uri.parse('ws://localhost:8080/ws'),
      retryDelay: (_) => Duration.zero,
    ),
  );
  return (
    bloc: SupportChatBloc(
      repository,
      const NotificationPermissions(),
      AuthRepository(client, storage),
      threadId,
    ),
    api: api,
    sockets: connector,
  );
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 40));

/// Поднять подписку: соединение, ack, subscribe.
Future<void> _goLive(_Connector connector) async {
  await _settle();
  connector.last.emit({'type': 'connection_ack'});
  await _settle();
}

/// Прислать событие чата с сервера.
void _push(_FakeSocket socket, {required String kind, String? messageId}) {
  socket.emit({
    'id': socket.subscriptionId,
    'type': 'next',
    'payload': {
      'data': {
        'supportChatEvents': {
          'threadId': 't1',
          'kind': kind,
          'messageId': messageId,
        },
      },
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    // Про оповещения уже спрашивали — иначе диалог влезает в каждый тест.
    () => SharedPreferences.setMockInitialValues({
      'support_chat_notifications_asked': true,
    }),
  );

  group('разбор события подписки', () {
    test('вид изменения приходит с сервера в верхнем регистре', () {
      expect(
        SupportChangeKind.parse('MESSAGE_ADDED'),
        SupportChangeKind.messageAdded,
      );
      expect(
        SupportChangeKind.parse('READ_STATE_CHANGED'),
        SupportChangeKind.readStateChanged,
      );
      // Незнакомый вид — от более нового сервера; молча пропускаем.
      expect(SupportChangeKind.parse('WAT'), isNull);
      expect(SupportChangeKind.parse(null), isNull);
    });
  });

  group('живое обновление переписки', () {
    test('свой чат подписывается без id треда', () async {
      final (:bloc, :api, :sockets) = _bloc(
        _FakeApi(messages: [_message('m1')]),
      );
      bloc.add(SupportChatOpened());
      await _goLive(sockets);

      final subscription = sockets.last.subscription!;
      expect(subscription['payload']['query'], contains('supportChatEvents'));
      expect(subscription['payload']['variables'], {'threadId': null});
      expect(bloc.state.live, isTrue);
      await bloc.close();
    });

    test('ответ разработчика появляется сам, без обновления вручную', () async {
      final api = _FakeApi(messages: [_message('m1', minute: 1)]);
      final (:bloc, api: _, :sockets) = _bloc(api);
      bloc.add(SupportChatOpened());
      await _goLive(sockets);
      expect(bloc.state.messages.map((m) => m.id), ['m1']);

      // Разработчик ответил: сервер шлёт только «что-то изменилось».
      api.messages = [
        _message('m1', minute: 1),
        _message('m2', fromStaff: true, body: 'смотрим', minute: 2),
      ];
      _push(sockets.last, kind: 'MESSAGE_ADDED', messageId: 'm2');
      await _settle();

      expect(bloc.state.messages.map((m) => m.id), ['m1', 'm2']);
      expect(bloc.state.messages.last.body, 'смотрим');
      await bloc.close();
    });

    test('прочтение собеседником меняет галочки на своих сообщениях', () async {
      final api = _FakeApi(messages: [_message('m1', minute: 1)]);
      final (:bloc, api: _, :sockets) = _bloc(api);
      bloc.add(SupportChatOpened());
      await _goLive(sockets);
      expect(bloc.state.messages.single.isRead, isFalse);

      api.messages = [
        _message('m1', minute: 1, readAt: '2026-08-07T10:05:00Z'),
      ];
      _push(sockets.last, kind: 'READ_STATE_CHANGED');
      await _settle();

      expect(bloc.state.messages.single.isRead, isTrue);
      await bloc.close();
    });

    test('пользователю новое сообщение отмечается прочитанным автоматически', () async {
      final api = _FakeApi(messages: [_message('m1', minute: 1)]);
      final (:bloc, api: _, :sockets) = _bloc(api);
      bloc.add(SupportChatOpened());
      await _goLive(sockets);
      // Одно — при открытии чата.
      expect(api.markReadCalls, 1);

      api.messages = [
        _message('m1', minute: 1),
        _message('m2', fromStaff: true, minute: 2),
      ];
      _push(sockets.last, kind: 'MESSAGE_ADDED', messageId: 'm2');
      await _settle();

      expect(api.markReadCalls, 2);
      expect(bloc.state.messages.last.isRead, isTrue);
      await bloc.close();
    });

    test('модератору новое сообщение прочитанным само не отмечается', () async {
      final api = _FakeApi(messages: [_message('m1', minute: 1)]);
      final (:bloc, api: _, :sockets) = _bloc(api, threadId: 't1');
      bloc.add(SupportChatOpened());
      await _goLive(sockets);
      expect(api.markReadCalls, 1); // Только явное открытие переписки.

      api.messages = [
        _message('m1', minute: 1),
        _message('m2', minute: 2, body: 'ещё вопрос'),
      ];
      _push(sockets.last, kind: 'MESSAGE_ADDED', messageId: 'm2');
      await _settle();

      expect(bloc.state.messages.map((m) => m.id), ['m1', 'm2']);
      // У модераторов отметка о прочтении — ручная, список обращений не должен
      // «сам собой» очищаться, пока он смотрит переписку.
      expect(api.markReadCalls, 1);
      await bloc.close();
    });

    test('обрыв связи виден, а после переподключения переписка перечитывается', () async {
      final api = _FakeApi(messages: [_message('m1', minute: 1)]);
      final (:bloc, api: _, :sockets) = _bloc(api);
      bloc.add(SupportChatOpened());
      await _goLive(sockets);
      expect(bloc.state.live, isTrue);

      await sockets.last.drop();
      await _settle();
      expect(bloc.state.live, isFalse);

      // Пока связи не было, разработчик успел ответить: сервер бэклога не
      // держит, поэтому после переподключения чат перечитывается целиком.
      api.messages = [
        _message('m1', minute: 1),
        _message('m2', fromStaff: true, minute: 2),
      ];
      await _goLive(sockets);

      expect(bloc.state.live, isTrue);
      expect(bloc.state.messages.map((m) => m.id), ['m1', 'm2']);
      await bloc.close();
    });

    test('длинная переписка открывается на последней странице', () async {
      // 120 сообщений: страница 50 — значит хвост начинается с 70-го.
      final api = _FakeApi(
        messages: [
          for (var i = 0; i < 120; i++) _message('m$i', minute: i),
        ],
      );
      final (:bloc, api: _, :sockets) = _bloc(api);
      bloc.add(SupportChatOpened());
      await _settle();

      expect(api.lastOffset, 70);
      expect(api.lastLimit, 50);
      expect(bloc.state.messages.first.id, 'm70');
      expect(bloc.state.messages.last.id, 'm119');
      await bloc.close();
    });

    test('своё отправленное сообщение не задваивается событием подписки', () async {
      final api = _FakeApi(messages: [_message('m1', minute: 1)]);
      final (:bloc, api: _, :sockets) = _bloc(api);
      bloc.add(SupportChatOpened());
      await _goLive(sockets);

      api.messages = [_message('m1', minute: 1), _message('m2', minute: 2)];
      bloc.add(SupportChatBodyChanged('привет'));
      bloc.add(SupportChatSendPressed());
      await _settle();
      expect(bloc.state.messages.map((m) => m.id), ['m1', 'm2']);

      // Сервер рассказывает про то же самое сообщение всем участникам.
      _push(sockets.last, kind: 'MESSAGE_ADDED', messageId: 'm2');
      await _settle();

      expect(bloc.state.messages.map((m) => m.id), ['m1', 'm2']);
      await bloc.close();
    });

    test('подписка закрывается вместе с экраном', () async {
      final (:bloc, :api, :sockets) = _bloc(
        _FakeApi(messages: [_message('m1')]),
      );
      bloc.add(SupportChatOpened());
      await _goLive(sockets);

      await bloc.close();
      await _settle();

      expect(
        sockets.last.sent.where((m) => m['type'] == 'complete'),
        isNotEmpty,
      );
    });
  });
}
