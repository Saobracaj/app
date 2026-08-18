import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/group_posts/data/group_posts_repository.dart';
import 'package:saobracaj/group_posts/state_management/group_posts_bloc.dart';
import 'package:saobracaj/group_posts/state_management/group_posts_events.dart';
import 'package:saobracaj/question_lists/models/question_list.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replays canned GraphQL answers in order and records what was asked for, so a
/// test can assert on the variables the Bloc sent.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.answers);

  /// One `data` object per request, in order. A single entry is replayed for
  /// every request.
  final List<Map<String, dynamic>> answers;
  final List<Map<String, dynamic>> requests = [];

  /// When set, the next request fails as if the network were down.
  bool failNext = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((options.data as Map).cast<String, dynamic>());
    if (failNext) {
      failNext = false;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final answer = answers.length == 1 ? answers.first : answers.removeAt(0);
    return ResponseBody.fromString(
      json.encode({'data': answer}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _post(
  String id, {
  String body = 'привет',
  DateTime? createdAt,
  List<Map<String, dynamic>> attachments = const [],
}) => {
  'id': id,
  'groupId': 'g1',
  'authorId': 'u1',
  'authorDisplayName': 'Мила',
  'body': body,
  'createdAt': (createdAt ?? DateTime.utc(2026, 8, 17)).toIso8601String(),
  'commentsCount': 0,
  'deletableByMe': true,
  'attachments': attachments,
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> posts, {
  bool hasMore = false,
  DateTime? nextBefore,
  String? nextBeforeId,
}) => {
  'groupPosts': {
    'posts': posts,
    'hasMore': hasMore,
    'nextBefore': nextBefore?.toIso8601String(),
    'nextBeforeId': nextBeforeId,
  },
};

({GroupPostsBloc bloc, _FakeAdapter http}) _bloc(
  List<Map<String, dynamic>> answers,
) {
  final adapter = _FakeAdapter(answers);
  final repository = GroupPostsRepository(
    GraphqlClient(TokenStorage(), dio: Dio()..httpClientAdapter = adapter),
  );
  return (bloc: GroupPostsBloc(repository, 'g1'), http: adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the first page is loaded with its cursor', () async {
    final cursor = DateTime.utc(2026, 8, 16);
    final (:bloc, :http) = _bloc([
      _page(
        [_post('p1')],
        hasMore: true,
        nextBefore: cursor,
        nextBeforeId: 'p1',
      ),
    ]);

    bloc.add(const GroupPostsOpened());
    await bloc.stream.firstWhere((s) => s.loaded);

    expect(bloc.state.posts.single.id, 'p1');
    expect(bloc.state.hasMore, isTrue);
    expect(bloc.state.nextBeforeId, 'p1');
    await bloc.close();
  });

  test(
    'the next page continues from the cursor and never repeats a post',
    () async {
      final cursor = DateTime.utc(2026, 8, 16);
      final (:bloc, :http) = _bloc([
        _page(
          [_post('p1')],
          hasMore: true,
          nextBefore: cursor,
          nextBeforeId: 'p1',
        ),
        // The server re-sends p1 (somebody posted meanwhile and the window moved).
        _page([_post('p1'), _post('p2')]),
      ]);

      bloc.add(const GroupPostsOpened());
      await bloc.stream.firstWhere((s) => s.loaded);
      bloc.add(const GroupPostsMoreRequested());
      await bloc.stream.firstWhere((s) => s.posts.length == 2);

      expect(bloc.state.posts.map((p) => p.id), ['p1', 'p2']);
      expect(http.requests.last['variables']['beforeId'], 'p1');
      await bloc.close();
    },
  );

  test('publishing sends the attachments and clears the composer', () async {
    final (:bloc, :http) = _bloc([
      _page(const []),
      {'createGroupPost': _post('p9', body: 'смотрите')},
    ]);

    bloc.add(const GroupPostsOpened());
    await bloc.stream.firstWhere((s) => s.loaded);
    bloc.add(
      GroupPostListAttached(
        const QuestionList(id: 'l1', name: 'Сложные', questionIds: [1, 2]),
      ),
    );
    bloc.add(const GroupPostBodyChanged('смотрите'));
    bloc.add(const GroupPostSubmitted());
    await bloc.stream.firstWhere((s) => s.posts.isNotEmpty);

    final variables = (http.requests.last['variables'] as Map)
        .cast<String, dynamic>();
    expect(variables['questionListIds'], ['l1']);
    expect(variables['body'], 'смотрите');
    expect(bloc.state.body, isEmpty);
    expect(bloc.state.pendingLists, isEmpty);
    await bloc.close();
  });

  /// The "recent mistakes" list is derived on the device and the backend has
  /// never heard of it, so it must not travel as a list id.
  test('an automatic list is never shared', () async {
    final (:bloc, :http) = _bloc([
      _page(const []),
      {'createGroupPost': _post('p9')},
    ]);

    bloc.add(const GroupPostsOpened());
    await bloc.stream.firstWhere((s) => s.loaded);
    bloc.add(
      GroupPostListAttached(
        const QuestionList(
          id: kRecentMistakesListId,
          isAuto: true,
          questionIds: [3],
        ),
      ),
    );
    bloc.add(const GroupPostSubmitted());
    await bloc.stream.firstWhere((s) => s.posts.isNotEmpty);

    expect(http.requests.last['variables']['questionListIds'], isEmpty);
    await bloc.close();
  });

  test('a failed delete puts the post back', () async {
    final (:bloc, :http) = _bloc([
      _page([_post('p1')]),
    ]);

    bloc.add(const GroupPostsOpened());
    await bloc.stream.firstWhere((s) => s.loaded);
    // The server never gets to answer — the optimistic removal has to roll back.
    http.failNext = true;
    bloc.add(const GroupPostDeleted('p1'));
    await bloc.stream.firstWhere((s) => s.errorMessage != null);

    expect(bloc.state.posts.single.id, 'p1');
    await bloc.close();
  });

  test('a shared question list is parsed as one attachment', () {
    final attachment = ChatAttachment.parse({
      'id': 'a1',
      'kind': 'QUESTION_LIST',
      'fileName': 'Сложные',
      'questionIds': [7, 8],
      'createdAt': DateTime.utc(2026, 8, 17).toIso8601String(),
    });

    expect(attachment.kind, ChatAttachmentKind.questionList);
    expect(attachment.questionIds, [7, 8]);
    expect(attachment.isReference, isTrue);
    expect(attachment.isImage, isFalse);
  });
}
