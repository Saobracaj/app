import 'package:freezed_annotation/freezed_annotation.dart';

part 'paused_simulation.freezed.dart';
part 'paused_simulation.g.dart';

/// Снимок идущей симуляции экзамена — всё, что нужно, чтобы продолжить её с
/// того же места: набор вопросов, порядок вариантов, данные ответы, текущий
/// вопрос, отметки и сколько времени уже израсходовано.
///
/// Снимок пишется в shared preferences ([PausedSimulationRepository]) после
/// каждого действия пользователя и при паузе, а стирается по завершении
/// симуляции (или когда пользователь сам её бросает). Снимок с
/// `pausedAt == null` означает, что приложение убили посреди симуляции — при
/// следующем запуске он трактуется как поставленный на паузу.
///
/// Варианты ответов внутри вопроса тасуются на старте, поэтому и порядок, и
/// ответы хранятся индексами в *исходный* список вариантов вопроса из банка:
/// текст вариантов в снимке не нужен, а банк с приложением одинаковый.
@freezed
sealed class PausedSimulation with _$PausedSimulation {
  const factory PausedSimulation({
    /// Когда симуляция была начата (показывается в баннере).
    required DateTime startedAt,

    /// Сколько секунд экзамена уже прошло к моменту снимка (паузы в это
    /// время не входят).
    required int elapsedSeconds,

    /// Момент записи снимка.
    required DateTime savedAt,

    /// Момент постановки на паузу; `null`, если снимок записан на ходу.
    DateTime? pausedAt,

    /// Идентификаторы вопросов варианта в порядке показа.
    required List<int> questions,
    @Default(0) int currentQuestionIndex,

    /// Порядок показа вариантов: id вопроса → индексы в исходном списке.
    @Default({}) Map<int, List<int>> choiceOrder,

    /// Данные ответы: id вопроса → индексы выбранных вариантов в исходном
    /// списке.
    @Default({}) Map<int, List<int>> answers,

    /// Индексы (в [questions]) отмеченных вопросов.
    @Default([]) List<int> markedQuestions,

    // Настройки запуска — чтобы продолжить с теми же опциями.
    @Default(false) bool showRightAnswers,
    @Default(false) bool showStats,
    @Default(false) bool buttonsLikeInExam,
  }) = _PausedSimulation;

  factory PausedSimulation.fromJson(Map<String, dynamic> json) =>
      _$PausedSimulationFromJson(json);
}
