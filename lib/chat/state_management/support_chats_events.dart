/// User actions of the moderator's list of support conversations.
sealed class SupportChatsEvent {}

/// Load (or reload) the list.
class SupportChatsRequested extends SupportChatsEvent {}

/// Toggle the "only conversations with unread messages" filter.
class SupportChatsFilterToggled extends SupportChatsEvent {
  SupportChatsFilterToggled(this.onlyUnread);
  final bool onlyUnread;
}

/// Перечитать список незаметно: без индикатора загрузки и без сообщения об
/// ошибке — то, что уже на экране, остаётся, пока не придёт свежее.
///
/// Так список догоняет происходящее без участия модератора: пришёл пуш о новом
/// обращении, приложение вернулось из фона, модератор вернулся из открытого
/// обращения (там сообщения стали прочитанными — счётчик должен сойтись).
class SupportChatsRefreshed extends SupportChatsEvent {}
