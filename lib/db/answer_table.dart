import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

/// A stable, globally-unique id for a statistics record, generated on the device
/// when the row is first created. It is the identity used to deduplicate records
/// when syncing with the back-end (see `StatisticsSyncService`), so it must never
/// change once assigned. 16 random bytes rendered as hex.
String genRecordId() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class AnswerRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isWrong => boolean()();

  /// Sync identity (see [genRecordId]). Nullable so it can be added by a
  /// migration; always populated on insert via `clientDefault`.
  TextColumn get uuid => text().nullable().clientDefault(genRecordId)();
}

class SubCategoryRecords extends Table {
  TextColumn get subcategory => text()();
  IntColumn get rightAnswers => integer()();
  IntColumn get allAnswers => integer()();

  TextColumn get uuid => text().nullable().clientDefault(genRecordId)();
}

class PracticeRecords extends Table {
  IntColumn get points => integer()();
  DateTimeColumn get time => dateTime()();
  IntColumn get mistakes => integer()();
  IntColumn get durationSeconds => integer()();
  TextColumn get wrongAnswers => text().map(const IntListConverter()).nullable()();

  TextColumn get uuid => text().nullable().clientDefault(genRecordId)();
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
