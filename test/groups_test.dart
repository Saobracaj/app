import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/groups/data/groups_repository.dart';
import 'package:saobracaj/groups/domain/invite_code.dart';
import 'package:saobracaj/groups/models/group.dart';
import 'package:saobracaj/groups/models/group_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replays canned GraphQL responses and records the operation names that were
/// sent, so a test can assert what the repository asked for.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final List<Object> responses;
  final List<String> operations = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = Map<String, dynamic>.from(options.data as Map);
    final query = body['query'].toString();
    operations.add(
      RegExp(r'(query|mutation)\s+(\w+)').firstMatch(query)?.group(2) ?? '?',
    );
    if (responses.isEmpty) throw StateError('unexpected request: $query');
    final next = responses.removeAt(0);
    if (next is DioException) throw next;
    return ResponseBody.fromString(
      json.encode(next),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GroupsRepository _repository(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: dio);
  return GroupsRepository(client, GraphqlSubscriptionClient(client, storage));
}

Map<String, dynamic> _group({
  String id = 'g1',
  String name = 'Ауто-школа',
  int memberCount = 2,
  bool viewerIsOwner = true,
  List<Map<String, dynamic>> feedPreview = const [],
}) => {
  'id': id,
  'name': name,
  'ownerId': 'u1',
  'createdAt': '2026-08-01T10:00:00+00:00',
  'memberCount': memberCount,
  'viewerIsOwner': viewerIsOwner,
  'feedPreview': feedPreview,
};

Map<String, dynamic> _event(
  String kind, {
  Map<String, dynamic>? subcategory,
  Map<String, dynamic>? practice,
  Map<String, dynamic>? achievement,
  Map<String, dynamic>? rename,
  Map<String, dynamic>? target,
}) => {
  'id': 'e1',
  'kind': kind,
  'occurredAt': '2026-08-04T09:30:00+00:00',
  'actor': {'id': 'u1', 'displayName': 'Марко'},
  'target': target,
  'subcategory': subcategory,
  'practice': practice,
  'achievement': achievement,
  'rename': rename,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('invite codes', () {
    // The same cases the backend's `normalize_invite_token` is tested against —
    // the two implementations have to agree or a valid code looks invalid
    // before it is ever sent.
    test('a code is accepted however the user typed it', () {
      for (final typed in [
        'abc-def-ghj',
        'ABCDEFGHJ',
        'abcdefghj',
        ' AbC def-GHJ ',
      ]) {
        expect(normalizeInviteCode(typed), 'ABC-DEF-GHJ');
      }
    });

    test('a code of the wrong length is rejected', () {
      expect(normalizeInviteCode('ABC-DEF-GH'), isNull);
      expect(normalizeInviteCode('ABC-DEF-GHJK'), isNull);
      expect(normalizeInviteCode(''), isNull);
    });

    test('the lookalike characters are not in the alphabet', () {
      // A user typing O for zero (or 1 for I) is told so, instead of being sent
      // to the server for a lookup that can only miss.
      expect(normalizeInviteCode('ABC-DEF-GH0'), isNull);
      expect(normalizeInviteCode('ABC-DEF-GHO'), isNull);
      expect(normalizeInviteCode('ABC-DEF-GH1'), isNull);
      expect(normalizeInviteCode('ABC-DEF-GH!'), isNull);
    });

    test('a pasted invite link yields the code', () {
      expect(
        inviteCodeFromLink('https://saobracaj.gleb.at/invite/abc-def-ghj'),
        'ABC-DEF-GHJ',
      );
      expect(inviteCodeFromLink('https://example.com/'), isNull);
    });

    test('the link is built from the code', () {
      expect(
        const GroupInvite(token: 'ABC-DEF-GHJ').link,
        'https://saobracaj.gleb.at/invite/ABC-DEF-GHJ',
      );
    });
  });

  group('event parsing', () {
    test('a subcategory result keeps its comparison with the last attempt', () {
      final event = GroupEvent.fromJson(
        _event(
          'SUBCATEGORY_COMPLETED',
          subcategory: {
            'subcategory': '91',
            'rightAnswers': 18,
            'allAnswers': 20,
            'delta': 'IMPROVED',
            'previousRightAnswers': 15,
            'previousAllAnswers': 20,
          },
        ),
      );

      expect(event.kind, GroupEventKind.subcategoryCompleted);
      expect(event.subcategory?.rightAnswers, 18);
      expect(event.subcategory?.delta, ResultDelta.improved);
      expect(event.subcategory?.previousRightAnswers, 15);
      expect(event.isRenderable, isTrue);
    });

    test('a mock exam keeps the questions that went wrong', () {
      final event = GroupEvent.fromJson(
        _event(
          'PRACTICE_FINISHED',
          practice: {
            'points': 90,
            'mistakes': 1,
            'passed': true,
            'wrongAnswers': [7, 21],
          },
        ),
      );

      expect(event.practice?.passed, isTrue);
      expect(event.practice?.wrongAnswers, [7, 21]);
    });

    test('an event kind this build does not know is not rendered', () {
      final event = GroupEvent.fromJson(_event('INVENTED_LATER'));

      expect(event.kind, GroupEventKind.unknown);
      expect(event.isRenderable, isFalse);
    });

    test('an achievement this build does not know is not rendered', () {
      final unknown = GroupEvent.fromJson(
        _event(
          'ACHIEVEMENT_UNLOCKED',
          achievement: {'achievement': 'INVENTED_LATER'},
        ),
      );
      final known = GroupEvent.fromJson(
        _event(
          'ACHIEVEMENT_UNLOCKED',
          achievement: {'achievement': 'PRACTICE_STREAK', 'streak': 3},
        ),
      );

      expect(unknown.isRenderable, isFalse);
      expect(known.isRenderable, isTrue);
      expect(known.achievement?.streak, 3);
    });

    test('события фантомного блока «null» не показываются', () {
      // Старые сборки записывали прогоны без блока под именем «null»; сервер,
      // ещё не вычистивший такие строки, отдаёт события про block “null”.
      final finished = GroupEvent.fromJson(
        _event(
          'SUBCATEGORY_COMPLETED',
          subcategory: {
            'subcategory': 'null',
            'rightAnswers': 7,
            'allAnswers': 7,
          },
        ),
      );
      final flawless = GroupEvent.fromJson(
        _event(
          'ACHIEVEMENT_UNLOCKED',
          achievement: {
            'achievement': 'FLAWLESS_SUBCATEGORY',
            'subcategory': 'null',
          },
        ),
      );
      final real = GroupEvent.fromJson(
        _event(
          'ACHIEVEMENT_UNLOCKED',
          achievement: {
            'achievement': 'FLAWLESS_SUBCATEGORY',
            'subcategory': '91',
          },
        ),
      );

      expect(finished.isRenderable, isFalse);
      expect(flawless.isRenderable, isFalse);
      expect(real.isRenderable, isTrue);
    });

    test('a payload with missing fields still parses', () {
      final event = GroupEvent.fromJson(
        _event('SUBCATEGORY_COMPLETED', subcategory: const {}),
      );

      expect(event.subcategory?.subcategory, '');
      expect(event.subcategory?.allAnswers, 0);
      expect(event.subcategory?.delta, isNull);
    });

    test('a group drops the events it cannot render from its preview', () {
      final parsed = Group.fromJson(
        _group(
          feedPreview: [_event('MEMBER_JOINED'), _event('INVENTED_LATER')],
        ),
      );

      expect(parsed.feedPreview, hasLength(1));
      expect(parsed.feedPreview.single.kind, GroupEventKind.memberJoined);
    });
  });

  group('the repository', () {
    test('publishes the groups it loaded', () async {
      final adapter = _FakeAdapter([
        {
          'data': {
            'myGroups': [_group(), _group(id: 'g2', name: 'Друзья')],
          },
        },
      ]);
      final repository = _repository(adapter);

      final published = <List<Group>>[];
      final subscription = repository.changes.listen(published.add);
      await repository.refresh();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(adapter.operations, ['MyGroups']);
      expect(repository.groups.map((g) => g.name), ['Ауто-школа', 'Друзья']);
      // The replayed empty list, then the loaded one.
      expect(published.last, hasLength(2));
    });

    test('a created group joins the list right away', () async {
      final adapter = _FakeAdapter([
        {
          'data': {'myGroups': <Object>[]},
        },
        {
          'data': {'createGroup': _group(id: 'g3', name: 'Новая')},
        },
      ]);
      final repository = _repository(adapter);

      await repository.refresh();
      await repository.create('Новая');

      expect(adapter.operations, ['MyGroups', 'CreateGroup']);
      expect(repository.groups.single.id, 'g3');
    });

    test('leaving a group drops it from the list', () async {
      final adapter = _FakeAdapter([
        {
          'data': {
            'myGroups': [_group(), _group(id: 'g2')],
          },
        },
        {
          'data': {'leaveGroup': true},
        },
      ]);
      final repository = _repository(adapter);

      await repository.refresh();
      await repository.leave('g1');

      expect(repository.groups.map((g) => g.id), ['g2']);
    });

    test(
      'a rename keeps the card preview the mutation did not return',
      () async {
        final adapter = _FakeAdapter([
          {
            'data': {
              'myGroups': [
                _group(feedPreview: [_event('MEMBER_JOINED')]),
              ],
            },
          },
          {
            'data': {'renameGroup': _group(name: 'Ауто-школа 2')},
          },
        ]);
        final repository = _repository(adapter);

        await repository.refresh();
        await repository.rename('g1', 'Ауто-школа 2');

        final group = repository.groups.single;
        expect(group.name, 'Ауто-школа 2');
        expect(
          group.feedPreview,
          hasLength(1),
          reason: 'a rename must not blank the home-screen card',
        );
      },
    );

    test(
      'joining a group the user is already in does not duplicate it',
      () async {
        final adapter = _FakeAdapter([
          {
            'data': {
              'myGroups': [_group()],
            },
          },
          {
            'data': {'joinGroupByInvite': _group()},
          },
        ]);
        final repository = _repository(adapter);

        await repository.refresh();
        await repository.joinByInvite('ABC-DEF-GHJ');

        expect(repository.groups, hasLength(1));
      },
    );

    test('signing out forgets the groups', () async {
      final adapter = _FakeAdapter([
        {
          'data': {
            'myGroups': [_group()],
          },
        },
      ]);
      final repository = _repository(adapter);

      await repository.refresh();
      repository.onLoggedOut();

      expect(repository.groups, isEmpty);
    });

    test('a feed page carries the cursor of the next one', () async {
      final adapter = _FakeAdapter([
        {
          'data': {
            'groupFeed': {
              'events': [_event('MEMBER_JOINED')],
              'hasMore': true,
              'nextBefore': '2026-08-04T09:30:00+00:00',
              'nextBeforeId': 'e1',
            },
          },
        },
      ]);
      final repository = _repository(adapter);

      final page = await repository.feed('g1', limit: 20);

      expect(page.events, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.nextBeforeId, 'e1');
      expect(page.nextBefore, isNotNull);
    });
  });
}
