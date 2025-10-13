import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/models/models.dart';
import 'package:collection/collection.dart';

void main() {
  test('test', () async {
    final file = File('assets/allQuestions.json');
    final s = await file.readAsString();
    final questionsJson = jsonDecode(s) as List;
    final questions = questionsJson.map((e) => Translation.fromJson(e)).map((e) => e.copyWith(id: e.imageId)).toList();

    final trFile = File('assets/allQuestions_ru.json');
    final trS = await trFile.readAsString();
    final translationsJson = jsonDecode(trS) as List;
    final translations =
        translationsJson
            .where((element) => element['qId'] != null)
            .where((element) => (element['Choices'] as List).length == questions.firstWhereOrNull((e) => e.id == element['qId'])?.choices.length)
            .map((e) => Translation.fromJson(e))
            .map((e) => e.copyWith(id: e.imageId))
            .toList();

    // Сохраняем переводы в новый файл
    /*var json = jsonEncode(translations.map((e) => e.toJson()).toList());
    final newFile = File('assets/allQuestions_ru_updated.json');
    await newFile.create();
    await newFile.writeAsString(json);*/

    final originalIds = questions.map((q) => q.id).toSet();
    final translatedIds = translations.map((q) => q.id).toSet();

    final missingIds = originalIds.difference(translatedIds);

    if (missingIds.isEmpty) {
      debugPrint('Все вопросы переведены.');
    } else {
      debugPrint('Отсутствуют ${missingIds.length} переводов');
      var arr = questions.where((element) => missingIds.contains(element.id));
      var json = jsonEncode(arr.take(100).map((e) => e.toJson()).toList());
      final newFile = File('missing.json');
      await newFile.create();
      await newFile.writeAsString(json);

      debugPrint('Первые 100 отсутствующих переводов сохранены в missing.json');
    }
    expect(missingIds.length, 0, reason: 'Отсутствуют ${missingIds.length} переводов');
  });
}
