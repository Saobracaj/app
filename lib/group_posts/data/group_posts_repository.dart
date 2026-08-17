import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../support_chat/models/support_chat.dart';
import '../models/group_post.dart';

/// Data access for a group's wall (`saobracaj_backend`, `src/group_posts/`).
///
/// Nothing is cached: a wall is shared state, and a stale post is worse than a
/// spinner. Live updates do not come from here either — a post and a comment are
/// group feed events, so the screen already learns about them through the
/// existing `groupFeedChanged` subscription and re-reads the head.
@lazySingleton
class GroupPostsRepository {
  GroupPostsRepository(this._client);

  final GraphqlClient _client;

  /// The attachment fields — identical to the support chat's, because the
  /// backend sends the same type, plus the shared list's ids.
  static const _attachmentFields = r'''
    id kind fileName contentType sizeBytes questionId questionIds url deleted
    createdAt
  ''';

  static final _postFields =
      '''
    id groupId authorId authorDisplayName body createdAt commentsCount
    deletableByMe attachments { $_attachmentFields }
  ''';

  static const _commentFields = r'''
    id postId authorId authorDisplayName body createdAt deletableByMe
  ''';

  /// One page of the wall, newest first.
  Future<GroupPostPage> page(
    String groupId, {
    int limit = 20,
    DateTime? before,
    String? beforeId,
  }) async {
    final data = await _client.run(
      '''
        query GroupPosts(\$groupId: ID!, \$limit: Int, \$before: DateTime, \$beforeId: ID) {
          groupPosts(groupId: \$groupId, limit: \$limit, before: \$before, beforeId: \$beforeId) {
            hasMore nextBefore nextBeforeId
            posts { $_postFields }
          }
        }
      ''',
      variables: {
        'groupId': groupId,
        'limit': limit,
        'before': before?.toUtc().toIso8601String(),
        'beforeId': beforeId,
      },
      authenticated: true,
    );
    final raw = data['groupPosts'];
    return raw is Map
        ? GroupPostPage.parse(raw.cast<String, dynamic>())
        : const GroupPostPage();
  }

  /// Publish a post. `questionListIds` name the caller's own question lists —
  /// the server snapshots each one's name and questions.
  Future<GroupPost> create(
    String groupId, {
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    final data = await _client.run(
      '''
        mutation CreateGroupPost(
          \$groupId: ID!, \$body: String!, \$attachmentIds: [ID!],
          \$questionIds: [Int!], \$questionListIds: [ID!]
        ) {
          createGroupPost(
            groupId: \$groupId, body: \$body, attachmentIds: \$attachmentIds,
            questionIds: \$questionIds, questionListIds: \$questionListIds
          ) { $_postFields }
        }
      ''',
      variables: {
        'groupId': groupId,
        'body': body,
        'attachmentIds': attachmentIds,
        'questionIds': questionIds,
        'questionListIds': questionListIds,
      },
      authenticated: true,
    );
    return GroupPost.parse(
      (data['createGroupPost'] as Map).cast<String, dynamic>(),
    );
  }

  Future<bool> deletePost(String postId) async {
    final data = await _client.run(
      r'''
        mutation DeleteGroupPost($postId: ID!) { deleteGroupPost(postId: $postId) }
      ''',
      variables: {'postId': postId},
      authenticated: true,
    );
    return data['deleteGroupPost'] == true;
  }

  /// The comments under a post, oldest first.
  Future<List<GroupPostComment>> comments(String postId) async {
    final data = await _client.run(
      '''
        query GroupPostComments(\$postId: ID!) {
          groupPostComments(postId: \$postId) {
            totalCount hasNextPage nodes { $_commentFields }
          }
        }
      ''',
      variables: {'postId': postId},
      authenticated: true,
    );
    final nodes = (data['groupPostComments'] as Map?)?['nodes'];
    return nodes is List
        ? nodes
              .whereType<Map>()
              .map((e) => GroupPostComment.parse(e.cast<String, dynamic>()))
              .toList()
        : const <GroupPostComment>[];
  }

  Future<GroupPostComment> addComment(String postId, String body) async {
    final data = await _client.run(
      '''
        mutation AddGroupPostComment(\$postId: ID!, \$body: String!) {
          addGroupPostComment(postId: \$postId, body: \$body) { $_commentFields }
        }
      ''',
      variables: {'postId': postId, 'body': body},
      authenticated: true,
    );
    return GroupPostComment.parse(
      (data['addGroupPostComment'] as Map).cast<String, dynamic>(),
    );
  }

  Future<bool> deleteComment(String commentId) async {
    final data = await _client.run(
      r'''
        mutation DeleteGroupPostComment($commentId: ID!) {
          deleteGroupPostComment(commentId: $commentId)
        }
      ''',
      variables: {'commentId': commentId},
      authenticated: true,
    );
    return data['deleteGroupPostComment'] == true;
  }

  /// Upload a file or an image into the group, before the post that carries it
  /// exists. An attachment that is never posted is swept by the server.
  Future<SupportAttachment> uploadAttachment({
    required String groupId,
    required List<int> bytes,
    required String fileName,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final data = await _client.upload(
      '''
        mutation UploadGroupPostAttachment(\$groupId: ID!, \$file: Upload!) {
          uploadGroupPostAttachment(groupId: \$groupId, file: \$file) {
            $_attachmentFields
          }
        }
      ''',
      variables: {'groupId': groupId},
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      onProgress: onProgress,
    );
    return SupportAttachment.parse(
      (data['uploadGroupPostAttachment'] as Map).cast<String, dynamic>(),
    );
  }

  /// A freshly signed link for an attachment whose own link expired while the
  /// wall was open. Empty when the server has nothing to sign.
  Future<String> attachmentUrl(String attachmentId) async {
    final data = await _client.run(
      r'''
        query GroupPostAttachmentUrl($attachmentId: ID!) {
          groupPostAttachmentUrl(attachmentId: $attachmentId)
        }
      ''',
      variables: {'attachmentId': attachmentId},
      authenticated: true,
    );
    return data['groupPostAttachmentUrl']?.toString() ?? '';
  }
}
