import 'package:drift/drift.dart';

class AnswerRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isWrong => boolean()();
}
