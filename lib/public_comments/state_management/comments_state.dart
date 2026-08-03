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
    // The top-level comment whose inline reply composer should take focus, set
    // when the user taps "Ответить". [replyFocusRequestId] is bumped on every
    // such tap so the target composer re-focuses even on repeated taps.
    String? replyFocusTarget,
    @Default(0) int replyFocusRequestId,
    // Transient: a comment the user just posted for which the UI should offer a
    // "subscribe to replies" dialog (cleared once the dialog is shown).
    PublicComment? subscriptionPromptFor,
    String? errorMessage,
  }) = _CommentsState;

  const CommentsState._();

  /// Whether the composer should be shown: signed in and not banned. A missing
  /// display name no longer hides the composer — it is collected via a dialog
  /// before the first comment is posted.
  bool get canWrite =>
      isAuthenticated && profile != null && (profile?.commentBan == false);

  /// Whether a display-name dialog must be shown before posting (signed in, not
  /// banned, no display name yet).
  bool get mustPromptDisplayName =>
      isAuthenticated &&
      profile != null &&
      !profile!.commentBan &&
      !profile!.hasDisplayName;

  /// Signed in but banned from writing by a moderator.
  bool get isBanned => isAuthenticated && (profile?.commentBan == true);
}
