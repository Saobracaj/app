/// Какой разговор открывает экран чата.
///
/// Виджеты и Bloc чата ничего не знают про поддержку: им дают цель, а чем она
/// окажется — своим чатом с разработчиком, конкретным обращением, чатом группы
/// или тредом на сообщение — решает вызывающая сторона. Ровно это и позволяет
/// переиспользовать экран, не копируя его.
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

/// Чат группы. Чата может ещё не быть — бэкенд создаёт его при первом
/// открытии, поэтому цель хранит идентификатор группы, а не чата.
class GroupChatTarget extends ChatTarget {
  const GroupChatTarget(this.groupId);
  final String groupId;
}

/// Тред на сообщение. Чата может ещё не быть — бэкенд создаёт его при первом
/// открытии, поэтому цель хранит идентификатор сообщения, а не чата.
class MessageThreadTarget extends ChatTarget {
  const MessageThreadTarget(this.messageId);
  final String messageId;
}
