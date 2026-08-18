import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/data/graphql_subscription_client.dart';
import '../models/chat.dart';
import '../models/chat_update.dart';

/// Data access for the **chats** (`saobracaj_backend`, `src/chat/`).
///
/// A conversation is addressed by its id, whatever it is about: the user's own
/// «чат с разработчиком», a group's chat, the thread of a message. Only
/// *opening* one differs — [supportChat] resolves the caller's support chat from
/// the token, [groupChat] and [messageThread] open (creating it if needed) the
/// chat of a group or of a message — and after that every call here takes a
/// plain chat id, which is what lets one Bloc and one screen serve all of them.
///
/// Attachment URLs come back signed and short-lived (15 minutes); a stale one is
/// re-signed through [attachmentUrl] rather than by re-reading the whole chat.
///
/// An open conversation follows the backend live through [changes], over the
/// app's single subscription socket.
@lazySingleton
class ChatRepository {
  ChatRepository(this._client, this._subscriptions);

  final GraphqlClient _client;
  final GraphqlSubscriptionClient _subscriptions;

  static const _attachmentFields = r'''
    id kind fileName contentType sizeBytes questionId questionIds url deleted createdAt
  ''';

  static final _messageFields =
      '''
    id threadId authorId authorDisplayName fromStaff body createdAt readAt
    editedAt threadChatId replyCount
    attachments { $_attachmentFields }
  ''';

  static const _chatFields = r'''
    id entityType entityId entityName parentMessageId isGroup userId
    userDisplayName userEmail createdAt lastMessageAt lastMessagePreview
    unreadCount messagesCount notificationsEnabled
  ''';

  static const _supportChatQuery =
      '''
    query MySupportChat { mySupportChat { $_chatFields } }
  ''';

  static const _chatQuery =
      '''
    query Chat(\$chatId: ID!) { chat(chatId: \$chatId) { $_chatFields } }
  ''';

  static const _threadMutation =
      '''
    mutation OpenMessageThread(\$messageId: ID!) {
      openMessageThread(messageId: \$messageId) { $_chatFields }
    }
  ''';

  static const _groupChatQuery =
      '''
    query GroupChat(\$groupId: String!) {
      chatFor(entityType: GROUP, entityId: \$groupId) { $_chatFields }
    }
  ''';

  static final _messagesQuery =
      '''
    query ChatMessages(\$chatId: ID!, \$offset: Int, \$limit: Int) {
      chatMessages(chatId: \$chatId, offset: \$offset, limit: \$limit) {
        totalCount hasNextPage nodes { $_messageFields }
      }
    }
  ''';

  static final _messageQuery =
      '''
    query ChatMessage(\$messageId: ID!) {
      chatMessage(messageId: \$messageId) { $_messageFields }
    }
  ''';

  static const _myUnreadQuery = r'''
    query MySupportUnreadCount { mySupportUnreadCount }
  ''';

  static const _chatsQuery =
      '''
    query SupportChats(\$onlyUnread: Boolean, \$offset: Int, \$limit: Int) {
      supportChats(onlyUnread: \$onlyUnread, offset: \$offset, limit: \$limit) {
        totalCount hasNextPage nodes { $_chatFields }
      }
    }
  ''';

  static const _unreadChatsQuery = r'''
    query SupportUnreadThreadsCount { supportUnreadThreadsCount }
  ''';

  static final _sendMutation =
      '''
    mutation SendChatMessage(\$chatId: ID!, \$body: String!, \$attachmentIds: [ID!], \$questionIds: [Int!], \$questionListIds: [ID!]) {
      sendChatMessage(chatId: \$chatId, body: \$body, attachmentIds: \$attachmentIds, questionIds: \$questionIds, questionListIds: \$questionListIds) {
        $_messageFields
      }
    }
  ''';

  static final _editMutation =
      '''
    mutation EditChatMessage(\$messageId: ID!, \$body: String!, \$attachmentIds: [ID!], \$questionIds: [Int!], \$questionListIds: [ID!]) {
      editChatMessage(messageId: \$messageId, body: \$body, attachmentIds: \$attachmentIds, questionIds: \$questionIds, questionListIds: \$questionListIds) {
        $_messageFields
      }
    }
  ''';

  static const _markReadMutation = r'''
    mutation MarkChatRead($chatId: ID!) { markChatRead(chatId: $chatId) }
  ''';

  static const _notificationsMutation = r'''
    mutation SetChatNotifications($chatId: ID!, $enabled: Boolean!) {
      setChatNotifications(chatId: $chatId, enabled: $enabled)
    }
  ''';

  static final _uploadMutation =
      '''
    mutation UploadChatAttachment(\$file: Upload!, \$chatId: ID!) {
      uploadChatAttachment(file: \$file, chatId: \$chatId) {
        $_attachmentFields
      }
    }
  ''';

  static const _attachmentUrlQuery = r'''
    query ChatAttachmentUrl($attachmentId: ID!) {
      chatAttachmentUrl(attachmentId: $attachmentId)
    }
  ''';

  static const _eventsSubscription = r'''
    subscription ChatEvents($chatId: ID!) {
      chatEvents(chatId: $chatId) { chatId kind messageId }
    }
  ''';

  /// The caller's own conversation with the developers, created by the backend
  /// on first access.
  Future<Chat> supportChat() async {
    final data = await _client.run(_supportChatQuery, authenticated: true);
    return Chat.parse((data['mySupportChat'] as Map).cast<String, dynamic>());
  }

  /// One conversation by id — a moderator's обращение, a thread, a group chat.
  Future<Chat> chat(String chatId) async {
    final data = await _client.run(
      _chatQuery,
      variables: {'chatId': chatId},
      authenticated: true,
    );
    return Chat.parse((data['chat'] as Map).cast<String, dynamic>());
  }

  /// The thread of a message — the chat holding its replies, created on the
  /// backend the first time somebody opens it.
  Future<Chat> messageThread(String messageId) async {
    final data = await _client.run(
      _threadMutation,
      variables: {'messageId': messageId},
      authenticated: true,
    );
    return Chat.parse(
      (data['openMessageThread'] as Map).cast<String, dynamic>(),
    );
  }

  /// Чат группы: бэкенд создаёт его при первом открытии, поэтому «открыть» и
  /// «создать» здесь — одно и то же. Пускает внутрь состав группы, а не список
  /// участников чата, так что вышедшему из группы прилетит ошибка доступа.
  Future<Chat> groupChat(String groupId) async {
    final data = await _client.run(
      _groupChatQuery,
      variables: {'groupId': groupId},
      authenticated: true,
    );
    return Chat.parse((data['chatFor'] as Map).cast<String, dynamic>());
  }

  /// A page of one conversation's messages, oldest first.
  Future<ChatMessagePage> messages(
    String chatId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final data = await _client.run(
      _messagesQuery,
      variables: {'chatId': chatId, 'offset': offset, 'limit': limit},
      authenticated: true,
    );
    return ChatMessagePage.parse(
      (data['chatMessages'] as Map).cast<String, dynamic>(),
    );
  }

  /// Одно сообщение по идентификатору.
  ///
  /// Так читается шапка треда: сообщение, ответы на которое он собирает, лежит
  /// в родительском чате, а не в ленте самого треда, и достать его из страницы
  /// ответов нельзя.
  Future<ChatMessage> message(String messageId) async {
    final data = await _client.run(
      _messageQuery,
      variables: {'messageId': messageId},
      authenticated: true,
    );
    return ChatMessage.parse(
      (data['chatMessage'] as Map).cast<String, dynamic>(),
    );
  }

  /// Unread staff replies — the badge on the settings entry.
  Future<int> myUnreadCount() async {
    final data = await _client.run(_myUnreadQuery, authenticated: true);
    return (data['mySupportUnreadCount'] as num?)?.toInt() ?? 0;
  }

  /// The moderator's list of обращения.
  Future<ChatConnection> supportChats({
    bool onlyUnread = false,
    int offset = 0,
    int limit = 50,
  }) async {
    final data = await _client.run(
      _chatsQuery,
      variables: {'onlyUnread': onlyUnread, 'offset': offset, 'limit': limit},
      authenticated: true,
    );
    return ChatConnection.parse(
      (data['supportChats'] as Map).cast<String, dynamic>(),
    );
  }

  /// How many обращения hold unread user messages.
  Future<int> unreadThreadsCount() async {
    final data = await _client.run(_unreadChatsQuery, authenticated: true);
    return (data['supportUnreadThreadsCount'] as num?)?.toInt() ?? 0;
  }

  /// Send into one conversation. Question links in [body] become «вопрос N»
  /// attachments server-side; [questionIds] adds them explicitly.
  ///
  /// [questionListIds] — списки самого отправителя: бэкенд снимает с них снимок
  /// (название, цвет и вопросы) в момент отправки, потому что у получателя
  /// доступа к чужим спискам нет, а владелец может их потом переименовать.
  Future<ChatMessage> send({
    required String chatId,
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    final data = await _client.run(
      _sendMutation,
      variables: {
        'chatId': chatId,
        'body': body,
        'attachmentIds': attachmentIds,
        'questionIds': questionIds,
        'questionListIds': questionListIds,
      },
      authenticated: true,
    );
    return ChatMessage.parse(
      (data['sendChatMessage'] as Map).cast<String, dynamic>(),
    );
  }

  /// Rewrite one's own message.
  ///
  /// [attachmentIds] — это **весь** желаемый набор файлов и картинок: и те, что
  /// остались от прошлой версии, и только что загруженные. Всё, чего в наборе
  /// нет, бэкенд удаляет вместе с байтами.
  Future<ChatMessage> edit({
    required String messageId,
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    final data = await _client.run(
      _editMutation,
      variables: {
        'messageId': messageId,
        'body': body,
        'attachmentIds': attachmentIds,
        'questionIds': questionIds,
        'questionListIds': questionListIds,
      },
      authenticated: true,
    );
    return ChatMessage.parse(
      (data['editChatMessage'] as Map).cast<String, dynamic>(),
    );
  }

  /// Mark the counterpart's messages in one conversation read.
  Future<int> markRead(String chatId) async {
    final data = await _client.run(
      _markReadMutation,
      variables: {'chatId': chatId},
      authenticated: true,
    );
    return (data['markChatRead'] as num?)?.toInt() ?? 0;
  }

  /// Turn push notifications about one conversation on or off. Off is the
  /// default — for chats and for threads alike.
  Future<bool> setNotifications({
    required String chatId,
    required bool enabled,
  }) async {
    final data = await _client.run(
      _notificationsMutation,
      variables: {'chatId': chatId, 'enabled': enabled},
      authenticated: true,
    );
    return data['setChatNotifications'] == true;
  }

  /// Upload one file (≤20 MB) as a pending attachment of [chatId], to be
  /// referenced by the next [send] or [edit].
  Future<ChatAttachment> uploadAttachment({
    required String chatId,
    required List<int> bytes,
    required String fileName,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final data = await _client.upload(
      _uploadMutation,
      variables: {'chatId': chatId},
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      onProgress: onProgress,
    );
    return ChatAttachment.parse(
      (data['uploadChatAttachment'] as Map).cast<String, dynamic>(),
    );
  }

  /// Live changes in one conversation.
  ///
  /// The stream starts the subscription on its first listener and stops it when
  /// the listener leaves, so a chat that is not on screen holds nothing open.
  /// Events that are not about this chat never arrive: the server filters them,
  /// and the subscription is authorised once, when it opens.
  Stream<ChatUpdate> changes({required String chatId}) {
    return _subscriptions
        .subscribe(_eventsSubscription, variables: {'chatId': chatId})
        .map<ChatUpdate?>((message) {
          switch (message) {
            case GraphqlSubscriptionResumed(:final firstConnect):
              return ChatLive(firstConnect: firstConnect);
            case GraphqlSubscriptionInterrupted():
              return const ChatOffline();
            case GraphqlSubscriptionData(:final data):
              final raw = data['chatEvents'];
              if (raw is! Map) return null;
              final kind = ChatChangeKind.parse(raw['kind']?.toString());
              // An unknown kind is a newer server talking about something this
              // build has no idea what to do with — ignoring it is safer than
              // guessing, and the screen still refreshes on the next event.
              if (kind == null) return null;
              return ChatChanged(
                kind: kind,
                messageId: raw['messageId']?.toString(),
              );
          }
        })
        .where((update) => update != null)
        .cast<ChatUpdate>();
  }

  /// Re-sign an attachment's download URL after the previous one expired.
  Future<String> attachmentUrl(String attachmentId) async {
    final data = await _client.run(
      _attachmentUrlQuery,
      variables: {'attachmentId': attachmentId},
      authenticated: true,
    );
    return data['chatAttachmentUrl']?.toString() ?? '';
  }
}
