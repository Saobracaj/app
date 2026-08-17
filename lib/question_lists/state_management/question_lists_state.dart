import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/question_list.dart';
import '../models/question_list_share.dart';

part 'question_lists_state.freezed.dart';

/// App-wide state of the question-lists feature: the user's custom lists (from
/// the backend, cached locally) plus the inputs of the automatic ones.
@freezed
sealed class QuestionListsState with _$QuestionListsState {
  const QuestionListsState._();

  const factory QuestionListsState({
    /// Custom lists, oldest first — exactly what the backend returned.
    @Default(<QuestionList>[]) List<QuestionList> customLists,

    /// Questions whose most recent answer was wrong, taken from the local answer
    /// history — the content of the "recent mistakes" automatic list.
    @Default(<int>[]) List<int> recentMistakes,

    /// A failed backend write (the optimistic change has already been rolled
    /// back); surfaced once as a snackbar and then cleared.
    String? errorMessage,

    /// The active share links of the user's lists, by list id — what the list
    /// menu shows as "link is active". Loaded with the lists, best-effort.
    @Default(<String, QuestionListShare>{})
    Map<String, QuestionListShare> shares,

    /// Whether a share / revoke call is in flight (the menu actions wait).
    @Default(false) bool shareBusy,

    /// One-shot: a share the user asked for is ready and the system share
    /// sheet should open with its link. Cleared by `QuestionListSharePresented`.
    QuestionListShare? shareToPresent,

    /// One-shot: a share was just revoked, for the confirmation snackbar.
    /// Cleared together with [shareToPresent].
    @Default(false) bool shareRevoked,

    /// A failed share / revoke, surfaced once as a snackbar and cleared with
    /// `QuestionListsErrorShown` like [errorMessage].
    @Default(false) bool shareFailed,
  }) = _QuestionListsState;

  /// The active share of [listId], or `null` when the list is not shared.
  QuestionListShare? shareOf(String listId) => shares[listId];

  /// The automatic lists, derived on the device. Currently just one.
  List<QuestionList> get autoLists => [
    QuestionList(
      id: kRecentMistakesListId,
      questionIds: recentMistakes,
      isAuto: true,
    ),
  ];

  /// Automatic lists first, then the custom ones — the order of the home-screen
  /// row.
  List<QuestionList> get allLists => [...autoLists, ...customLists];

  /// The list with this id, or `null` if it no longer exists (e.g. it was just
  /// deleted while its screen was open).
  QuestionList? byId(String id) {
    for (final list in allLists) {
      if (list.id == id) return list;
    }
    return null;
  }
}
