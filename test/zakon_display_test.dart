import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/domain/zakon_display.dart';

/// Строки экрана правилника: подписи «**II-43**» склеены со строкой картинок
/// над ними, чтобы код стоял прямо под своим знаком (таблица «знак → номер»),
/// а не столбцом отдельных строк. JSON читается с диска, как в
/// pravilnik_test.dart: большие строки в тестовой среде из rootBundle не
/// возвращаются.
void main() {
  List<BezbParagraph> load(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as List)
          .map((e) => BezbParagraph.fromJson(e as Map<String, dynamic>))
          .toList();

  final pravilnik = load('assets/parsed_pravilnik.json');
  final rows = buildZakonDisplayRows(pravilnik);

  /// Строка-подпись: только жирные коды знаков («**II-43**», «**III -24.1**»).
  final captionRe =
      RegExp(r'^\*\*(?:[IVX]{1,3}\s*-\s*\d+(?:\.\d+)*\s*)+\*\*$');
  bool isCaption(BezbParagraph r) => captionRe.hasMatch((r.sr ?? '').trim());

  test('подписи склеены со строками картинок, коды — по одному на картинку',
      () {
    // Блок «обавезан смер»: строка с тремя картинками, за ней три подписи.
    final row = rows.firstWhere(
      (r) => r.row.images.any((i) => i.src.endsWith('ii-43.svg')),
    );
    expect(row.row.images, hasLength(3));
    expect(row.signCodes, ['II-43', 'II-43.1', 'II-43.2']);
    expect(row.mergedCaptions, hasLength(3));
    // Сами строки-подписи с экрана ушли — их коды теперь ячейки таблицы.
    expect(
      rows.where(
        (r) => isCaption(r.row) && (r.row.sr ?? '').contains('II-43.1'),
      ),
      isEmpty,
    );
  });

  test('склейка покрывает все группы знаков, картинки не теряются', () {
    final merged = rows.where((r) => r.signCodes.isNotEmpty).toList();
    // ~250 блоков «картинки + подписи» во всех группах (I–IV — знаки,
    // V и дальше — разметка и семафоры).
    expect(merged.length, greaterThan(240));
    for (final group in ['I-', 'II-', 'III-', 'IV-', 'V-', 'VII-']) {
      expect(
        merged.where((r) => r.signCodes.any((c) => c.startsWith(group))),
        isNotEmpty,
        reason: group,
      );
    }
    // Ни одна картинка при склейке не пропала.
    final before = pravilnik.expand((r) => r.images).length;
    final after = rows
        .expand((r) => [...r.row.images, ...r.mergedCaptions.expand((c) => c.images)])
        .length;
    expect(after, before);
    // Подпись со своей картинкой (смешанные строки docx) не склеивается —
    // иначе её картинка ушла бы с экрана вместе со строкой.
    for (final r in rows) {
      expect(
        r.mergedCaptions.where((c) => c.images.isNotEmpty),
        isEmpty,
        reason: r.row.sr,
      );
    }
  });

  test('коды выровнены с картинками либо один общий на ряд', () {
    for (final r in rows.where((r) => r.signCodes.isNotEmpty)) {
      expect(
        r.signCodes.length == r.row.images.length ||
            (r.signCodes.length == 1 && r.row.images.length > 1),
        isTrue,
        reason: '${r.signCodes} vs ${r.row.images.length} картинок',
      );
    }
  });

  test('адрес склеенной подписи не теряется — ссылка найдёт её блок', () {
    // Подпись «**II-43.1**» стояла отдельным абзацем со своим номером; после
    // склейки этот номер жив в mergedCaptions — по нему ищет ScrollTo.
    final row = rows.firstWhere((r) => r.signCodes.contains('II-43.1'));
    expect(
      row.mergedCaptions.map((c) => c.paragraph),
      everyElement(isNotNull),
    );
  });

  test('закон без картинок проходит один к одному', () {
    final zakon = load('assets/parsed_zakon.json');
    final zakonRows = buildZakonDisplayRows(zakon);
    expect(zakonRows, hasLength(zakon.length));
    expect(zakonRows.every((r) => r.signCodes.isEmpty), isTrue);
  });
}
