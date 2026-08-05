import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server side of one connection: records what the client sent and lets the
/// test push frames back.
class _FakeSocket implements GraphqlSocket {
  final _controller = StreamController<dynamic>();
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  void send(String message) =>
      sent.add(json.decode(message) as Map<String, dynamic>);

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }

  void emit(Map<String, dynamic> message) {
    if (!_controller.isClosed) _controller.add(json.encode(message));
  }

  /// The connection dropped (the server went away, the network moved).
  Future<void> drop() async {
    if (!_controller.isClosed) await _controller.close();
  }

  Map<String, dynamic>? frame(String type) =>
      sent.where((m) => m['type'] == type).firstOrNull;
}

/// Hands out a fresh socket per connect attempt, so a reconnect can be observed.
class _Connector {
  final List<_FakeSocket> sockets = [];

  Future<GraphqlSocket> call(Uri url) async {
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }

  _FakeSocket get last => sockets.last;
}

/// A JWT the client will accept as live: only `exp` is ever read.
String _token({Duration validFor = const Duration(hours: 1)}) {
  String part(Map<String, dynamic> claims) =>
      base64Url.encode(utf8.encode(json.encode(claims))).replaceAll('=', '');
  final exp = DateTime.now().toUtc().add(validFor).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.signature';
}

/// A Dio that fails every call: the tests never let the client reach the
/// refresh endpoint (the stored token is live), so a request means a bug.
class _RefusingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw StateError('no HTTP request expected: ${options.data}');

  @override
  void close({bool force = false}) {}
}

({GraphqlSubscriptionClient client, _Connector connector}) _client() {
  final storage = TokenStorage();
  final dio = Dio()..httpClientAdapter = _RefusingAdapter();
  final connector = _Connector();
  return (
    client: GraphqlSubscriptionClient(
      GraphqlClient(storage, dio: dio),
      storage,
      connector: connector.call,
      languageProvider: () => 'ru',
      endpoint: Uri.parse('ws://localhost:8080/ws'),
      retryDelay: (_) => Duration.zero,
    ),
    connector: connector,
  );
}

/// Let the client's own futures and timers run.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_access_token': _token(),
      'auth_refresh_token': _token(validFor: const Duration(days: 7)),
    }),
  );

  test('authenticates in connection_init and subscribes after the ack', () async {
    final (:client, :connector) = _client();
    final messages = <GraphqlSubscriptionMessage>[];
    final sub = client
        .subscribe('subscription S { x }', variables: {'id': '1'})
        .listen(messages.add);
    await _settle();

    final socket = connector.last;
    final init = socket.frame('connection_init')!;
    final payload = init['payload'] as Map<String, dynamic>;
    expect(payload['Authorization'], startsWith('Bearer '));
    expect(payload['language'], 'ru');
    expect(payload['deviceId'], isNotEmpty);
    // Nothing is subscribed before the server acknowledges the connection.
    expect(socket.frame('subscribe'), isNull);

    socket.emit({'type': 'connection_ack'});
    await _settle();

    final subscribe = socket.frame('subscribe')!;
    expect(subscribe['payload']['query'], contains('subscription S'));
    expect(subscribe['payload']['variables'], {'id': '1'});
    expect(messages.single, isA<GraphqlSubscriptionResumed>());
    expect(
      (messages.single as GraphqlSubscriptionResumed).firstConnect,
      isTrue,
    );

    socket.emit({
      'id': subscribe['id'],
      'type': 'next',
      'payload': {
        'data': {'x': 42},
      },
    });
    await _settle();
    expect((messages.last as GraphqlSubscriptionData).data, {'x': 42});

    await sub.cancel();
  });

  test('answers a ping with a pong so the server keeps the socket', () async {
    final (:client, :connector) = _client();
    final sub = client.subscribe('subscription S { x }').listen((_) {});
    await _settle();
    connector.last
      ..emit({'type': 'connection_ack'})
      ..emit({'type': 'ping'});
    await _settle();

    expect(connector.last.frame('pong'), isNotNull);
    await sub.cancel();
  });

  test('reconnects, re-subscribes and says events may have been missed', () async {
    final (:client, :connector) = _client();
    final messages = <GraphqlSubscriptionMessage>[];
    final sub = client.subscribe('subscription S { x }').listen(messages.add);
    await _settle();
    connector.last.emit({'type': 'connection_ack'});
    await _settle();

    await connector.last.drop();
    await _settle();

    expect(connector.sockets, hasLength(2), reason: 'should have reconnected');
    connector.last.emit({'type': 'connection_ack'});
    await _settle();

    expect(connector.last.frame('subscribe'), isNotNull);
    final resumes = messages.whereType<GraphqlSubscriptionResumed>().toList();
    expect(resumes, hasLength(2));
    // The second one is a recovery: whatever happened while the socket was down
    // was not delivered, and the subscriber has to re-read.
    expect(resumes.last.firstConnect, isFalse);

    await sub.cancel();
  });

  test('an operation error ends that subscription with the server message', () async {
    final (:client, :connector) = _client();
    Object? error;
    final sub = client
        .subscribe('subscription S { x }')
        .listen((_) {}, onError: (Object e) => error = e);
    await _settle();
    connector.last.emit({'type': 'connection_ack'});
    await _settle();

    final id = connector.last.frame('subscribe')!['id'];
    connector.last.emit({
      'id': id,
      'type': 'error',
      'payload': [
        {'message': 'not a member'},
      ],
    });
    await _settle();

    expect(error, isA<GraphqlException>());
    expect('$error', contains('not a member'));
    // Nothing is subscribed any more, so the socket is let go.
    expect(connector.sockets.first.closed, isTrue);
    await sub.cancel();
  });

  test('the socket is opened for the first listener and closed after the last', () async {
    final (:client, :connector) = _client();
    final first = client.subscribe('subscription A { a }').listen((_) {});
    await _settle();
    final second = client.subscribe('subscription B { b }').listen((_) {});
    await _settle();
    connector.last.emit({'type': 'connection_ack'});
    await _settle();

    // One socket carries both subscriptions.
    expect(connector.sockets, hasLength(1));
    expect(connector.last.sent.where((m) => m['type'] == 'subscribe'), hasLength(2));

    await first.cancel();
    await _settle();
    expect(connector.last.closed, isFalse, reason: 'B is still listening');

    await second.cancel();
    await _settle();
    expect(connector.last.closed, isTrue);
  });

  test('a session that cannot be renewed fails the subscription for good', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': _token(validFor: const Duration(hours: -1)),
      'auth_refresh_token': _token(validFor: const Duration(days: -1)),
    });
    final (:client, :connector) = _client();
    Object? error;
    final sub = client
        .subscribe('subscription S { x }')
        .listen((_) {}, onError: (Object e) => error = e);
    await _settle();

    expect(error, isA<AuthExpiredException>());
    expect(connector.sockets, isEmpty, reason: 'no point opening a socket');
    await sub.cancel();
  });
}
