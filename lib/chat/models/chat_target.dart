/// Какой разговор открывает экран чата.
///
/// Виджеты и Bloc чата ничего не знают про поддержку: им дают цель, а чем она
/// окажется — своим чатом с разработчиком, конкретным обращением, тредом на
/// сообщение или (в будущем) чатом группы — решает вызывающая сторона. Ровно
/// это и позволяет переиспользовать экран, не копируя его.
sealed class ChatTarget {
  const ChatTarget();
}

/// Собственный чат пользователя с разработчиком: идентификатор не нужен —
/// бэкенд находит разговор по токену.
class SupportChatTarget extends ChatTarget {
  const SupportChatTarget();
}

/// Разговор, который уже известен по идентификатору: обращение в списке
/// модератора, тред из ссылки, чат группы.
class ChatIdTarget extends ChatTarget {
  const ChatIdTarget(this.chatId);
  final String chatId;
}

/// Тред на сообщение. Чата может ещё не быть — бэкенд создаёт его при первом
/// открытии, поэтому цель хранит идентификатор сообщения, а не чата.
class MessageThreadTarget extends ChatTarget {
  const MessageThreadTarget(this.messageId);
  final String messageId;
}
