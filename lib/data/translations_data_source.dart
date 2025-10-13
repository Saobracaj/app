import 'dart:convert';
import 'package:collection/collection.dart';

import 'package:flutter/services.dart';
import 'package:saobracaj/models/models.dart';

final translationsDataSource = TranslationsDataSource();

class TranslationsDataSource {
  List<Translation>? _translations;

  TranslationsDataSource() {
    _init();
  }

  Future<void> _init() async {
    final translationsString = await rootBundle.loadString('assets/allQuestions_ru.json');

    final translationsJson = jsonDecode(translationsString) as List;
    _translations = translationsJson.map((e) => Translation.fromJson(e)).map((e) => e.copyWith(id: e.imageId)).toList();
  }

  Translation? getByQuestionId(int questionId) {
    return _translations?.firstWhereOrNull((element) => element.id == questionId);
  }

  Future<List<Translation>> get translations async {
    final translationsString = await rootBundle.loadString('assets/allQuestions_ru.json');

    final translationsJson = jsonDecode(translationsString) as List;
    _translations = translationsJson.map((e) => Translation.fromJson(e)).map((e) => e.copyWith(id: e.imageId)).toList();
    return _translations!;
  }
}
