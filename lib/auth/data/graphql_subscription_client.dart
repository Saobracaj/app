import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth_config.dart';
import 'graphql_client.dart';
import 'token_storage.dart';

/// What a subscriber hears on a subscription's stream.
sealed class GraphqlSubscriptionMessage {
  const GraphqlSubscriptionMessage();
}

/// One `next` payload — the `data` object of the GraphQL answer.
class GraphqlSubscriptionData extends GraphqlSubscriptionMessage {
  const GraphqlSubscriptionData(this.data);

  final Map<String, dynamic> data;
}

/// The subscription is running: sent on the first `connection_ack` and again
/// after every reconnect.
///
/// A reconnect is not free of consequences — the server streams what happens
/// *from now on*, so whatever went past while the socket was down was missed.
/// Subscribers use this to re-read the state they mirror instead of quietly
/// showing a hole.
class GraphqlSubscriptionResumed extends GraphqlSubscriptionMessage {
  const GraphqlSubscriptionResumed({required this.firstConnect});

  /// Whether this is the initial connect rather than a recovery.
  final bool firstConnect;
}

/// The connection dropped and a reconnect is on the way. The subscription is
/// still alive as an object, it just is not receiving anything meanwhile — a
/// screen can say so instead of pretending it is up to date.
class GraphqlSubscriptionInterrupted extends GraphqlSubscriptionMessage {
  const GraphqlSubscriptionInterrupted();
}

/// The socket the client talks over, narrow enough that a test can play the
/// server without a network.
abstract class GraphqlSocket {
  /// Incoming frames (strings, or the byte lists a binary frame arrives as).
  Stream<dynamic> get messages;

  void send(String message);

  Future<void> close();
}

/// Opens a socket to [url]. Injected so tests can hand back a fake.
typedef GraphqlSocketConnector = Future<GraphqlSocket> Function(Uri url);

/// GraphQL subscriptions over a websocket, speaking `graphql-transport-ws`
/// (the protocol `async-graphql` serves on `/ws`).
///
/// One socket carries every active subscription in the app: the group feed today,
/// public comments and active-session sync later. The client
///
/// * authenticates in the `connection_init` payload — the same bearer token,
///   device id and language the HTTP client sends as headers — and refreshes the
///   access token *before* connecting, because a socket cannot retry the way a
///   request can;
/// * connects on the first subscriber and disconnects when the last one leaves,
///   so a signed-in user browsing questions holds no socket open;
/// * reconnects with a growing delay and re-subscribes everything, announcing it
///   with [GraphqlSubscriptionResumed] so subscribers can close the gap;
/// * gives up only when the session itself is over ([AuthExpiredException]) —
///   a network failure is always temporary as far as this class is concerned.
///
/// Registered via `RegisterModule` in `lib/core/di.dart`.
class GraphqlSubscriptionClient {
  GraphqlSubscriptionClient(
    this._client,
    this._storage, {
    GraphqlSocketConnector? connector,
    this.languageProvider,
    Uri? endpoint,
    Duration Function(int attempt)? retryDelay,
  }) : _connector = connector ?? _connectWebSocket,
       _endpoint = endpoint,
       _retryDelay = retryDelay ?? _defaultRetryDelay;

  final GraphqlClient _client;
  final TokenStorage _storage;
  final GraphqlSocketConnector _connector;
  final Uri? _endpoint;
  final Duration Function(int attempt) _retryDelay;

  /// Returns the current UI language code (e.g. `ru`), as for `Accept-Language`.
  final String Function()? languageProvider;

  final Map<String, _Operation> _operations = {};

  GraphqlSocket? _socket;
  StreamSubscription<dynamic>? _socketMessages;
  Future<void>? _connecting;
  bool _acked = false;
  bool _everConnected = false;
  int _attempt = 0;
  Timer? _retryTimer;
  bool _sessionOver = false;

  int _nextId = 0;

  /// Whether a socket is currently up and acknowledged.
  bool get isConnected => _acked;

  /// Subscribe to [query]. The returned stream starts the subscription on its
  /// first listener and stops it when the listener goes away.
  Stream<GraphqlSubscriptionMessage> subscribe(
    String query, {
    Map<String, dynamic> variables = const {},
  }) {
    final id = '${_nextId++}';
    late final StreamController<GraphqlSubscriptionMessage> controller;
    controller = StreamController<GraphqlSubscriptionMessage>(
      onListen: () {
        _operations[id] = _Operation(id, query, variables, controller);
        _sessionOver = false;
        unawaited(_ensureConnected());
      },
      onCancel: () {
        final operation = _operations.remove(id);
        if (operation != null && operation.started && _acked) {
          _send({'id': id, 'type': 'complete'});
        }
        if (_operations.isEmpty) unawaited(_disconnect());
      },
    );
    return controller.stream;
  }

  /// Drop the connection and fail every subscription — used when the session
  /// ends, so nothing keeps a socket open on behalf of a signed-out user.
  Future<void> reset() async {
    final operations = _operations.values.toList();
    _operations.clear();
    for (final operation in operations) {
      await operation.controller.close();
    }
    await _disconnect();
  }

  Future<void> _ensureConnected() {
    // `_socket != null` covers the window between "connected" and
    // "acknowledged": a second subscriber arriving mid-handshake joins the
    // socket that is already coming up instead of opening one of its own.
    if (_acked || _socket != null || _sessionOver) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    if (_operations.isEmpty) return;

    final String? token;
    try {
      token = await _client.freshAccessToken();
    } on AuthExpiredException catch (e) {
      // Nothing to reconnect to: the session is gone until the user signs in
      // again, and retrying would only hammer the refresh endpoint.
      _failAll(e);
      return;
    } catch (_) {
      _scheduleRetry();
      return;
    }

    GraphqlSocket? socket;
    try {
      socket = await _connector(_endpoint ?? AuthConfig.websocketUrl);
      _socket = socket;
      _socketMessages = socket.messages.listen(
        _onMessage,
        onError: (_) => _onDisconnected(),
        onDone: _onDisconnected,
        cancelOnError: false,
      );
      _send({
        'type': 'connection_init',
        'payload': {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'deviceId': await _storage.deviceId(),
          if (languageProvider?.call() case final language?
              when language.isNotEmpty)
            'language': language,
        },
      });
    } catch (_) {
      _socket = null;
      await _socketMessages?.cancel();
      _socketMessages = null;
      await socket?.close();
      _scheduleRetry();
    }
  }

  void _onMessage(dynamic raw) {
    final Object? decoded;
    try {
      decoded = json.decode(raw is List<int> ? utf8.decode(raw) : '$raw');
    } catch (_) {
      return; // Not our protocol; a frame we cannot read is a frame we ignore.
    }
    if (decoded is! Map) return;
    final message = decoded.cast<String, dynamic>();

    switch (message['type']) {
      case 'connection_ack':
        _acked = true;
        _attempt = 0;
        final firstConnect = !_everConnected;
        _everConnected = true;
        for (final operation in _operations.values) {
          _start(operation);
          operation.controller.add(
            GraphqlSubscriptionResumed(firstConnect: firstConnect),
          );
        }
      case 'next':
        final operation = _operations[message['id']?.toString()];
        if (operation == null) return;
        final payload = message['payload'];
        final data = payload is Map ? payload['data'] : null;
        if (data is Map) {
          operation.controller.add(
            GraphqlSubscriptionData(data.cast<String, dynamic>()),
          );
        }
      case 'error':
        // A per-operation failure: the server refused this subscription (not a
        // member any more, the feature was switched off). It will not start on a
        // reconnect either, so the operation ends here.
        final operation = _operations.remove(message['id']?.toString());
        if (operation == null) return;
        operation.controller.addError(
          GraphqlException(_errorMessage(message['payload'])),
        );
        unawaited(operation.controller.close());
        if (_operations.isEmpty) unawaited(_disconnect());
      case 'complete':
        final operation = _operations.remove(message['id']?.toString());
        unawaited(operation?.controller.close());
        if (_operations.isEmpty) unawaited(_disconnect());
      case 'ping':
        _send({'type': 'pong'});
    }
  }

  String _errorMessage(Object? payload) {
    if (payload is List && payload.isNotEmpty) {
      final first = payload.first;
      if (first is Map) return first['message']?.toString() ?? 'Subscription failed';
    }
    if (payload is Map) return payload['message']?.toString() ?? 'Subscription failed';
    return 'Subscription failed';
  }

  void _start(_Operation operation) {
    operation.started = true;
    _send({
      'id': operation.id,
      'type': 'subscribe',
      'payload': {'query': operation.query, 'variables': operation.variables},
    });
  }

  void _onDisconnected() {
    _acked = false;
    _socketMessages?.cancel();
    _socketMessages = null;
    _socket = null;
    for (final operation in _operations.values) {
      operation.started = false;
      operation.controller.add(const GraphqlSubscriptionInterrupted());
    }
    if (_operations.isNotEmpty) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _operations.isEmpty || _sessionOver) return;
    final delay = _retryDelay(_attempt++);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_ensureConnected());
    });
  }

  void _failAll(Object error) {
    _sessionOver = true;
    final operations = _operations.values.toList();
    _operations.clear();
    for (final operation in operations) {
      operation.controller.addError(error);
      unawaited(operation.controller.close());
    }
    unawaited(_disconnect());
  }

  Future<void> _disconnect() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _acked = false;
    _attempt = 0;
    final socket = _socket;
    _socket = null;
    await _socketMessages?.cancel();
    _socketMessages = null;
    await socket?.close();
  }

  void _send(Map<String, dynamic> message) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.send(json.encode(message));
    } catch (_) {
      // The socket died between the check and the write; the `done` handler
      // takes it from here.
    }
  }

  static Duration _defaultRetryDelay(int attempt) {
    const schedule = [1, 2, 5, 10, 20, 30];
    return Duration(
      seconds: schedule[attempt < schedule.length ? attempt : schedule.length - 1],
    );
  }

  static Future<GraphqlSocket> _connectWebSocket(Uri url) async {
    final channel = WebSocketChannel.connect(
      url,
      protocols: const ['graphql-transport-ws'],
    );
    await channel.ready;
    return _ChannelSocket(channel);
  }
}

class _Operation {
  _Operation(this.id, this.query, this.variables, this.controller);

  final String id;
  final String query;
  final Map<String, dynamic> variables;
  final StreamController<GraphqlSubscriptionMessage> controller;

  /// Whether `subscribe` has been sent on the current connection.
  bool started = false;
}

class _ChannelSocket implements GraphqlSocket {
  _ChannelSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get messages => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close() => _channel.sink.close();
}
