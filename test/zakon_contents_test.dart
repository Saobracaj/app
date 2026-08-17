import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/domain/zakon_contents.dart';

/// Кусок закона той же формы, что и `assets/parsed_zakon.json`: заголовок,
/// глава, её члены с абзацами, следующая глава.
final _zakon = <BezbParagraph>[
  const BezbParagraph(sr: 'ЗАКОН', isTitle: true),
  const BezbParagraph(chapter: 'I', sr: 'I. ОСНОВНЕ ОДРЕДБЕ'),
  const BezbParagraph(chapter: 'I', chlan: '1', paragraph: '0', sr: 'Члан 1.'),
  const BezbParagraph(chapter: 'I', chlan: '1', paragraph: '1', sr: 'текст'),
  const BezbParagraph(chapter: 'I', chlan: '2', paragraph: '0', sr: 'Члан 2.'),
  const BezbParagraph(
    chapter: 'I',
    chlan: '2а',
    paragraph: '0',
    sr: 'Члан 2а.',
  ),
  const BezbParagraph(chapter: 'II', sr: 'II. ОСНОВНА НАЧЕЛА'),
  const BezbParagraph(chapter: 'II', chlan: '3', paragraph: '0', sr: 'Члан 3.'),
];

void main() {
  test('оглавление собирает идущие подряд члены в одну группу', () {
    final toc = zakonTableOfContents(_zakon);

    expect(toc.map((group) => group.map((p) => p.sr).toList()), [
      ['ЗАКОН'],
      ['I. ОСНОВНЕ ОДРЕДБЕ'],
      ['Члан 1.', 'Члан 2.', 'Члан 2а.'],
      ['II. ОСНОВНА НАЧЕЛА'],
      ['Члан 3.'],
    ]);
  });

  test('в оглавление не попадают абзацы, только заголовки', () {
    final toc = zakonTableOfContents(_zakon);

    expect(
      toc.expand((group) => group).map((p) => p.sr),
      isNot(contains('текст')),
    );
  });

  test('пустой закон даёт пустое оглавление', () {
    expect(zakonTableOfContents(const []), isEmpty);
  });
}
