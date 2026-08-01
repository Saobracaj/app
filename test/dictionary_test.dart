import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/dictionary/dictionary.dart';

void main() {
  group('Подсветка терминов закона (dictionary)', () {
    test('стандартный термин подсвечивается ссылкой на dict', () {
      final res = 'Возач управља возилом'.dict;
      expect(res, contains('(dict/'));
    });

    test('новый термин: мања материјална штета подсвечивается', () {
      final res = 'Учесници попуњавају образац код мања материјална штета'.dict;
      expect(res, contains(Uri.encodeComponent('мања материјална штета')));
    });

    test('добавленный падеж: standalone "заустављања" подсвечивается', () {
      final res = 'Забрана заустављања и паркирања'.dict;
      // слово "заустављања" теперь должно превратиться в ссылку
      expect(res, contains('заустављања](dict/'));
    });

    test('исправлен баг: "насеље" ведёт на определение Насеље, а не на переезд', () {
      final res = 'Возило се креће кроз насеље'.dict;
      final title = Uri.encodeComponent('Насеље');
      expect(res, contains('насеље](dict/$title)'));

      final entry = getDictByTitle('Насеље');
      expect(entry, isNotNull);
      expect(entry!['sr'] as String, contains('_насеље_'));
    });

    test('исправлен баг: "мотоцикл" ведёт на определение Мотоцикл, а не на лаки трицикл', () {
      final entry = getDictByTitle('Мотоцикл');
      expect(entry, isNotNull);
      expect(entry!['sr'] as String, contains('_мотоцикл_'));
    });

    test('добавлены определения из главы 7: 105 и 106', () {
      expect(getDictByTitle('аутономно возило'), isNotNull);
      expect(getDictByTitle('тестирање аутономног возила'), isNotNull);
    });
  });
}
