import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/presentation/dismiss_focus.dart';

/// Экран-макет: поле ввода сверху, кнопка и пустое место под ним — так же
/// устроен экран поиска вопросов (поле + список/пустота под ним).
///
/// Пустое место жмём через [WidgetTester.tapAt]: пустой [SizedBox] сам по себе
/// не участвует в hit-test, и нажатие в этой точке достаётся ровно тому, что
/// проверяется, — обёртке [DismissFocusOnTap].
Widget _screen({required VoidCallback onButtonPressed}) {
  return MaterialApp(
    home: Scaffold(
      body: DismissFocusOnTap(
        child: Column(
          children: [
            const TextField(key: Key('field')),
            ElevatedButton(
              onPressed: onButtonPressed,
              child: const Text('Кнопка'),
            ),
            const Expanded(child: SizedBox.expand(key: Key('empty'))),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('нажатие на свободное место снимает фокус с поля ввода', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(onButtonPressed: () {}));

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(
      tester.testTextInput.isVisible,
      isTrue,
      reason: 'клавиатура открылась по нажатию на поле',
    );

    await tester.tapAt(tester.getCenter(find.byKey(const Key('empty'))));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus is FocusScopeNode, isTrue);
    expect(
      tester.testTextInput.isVisible,
      isFalse,
      reason: 'клавиатура закрылась вместе с фокусом',
    );
  });

  testWidgets(
    'нажатия на элементы с собственным обработчиком проходят насквозь',
    (tester) async {
      var pressed = 0;
      await tester.pumpWidget(_screen(onButtonPressed: () => pressed++));

      await tester.tap(find.text('Кнопка'));
      await tester.pump();
      expect(pressed, 1);

      // Само поле по-прежнему фокусируется — обёртка не перехватывает нажатие.
      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets(
    'нажатие по пустому месту без фокуса не двигает фокус выше по дереву',
    (tester) async {
      await tester.pumpWidget(_screen(onButtonPressed: () {}));
      final before = FocusManager.instance.primaryFocus;

      await tester.tapAt(tester.getCenter(find.byKey(const Key('empty'))));
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(before));
    },
  );
}
