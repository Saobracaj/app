
import 'package:flutter/services.dart';

final dictianoryDataSource = DictianoryDataSource();

class DictianoryDataSource {

  Future<String> loadDictianory(String ref) async {
    final translationsString = await rootBundle.loadString('assets/dict/$ref');
    return translationsString;
  }
}
