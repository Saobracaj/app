import 'dart:convert';

import 'package:drift/drift.dart';

class AnswerRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isWrong => boolean()();
}

class SubCategoryRecords extends Table {
  TextColumn get subcategory => text()();
  IntColumn get rightAnswers => integer()();
  IntColumn get allAnswers => integer()();
}

class PracticeRecords extends Table {
  IntColumn get points => integer()();
  DateTimeColumn get time => dateTime()();
  IntColumn get mistakes => integer()();
  IntColumn get durationSeconds => integer()();
  TextColumn get wrongAnswers => text().map(const IntListConverter()).nullable()();
}

class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) {
    final list = jsonDecode(fromDb) as List<dynamic>;
    return list.cast<int>();
  }

  @override
  String toSql(List<int> value) {
    return jsonEncode(value);
  }
}
