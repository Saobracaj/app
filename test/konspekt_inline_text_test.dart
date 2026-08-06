import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_inline_text.dart';

/// Заголовки секций конспекта написаны с той же разметкой, что и тело
/// (`*Коловоз*`, `**важно**`), поэтому выводить их обычным [Text] нельзя —
/// пользователь видел звёздочки вместо выделения.
void main() {
  const titleStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

  Future<InlineSpan> pumpTitle(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KonspektInlineText(text: text, style: titleStyle),
        ),
      ),
    );
    return tester.widget<RichText>(find.byType(RichText).first).text;
  }

  /// Все стили, применённые к кускам заголовка, сверху вниз.
  List<TextStyle> stylesOf(InlineSpan span) {
    final styles = <TextStyle>[];
    span.visitChildren((child) {
      if (child is TextSpan && (child.text?.isNotEmpty ?? false)) {
        styles.add(child.style ?? const TextStyle());
      }
      return true;
    });
    return styles;
  }

  testWidgets('разметка заголовка не показывается как текст', (tester) async {
    final span = await pumpTitle(
      tester,
      '*Коловоз*, *коловозна трака* — читаем **стрелки** на фото',
    );

    expect(
      span.toPlainText(),
      'Коловоз, коловозна трака — читаем стрелки на фото',
    );
    expect(find.textContaining('*'), findsNothing);
  });

  testWidgets('выделение сохраняет размер шрифта заголовка', (tester) async {
    final span = await pumpTitle(tester, 'Знак *насеље*: где **начинается**');
    final styles = stylesOf(span);

    // Выделение должно накладываться поверх стиля заголовка, а не подменять
    // его стилем обычного текста из темы.
    expect(styles.every((s) => s.fontSize == titleStyle.fontSize), isTrue);
    expect(styles.any((s) => s.fontStyle == FontStyle.italic), isTrue);
    expect(styles.any((s) => s.fontWeight == FontWeight.bold), isTrue);
  });

  testWidgets('заголовок без разметки выводится как есть', (tester) async {
    final span = await pumpTitle(tester, 'Пешачки прелаз');

    expect(span.toPlainText(), 'Пешачки прелаз');
    expect(stylesOf(span).single.fontSize, titleStyle.fontSize);
  });
}
