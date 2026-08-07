import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_chat.freezed.dart';

/// What a support-chat attachment is, mirroring the backend's `AttachmentKind`.
enum SupportAttachmentKind {
  /// A stored binary the user downloads.
  file,

  /// A stored image, previewed inline and openable full-screen.
  image,

  /// A reference to an exam question — nothing is stored; the client renders
  /// «вопрос 1234» and opens the existing preview sheet on tap.
  question;

  static SupportAttachmentKind parse(String? raw) => switch (raw?.toUpperCase()) {
    'IMAGE' => SupportAttachmentKind.image,
    'QUESTION' => SupportAttachmentKind.question,
    _ => SupportAttachmentKind.file,
  };
}

/// One attachment of a support message.
///
/// [url] is a **short-lived** signed link the backend hands only to a
/// participant of the conversation; it is null for a [SupportAttachmentKind.question]
/// (which stores nothing) and can expire, so anything long-lived re-reads it
/// through `supportAttachmentUrl`.
@freezed
abstract class SupportAttachment with _$SupportAttachment {
  const factory SupportAttachment({
    required String id,
    required SupportAttachmentKind kind,
    @Default('') String fileName,
    @Default('') String contentType,
    @Default(0) int sizeBytes,
    int? questionId,
    String? url,
    required DateTime createdAt,
  }) = _SupportAttachment;

  const SupportAttachment._();

  static SupportAttachment parse(Map<String, dynamic> json) =>
      SupportAttachment(
        id: json['id'].toString(),
        kind: SupportAttachmentKind.parse(json['kind']?.toString()),
        fileName: json['fileName']?.toString() ?? '',
        contentType: json['contentType']?.toString() ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        questionId: (json['questionId'] as num?)?.toInt(),
        url: json['url']?.toString(),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );

  /// A human-readable size ("1,2 МБ"), empty for a question reference.
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

/// One message in a support thread. [fromStaff] says which side wrote it, and
/// [readAt] is when the *other* side read it (null while unread).
@freezed
abstract class SupportMessage with _$SupportMessage {
  const factory SupportMessage({
    required String id,
    @Default('') String threadId,
    @Default('') String authorId,
    @Default('') String authorDisplayName,
    @Default(false) bool fromStaff,
    @Default('') String body,
    required DateTime createdAt,
    DateTime? readAt,
    @Default(<SupportAttachment>[]) List<SupportAttachment> attachments,
  }) = _SupportMessage;

  const SupportMessage._();

  static SupportMessage parse(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    return SupportMessage(
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
      attachments: rawAttachments is List
          ? rawAttachments
                .whereType<Map>()
                .map((e) => SupportAttachment.parse(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  bool get isRead => readAt != null;
}

/// A conversation between one user and the developers.
@freezed
abstract class SupportThread with _$SupportThread {
  const factory SupportThread({
    required String id,
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
  }) = _SupportThread;

  const SupportThread._();

  static SupportThread parse(Map<String, dynamic> json) => SupportThread(
    id: json['id'].toString(),
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

  /// What to show as the thread's name in the moderator list.
  String get title =>
      userDisplayName.isNotEmpty ? userDisplayName : userEmail;
}

/// A page of messages, oldest first.
@freezed
abstract class SupportMessagePage with _$SupportMessagePage {
  const factory SupportMessagePage({
    @Default(<SupportMessage>[]) List<SupportMessage> nodes,
    @Default(0) int totalCount,
    @Default(false) bool hasNextPage,
  }) = _SupportMessagePage;

  const SupportMessagePage._();

  static SupportMessagePage parse(Map<String, dynamic> json) =>
      SupportMessagePage(
        nodes: _nodes(json, SupportMessage.parse),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        hasNextPage: json['hasNextPage'] == true,
      );
}

/// A page of conversations for the moderator list, newest activity first.
@freezed
abstract class SupportThreadPage with _$SupportThreadPage {
  const factory SupportThreadPage({
    @Default(<SupportThread>[]) List<SupportThread> nodes,
    @Default(0) int totalCount,
    @Default(false) bool hasNextPage,
  }) = _SupportThreadPage;

  const SupportThreadPage._();

  static SupportThreadPage parse(Map<String, dynamic> json) =>
      SupportThreadPage(
        nodes: _nodes(json, SupportThread.parse),
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
