import '../../models/models.dart';

sealed class DailyQuestionEvent {}

/// The bank to draw today's question from (sent once it is loaded).
class DailyQuestionStarted extends DailyQuestionEvent {
  DailyQuestionStarted(this.questions);

  final List<Question> questions;
}

/// The user tapped an option (toggles it; several can be selected when the
/// question wants several answers).
class DailyQuestionChoiceToggled extends DailyQuestionEvent {
  DailyQuestionChoiceToggled(this.index);

  final int index;
}

/// «Проверить»: grade the selection, record the answer, remember it for the
/// rest of the day.
class DailyQuestionChecked extends DailyQuestionEvent {}
