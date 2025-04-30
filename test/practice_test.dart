import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  test('All numbers from practice.json exist as qId in questions.json', () async {
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

    // Проверяем наличие каждого id
    for (final id in practiceIds) {
      expect(qIds.contains(id), true, reason: 'Missing qId $id in questions.json');
    }
  });
}
