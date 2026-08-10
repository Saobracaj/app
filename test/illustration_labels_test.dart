import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подписи иллюстраций `oznaka-pneumatika` и `oznake-sporo-dugo-tesko`.
///
/// Проверяем ровно то, что ломается незаметно: разъехавшийся набор ключей
/// между языками, сербский термин, случайно уехавший в переводы, и подпись,
/// которая на каком-то языке перестала влезать в отведённое место (в
/// приложении она просто наедет на соседнюю).

Map<String, dynamic> _block(String langCode, String block) {
  final raw = File('assets/translations/$langCode.json').readAsStringSync();
  return (json.decode(raw) as Map<String, dynamic>)[block]
      as Map<String, dynamic>;
}

/// Высота подписи при тех же настройках, с какими её рисует painter.
double _height(String text, {required double maxWidth, required double size}) {
  return (TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'Inter', fontSize: size, height: 1.2),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth))
      .height;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // В тестах по умолчанию стоит шрифт-заглушка с квадратными глифами, на нём
  // мерить нечего — подгружаем настоящий Inter из ассетов приложения.
  setUpAll(() async {
    final regular = File('assets/fonts/Inter-400.ttf').readAsBytesSync();
    await (FontLoader('Inter')
          ..addFont(Future.value(ByteData.sublistView(regular))))
        .load();
  });

  for (final block in ['tireMarking', 'vehiclePlates']) {
    group('Переводы блока $block', () {
      test('во всех языках одинаковый набор ключей и нет пустых строк', () {
        final ru = _block('ru', block);
        expect(ru, isNotEmpty);

        for (final lang in ['en', 'sr']) {
          final other = _block(lang, block);
          expect(
            other.keys.toSet(),
            ru.keys.toSet(),
            reason: 'набор ключей $block в $lang.json разошёлся с ru.json',
          );
          for (final entry in other.entries) {
            expect(
              (entry.value as String).trim(),
              isNotEmpty,
              reason: 'пустой перевод $block.${entry.key} в $lang.json',
            );
          }
        }
      });

      test('текст отличается от русского в en и sr', () {
        for (final lang in ['en', 'sr']) {
          expect(
            _block(lang, block),
            isNot(equals(_block('ru', block))),
            reason: '$block в $lang.json дословно повторяет ru.json',
          );
        }
      });
    });
  }

  test('сербские термины иллюстраций не уезжают в переводы', () {
    // Эти строки захардкожены в виджетах: термин из правил не переводится,
    // а переводимая подпись стоит рядом и поясняет его.
    const terms = [
      'спора возила',
      'дуга возила',
      'тешка возила',
      'брзинска ознака',
      'ознака носивости',
      'радијална конструкција',
      'зимски пнеуматик',
      'индикатор истрошености',
    ];
    for (final lang in ['ru', 'en', 'sr']) {
      for (final block in ['tireMarking', 'vehiclePlates']) {
        final text = json.encode(_block(lang, block));
        for (final term in terms) {
          expect(
            text,
            isNot(contains(term)),
            reason: 'термин «$term» попал в $block ($lang.json) — '
                'он должен оставаться захардкоженным в виджете',
          );
        }
      }
    }
  });

  group('Подписи влезают в отведённое место', () {
    // Размеры продублированы из painter'ов: ключ → (ширина, кегль, предел
    // высоты). Строка расшифровки шины идёт в одну строку под сербским
    // термином, подпись таблички — максимум в две.
    const legendHints = ['width', 'profile', 'radial', 'rim', 'load', 'speed'];
    const cardHints = ['winter', 'wear'];

    for (final lang in ['ru', 'en', 'sr']) {
      test('в $lang.json ничего не наезжает', () {
        final tire = _block(lang, 'tireMarking');
        for (final key in legendHints) {
          expect(
            _height(tire[key] as String, maxWidth: 316, size: 11.5),
            lessThanOrEqualTo(18),
            reason: 'tireMarking.$key ($lang) не влезает в строку расшифровки',
          );
        }
        for (final key in cardHints) {
          expect(
            _height(tire[key] as String, maxWidth: 170, size: 11.5),
            lessThanOrEqualTo(18),
            reason: 'tireMarking.$key ($lang) не влезает в плашку M+S/TWI',
          );
        }

        final plates = _block(lang, 'vehiclePlates');
        for (final entry in plates.entries) {
          expect(
            _height(entry.value as String, maxWidth: 124, size: 12),
            lessThanOrEqualTo(34),
            reason: 'vehiclePlates.${entry.key} ($lang) не влезает под '
                'табличку (больше двух строк)',
          );
        }
      });
    }
  });
}
