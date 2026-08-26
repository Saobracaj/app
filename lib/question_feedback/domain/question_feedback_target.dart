import '../../core/deep_links.dart';

/// На что именно жалуется пользователь: на вопрос (кнопка на вкладках экрана
/// вопроса) или на конспект категории (кнопка на экране `/konspekt`).
///
/// Из цели складывается ссылка в тексте жалобы и, для вопроса, явный
/// `questionIds` сообщения — бэкенд превращает их во вложение «вопрос N».
class QuestionFeedbackTarget {
  const QuestionFeedbackTarget.question(int this.questionId)
    : categoryId = null;

  const QuestionFeedbackTarget.konspekt(String this.categoryId)
    : questionId = null;

  final int? questionId;
  final String? categoryId;

  /// Ссылка на предмет жалобы — вопрос или конспект категории.
  Uri get link => questionId != null
      ? appLink('/question/$questionId')
      : appLink('/konspekt', {'category': categoryId});

  /// Вопросы, прикладываемые к сообщению явно (у конспекта их нет).
  List<int> get questionIds =>
      questionId != null ? [questionId!] : const <int>[];
}
