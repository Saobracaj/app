import '../models/question_list.dart';

/// Everything that can change the question-lists state.
sealed class QuestionListsEvent {}

/// Subscribe to the repository and the session, load the cache and refresh.
/// Dispatched once when the app-wide Bloc is created.
class QuestionListsStarted extends QuestionListsEvent {}

/// Re-read the automatic lists' source data (the local answer history) and pull
/// the custom lists from the backend. Dispatched when a screen showing lists
/// appears, and when a run ends — answering questions changes the "recent
/// mistakes" list, and a finished exam changes "last exam mistakes".
class QuestionListsRefreshed extends QuestionListsEvent {}

/// Something is about to show the automatic lists (the home-screen block or the
/// screen of one of them). Only then is the crowd-difficulty snapshot fetched —
/// it is a whole-bank request and must not be part of app start-up. Dispatching
/// it repeatedly is free: the Bloc fetches once and afterwards only recomputes
/// on [QuestionListsRefreshed].
class AutoListsRequested extends QuestionListsEvent {}

/// Create a custom list. [questionId], when given, is put into the new list
/// right away (the "create a list from the question screen" flow).
class QuestionListCreated extends QuestionListsEvent {
  QuestionListCreated({required this.name, required this.color, this.questionId});

  final String name;
  final int color;
  final int? questionId;
}

/// Rename and/or recolour a custom list.
class QuestionListEdited extends QuestionListsEvent {
  QuestionListEdited({required this.id, this.name, this.color});

  final String id;
  final String? name;
  final int? color;
}

/// Delete a custom list (soft-deleted on the backend).
class QuestionListDeleted extends QuestionListsEvent {
  QuestionListDeleted(this.id);

  final String id;
}

/// Tick/untick a question in a custom list.
class QuestionInListToggled extends QuestionListsEvent {
  QuestionInListToggled({
    required this.listId,
    required this.questionId,
    required this.included,
  });

  final String listId;
  final int questionId;
  final bool included;
}

/// Replace a custom list's contents — drag-and-drop reordering and removal.
class QuestionListQuestionsChanged extends QuestionListsEvent {
  QuestionListQuestionsChanged({required this.listId, required this.questionIds});

  final String listId;
  final List<int> questionIds;
}

/// Dismiss the last error after it has been shown.
class QuestionListsErrorShown extends QuestionListsEvent {}

/// Internal: the repository published a new set of custom lists.
class QuestionListsUpdated extends QuestionListsEvent {
  QuestionListsUpdated(this.lists);

  final List<QuestionList> lists;
}

/// Internal: the local answer history was re-read.
class RecentMistakesUpdated extends QuestionListsEvent {
  RecentMistakesUpdated(this.questionIds);

  final List<int> questionIds;
}

/// Internal: the newest exam attempt was re-read from `practice_records`.
class LastExamMistakesUpdated extends QuestionListsEvent {
  LastExamMistakesUpdated(this.questionIds);

  final List<int> questionIds;
}

/// Internal: the "personal weak spots" list was recomputed (or cleared, when the
/// session ended).
class PersonalWeakSpotsUpdated extends QuestionListsEvent {
  PersonalWeakSpotsUpdated(this.questionIds);

  final List<int> questionIds;
}
