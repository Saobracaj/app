/// События диалога «Не сдал экзамен».
sealed class ExtensionRequestEvent {}

/// Диалог открыт: узнать, есть ли сессия.
class ExtensionRequestOpened extends ExtensionRequestEvent {}

class ExtensionExamDateChanged extends ExtensionRequestEvent {
  ExtensionExamDateChanged(this.text);

  final String text;
}

class ExtensionNoteChanged extends ExtensionRequestEvent {
  ExtensionNoteChanged(this.text);

  final String text;
}

/// Отправить запрос в чат с разработчиком.
class ExtensionRequestSubmitted extends ExtensionRequestEvent {}
