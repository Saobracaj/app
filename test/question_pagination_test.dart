import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/test/quest/presentation/question_pagination.dart';

/// Раскладка нижней пагинации веб-версии (задача 1217510064568188): пока
/// номера влезают в строку — видны все, дальше строка сворачивается вокруг
/// текущего вопроса, но никогда не вырастает шире отведённых мест.

/// Строка в виде «1 … 5 6 7 … 41» — так её проще и читать, и сравнивать.
String _render(List<PaginationSlot> slots) =>
    slots.map((s) => s.index != null ? '${s.index! + 1}' : '…').join(' ');

void main() {
  test('короткий прогон показывает все номера', () {
    expect(
      _render(paginationSlots(count: 8, current: 2, slots: 12)),
      '1 2 3 4 5 6 7 8',
    );
  });

  test('ровно по размеру строки — тоже все', () {
    expect(
      _render(paginationSlots(count: 7, current: 0, slots: 7)).split(' '),
      hasLength(7),
    );
  });

  test('начало длинного прогона: окно прижато влево', () {
    expect(
      _render(paginationSlots(count: 41, current: 0, slots: 7)),
      '1 2 3 4 … 41',
    );
  });

  test('середина: текущий вопрос внутри окна, многоточия с обеих сторон', () {
    expect(
      _render(paginationSlots(count: 41, current: 19, slots: 7)),
      '1 … 19 20 21 … 41',
    );
  });

  test('конец: окно прижато вправо', () {
    expect(
      _render(paginationSlots(count: 41, current: 40, slots: 7)),
      '1 … 38 39 40 41',
    );
  });

  test('строка никогда не длиннее отведённых мест', () {
    for (final slots in [5, 6, 7, 9, 12]) {
      for (final count in [2, 5, 6, 15, 41, 145]) {
        for (final current in [0, 1, count ~/ 2, count - 2, count - 1]) {
          if (current < 0) continue;
          final row = paginationSlots(
            count: count,
            current: current,
            slots: slots,
          );
          expect(
            row.length,
            lessThanOrEqualTo(count < slots ? count : slots),
            reason: 'count=$count current=$current slots=$slots',
          );
          // Индексы идут строго по возрастанию и не выходят за границы.
          final indexes = row.map((s) => s.index).whereType<int>().toList();
          expect(indexes.first, 0);
          expect(indexes.last, count - 1);
          for (var i = 1; i < indexes.length; i++) {
            expect(indexes[i], greaterThan(indexes[i - 1]));
          }
          // Многоточие всегда ведёт к существующему вопросу.
          for (final jump in row.map((s) => s.jumpTo).whereType<int>()) {
            expect(jump, inInclusiveRange(0, count - 1));
          }
        }
      }
    }
  });

  test('текущий вопрос всегда виден в строке', () {
    for (final count in [15, 41, 145]) {
      for (var current = 0; current < count; current++) {
        final shown = paginationSlots(
          count: count,
          current: current,
          slots: 7,
        ).map((s) => s.index).whereType<int>();
        expect(shown, contains(current), reason: 'count=$count cur=$current');
      }
    }
  });
}
