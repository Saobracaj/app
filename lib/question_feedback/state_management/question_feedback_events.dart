/// События диалога «Сообщить об ошибке».
sealed class QuestionFeedbackEvent {}

/// Диалог открылся: читаем, вошёл ли пользователь и включены ли уведомления.
class QuestionFeedbackOpened extends QuestionFeedbackEvent {}

class QuestionFeedbackTextChanged extends QuestionFeedbackEvent {
  QuestionFeedbackTextChanged(this.text);

  final String text;
}

/// Пользователь ответил на вопрос про оповещения об ответе разработчика.
class QuestionFeedbackNotifyToggled extends QuestionFeedbackEvent {
  QuestionFeedbackNotifyToggled(this.enabled);

  final bool enabled;
}

class QuestionFeedbackSubmitted extends QuestionFeedbackEvent {}

class QuestionFeedbackErrorDismissed extends QuestionFeedbackEvent {}
