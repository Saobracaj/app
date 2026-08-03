import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/public_comments/presentation/comment_composer.dart';

/// Экран-обёртка: поле ввода комментария плюс произвольная область рядом,
/// по которой имитируется «клик в любое место экрана».
Widget _harness({
  required Future<bool> Function(String) onSubmit,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          CommentComposer(hint: 'Написать комментарий', onSubmit: onSubmit),
          Container(
            key: const Key('outside'),
            color: const Color(0xFFEEEEEE),
            height: 200,
          ),
        ],
      ),
    ),
  );
}

bool _fieldHasFocus(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

void main() {
  group('Поле ввода комментария', () {
    testWidgets('фокус снимается при клике на любое место экрана',
        (tester) async {
      await tester.pumpWidget(_harness(onSubmit: (_) async => true));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(_fieldHasFocus(tester), isTrue);

      await tester.tap(find.byKey(const Key('outside')));
      await tester.pumpAndSettle();
      expect(_fieldHasFocus(tester), isFalse,
          reason: 'клик вне поля должен снимать фокус и прятать клавиатуру');
    });

    testWidgets('кнопка «Отправить» скрывается вместе со снятием фокуса',
        (tester) async {
      await tester.pumpWidget(_harness(onSubmit: (_) async => true));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.byKey(const Key('outside')));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('клик по кнопке «Отправить» не считается кликом «наружу»',
        (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(_harness(onSubmit: (text) async {
        submitted.add(text);
        return true;
      }));

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '  привет  ');
      await tester.pumpAndSettle();

      // Нажатие с кадром между down и up — так же, как на реальном устройстве:
      // если бы кнопка считалась «местом снаружи», перерисовка после снятия
      // фокуса успела бы убрать её из-под пальца.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(FilledButton)));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(submitted, ['привет'],
          reason: 'кнопка входит в TextFieldTapRegion, поэтому нажатие доходит '
              'до обработчика');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });
  });
}
