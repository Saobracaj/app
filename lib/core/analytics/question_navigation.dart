/// Чем пользователь перевёл прогон (тренажёр или симуляцию экзамена) на
/// другой вопрос — свойство `navigation` события `question_viewed`.
///
/// Значения закрытые и низкокардинальные: по ним в PostHog сравнивают,
/// листают ли люди свайпом, кнопкой, клавиатурой или навигатором.
enum QuestionNavigation {
  /// Первый вопрос прогона — показан самим открытием экрана, а не переходом.
  runStart('run_start'),

  /// Симуляция продолжена из снимка (пауза, перезапуск приложения).
  resume('resume'),

  /// Ход симуляции пришёл с другого устройства (зеркало).
  remote('remote'),

  /// Протяжка страницы пальцем.
  swipe('swipe'),

  /// Горизонтальная прокрутка без жеста — колесо мыши, трекпад.
  scroll('scroll'),

  /// Кнопка «дальше» / «следеће питање».
  nextButton('next_button'),

  /// Кнопка «назад» / «претходно питање».
  backButton('back_button'),

  /// Клавиши ← / →.
  keyboard('keyboard'),

  /// Выбор вопроса по номеру: полоса прогресса, пагинация веба, навигатор.
  navigator('navigator'),

  /// Таблица отчёта симуляции («извештај»).
  report('report');

  const QuestionNavigation(this.key);

  /// Значение свойства в событии.
  final String key;
}

/// Куда относительно текущего вопроса ушёл прогон — свойство `direction`
/// события `question_viewed`. У первого показа направления нет.
enum QuestionDirection {
  forward('forward'),
  back('back');

  const QuestionDirection(this.key);

  final String key;

  /// Направление перехода с вопроса [from] на вопрос [to] (индексы в
  /// прогоне); `null`, если это один и тот же вопрос.
  static QuestionDirection? between(int from, int to) {
    if (to == from) return null;
    return to > from ? QuestionDirection.forward : QuestionDirection.back;
  }
}
