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

    /// A failed backend write (the optimistic change has already been rolled
    /// back); surfaced once as a snackbar and then cleared.
    String? errorMessage,
  }) = _QuestionListsState;

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
