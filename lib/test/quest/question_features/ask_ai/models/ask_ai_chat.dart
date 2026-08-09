import 'package:freezed_annotation/freezed_annotation.dart';

part 'ask_ai_chat.freezed.dart';

/// What an Ask-AI conversation is about, mirroring the backend's `AskAiScope`.
/// A dialog belongs to a `(user, scope)` pair, so re-opening the same question
/// (or the same exam result) continues the same conversation.
enum AskAiChatScope {
  /// One exam question; the scope id is the question id.
  question('QUESTION'),

  /// One exam attempt; the scope id is the app's local attempt uuid — the same
  /// one the statistics sync ships to the backend.
  examResult('EXAM_RESULT'),

  /// A whole category; the scope id is the category id.
  category('CATEGORY');

  const AskAiChatScope(this.wireName);

  /// The GraphQL enum value.
  final String wireName;
}

/// Who wrote a chat message.
enum AskAiChatRole {
  user,
  assistant;

  static AskAiChatRole parse(String? raw) =>
      raw?.toUpperCase() == 'USER' ? AskAiChatRole.user : AskAiChatRole.assistant;
}

/// One message of an Ask-AI conversation.
@freezed
abstract class AskAiChatMessage with _$AskAiChatMessage {
  const factory AskAiChatMessage({
    required String id,
    required AskAiChatRole role,
    @Default('') String content,
    required DateTime createdAt,
  }) = _AskAiChatMessage;

  static AskAiChatMessage parse(Map<String, dynamic> json) => AskAiChatMessage(
    id: json['id'].toString(),
    role: AskAiChatRole.parse(json['role']?.toString()),
    content: json['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

/// The caller's standing against the daily message quota — the backend exposes
/// it so the app can show a "come back tomorrow" state instead of failing a
/// send.
@freezed
abstract class AskAiQuota with _$AskAiQuota {
  const factory AskAiQuota({
    @Default(0) int limit,
    @Default(0) int used,
    @Default(0) int remaining,
  }) = _AskAiQuota;

  const AskAiQuota._();

  bool get exhausted => remaining <= 0;

  static AskAiQuota parse(Map<String, dynamic> json) => AskAiQuota(
    limit: (json['limit'] as num?)?.toInt() ?? 0,
    used: (json['used'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
  );
}
