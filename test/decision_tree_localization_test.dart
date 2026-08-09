import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/animations/decision_tree_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Названия категорий транспорта: остаются сербскими на всех языках,
/// поэтому в файлы переводов попадать не должны.
const _serbianTerms = ['трицикл', 'четвороцикл', 'возило'];

Map<String, dynamic> _translations(String langCode) {
  final raw = File('assets/translations/$langCode.json').readAsStringSync();
  return json.decode(raw) as Map<String, dynamic>;
}

Map<String, dynamic> _decisionTree(String langCode) =>
    _translations(langCode)['decisionTree'] as Map<String, dynamic>;

/// Дерево категорий, отрисованное в указанной локали.
Widget _tree(Locale locale) => EasyLocalization(
      // Ключ по локали: без него повторный pumpWidget переиспользует прежний
      // State и startLocale не применяется.
      key: ValueKey(locale),
      useOnlyLangCode: true,
      ignorePluralRules: false,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: locale,
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ThemedCompactDecisionTree(),
            ),
          ),
        ),
      ),
    );

/// Painter дерева из уже отрисованного виджета.
CustomPainter _painterOf(WidgetTester tester) {
  final paint = tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(ThemedCompactDecisionTree),
      matching: find.byType(CustomPaint),
    ),
  ).firstWhere((it) => it.painter != null);
  return paint.painter!;
}

Future<CustomPainter> _pumpTree(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(_tree(locale));
  await tester.pumpAndSettle();
  return _painterOf(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('Переводы дерева категорий', () {
    test('во всех языках одинаковый набор ключей и нет пустых строк', () {
      final ru = _decisionTree('ru');
      expect(ru, isNotEmpty);

      for (final lang in ['en', 'sr']) {
        final other = _decisionTree(lang);
        expect(
          other.keys.toSet(),
          ru.keys.toSet(),
          reason: 'набор ключей в $lang.json разошёлся с ru.json',
        );
        for (final entry in other.entries) {
          expect(
            (entry.value as String).trim(),
            isNotEmpty,
            reason: 'пустой перевод decisionTree.${entry.key} в $lang.json',
          );
        }
      }
    });

    test('текст отличается от русского в en и sr', () {
      final ru = _decisionTree('ru');
      // «да» в сербском совпадает с русским — это нормально, сравниваем блок целиком.
      for (final lang in ['en', 'sr']) {
        expect(
          _decisionTree(lang),
          isNot(equals(ru)),
          reason: '$lang.json дословно повторяет ru.json',
        );
      }
    });

    test('названия категорий транспорта не переводятся', () {
      for (final lang in ['ru', 'en', 'sr']) {
        final block = json.encode(_decisionTree(lang));
        for (final term in _serbianTerms) {
          expect(
            block,
            isNot(contains(term)),
            reason: 'термин «$term» попал в переводы ($lang.json) — '
                'он должен оставаться захардкоженным в виджете',
          );
        }
      }
    });
  });

  group('Переводы влезают в фигуры дерева', () {
    // В тестах по умолчанию стоит шрифт-заглушка с квадратными глифами, на нём
    // мерить нечего — подгружаем настоящий Inter из ассетов приложения.
    setUpAll(() async {
      final data = File('assets/fonts/Inter-400.ttf').readAsBytesSync();
      await (FontLoader('Inter')
            ..addFont(Future.value(ByteData.sublistView(data))))
          .load();
    });

    // Размеры фигур продублированы из _ThemedTreePainter: ключ перевода →
    // (ширина фигуры, высота фигуры, кегль, доля ширины под текст).
    const slots = <String, List<double>>{
      'fuelNote': [380, 45, 14, 1],
      'wheelsQuestion': [140, 40, 14, 1],
      'lightLimits': [140, 80, 14, 1],
      'withinLightLimits': [130, 110, 11, 0.75],
      'withinLightLimitsAndMass': [130, 100, 11, 0.75],
      'powerLimit': [90, 90, 13, 0.75],
      'yes': [40, 20, 13, 1],
      'no': [40, 20, 13, 1],
    };

    for (final lang in ['ru', 'en', 'sr']) {
      test('в $lang.json ничего не выходит за границы', () {
        final block = _decisionTree(lang);
        for (final slot in slots.entries) {
          final box = slot.value;
          final maxWidth =
              box[3] == 1 ? box[0] - 8 : box[0] * box[3];
          final painter = TextPainter(
            text: TextSpan(
              text: block[slot.key] as String,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: box[2],
                height: 1.15,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxWidth);

          expect(
            painter.height,
            lessThanOrEqualTo(box[1]),
            reason: 'decisionTree.${slot.key} ($lang) не влезает по высоте',
          );
          expect(
            painter.didExceedMaxLines,
            isFalse,
            reason: 'decisionTree.${slot.key} ($lang) обрезается',
          );
        }

        // Нижний блок — сербский термин плюс переведённое пояснение.
        final auto = TextPainter(
          text: TextSpan(
            text: 'путничко\nвозило\n${block['seatsNote']}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.15,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 82);
        expect(
          auto.height,
          lessThanOrEqualTo(55),
          reason: 'decisionTree.seatsNote ($lang) не влезает по высоте',
        );
      });
    }
  });

  group('ThemedCompactDecisionTree', () {
    testWidgets('рисуется в каждой поддерживаемой локали', (tester) async {
      for (final lang in ['ru', 'en', 'sr']) {
        await _pumpTree(tester, Locale(lang));
        expect(find.byType(ThemedCompactDecisionTree), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('при смене языка перерисовывается', (tester) async {
      final ru = await _pumpTree(tester, const Locale('ru'));
      final en = await _pumpTree(tester, const Locale('en'));

      expect(
        en.shouldRepaint(ru),
        isTrue,
        reason: 'подписи закэшированы в Painter — дерево осталось бы на '
            'старом языке',
      );
    });
  });
}
