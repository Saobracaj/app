import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final practiceFile = File('assets/practice.json');
  final questionsFile = File('assets/allQuestions.json');

  // Чтение и парсинг файлов
  final practiceJson = await practiceFile.readAsString();
  final questionsJson = await questionsFile.readAsString();



  final List<dynamic> practiceData = jsonDecode(practiceJson);
  final Set<int> practiceIds = practiceData
      .expand((list) => List<int>.from(list))
      .toSet();

  print('Practices number: ${practiceData.length}');

  final List<dynamic> questionsData = jsonDecode(questionsJson);

  // Оставляем только вопросы, у которых categoryId != "38"
  final filteredQuestions = questionsData.where((e) => e['categoryId'] != "38");

  // Список qId из отфильтрованных вопросов
  final List<int> filteredQIds = filteredQuestions
      .map((e) => e['qId'] as int)
      .toList();

  // Нахождение отсутствующих в практике вопросов
  final missingQIds = filteredQIds
      .where((qId) => !practiceIds.contains(qId))
      .toList();

  if (missingQIds.isEmpty) {
    print('✅ Все вопросы из practice.json охватывают нужные qId из allQuestions.json (без categoryId=38)');
  } else {
    print('❌ Найдены вопросы (кроме categoryId=38), не представленные в практике:\n');
    for (final id in missingQIds) {
      print('https://saobracaj.gleb.at/?qid=$id');
    }
    print('\nВсего пропущено: ${missingQIds.length}');
  }
}
