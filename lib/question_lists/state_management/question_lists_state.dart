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

    /// The questions failed in the most recent exam attempt, in exam order — the
    /// content of the "last exam mistakes" automatic list. Empty while no exam
    /// has been taken and after one passed without a single mistake; in both
    /// cases the list is not shown.
    @Default(<int>[]) List<int> lastExamMistakes,

    /// Questions missed at least twice over the whole answer history, most
    /// mistakes first — the content of the "chronic mistakes" automatic list.
    /// Empty until something has been missed twice, and then the list is hidden.
    @Default(<int>[]) List<int> chronicMistakes,

    /// Questions the user gets wrong although the crowd finds them easy, hardest
    /// gap first — the content of the "personal weak spots" automatic list.
    /// Empty until something asks for the automatic lists (the snapshot of crowd
    /// difficulty is fetched lazily) and for a guest, who cannot fetch it at all.
    @Default(<int>[]) List<int> personalWeakSpots,

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

  /// Every automatic list the app knows about, in display order — including the
  /// ones that are currently empty and therefore not shown.
  List<QuestionList> get _everyAutoList => [
    QuestionList(
      id: kRecentMistakesListId,
      questionIds: recentMistakes,
      isAuto: true,
    ),
    QuestionList(
      id: kLastExamMistakesListId,
      questionIds: lastExamMistakes,
      isAuto: true,
    ),
    QuestionList(
      id: kChronicMistakesListId,
      questionIds: chronicMistakes,
      isAuto: true,
    ),
    QuestionList(
      id: kPersonalWeakSpotsListId,
      questionIds: personalWeakSpots,
      isAuto: true,
    ),
  ];

  /// The automatic lists worth showing: an empty one is left out, so a guest, a
  /// brand-new user or simply "nothing matched" sees no card at all. The
  /// exception is `auto:recent_mistakes` ([kAlwaysShownAutoListIds]), which has
  /// always been on the home screen even with nothing in it.
  List<QuestionList> get autoLists => [
    for (final list in _everyAutoList)
      if (kAlwaysShownAutoListIds.contains(list.id) ||
          list.questionIds.isNotEmpty)
        list,
  ];

  /// Automatic lists first, then the custom ones — the order of the home-screen
  /// row.
  List<QuestionList> get allLists => [...autoLists, ...customLists];

  /// The list with this id, or `null` if it no longer exists (e.g. it was just
  /// deleted while its screen was open).
  ///
  /// Hidden (empty) automatic lists still resolve: their screen can be open
  /// while the data is still being computed, and "список пуст" is a truer answer
  /// there than "список не найден".
  QuestionList? byId(String id) {
    for (final list in [..._everyAutoList, ...customLists]) {
      if (list.id == id) return list;
    }
    return null;
  }
}
