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
  question,

  /// A shared question list — nothing is stored either: a snapshot of the
  /// list's name and its question ids, rendered as one chip.
  questionList;

  static SupportAttachmentKind parse(String? raw) =>
      switch (raw?.toUpperCase()) {
        'IMAGE' => SupportAttachmentKind.image,
        'QUESTION' => SupportAttachmentKind.question,
        'QUESTION_LIST' => SupportAttachmentKind.questionList,
        _ => SupportAttachmentKind.file,
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

    /// The questions of a shared list, for [SupportAttachmentKind.questionList];
    /// the list's name is in [fileName].
    @Default(<int>[]) List<int> questionIds,
    String? url,

    /// The stored bytes are gone: the uploader deleted their account and took
    /// their photos and files with them. Rendered as a placeholder.
    @Default(false) bool deleted,
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
    if (kind == SupportAttachmentKind.image) return true;
    return contentType.toLowerCase().startsWith('image/') ||
        _imageExtensions.contains(_extensionOf(fileName));
  }

  /// Whether the attachment stores nothing at all — a reference to something
  /// the app already has (a question, a shared list).
  bool get isReference =>
      kind == SupportAttachmentKind.question ||
      kind == SupportAttachmentKind.questionList;

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
  String get title => userDisplayName.isNotEmpty ? userDisplayName : userEmail;
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
