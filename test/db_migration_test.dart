import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/db/db.dart';

void main() {
  test('миграция v7 удаляет результаты фантомного блока «null»', () async {
    // База, как её оставила сборка со схемой v6: прогоны ошибок записаны как
    // результат блока «null» (адрес прогона подставлял `subcategory=null`).
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE sub_category_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subcategory TEXT NOT NULL,
              right_answers INTEGER NOT NULL,
              all_answers INTEGER NOT NULL,
              occurred_at INTEGER,
              uuid TEXT
            )''');
          raw.execute('''
            INSERT INTO sub_category_records
              (subcategory, right_answers, all_answers, uuid)
            VALUES ('null', 7, 7, 'phantom'),
                   ('', 3, 3, 'phantom-empty'),
                   ('91', 18, 20, 'real')''');
          raw.execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(db.close);

    final records = await db.getAllSubcategoryRecords();

    expect(records.map((r) => r.uuid), ['real']);
    expect(records.single.subcategory, '91');
  });
}
