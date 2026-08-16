// ignore_for_file: avoid_print
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

  // Банк содержит только то, что экзамен категории B вообще вытягивает:
  // категория 38 («последице непоштовања прописа», тест C и D) удалена, так
  // что фильтровать больше нечего.
  final List<int> qIds = questionsData.map((e) => e['qId'] as int).toList();

  // Нахождение отсутствующих в практике вопросов
  final missingQIds = qIds
      .where((qId) => !practiceIds.contains(qId))
      .toList();

  if (missingQIds.isEmpty) {
    print('✅ Все вопросы из allQuestions.json встречаются в practice.json');
  } else {
    print('❌ Найдены вопросы, не представленные в практике:\n');
    for (final id in missingQIds) {
      print('https://saobracaj.gleb.at/?qid=$id');
    }
    print('\nВсего пропущено: ${missingQIds.length}');
  }
}
