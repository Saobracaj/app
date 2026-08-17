import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';

extension ZakonParagraphKind on BezbParagraph {
  /// Заголовок главы («I. ОСНОВНЕ ОДРЕДБЕ») — у него есть только номер главы.
  bool get isChapter => chapter != null && chlan == null && paragraph == null;

  /// Заголовок члена («Члан 1.») — нулевой абзац внутри главы.
  bool get isChlan => chapter != null && chlan != null && paragraph == '0';
}

/// Оглавление закона: заголовки, главы и члены, где идущие подряд члены
/// собраны в одну группу — в оглавлении они показываются рядом номерами, а не
/// отдельными строками.
///
/// Одна и та же структура используется и всплывающим оглавлением на телефоне,
/// и закреплённой колонкой на широком экране.
List<List<BezbParagraph>> zakonTableOfContents(List<BezbParagraph> zakon) {
  final List<BezbParagraph> paragraphs = zakon
      .where(
        (element) => element.isTitle || element.isChapter || element.isChlan,
      )
      .toList();
  final List<List<BezbParagraph>> list = [];

  var i = 0;
  while (i < paragraphs.length) {
    final p = paragraphs[i];

    if (!p.isChlan) {
      list.add([p]);
      i++;
    } else {
      final chlans = <BezbParagraph>[];

      BezbParagraph chlan = p;

      while (chlan.isChlan && i < paragraphs.length) {
        chlan = paragraphs[i];
        if (chlan.isChlan) {
          chlans.add(chlan);
          i++;
        }
      }
      list.add(chlans);
    }
  }
  return list;
}
