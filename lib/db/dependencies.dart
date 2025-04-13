import 'answer_repository.dart';
import 'db.dart';

final db = AppDatabase();
final repository = AnswerRepository(db);
/*
// Добавить ответ
await repository.addAnswer(42, true);

// Получить все ответы по questionId = 42
final answers = await repository.getAnswersByQuestionId(42);

// Получить все вопросы с ошибками
final wrongQuestions = await repository.getQuestionsWithErrors();*/
