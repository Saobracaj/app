import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/question_list.dart';

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

    /// Questions the user gets wrong although the crowd finds them easy, hardest
    /// gap first — the content of the "personal weak spots" automatic list.
    /// Empty until something asks for the automatic lists (the snapshot of crowd
    /// difficulty is fetched lazily) and for a guest, who cannot fetch it at all.
    @Default(<int>[]) List<int> personalWeakSpots,

    /// A failed backend write (the optimistic change has already been rolled
    /// back); surfaced once as a snackbar and then cleared.
    String? errorMessage,
  }) = _QuestionListsState;

  /// Every automatic list the app knows about, in display order — including the
  /// ones that are currently empty and therefore not shown.
  List<QuestionList> get _everyAutoList => [
    QuestionList(
      id: kRecentMistakesListId,
      questionIds: recentMistakes,
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
