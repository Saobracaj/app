import 'dart:convert';
import 'package:collection/collection.dart';

import 'package:flutter/services.dart';
import 'package:saobracaj/models/models.dart';

final dictianoryDataSource = DictianoryDataSource();

class DictianoryDataSource {

  Future<String> loadDictianory(String ref) async {
    final translationsString = await rootBundle.loadString('assets/dict/$ref');
    return translationsString;
  }
}
