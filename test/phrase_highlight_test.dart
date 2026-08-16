import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/markdown/phrase_highlight.dart';

/// Разметка ключевых фраз `~~…~~` поверх текста вопроса/варианта, уже
/// пропущенного через словарь (`String.dict`) — то есть с markdown-ссылками
/// `[термин](dict/…)` внутри.
void main() {
  group('markPhrases', () {
    test('оборачивает фразу целыми словами без учёта регистра', () {
      expect(
        markPhrases('Возач НИЈЕ ДУЖАН да стане.', const [
          PhraseHighlight('није дужан'),
        ]),
        'Возач ~~НИЈЕ ДУЖАН~~ да стане.',
      );
    });

    test('часть слова не считается совпадением', () {
      expect(
        markPhrases('паркирање је забрањено', const [
          PhraseHighlight('паркира'),
        ]),
        'паркирање је забрањено',
      );
    });

    test('знаки препинания остаются за пределами выделения', () {
      expect(
        markPhrases('(звучним знаком), даље', const [
          PhraseHighlight('звучним знаком'),
        ]),
        '(~~звучним знаком~~), даље',
      );
    });

    test('все вхождения и слияние пересекающихся фраз', () {
      expect(
        markPhrases('а б в а б', const [
          PhraseHighlight('а б'),
          PhraseHighlight('б в'),
        ]),
        '~~а б в~~ ~~а б~~',
      );
    });

    test('ссылка словаря целиком внутри фразы остаётся ссылкой', () {
      expect(
        markPhrases('Возач [паркира](dict/%D0%9F) возило.', const [
          PhraseHighlight('паркира'),
        ]),
        'Возач ~~[паркира](dict/%D0%9F)~~ возило.',
      );
    });

    test('граница фразы внутри ссылки раздвигается до границ ссылки', () {
      // Словарная фраза из двух слов, а подсказка — только второе слово:
      // открыть ~~ внутри [ … ] нельзя, поэтому выделяется весь термин.
      expect(
        markPhrases('даје [звучни знак](dict/x) возачу', const [
          PhraseHighlight('знак возачу'),
        ]),
        'даје ~~[звучни знак](dict/x) возачу~~',
      );
    });

    testWidgets('flutter_markdown читает разметку: тильд на экране нет', (
      tester,
    ) async {
      // Тот же парсер, что и у QuestMarkdown: и вокруг ссылки, и с ссылкой
      // внутри выделение превращается в span, а не в буквальные тильды.
      for (final marked in [
        'Возач ~~[паркира](dict/%D0%9F)~~ возило.',
        'даје ~~[звучни знак](dict/x) возачу~~',
        '~~а б в~~ ~~а б~~',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MarkdownBody(data: marked)),
          ),
        );
        expect(find.textContaining('~~', findRichText: true), findsNothing);
        // Текст выделения виден целиком (ссылка внутри — тоже).
        expect(
          find.textContaining(
            marked
                .replaceAll('~~', '')
                .replaceAll(RegExp(r'\[|\]\([^)]*\)'), ''),
            findRichText: true,
          ),
          findsOneWidget,
        );
      }
    });

    test('целый ответ (whole) совпадает только с текстом целиком', () {
      const whole = [PhraseHighlight('паркирање је дозвољено', whole: true)];
      expect(
        markPhrases('Паркирање је дозвољено.', whole),
        '~~Паркирање је дозвољено~~.',
      );
      expect(
        markPhrases('Паркирање је дозвољено само ноћу.', whole),
        'Паркирање је дозвољено само ноћу.',
      );
    });

    test('без совпадений и без фраз текст не меняется', () {
      expect(markPhrases('текст', const []), 'текст');
      expect(markPhrases('текст', const [PhraseHighlight('нема')]), 'текст');
    });

    test('картинки не считаются видимым текстом', () {
      expect(
        markPhrases('![знак](anim/z.gif) знак стоп', const [
          PhraseHighlight('знак стоп'),
        ]),
        '![знак](anim/z.gif) ~~знак стоп~~',
      );
    });
  });
}
