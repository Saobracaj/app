/// События счётчика непрочитанного в чате с разработчиком.
sealed class SupportUnreadEvent {
  const SupportUnreadEvent();
}

/// Начать следить: за сессией, сетью, пушами, пометками «прочитано» и
/// возвратом приложения из фона. Посылается один раз при старте приложения.
///
/// [watchLifecycle] выключают тесты без виджетного биндинга.
class SupportUnreadStarted extends SupportUnreadEvent {
  const SupportUnreadStarted({this.watchLifecycle = true});

  final bool watchLifecycle;
}

/// Перечитать список непрочитанного — по любому из поводов выше.
class SupportUnreadRefreshRequested extends SupportUnreadEvent {
  const SupportUnreadRefreshRequested();
}

/// Сменилась сессия: кто вошёл и с какой стороны читает. Гость — пустой
/// счётчик, вошедший — свежий список.
class SupportUnreadSessionChanged extends SupportUnreadEvent {
  const SupportUnreadSessionChanged({
    required this.authenticated,
    required this.moderator,
  });

  final bool authenticated;
  final bool moderator;
}
