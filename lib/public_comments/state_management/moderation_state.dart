import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/public_comment.dart';

part 'moderation_state.freezed.dart';

/// State of the comment-moderation feed (settings › moderation), available to
/// users with the `moderate_comments` permission. [comments] is the global
/// feed, newest first, accumulated across scroll pagination.
@freezed
abstract class ModerationState with _$ModerationState {
  const factory ModerationState({
    @Default(true) bool loading,
    @Default(<PublicComment>[]) List<PublicComment> comments,
    @Default(false) bool hasNextPage,
    @Default(false) bool loadingMore,
    String? errorMessage,
  }) = _ModerationState;
}
