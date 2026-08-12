import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';

/// Тесты строительных блоков раскладки широких экранов: сетка «auto-fill»,
/// колонка контента и пара «основное + боковая карточка».

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ResponsiveGrid', () {
    testWidgets('колонок столько, сколько влезает по минимальной ширине', (
      tester,
    ) async {
      _setScreenSize(tester, const Size(1000, 800));
      await tester.pumpWidget(
        _app(
          ResponsiveGrid(
            minItemWidth: 232,
            children: [
              for (var i = 0; i < 8; i++) SizedBox(height: 40, key: ValueKey(i)),
            ],
          ),
        ),
      );

      // 1000 = 4 колонки по 232 (три зазора по 12), пятая уже не влезает.
      final first = tester.getSize(find.byKey(const ValueKey(0)));
      expect(first.width, closeTo((1000 - 12 * 3) / 4, 0.01));
      // Пятая плитка ушла на второй ряд — то есть ниже первой.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(4))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey(0))).dy),
      );
    });

    testWidgets('на узкой колонке остаётся одна колонка', (tester) async {
      _setScreenSize(tester, const Size(300, 800));
      await tester.pumpWidget(
        _app(
          ResponsiveGrid(
            minItemWidth: 340,
            children: const [SizedBox(height: 40), SizedBox(height: 40)],
          ),
        ),
      );

      expect(tester.getSize(find.byType(SizedBox).first).width, 300);
    });
  });

  group('WideContent', () {
    testWidgets('колонка контента не шире предела и центрирована', (
      tester,
    ) async {
      _setScreenSize(tester, const Size(1920, 900));
      await tester.pumpWidget(
        _app(
          const WideContent(
            padding: EdgeInsets.zero,
            child: SizedBox(height: 10, width: double.infinity),
          ),
        ),
      );

      final box = tester.getRect(find.byType(SizedBox));
      expect(box.width, kWidePageMaxWidth);
      expect(box.center.dx, 1920 / 2);
    });
  });

  group('MainWithSide', () {
    testWidgets('широкий экран: две колонки рядом', (tester) async {
      _setScreenSize(tester, const Size(1200, 800));
      await tester.pumpWidget(
        _app(
          const MainWithSide(
            main: SizedBox(key: ValueKey('main'), height: 40),
            side: SizedBox(key: ValueKey('side'), height: 40),
          ),
        ),
      );

      final main = tester.getRect(find.byKey(const ValueKey('main')));
      final side = tester.getRect(find.byKey(const ValueKey('side')));
      expect(side.left, greaterThan(main.right - 1));
      expect(side.width, 300);
    });

    testWidgets('узкий экран: колонки складываются', (tester) async {
      _setScreenSize(tester, const Size(500, 800));
      await tester.pumpWidget(
        _app(
          const MainWithSide(
            main: SizedBox(key: ValueKey('main'), height: 40),
            side: SizedBox(key: ValueKey('side'), height: 40),
          ),
        ),
      );

      final main = tester.getRect(find.byKey(const ValueKey('main')));
      final side = tester.getRect(find.byKey(const ValueKey('side')));
      expect(side.top, greaterThan(main.bottom - 1));
    });
  });
}
