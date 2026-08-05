import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/groups/data/groups_repository.dart';
import 'package:saobracaj/groups/models/group_event.dart';
import 'package:saobracaj/groups/state_management/group_feed_bloc.dart';
import 'package:saobracaj/groups/state_management/group_feed_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replays canned `groupFeed` pages in order.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.pages);

  final List<Map<String, dynamic>> pages;
  int requests = 0;

  /// When set, the next request fails as if the network were down.
  bool failNext = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (failNext) {
      failNext = false;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final page = pages.length == 1 ? pages.first : pages.removeAt(0);
    return ResponseBody.fromString(
      json.encode({
        'data': {'groupFeed': page},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The server end of the feed subscription.
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

  String? get subscriptionId => sent
      .where((m) => m['type'] == 'subscribe')
      .map((m) => m['id'].toString())
      .lastOrNull;
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

Map<String, dynamic> _event(
  String id, {
  String kind = 'MEMBER_JOINED',
  required DateTime occurredAt,
  String actor = 'Мила',
}) => {
  'id': id,
  'kind': kind,
  'occurredAt': occurredAt.toUtc().toIso8601String(),
  'actor': {'id': 'u1', 'displayName': actor},
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> events, {
  bool hasMore = false,
  DateTime? nextBefore,
  String? nextBeforeId,
}) => {
  'events': events,
  'hasMore': hasMore,
  'nextBefore': nextBefore?.toUtc().toIso8601String(),
  'nextBeforeId': nextBeforeId,
};

({GroupFeedBloc bloc, _FakeAdapter http, _Connector sockets}) _bloc(
  List<Map<String, dynamic>> pages,
) {
  final storage = TokenStorage();
  final adapter = _FakeAdapter(pages);
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = adapter);
  final connector = _Connector();
  final repository = GroupsRepository(
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
    bloc: GroupFeedBloc(repository, 'g1'),
    http: adapter,
    sockets: connector,
  );
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 40));

/// Bring the subscription up: connect, acknowledge, subscribe.
Future<void> _goLive(_Connector connector) async {
  await _settle();
  connector.last.emit({'type': 'connection_ack'});
  await _settle();
}

void _push(_FakeSocket socket, Map<String, dynamic> event) {
  socket.emit({
    'id': socket.subscriptionId,
    'type': 'next',
    'payload': {
      'data': {'groupFeedChanged': event},
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 5, 20);
  DateTime minutesAgo(int minutes) => now.subtract(Duration(minutes: minutes));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads the newest page and keeps the cursor to the rest', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page(
        [
          _event('e2', occurredAt: minutesAgo(1)),
          _event('e1', occurredAt: minutesAgo(10)),
        ],
        hasMore: true,
        nextBefore: minutesAgo(10),
        nextBeforeId: 'e1',
      ),
    ]);
    bloc.add(const GroupFeedOpened());
    await _settle();

    expect(bloc.state.events.map((e) => e.id), ['e2', 'e1']);
    expect(bloc.state.loaded, isTrue);
    expect(bloc.state.hasMore, isTrue);
    expect(bloc.state.nextBeforeId, 'e1');
    await bloc.close();
  });

  test('the next page is appended, and an event already on screen is not repeated', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page(
        [_event('e3', occurredAt: minutesAgo(1))],
        hasMore: true,
        nextBefore: minutesAgo(1),
        nextBeforeId: 'e3',
      ),
      _page([
        // The server hands back the cursor row again — it must not double up.
        _event('e3', occurredAt: minutesAgo(1)),
        _event('e2', occurredAt: minutesAgo(30)),
      ]),
    ]);
    bloc.add(const GroupFeedOpened());
    await _settle();
    bloc.add(const GroupFeedMoreRequested());
    await _settle();

    expect(bloc.state.events.map((e) => e.id), ['e3', 'e2']);
    expect(bloc.state.hasMore, isFalse);
    await bloc.close();
  });

  test('a live event lands at the top and the connection is reported', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page([_event('e1', occurredAt: minutesAgo(30))]),
    ]);
    bloc.add(const GroupFeedOpened());
    await _goLive(sockets);

    expect(bloc.state.live, isTrue);
    _push(sockets.last, _event('e2', occurredAt: minutesAgo(1), actor: 'Јован'));
    await _settle();

    expect(bloc.state.events.map((e) => e.id), ['e2', 'e1']);
    expect(bloc.state.events.first.actor.displayName, 'Јован');

    // The same event again (a resend, or it was already on the page) changes
    // nothing.
    _push(sockets.last, _event('e2', occurredAt: minutesAgo(1)));
    await _settle();
    expect(bloc.state.events, hasLength(2));
    await bloc.close();
  });

  test('a live event is placed by its time, not by its arrival', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page([
        _event('e3', occurredAt: minutesAgo(1)),
        _event('e1', occurredAt: minutesAgo(30)),
      ]),
    ]);
    bloc.add(const GroupFeedOpened());
    await _goLive(sockets);

    // A sync uploading older results: it arrives now, but it happened between
    // the two events already on screen.
    _push(sockets.last, _event('e2', occurredAt: minutesAgo(10)));
    await _settle();

    expect(bloc.state.events.map((e) => e.id), ['e3', 'e2', 'e1']);
    await bloc.close();
  });

  test('an event older than the loaded page is left to the pager', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page(
        [_event('e5', occurredAt: minutesAgo(1))],
        hasMore: true,
        nextBefore: minutesAgo(1),
        nextBeforeId: 'e5',
      ),
    ]);
    bloc.add(const GroupFeedOpened());
    await _goLive(sockets);

    // Older than everything on screen while there is unread history below: it
    // belongs to a page that has not been read yet, and would otherwise appear
    // twice once that page loads.
    _push(sockets.last, _event('old', occurredAt: minutesAgo(120)));
    await _settle();

    expect(bloc.state.events.map((e) => e.id), ['e5']);
    await bloc.close();
  });

  test('after a reconnect the head is re-read, because nothing is replayed', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page([_event('e1', occurredAt: minutesAgo(30))]),
      _page([
        // Happened while the socket was down: only a re-read can find it.
        _event('e2', occurredAt: minutesAgo(5)),
        _event('e1', occurredAt: minutesAgo(30)),
      ]),
    ]);
    bloc.add(const GroupFeedOpened());
    await _goLive(sockets);
    expect(http.requests, 1);

    await sockets.last.drop();
    await _settle();
    expect(sockets.sockets, hasLength(2), reason: 'should have reconnected');
    expect(bloc.state.live, isFalse);

    await _goLive(sockets);

    expect(bloc.state.live, isTrue);
    expect(http.requests, 2, reason: 'the head is re-read after a reconnect');
    expect(bloc.state.events.map((e) => e.id), ['e2', 'e1']);
    await bloc.close();
  });

  test('a failed refresh reports it and keeps what is on screen', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page([_event('e1', occurredAt: minutesAgo(30))]),
    ]);
    bloc.add(const GroupFeedOpened());
    await _settle();
    expect(bloc.state.events, hasLength(1));

    http.failNext = true;
    bloc.add(const GroupFeedRefreshed());
    await _settle();

    expect(bloc.state.errorMessage, isNotNull);
    expect(bloc.state.events, hasLength(1), reason: 'the list is not thrown away');

    bloc.add(const GroupFeedErrorShown());
    await _settle();
    expect(bloc.state.errorMessage, isNull);
    await bloc.close();
  });

  test('unknown event kinds are dropped rather than rendered blank', () async {
    final (:bloc, :http, :sockets) = _bloc([
      _page([
        _event('e2', kind: 'SOMETHING_NEW', occurredAt: minutesAgo(1)),
        _event('e1', occurredAt: minutesAgo(30)),
      ]),
    ]);
    bloc.add(const GroupFeedOpened());
    await _settle();

    expect(bloc.state.events.map((e) => e.id), ['e1']);
    expect(bloc.state.events.single.kind, GroupEventKind.memberJoined);
    await bloc.close();
  });
}

