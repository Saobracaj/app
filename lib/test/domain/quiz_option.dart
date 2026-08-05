/// The boolean options the user picks before starting a run — on the
/// "start a category" screen ([QuizOption.shuffleQuestions],
/// [QuizOption.shuffleAnswerOptions]) and on the exam-simulation setup screen
/// (the `practice*` entries).
///
/// Each option carries the shared-preferences key it is stored under and the
/// value used until the user touches it. Keys are persisted verbatim — renaming
/// one silently resets that option for every existing install.
enum QuizOption {
  shuffleQuestions('quiz.shuffle_questions', true),
  shuffleAnswerOptions('quiz.shuffle_answer_options', true),
  practiceShowRightAnswers('practice.show_right_answers', false),
  practiceShowStats('practice.show_stats', false),
  practiceButtonsLikeInExam('practice.buttons_like_in_exam', false);

  const QuizOption(this.storageKey, this.defaultValue);

  /// The shared-preferences key holding this option.
  final String storageKey;

  /// What the option is set to before the user ever changes it.
  final bool defaultValue;
}
