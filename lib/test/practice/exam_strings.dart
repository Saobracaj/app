/// The wording of the exam simulation.
///
/// **Deliberately not localized.** The theory exam is sat in Serbian, so the
/// simulation reproduces the examiner's own wording verbatim in every app
/// locale — a candidate who trains against "Следеће питање" is not surprised by
/// it on the day. These strings therefore live here as constants instead of in
/// `assets/translations/*.json`, in the same spirit as [ExamPalette].
///
/// Scope: the exam *run* — the question screen, its buttons, the in-exam report
/// table and the confirmation dialogs. The options screen that precedes it and
/// the results screen that follows it are ordinary app UI and stay translated
/// via `LocaleKeys.simulation_*`.
abstract final class ExamStrings {
  // Header.
  static String questionCounter(int current, int total) =>
      'Питање: $current / $total';
  static String points(int points) => 'Број поена: $points';
  static const String markQuestion = 'Обележите питање';

  // Question body.
  static String requiredAnswers(int count) => 'Број потребних одговора: $count';

  // Actions.
  static const String previousQuestion = 'Претходно питање';
  static const String nextQuestion = 'Следеће питање';
  static const String endExam = 'Крај испита';
  static const String report = 'Извештај';
  static const String showAnswer = 'Прикажи одговор';
  static const String back = 'Назад';

  // Validation.
  static const String wrongAnswerCount =
      'Нисте означили потребан број одговора';

  // "Really finish?" dialog.
  static const String finishTitle =
      'Да ли сигурно желите завршити теоријски испит?';
  static const String finishBody =
      'Након потврде више нећете моћи унети било коју измену у дате одговоре.';
  static const String finishCancel = 'Одустаните';
  static const String finishConfirm = 'Да';

  // Report table.
  static String reportRow(int index) => 'Питање $index';
  static const String reportColumnQuestion = 'Питање';
  static const String reportColumnPoints = 'Број поена';
  static const String reportColumnAnswered = 'Одговорено';
  static const String reportColumnMarked = 'Обележено';

  // Start confirmation on the options screen — the only pre-exam string kept in
  // Serbian, because it is the button the real software shows to begin.
  static const String confirmStart = 'Потврдите почетак симулације испита';
}
