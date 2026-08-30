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
    // II-43.2 нет в assets/signs/ — дедупликация его не тронула, но описание
    // и адрес у него такие же полноправные.
    final info = index.byCode['II-43.2']!;
    expect(info.asset, startsWith('assets/pravilnik/'));
    expect(info.descriptionSr, isNotEmpty);
    expect(info.chlan, isNotNull);
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
    // «Зона школе» (файл iii-28.svg) в правилнике 2010 года не описана —
    // лучше без описания, чем описание «престанка забране давања звучних
    // знакова», под номером III-28 которого документ описывает другой знак.
    expect(lookupRoadSign(index, 'iii-28'), isNull);
  });

  test('маркеры конспектов находят описание, кроме знаков образца 2017', () {
    // Каждый файл в assets/signs/ — потенциальный маркер anim/sign-*.
    final signs = Directory('assets/signs')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toList();
    expect(signs, isNotEmpty);

    // Знаков нет в правилнике 2010 года: e75-srb — не знак правилника,
    // остальные появились или сменили вид позже.
    const absentFromDocument = {
      'e75-srb',
      'ii-46',
      'ii-47',
      'iii-5',
      'iii-7',
      'iii-14-40',
      'iii-15-40',
      'iii-18',
      'iii-26',
      'iii-27',
      'iii-28',
      'iii-29',
      'iii-30',
      'iv-18',
    };
    final missing = signs
        .where((s) => !absentFromDocument.contains(s) && !s.endsWith('-2017'))
        .where((s) => lookupRoadSign(index, s) == null)
        .toList();
    expect(missing, isEmpty);
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

  test('список переномерованных знаков совпадает с парсером', () {
    // Правило «файл ≠ код» записано дважды: здесь и в подмене картинок самого
    // документа (tool/parse_pravilnik.py). Разъехавшись, они дадут описание от
    // чужого знака — сверяем прямо по исходнику скрипта.
    final source = File('tool/parse_pravilnik.py').readAsStringSync();
    final block = RegExp(r'OFFICIAL_OVERRIDES = \{(.*?)\n\}', dotAll: true)
        .firstMatch(source)!
        .group(1)!;
    final codes = RegExp(r"'([^']+)':")
        .allMatches(block)
        .map((m) => m.group(1)!)
        .toSet();
    expect(codes, renumberedIn2017);
  });
}
