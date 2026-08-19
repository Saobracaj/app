import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/question_lists/domain/list_style.dart';
import 'package:saobracaj/question_lists/models/question_list.dart';
import 'package:saobracaj/question_lists/presentation/question_lists_section.dart';

/// Отношение контраста двух цветов по WCAG: (L1 + 0.05) / (L2 + 0.05).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Рисует аватарку списка в теме нужной яркости и возвращает фактические цвета
/// кружка и глифа внутри него.
Future<({Color background, Color foreground})> _avatarColors(
  WidgetTester tester,
  QuestionList list,
  Brightness brightness,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2962FF),
          brightness: brightness,
        ),
      ),
      home: Scaffold(body: Center(child: QuestionListAvatar(list: list))),
    ),
  );
  // MaterialApp прогоняет тему через AnimatedTheme: без этого цвета читались бы
  // с промежуточного кадра анимации.
  await tester.pumpAndSettle();
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(QuestionListAvatar),
      matching: find.byType(Container),
    ),
  );
  final icon = tester.widget<Icon>(
    find.descendant(
      of: find.byType(QuestionListAvatar),
      matching: find.byType(Icon),
    ),
  );
  return (
    background: (container.decoration! as BoxDecoration).color!,
    foreground: icon.color!,
  );
}

const _autoListIds = [
  kRecentMistakesListId,
  kLastExamMistakesListId,
  kChronicMistakesListId,
  kPersonalWeakSpotsListId,
];

void main() {
  group('QuestionListAvatar', () {
    for (final brightness in Brightness.values) {
      for (final id in _autoListIds) {
        testWidgets('глиф автосписка $id читается в теме $brightness', (
          tester,
        ) async {
          final colors = await _avatarColors(
            tester,
            QuestionList(id: id, isAuto: true),
            brightness,
          );

          // 4.5:1 — минимум WCAG AA для мелкой графики. Раньше глиф был жёстко
          // белым, и в тёмной теме на светлых пастельных ролях схемы он почти
          // сливался с кружком.
          expect(
            _contrast(colors.foreground, colors.background),
            greaterThanOrEqualTo(4.5),
            reason: 'фон ${colors.background}, глиф ${colors.foreground}',
          );
        });
      }
    }
  });

  group('onListColor', () {
    for (final color in kListColors) {
      test('даёт читаемую галочку на цвете $color', () {
        final chosen = _contrast(onListColor(color), color);

        // 3:1 — минимум WCAG для нетекстовой графики; средние по светлоте
        // цвета палитры выше и не поднять, поэтому заодно проверяем, что из
        // двух чернил выбраны лучшие (белая галочка на жёлтом не читалась).
        expect(chosen, greaterThanOrEqualTo(3.0));
        expect(
          chosen,
          greaterThanOrEqualTo(_contrast(Colors.white, color)),
        );
        expect(
          chosen,
          greaterThanOrEqualTo(_contrast(Colors.black87, color)),
        );
      });
    }
  });
}
