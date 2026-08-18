import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/data/graphql_subscription_client.dart';
import '../models/support_chat.dart';
import '../models/support_chat_update.dart';

/// Data access for the **support chat** — the user's conversation with the
/// developers (`saobracaj_backend`, `src/support_chat/`).
///
/// Two audiences share the type: a signed-in user only ever reaches their own
/// thread (the backend resolves it from the token, so no id is ever sent), while
/// a holder of the `support_chat` permission lists and answers every thread.
///
/// Attachment URLs come back signed and short-lived (15 minutes); a stale one is
/// re-signed through [attachmentUrl] rather than by re-reading the whole thread.
///
/// An open conversation follows the backend live through [changes], over the
/// app's single subscription socket.
@lazySingleton
class SupportChatRepository {
  SupportChatRepository(this._client, this._subscriptions);

  final GraphqlClient _client;
  final GraphqlSubscriptionClient _subscriptions;

  static const _attachmentFields = r'''
    id kind fileName contentType sizeBytes questionId url deleted createdAt
  ''';

  static final _messageFields =
      '''
    id threadId authorId authorDisplayName fromStaff body createdAt readAt
    attachments { $_attachmentFields }
  ''';

  static const _threadFields = r'''
    id userId userDisplayName userEmail createdAt lastMessageAt
    lastMessagePreview unreadCount messagesCount
  ''';

  static const _myThreadQuery =
      '''
    query MySupportThread { mySupportThread { $_threadFields } }
  ''';

  static final _myMessagesQuery =
      '''
    query MySupportMessages(\$offset: Int, \$limit: Int) {
      mySupportMessages(offset: \$offset, limit: \$limit) {
        totalCount hasNextPage nodes { $_messageFields }
      }
    }
  ''';

  static const _myUnreadQuery = r'''
    query MySupportUnreadCount { mySupportUnreadCount }
  ''';

  static const _threadsQuery =
      '''
    query SupportThreads(\$onlyUnread: Boolean, \$offset: Int, \$limit: Int) {
      supportThreads(onlyUnread: \$onlyUnread, offset: \$offset, limit: \$limit) {
        totalCount hasNextPage nodes { $_threadFields }
      }
    }
  ''';

  static const _threadQuery =
      '''
    query SupportThread(\$threadId: ID!) {
      supportThread(threadId: \$threadId) { $_threadFields }
    }
  ''';

  static final _threadMessagesQuery =
      '''
    query SupportMessages(\$threadId: ID!, \$offset: Int, \$limit: Int) {
      supportMessages(threadId: \$threadId, offset: \$offset, limit: \$limit) {
        totalCount hasNextPage nodes { $_messageFields }
      }
    }
  ''';

  static const _unreadThreadsQuery = r'''
    query SupportUnreadThreadsCount { supportUnreadThreadsCount }
  ''';

  static final _sendMutation =
      '''
    mutation SendSupportMessage(\$body: String!, \$attachmentIds: [ID!], \$questionIds: [Int!], \$questionListIds: [ID!]) {
      sendSupportMessage(body: \$body, attachmentIds: \$attachmentIds, questionIds: \$questionIds, questionListIds: \$questionListIds) {
        $_messageFields
      }
    }
  ''';

  static final _replyMutation =
      '''
    mutation ReplyToSupportThread(\$threadId: ID!, \$body: String!, \$attachmentIds: [ID!], \$questionIds: [Int!], \$questionListIds: [ID!]) {
      replyToSupportThread(threadId: \$threadId, body: \$body, attachmentIds: \$attachmentIds, questionIds: \$questionIds, questionListIds: \$questionListIds) {
        $_messageFields
      }
    }
  ''';

  static const _markReadMutation = r'''
    mutation MarkSupportThreadRead($threadId: ID) {
      markSupportThreadRead(threadId: $threadId)
    }
  ''';

  static final _uploadMutation =
      '''
    mutation UploadSupportAttachment(\$file: Upload!, \$threadId: ID) {
      uploadSupportAttachment(file: \$file, threadId: \$threadId) {
        $_attachmentFields
      }
    }
  ''';

  static const _attachmentUrlQuery = r'''
    query SupportAttachmentUrl($attachmentId: ID!) {
      supportAttachmentUrl(attachmentId: $attachmentId)
    }
  ''';

  static const _eventsSubscription = r'''
    subscription SupportChatEvents($threadId: ID) {
      supportChatEvents(threadId: $threadId) { threadId kind messageId }
    }
  ''';

  /// The caller's own conversation, created by the backend on first access.
  Future<SupportThread> myThread() async {
    final data = await _client.run(_myThreadQuery, authenticated: true);
    return SupportThread.parse(
      (data['mySupportThread'] as Map).cast<String, dynamic>(),
    );
  }

  /// A page of the caller's own messages, oldest first.
  Future<SupportMessagePage> myMessages({
    int offset = 0,
    int limit = 50,
  }) async {
    final data = await _client.run(
      _myMessagesQuery,
      variables: {'offset': offset, 'limit': limit},
      authenticated: true,
    );
    return SupportMessagePage.parse(
      (data['mySupportMessages'] as Map).cast<String, dynamic>(),
    );
  }

  /// Unread staff replies — the badge on the settings entry.
  Future<int> myUnreadCount() async {
    final data = await _client.run(_myUnreadQuery, authenticated: true);
    return (data['mySupportUnreadCount'] as num?)?.toInt() ?? 0;
  }

  /// The moderator's list of conversations.
  Future<SupportThreadPage> threads({
    bool onlyUnread = false,
    int offset = 0,
    int limit = 50,
  }) async {
    final data = await _client.run(
      _threadsQuery,
      variables: {'onlyUnread': onlyUnread, 'offset': offset, 'limit': limit},
      authenticated: true,
    );
    return SupportThreadPage.parse(
      (data['supportThreads'] as Map).cast<String, dynamic>(),
    );
  }

  /// One conversation, from the support side.
  Future<SupportThread> thread(String threadId) async {
    final data = await _client.run(
      _threadQuery,
      variables: {'threadId': threadId},
      authenticated: true,
    );
    return SupportThread.parse(
      (data['supportThread'] as Map).cast<String, dynamic>(),
    );
  }

  /// A page of any conversation's messages, from the support side.
  Future<SupportMessagePage> threadMessages(
    String threadId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final data = await _client.run(
      _threadMessagesQuery,
      variables: {'threadId': threadId, 'offset': offset, 'limit': limit},
      authenticated: true,
    );
    return SupportMessagePage.parse(
      (data['supportMessages'] as Map).cast<String, dynamic>(),
    );
  }

  /// How many conversations hold unread user messages.
  Future<int> unreadThreadsCount() async {
    final data = await _client.run(_unreadThreadsQuery, authenticated: true);
    return (data['supportUnreadThreadsCount'] as num?)?.toInt() ?? 0;
  }

  /// Send into the caller's own conversation. Question links in [body] become
  /// «вопрос N» attachments server-side; [questionIds] adds them explicitly.
  ///
  /// [questionListIds] — списки самого отправителя: бэкенд снимает с них снимок
  /// (название, цвет и вопросы) в момент отправки, потому что у получателя
  /// доступа к чужим спискам нет, а владелец может их потом переименовать.
  Future<SupportMessage> send({
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    final data = await _client.run(
      _sendMutation,
      variables: {
        'body': body,
        'attachmentIds': attachmentIds,
        'questionIds': questionIds,
        'questionListIds': questionListIds,
      },
      authenticated: true,
    );
    return SupportMessage.parse(
      (data['sendSupportMessage'] as Map).cast<String, dynamic>(),
    );
  }

  /// Answer a user's conversation as support staff.
  Future<SupportMessage> reply({
    required String threadId,
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    final data = await _client.run(
      _replyMutation,
      variables: {
        'threadId': threadId,
        'body': body,
        'attachmentIds': attachmentIds,
        'questionIds': questionIds,
        'questionListIds': questionListIds,
      },
      authenticated: true,
    );
    return SupportMessage.parse(
      (data['replyToSupportThread'] as Map).cast<String, dynamic>(),
    );
  }

  /// Mark the counterpart's messages read. [threadId] is only honoured for
  /// support staff; a user always marks their own thread.
  Future<int> markRead({String? threadId}) async {
    final data = await _client.run(
      _markReadMutation,
      variables: {'threadId': threadId},
      authenticated: true,
    );
    return (data['markSupportThreadRead'] as num?)?.toInt() ?? 0;
  }

  /// Upload one file (≤20 MB) as a pending attachment, to be referenced by the
  /// next [send]/[reply]. [threadId] is only honoured for support staff.
  Future<SupportAttachment> uploadAttachment({
    required List<int> bytes,
    required String fileName,
    String? contentType,
    String? threadId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final data = await _client.upload(
      _uploadMutation,
      variables: {'threadId': threadId},
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      onProgress: onProgress,
    );
    return SupportAttachment.parse(
      (data['uploadSupportAttachment'] as Map).cast<String, dynamic>(),
    );
  }

  /// Live changes in one conversation — [threadId] `null` for the caller's own,
  /// exactly as everywhere else here.
  ///
  /// The stream starts the subscription on its first listener and stops it when
  /// the listener leaves, so a chat that is not on screen holds nothing open.
  /// Events that are not about this thread never arrive: the server filters
  /// them, and the subscription is authorised once, when it opens.
  Stream<SupportChatUpdate> changes({String? threadId}) {
    return _subscriptions
        .subscribe(_eventsSubscription, variables: {'threadId': threadId})
        .map<SupportChatUpdate?>((message) {
          switch (message) {
            case GraphqlSubscriptionResumed(:final firstConnect):
              return SupportChatLive(firstConnect: firstConnect);
            case GraphqlSubscriptionInterrupted():
              return const SupportChatOffline();
            case GraphqlSubscriptionData(:final data):
              final raw = data['supportChatEvents'];
              if (raw is! Map) return null;
              final kind = SupportChangeKind.parse(raw['kind']?.toString());
              // An unknown kind is a newer server talking about something this
              // build has no idea what to do with — ignoring it is safer than
              // guessing, and the screen still refreshes on the next event.
              if (kind == null) return null;
              return SupportChatChanged(
                kind: kind,
                messageId: raw['messageId']?.toString(),
              );
          }
        })
        .where((update) => update != null)
        .cast<SupportChatUpdate>();
  }

  /// Re-sign an attachment's download URL after the previous one expired.
  Future<String> attachmentUrl(String attachmentId) async {
    final data = await _client.run(
      _attachmentUrlQuery,
      variables: {'attachmentId': attachmentId},
      authenticated: true,
    );
    return data['supportAttachmentUrl']?.toString() ?? '';
  }
}
