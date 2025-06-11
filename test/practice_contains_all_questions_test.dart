import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  test('Every qId from questions.json exists at least once in practice.json', () async {
    // Загружаем JSON-данные из assets
    final practiceJson = await rootBundle.loadString('assets/practice.json');
    final questionsJson = await rootBundle.loadString('assets/allQuestions.json');

    // Парсим practice.json как список списков чисел
    final List<dynamic> practiceData = jsonDecode(practiceJson);
    final Set<int> practiceIds = practiceData
        .expand((list) => List<int>.from(list))
        .toSet();

    // Парсим questions.json как список объектов с qId
    final List<dynamic> questionsData = jsonDecode(questionsJson);
    final Set<int> qIds = questionsData
        .map((e) => e['qId'] as int)
        .toSet();

    // Проверяем, что каждый qId встречается в practice.json
    for (final qId in qIds) {
      expect(practiceIds.contains(qId), true, reason: 'qId $qId not found in practice.json');
    }
  });
}
