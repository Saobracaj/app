import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/statistics/phantom_subcategory.dart';
import 'package:saobracaj/test/start_test.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';

void main() {
  test('фантомный блок: пусто или строка «null», настоящий id — нет', () {
    expect(isPhantomSubcategory(null), isTrue);
    expect(isPhantomSubcategory(''), isTrue);
    expect(isPhantomSubcategory('  '), isTrue);
    expect(isPhantomSubcategory('null'), isTrue);
    expect(isPhantomSubcategory('91'), isFalse);
    expect(isPhantomSubcategory('signs'), isFalse);
  });

  test('адрес прогона без блока не содержит subcategory', () {
    // Так открываются ошибки и списки: раньше сюда попадало `subcategory=null`,
    // и каждый такой прогон записывался как результат блока «null».
    const options = StartTestState(random: true, randomOptionsOrder: false);
    expect(
      quizRunPath(questionIds: [1, 2, 3], options: options),
      '/quest?q=1,2,3&randomOptionsOrder=false&random=true',
    );
    expect(
      quizRunPath(questionIds: [1], options: options, subcategory: 'null'),
      isNot(contains('subcategory')),
    );
    expect(
      quizRunPath(questionIds: [1], options: options, subcategory: ''),
      isNot(contains('subcategory')),
    );
  });

  test('адрес прогона блока несёт его id', () {
    const options = StartTestState(random: false, randomOptionsOrder: true);
    expect(
      quizRunPath(questionIds: [7, 8], options: options, subcategory: '91'),
      '/quest?q=7,8&randomOptionsOrder=true&random=false&subcategory=91',
    );
  });
}
