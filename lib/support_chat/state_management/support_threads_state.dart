import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/support_chat.dart';

part 'support_threads_state.freezed.dart';

/// State of the moderator's list of support conversations.
@freezed
abstract class SupportThreadsState with _$SupportThreadsState {
  const factory SupportThreadsState({
    @Default(true) bool loading,
    @Default(<SupportThread>[]) List<SupportThread> threads,
    @Default(0) int totalCount,
    @Default(false) bool onlyUnread,
    String? errorMessage,
  }) = _SupportThreadsState;
}
