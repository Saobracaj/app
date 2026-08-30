import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/domain/road_sign_index.dart';

/// Индекс «знак → описание из правилника» собирается по регулярной структуре
/// документа (картинки → подписи «**I-1**» → абзац-описание). JSON читается с
/// диска, как в pravilnik_test.dart: большие строки в тестовой среде из
/// rootBundle не возвращаются.
void main() {
  final rows =
      (jsonDecode(File('assets/parsed_pravilnik.json').readAsStringSync())
              as List)
          .map((e) => BezbParagraph.fromJson(e as Map<String, dynamic>))
          .toList();
  final index = buildRoadSignIndex(rows);

  test('индекс покрывает все группы знаков', () {
    // В группах I–IV ~250 знаков; просевший счётчик значит, что структура
    // «картинки → подписи → описание» где-то разошлась с разбором.
    expect(index.byCode.length, greaterThan(240));
    for (final group in ['I-', 'II-', 'III-', 'IV-']) {
      expect(
        index.byCode.keys.where((c) => c.startsWith(group)),
        isNotEmpty,
        reason: group,
      );
    }
    // По файлу находится большинство: официальные SVG подставлены в документ.
    expect(index.byAsset.keys.where((a) => a.startsWith('assets/signs/')),
        hasLength(greaterThan(150)));
  });

  test('I-1: название, описание, адрес и общий с конспектами файл', () {
    final info = lookupRoadSign(index, 'i-1')!;
    expect(info.code, 'I-1');
    expect(info.asset, 'assets/signs/i-1.svg');
    expect(info.nameSr, 'кривина налево');
    expect(info.nameRu, 'поворот налево');
    expect(info.descriptionSr, contains('(I-1)'));
    expect(info.descriptionRu, contains('(I-1)'));
    expect(info.chapter, 'II');
    expect(info.chlan, '13');
    expect(info.paragraph, isNotNull);
  });

  test('варианты знака делят один абзац-описание', () {
    final base = lookupRoadSign(index, 'i-1')!;
    final variant = lookupRoadSign(index, 'i-1.1')!;
    expect(variant.descriptionSr, base.descriptionSr);
    expect(variant.nameSr, 'кривина надесно');
    expect(variant.asset, 'assets/signs/i-1.1.svg');
  });

  test('знак без официального SVG остаётся с извлечённым из docx файлом', () {
    // II-19.1 нет в assets/signs/ — дедупликация его не тронула, но описание
    // и адрес у него такие же полноправные.
    final info = index.byCode['II-19.1']!;
    expect(info.asset, startsWith('assets/pravilnik/'));
    expect(info.descriptionSr, isNotEmpty);
    expect(info.chlan, isNotNull);
  });

  test('описание предпочитает упоминание в формате «({код})»', () {
    // Описание каждого знака упоминает его код в скобках — «(I-1)»,
    // «(II-43), (II-43.1)…»; поиск в окне берёт такую строку первой, чтобы
    // случайное упоминание кода в чужом абзаце не перехватило описание.
    for (final code in ['I-1', 'II-43.2', 'III-19', 'II-2']) {
      final sr = index.byCode[code]!.descriptionSr!;
      expect(sr.replaceAll(' ', ''), contains('($code'), reason: code);
    }
    // «III-…» не должен находиться внутри более длинного номера: II-29.3 —
    // опечатка документа (на деле III-29.3), и его описание — ближайший пункт
    // перечня «24) знак „престанак свих забрана”…», а не случайная подстрока.
    expect(
      index.byCode['II-29.3']!.descriptionSr,
      contains('престанак свих забрана'),
    );
  });

  test('у каждого знака индекса есть описание и адрес для ссылки', () {
    for (final info in index.byCode.values) {
      expect(info.descriptionSr, isNotNull, reason: info.code);
      // Абзац упоминает знак или его семейство: вариант вроде II-9.1 из-за
      // опечаток документа может опираться на пункт базового II-9.
      expect(
        info.descriptionSr,
        contains(info.code.split('.').first),
        reason: info.code,
      );
      expect(info.chlan, isNotNull, reason: info.code);
      expect(info.paragraph, isNotNull, reason: info.code);
    }
  });

  test('описание берётся у знака с тем же изображением, а не с тем же кодом',
      () {
    // Номера 2010 и 2017 разошлись: файл iii-68.svg — «аутопут» (в этом
    // документе он III-19), а III-68 документа — «деца на путу». Привязка
    // идёт по файлу, поэтому описание достаётся от аутопута.
    final autoput = lookupRoadSign(index, 'iii-68')!;
    expect(autoput.code, 'III-19');
    expect(autoput.descriptionSr, contains('аутопут'));
    // «Зона школе» (файл iii-28.svg) в этом документе стоит под номером
    // III-82 — описание достаётся от него, а не от III-28 документа
    // («престанак забране давања звучних знакова» — другой знак).
    final zonaSkole = lookupRoadSign(index, 'iii-28')!;
    expect(zonaSkole.code, 'III-82');
    expect(zonaSkole.descriptionSr, contains('зона школе'));
  });

  test('маркеры конспектов находят описание, кроме знаков образца 2017', () {
    // Каждый файл в assets/signs/ — потенциальный маркер anim/sign-*.
    final signs = Directory('assets/signs')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toList();
    expect(signs, isNotEmpty);

    // Знаков нет в правилнике 2010 года: появились или сменили вид позже.
    const absentFromDocument = {
      'ii-46',
      'ii-47',
      'iii-5',
      'iii-7',
      'iv-18',
    };
    final missing = signs
        .where((s) => !absentFromDocument.contains(s) && !s.endsWith('-2017'))
        .where((s) => lookupRoadSign(index, s) == null)
        .toList();
    expect(missing, isEmpty);
    // …и наоборот: раз знак попал в список, описания у него правда нет —
    // найденное описание значит, что запись в списке устарела.
    final stale = absentFromDocument
        .where((s) => lookupRoadSign(index, s) != null)
        .toList();
    expect(stale, isEmpty);
    // Вариант с числом находит базовый знак.
    expect(lookupRoadSign(index, 'ii-30-40')?.code, 'II-30');
  });

  test('знак образца 2017 берёт описание своего двойника из документа', () {
    // Зелёная «деца на путу» (III-11 по нумерации 2017) в правилнике 2010
    // года стоит под номером III-68 — описание её, только рисунок новый.
    final deca = lookupRoadSign(index, 'iii-11-2017')!;
    expect(deca.code, 'III-68');
    expect(deca.descriptionSr, contains('деца на путу'));
    // Пары в документе нет — лучше без описания, чем чужое.
    expect(lookupRoadSign(index, 'iii-25-2017'), isNull);
    for (final entry in equivalentIn2010.entries) {
      expect(lookupRoadSign(index, entry.key)?.code, entry.value,
          reason: entry.key);
    }
  });

  test('список переномерованных знаков согласован с парсером', () {
    // Правило «файл ≠ код» записано дважды: здесь и в подмене картинок самого
    // документа (tool/parse_pravilnik.py). Разъехавшись, они дадут описание от
    // чужого знака — сверяем прямо по исходнику скрипта. Запрет привязки по
    // коду нужен только коду, чей ОДНОИМЁННЫЙ файл существует и означает
    // другой знак; ключам без такого файла (замена «II-30 → ii-30-40» и
    // подобные) запрет только вредил бы — вариантам семейства (ii-30-blank)
    // описание достаётся по коду базового знака.
    final source = File('tool/parse_pravilnik.py').readAsStringSync();
    final block = RegExp(r'OFFICIAL_OVERRIDES = \{(.*?)\n\}', dotAll: true)
        .firstMatch(source)!
        .group(1)!;
    final codes = RegExp(r"'([^']+)':")
        .allMatches(block)
        .map((m) => m.group(1)!)
        .toSet();
    expect(renumberedIn2017.difference(codes), isEmpty);
    for (final code in codes) {
      if (File('assets/signs/${code.toLowerCase()}.svg').existsSync()) {
        expect(renumberedIn2017, contains(code), reason: code);
      }
    }
  });
}
