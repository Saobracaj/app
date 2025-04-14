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