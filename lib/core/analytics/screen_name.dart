/// Turns a concrete routemaster path into the low-cardinality screen name sent
/// to analytics.
///
/// Screen names live in PostHog as enumerable dimensions; a raw path
/// like `/question/7923` or `/lists/3f2a.../q` would explode that dimension
/// into thousands of one-off values. Parameter segments are therefore replaced
/// with their route-template placeholders: any purely numeric segment (a
/// question id) and any segment that follows `question`, `lists`, `groups`,
/// `invite`, `shared`, `threads`, `chat` or `thread` (see the route map in
/// `lib/routes.dart`). Query parameters are dropped entirely — question ids,
/// invite codes and law references all travel there.
String analyticsScreenName(String path) {
  final segments = Uri.parse(
    path,
  ).pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return '/';
  const placeholderAfter = {
    'question': ':id',
    'lists': ':id',
    'groups': ':id',
    'invite': ':token',
    'shared': ':code',
    'threads': ':id',
    'chat': ':id',
    'thread': ':id',
  };
  final out = <String>[];
  for (var i = 0; i < segments.length; i++) {
    final placeholder = i > 0 ? placeholderAfter[segments[i - 1]] : null;
    if (placeholder != null) {
      out.add(placeholder);
    } else if (int.tryParse(segments[i]) != null) {
      out.add(':id');
    } else {
      out.add(segments[i]);
    }
  }
  return '/${out.join('/')}';
}

/// A readable screen name for the PostHog reports, as the operator asked —
/// «Вопрос (прогон)» beats `/lists/:id/q` in a funnel. Falls back to the route
/// template itself for anything not in the map (a settings section, an admin
/// screen): the template is already low-cardinality and self-describing.
String analyticsScreenTitle(String template) {
  final known = _screenTitles[template];
  if (known != null) return known;
  // The law opens as a child of many routes ('/quest/zakon',
  // '/lists/:id/q/zakon', …) — one name for all of them.
  if (template == '/zakon' || template.endsWith('/zakon')) return 'Закон';
  return template;
}

const _screenTitles = {
  '/': 'Главная',
  '/home': 'Главная',
  '/questions': 'Категории вопросов',
  '/statistics': 'История',
  '/practice': 'Экзамен',
  '/start': 'Старт прогона',
  '/quest': 'Вопрос (прогон)',
  '/quest/q': 'Вопрос (прогон)',
  '/statistics/q': 'Вопрос (из истории)',
  '/lists/:id/q': 'Вопрос (из списка)',
  '/groups/:id/feed/q': 'Вопрос (из группы)',
  '/shared/:code/q': 'Вопрос (из общего списка)',
  '/questPractice': 'Практика по вопросу',
  '/questPractice/q': 'Вопрос (практика)',
  '/question/:id': 'Обсуждение вопроса',
  '/konspekt/question/:id': 'Обсуждение вопроса',
  '/konspekt': 'Конспект',
  '/lists/:id': 'Список вопросов',
  '/groups/:id/feed': 'Группа',
  '/groups/:id/feed/events': 'События группы',
  '/groups/:id/feed/members': 'Участники группы',
  '/groups/:id/feed/invite': 'Приглашение в группу',
  '/groups/:id/feed/chat': 'Чат группы',
  '/invite/:token': 'Инвайт в группу',
  '/shared/:code': 'Общий список вопросов',
  '/about': 'О приложении',
  '/login': 'Вход',
  '/register': 'Регистрация',
  '/resetPassword': 'Сброс пароля',
  '/confirmCode': 'Код подтверждения',
  '/settings': 'Настройки',
  '/settings/profile': 'Профиль',
  '/tariffs': 'Тарифы',
  '/subscription': 'Подписка',
  '/appearance': 'Оформление',
  '/features': 'Функции',
  '/notifications': 'Уведомления',
  '/displayName': 'Имя пользователя',
  '/deleteAccount': 'Удаление аккаунта',
  '/billing': 'Платежи (админка)',
  '/support': 'Чат с разработчиком',
  '/support/threads': 'Обращения в поддержку',
  '/support/threads/:id': 'Обращение в поддержку',
  '/chat/:id': 'Чат',
  '/thread/:id': 'Ветка чата',
};
