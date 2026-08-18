import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/chat.dart';

part 'support_chats_state.freezed.dart';

/// State of the moderator's list of support conversations.
@freezed
abstract class SupportChatsState with _$SupportChatsState {
  const factory SupportChatsState({
    @Default(true) bool loading,
    @Default(<Chat>[]) List<Chat> threads,
    @Default(0) int totalCount,
    @Default(false) bool onlyUnread,
    String? errorMessage,
  }) = _SupportChatsState;
}
