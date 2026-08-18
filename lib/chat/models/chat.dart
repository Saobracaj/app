import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';

/// What a support-chat attachment is, mirroring the backend's `AttachmentKind`.
enum ChatAttachmentKind {
  /// A stored binary the user downloads.
  file,

  /// A stored image, previewed inline and openable full-screen.
  image,

  /// A reference to an exam question — nothing is stored; the client renders
  /// «вопрос 1234» and opens the existing preview sheet on tap.
  question,

  /// A shared question list — nothing is stored either: a snapshot of the
  /// list's name and its question ids, rendered as one chip.
  questionList;

  static ChatAttachmentKind parse(String? raw) =>
      switch (raw?.toUpperCase()) {
        'IMAGE' => ChatAttachmentKind.image,
        'QUESTION' => ChatAttachmentKind.question,
        'QUESTION_LIST' => ChatAttachmentKind.questionList,
        _ => ChatAttachmentKind.file,
      };
}

/// Extensions the app treats as pictures when nothing else says so.
const _imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
};

/// MIME types by file extension — enough to cover what people actually attach.
const _contentTypesByExtension = <String, String>{
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'json': 'application/json',
  'zip': 'application/zip',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// The lower-case extension of [fileName], without the dot, or `''`.
String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

/// The MIME type an upload should be labelled with when the platform reported
/// none.
///
/// `XFile.mimeType` is null everywhere except the web, and the backend decides
/// an attachment's kind purely from what the uploader claims — so without this
/// every screenshot sent from the phone was stored as a plain file and never
/// shown inline. Returns `null` for an unknown extension, which lets the
/// transport fall back to `application/octet-stream` as before.
String? contentTypeForFileName(String fileName) =>
    _contentTypesByExtension[_extensionOf(fileName)];

/// One attachment of a support message.
///
/// [url] is a **short-lived** signed link the backend hands only to a
/// participant of the conversation; it is null for a [ChatAttachmentKind.question]
/// (which stores nothing) and can expire, so anything long-lived re-reads it
/// through `supportAttachmentUrl`.
@freezed
abstract class ChatAttachment with _$ChatAttachment {
  const factory ChatAttachment({
    required String id,
    required ChatAttachmentKind kind,
    @Default('') String fileName,
    @Default('') String contentType,
    @Default(0) int sizeBytes,
    int? questionId,

    /// The questions of a shared list, for [ChatAttachmentKind.questionList];
    /// the list's name is in [fileName].
    @Default(<int>[]) List<int> questionIds,
    String? url,

    /// The stored bytes are gone: the uploader deleted their account and took
    /// their photos and files with them. Rendered as a placeholder.
    @Default(false) bool deleted,
    required DateTime createdAt,
  }) = _ChatAttachment;

  const ChatAttachment._();

  static ChatAttachment parse(Map<String, dynamic> json) =>
      ChatAttachment(
        id: json['id'].toString(),
        kind: ChatAttachmentKind.parse(json['kind']?.toString()),
        fileName: json['fileName']?.toString() ?? '',
        contentType: json['contentType']?.toString() ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        questionId: (json['questionId'] as num?)?.toInt(),
        questionIds:
            (json['questionIds'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const <int>[],
        url: json['url']?.toString(),
        deleted: json['deleted'] == true,
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );

  /// Whether to render this attachment as an inline picture.
  ///
  /// The server's [kind] is the answer whenever it has one, but it is derived
  /// from the MIME type the uploader reported — and messages sent before the
  /// app learned to report one stored their screenshots as plain files, so
  /// anything still marked `file` is given a second chance by its content type
  /// and its extension.
  bool get isImage {
    if (isReference) return false;
    if (kind == ChatAttachmentKind.image) return true;
    return contentType.toLowerCase().startsWith('image/') ||
        _imageExtensions.contains(_extensionOf(fileName));
  }

  /// Whether the attachment stores nothing at all — a reference to something
  /// the app already has (a question, a shared list).
  bool get isReference =>
      kind == ChatAttachmentKind.question ||
      kind == ChatAttachmentKind.questionList;

  /// A human-readable size ("1,2 МБ"), empty for a reference.
  String get readableSize {
    if (sizeBytes <= 0) return '';
    const units = ['B', 'KB', 'MB'];
    var value = sizeBytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final rounded = value >= 10 || unit == 0
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$rounded ${units[unit]}';
  }
}

/// Реакции, которые можно поставить на сообщение, — зеркало серверного
/// `REACTION_EMOJIS` (`saobracaj_backend`, `src/chat/model.rs`).
///
/// Набор закрыт с обеих сторон: в меню помещается ровно одна строка значков, а
/// произвольную строку бэкенд всё равно отказывается принимать. Порядок здесь —
/// это порядок в меню.
const chatReactionEmojis = <String>['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Одна реакция на сообщение: эмодзи, сколько человек его поставили и стоит ли
/// среди них моя — по [mine] значок подсвечивается и снимается повторным
/// нажатием.
@freezed
abstract class ChatReaction with _$ChatReaction {
  const factory ChatReaction({
    required String emoji,
    @Default(0) int count,
    @Default(false) bool mine,
  }) = _ChatReaction;

  const ChatReaction._();

  static ChatReaction parse(Map<String, dynamic> json) => ChatReaction(
    emoji: json['emoji']?.toString() ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    mine: json['mine'] == true,
  );
}

/// One message of a conversation. [fromStaff] says which side wrote it, and
/// [readAt] is when the *other* side read it (null while unread).
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    @Default('') String threadId,
    @Default('') String authorId,
    @Default('') String authorDisplayName,
    @Default(false) bool fromStaff,
    @Default('') String body,
    required DateTime createdAt,
    DateTime? readAt,

    /// Когда автор последний раз правил сообщение; `null` — не правил. Рядом со
    /// временем отправки показывается «Изменено».
    DateTime? editedAt,

    /// Чат с ответами на это сообщение — тред, если его уже открывали.
    String? threadChatId,

    /// Сколько в этом треде ответов: из этого рисуется ссылка под сообщением.
    @Default(0) int replyCount,
    @Default(<ChatAttachment>[]) List<ChatAttachment> attachments,

    /// Реакции на сообщение, по одной на эмодзи, в порядке первого появления.
    @Default(<ChatReaction>[]) List<ChatReaction> reactions,
  }) = _ChatMessage;

  const ChatMessage._();

  static ChatMessage parse(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    final rawReactions = json['reactions'];
    return ChatMessage(
      id: json['id'].toString(),
      threadId: json['threadId']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorDisplayName: json['authorDisplayName']?.toString() ?? '',
      fromStaff: json['fromStaff'] == true,
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? '')?.toLocal(),
      editedAt: DateTime.tryParse(
        json['editedAt']?.toString() ?? '',
      )?.toLocal(),
      threadChatId: json['threadChatId']?.toString(),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      attachments: rawAttachments is List
          ? rawAttachments
                .whereType<Map>()
                .map((e) => ChatAttachment.parse(e.cast<String, dynamic>()))
                .toList()
          : const [],
      reactions: rawReactions is List
          ? rawReactions
                .whereType<Map>()
                .map((e) => ChatReaction.parse(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  bool get isRead => readAt != null;

  /// Правилось ли сообщение после отправки.
  bool get isEdited => editedAt != null;

  /// Есть ли у сообщения тред с ответами.
  bool get hasThread => (threadChatId ?? '').isNotEmpty && replyCount > 0;

  /// Стоит ли на сообщении моя реакция [emoji].
  bool hasMyReaction(String emoji) =>
      reactions.any((r) => r.emoji == emoji && r.mine);

  /// Сообщение, каким оно становится сразу после нажатия на реакцию — до
  /// ответа сервера.
  ///
  /// Правило продукта целиком здесь: своя реакция снимается повторным
  /// нажатием, чужие только пересчитываются, а опустевший значок исчезает —
  /// у бэкенда та же логика, и Bloc'у остаётся только отправить запрос.
  ChatMessage withToggledReaction(String emoji) {
    final updated = <ChatReaction>[];
    var found = false;
    for (final reaction in reactions) {
      if (reaction.emoji != emoji) {
        updated.add(reaction);
        continue;
      }
      found = true;
      final count = reaction.mine ? reaction.count - 1 : reaction.count + 1;
      if (count > 0) {
        updated.add(reaction.copyWith(count: count, mine: !reaction.mine));
      }
    }
    if (!found) {
      updated.add(ChatReaction(emoji: emoji, count: 1, mine: true));
    }
    return copyWith(reactions: updated);
  }
}

/// Что за сущность обсуждается — зеркало серверного `ChatEntityType`.
enum ChatEntityType {
  /// Чат пользователя с разработчиком.
  support,

  /// Тред: ответы на одно сообщение.
  messageThread,

  /// Чат группы (задел, пока такие чаты никто не создаёт).
  group,

  /// Обсуждение вопроса (задел).
  question;

  static ChatEntityType parse(String? raw) => switch (raw?.toUpperCase()) {
    'MESSAGE_THREAD' => ChatEntityType.messageThread,
    'GROUP' => ChatEntityType.group,
    'QUESTION' => ChatEntityType.question,
    _ => ChatEntityType.support,
  };
}

/// Один разговор. О чём он — говорит пара ([entityType], [entityId]); всё
/// остальное одинаково для чата с разработчиком, треда и будущих групповых
/// чатов, поэтому их всех показывает один экран и ведёт один Bloc.
@freezed
abstract class Chat with _$Chat {
  const factory Chat({
    required String id,
    @Default(ChatEntityType.support) ChatEntityType entityType,
    @Default('') String entityId,

    /// Сообщение, ответы на которое собирает этот чат, — только у треда.
    String? parentMessageId,
    @Default(false) bool isGroup,

    /// Включены ли у **этого** пользователя оповещения об этом разговоре. По
    /// умолчанию выключены — и у чатов, и у тредов.
    @Default(false) bool notificationsEnabled,
    @Default('') String userId,
    @Default('') String userDisplayName,

    /// The owner's email, filled in only for the moderator's view.
    @Default('') String userEmail,
    required DateTime createdAt,
    DateTime? lastMessageAt,
    @Default('') String lastMessagePreview,

    /// Messages the *reading* side has not seen yet.
    @Default(0) int unreadCount,
    @Default(0) int messagesCount,
  }) = _Chat;

  const Chat._();

  static Chat parse(Map<String, dynamic> json) => Chat(
    id: json['id'].toString(),
    entityType: ChatEntityType.parse(json['entityType']?.toString()),
    entityId: json['entityId']?.toString() ?? '',
    parentMessageId: (json['parentMessageId']?.toString() ?? '').isEmpty
        ? null
        : json['parentMessageId'].toString(),
    isGroup: json['isGroup'] == true,
    notificationsEnabled: json['notificationsEnabled'] == true,
    userId: json['userId']?.toString() ?? '',
    userDisplayName: json['userDisplayName']?.toString() ?? '',
    userEmail: json['userEmail']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    lastMessageAt: DateTime.tryParse(
      json['lastMessageAt']?.toString() ?? '',
    )?.toLocal(),
    lastMessagePreview: json['lastMessagePreview']?.toString() ?? '',
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    messagesCount: (json['messagesCount'] as num?)?.toInt() ?? 0,
  );

  /// What to show as the conversation's name in the moderator list.
  String get title => userDisplayName.isNotEmpty ? userDisplayName : userEmail;

  /// Тред ли это — от этого зависят и заголовок, и то, что внутри треда нельзя
  /// создать ещё один тред.
  bool get isThread => entityType == ChatEntityType.messageThread;
}

/// A page of messages, oldest first.
@freezed
abstract class ChatMessagePage with _$ChatMessagePage {
  const factory ChatMessagePage({
    @Default(<ChatMessage>[]) List<ChatMessage> nodes,
    @Default(0) int totalCount,
    @Default(false) bool hasNextPage,
  }) = _ChatMessagePage;

  const ChatMessagePage._();

  static ChatMessagePage parse(Map<String, dynamic> json) =>
      ChatMessagePage(
        nodes: _nodes(json, ChatMessage.parse),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        hasNextPage: json['hasNextPage'] == true,
      );
}

/// A page of conversations for the moderator list, newest activity first.
@freezed
abstract class ChatConnection with _$ChatConnection {
  const factory ChatConnection({
    @Default(<Chat>[]) List<Chat> nodes,
    @Default(0) int totalCount,
    @Default(false) bool hasNextPage,
  }) = _ChatConnection;

  const ChatConnection._();

  static ChatConnection parse(Map<String, dynamic> json) =>
      ChatConnection(
        nodes: _nodes(json, Chat.parse),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        hasNextPage: json['hasNextPage'] == true,
      );
}

List<T> _nodes<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) parse,
) {
  final raw = json['nodes'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => parse(e.cast<String, dynamic>()))
      .toList();
}
