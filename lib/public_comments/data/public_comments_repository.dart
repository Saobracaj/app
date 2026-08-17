import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../models/public_comment.dart';
import '../models/public_comment_page.dart';

/// Data access for **public question comments** (`saobracaj_backend`).
///
/// Reads (`questionComments`, `questionCommentCount`, `allComments`) are open to
/// guests — viewer-relative flags come back `false` when signed out — but the
/// app still sends them authenticated when a session exists so `likedByMe` /
/// `subscribedByMe` / `deletableByMe` are populated. Writes require a signed-in,
/// non-banned user with a display name.
///
/// Realtime (`questionCommentsChanged`) is a GraphQL subscription over
/// WebSocket; the current [GraphqlClient] is HTTP-only, so the UI refetches
/// after its own mutations and on manual refresh instead — see the comments Bloc.
@lazySingleton
class PublicCommentsRepository {
  PublicCommentsRepository(this._client);

  final GraphqlClient _client;

  /// Scalar fields of a comment (no nested replies).
  static const _fields = r'''
    id questionId parentId authorId authorDisplayName body deleted createdAt
    likesCount likedByMe repliesCount subscribedByMe deletableByMe
  ''';

  static final _questionCommentsQuery =
      '''
    query QuestionComments(\$questionId: Int!, \$offset: Int, \$limit: Int) {
      questionComments(questionId: \$questionId, offset: \$offset, limit: \$limit) {
        totalCount
        hasNextPage
        nodes { $_fields replies { $_fields } }
      }
    }
  ''';

  static final _allCommentsQuery =
      '''
    query AllComments(\$offset: Int, \$limit: Int) {
      allComments(offset: \$offset, limit: \$limit) {
        totalCount
        hasNextPage
        nodes { $_fields }
      }
    }
  ''';

  static const _countQuery = r'''
    query QuestionCommentCount($questionId: Int!) {
      questionCommentCount(questionId: $questionId)
    }
  ''';

  static final _addCommentMutation =
      '''
    mutation AddComment(\$questionId: Int!, \$parentId: ID, \$body: String!) {
      addComment(questionId: \$questionId, parentId: \$parentId, body: \$body) {
        $_fields replies { $_fields }
      }
    }
  ''';

  static final _likeMutation =
      '''
    mutation LikeComment(\$id: ID!) { likeComment(id: \$id) { $_fields } }
  ''';

  static final _unlikeMutation =
      '''
    mutation UnlikeComment(\$id: ID!) { unlikeComment(id: \$id) { $_fields } }
  ''';

  static const _deleteMutation = r'''
    mutation DeleteComment($id: ID!) { deleteComment(id: $id) }
  ''';

  static const _moderateDeleteMutation = r'''
    mutation ModerateDeleteComment($id: ID!) { moderateDeleteComment(id: $id) }
  ''';

  static const _subscriptionMutation = r'''
    mutation SetCommentSubscription($commentId: ID!, $subscribed: Boolean!) {
      setCommentSubscription(commentId: $commentId, subscribed: $subscribed)
    }
  ''';

  static const _banMutation = r'''
    mutation ModerateSetCommentBan($userId: ID!, $banned: Boolean!) {
      moderateSetCommentBan(userId: $userId, banned: $banned)
    }
  ''';

  /// A page of top-level comments (with replies) for a question, sorted by likes
  /// then recency. [limit] is capped at 30 by the backend.
  Future<PublicCommentPage> questionComments(
    int questionId, {
    int offset = 0,
    int limit = 30,
    bool authenticated = true,
  }) async {
    final data = await _client.run(
      _questionCommentsQuery,
      variables: {'questionId': questionId, 'offset': offset, 'limit': limit},
      authenticated: authenticated,
    );
    return _page(data['questionComments']);
  }

  /// The global moderation feed: every comment, newest first (flat).
  Future<PublicCommentPage> allComments({
    int offset = 0,
    int limit = 30,
  }) async {
    final data = await _client.run(
      _allCommentsQuery,
      variables: {'offset': offset, 'limit': limit},
      authenticated: true,
    );
    return _page(data['allComments']);
  }

  /// The number of top-level comments for a question (tab-bar badge).
  Future<int> questionCommentCount(
    int questionId, {
    bool authenticated = true,
  }) async {
    final data = await _client.run(
      _countQuery,
      variables: {'questionId': questionId},
      authenticated: authenticated,
    );
    return (data['questionCommentCount'] as num?)?.toInt() ?? 0;
  }

  /// Post a top-level comment (when [parentId] is null) or a reply.
  Future<PublicComment> addComment({
    required int questionId,
    String? parentId,
    required String body,
  }) async {
    final data = await _client.run(
      _addCommentMutation,
      variables: {
        'questionId': questionId,
        'parentId': parentId,
        'body': body,
      },
      authenticated: true,
    );
    return _comment(data['addComment']);
  }

  /// Like a comment (idempotent). Returns the comment with the updated count.
  Future<PublicComment> likeComment(String id) async {
    final data = await _client.run(
      _likeMutation,
      variables: {'id': id},
      authenticated: true,
    );
    return _comment(data['likeComment']);
  }

  /// Remove the caller's like (idempotent).
  Future<PublicComment> unlikeComment(String id) async {
    final data = await _client.run(
      _unlikeMutation,
      variables: {'id': id},
      authenticated: true,
    );
    return _comment(data['unlikeComment']);
  }

  /// Delete the caller's own comment (or any comment, as a moderator).
  Future<bool> deleteComment(String id) async {
    final data = await _client.run(
      _deleteMutation,
      variables: {'id': id},
      authenticated: true,
    );
    return data['deleteComment'] == true;
  }

  /// Delete any comment as a moderator (`moderate_comments`).
  Future<bool> moderateDeleteComment(String id) async {
    final data = await _client.run(
      _moderateDeleteMutation,
      variables: {'id': id},
      authenticated: true,
    );
    return data['moderateDeleteComment'] == true;
  }

  /// Subscribe/unsubscribe the caller to a thread's replies (the id may be any
  /// comment in the thread; the backend resolves it to the top-level thread).
  Future<bool> setCommentSubscription(
    String commentId,
    bool subscribed,
  ) async {
    final data = await _client.run(
      _subscriptionMutation,
      variables: {'commentId': commentId, 'subscribed': subscribed},
      authenticated: true,
    );
    return data['setCommentSubscription'] == true;
  }

  /// Ban/unban a user from commenting (`moderate_comments`).
  Future<bool> moderateSetCommentBan(String userId, bool banned) async {
    final data = await _client.run(
      _banMutation,
      variables: {'userId': userId, 'banned': banned},
      authenticated: true,
    );
    return data['moderateSetCommentBan'] == true;
  }

  PublicCommentPage _page(dynamic raw) {
    if (raw is! Map) return const PublicCommentPage();
    return PublicCommentPage.fromJson(raw.cast<String, dynamic>());
  }

  PublicComment _comment(dynamic raw) {
    if (raw is! Map) {
      throw GraphqlException('Empty comment response');
    }
    return PublicComment.fromJson(raw.cast<String, dynamic>());
  }
}
