import 'package:freezed_annotation/freezed_annotation.dart';

import '../../profile/models/user_profile.dart';
import '../models/public_comment.dart';

part 'comments_state.freezed.dart';

/// State of the public-comments panel for one question.
///
/// [comments] holds the top-level comments loaded so far (each with its
/// replies), accumulated across pagination. Write affordances are gated on
/// [canWrite]; [expandedThreads] tracks which threads have had their older
/// replies revealed ("show previous").
@freezed
abstract class CommentsState with _$CommentsState {
  const factory CommentsState({
    @Default(true) bool loading,
    @Default(<PublicComment>[]) List<PublicComment> comments,
    @Default(0) int totalCount,
    @Default(false) bool hasNextPage,
    @Default(false) bool loadingMore,
    @Default(false) bool submitting,
    @Default(false) bool isAuthenticated,
    UserProfile? profile,
    @Default(<String>{}) Set<String> expandedThreads,
    // The top-level comment whose inline reply field is currently open, if any.
    String? replyingTo,
    String? errorMessage,
  }) = _CommentsState;

  const CommentsState._();

  /// Whether the composer should be shown: signed in, not banned, and with a
  /// display name set (the pre-comment display-name dialog is a separate flow).
  bool get canWrite =>
      isAuthenticated && (profile?.commentBan == false) && (profile?.hasDisplayName == true);

  /// Signed in and allowed to comment but has not set a display name yet — the
  /// composer prompts for one before the first post (handled elsewhere).
  bool get needsDisplayName =>
      isAuthenticated &&
      profile != null &&
      !profile!.commentBan &&
      !profile!.hasDisplayName;

  /// Signed in but banned from writing by a moderator.
  bool get isBanned => isAuthenticated && (profile?.commentBan == true);
}
