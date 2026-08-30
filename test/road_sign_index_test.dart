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
    // В группах I–IV ~290 знаков; просевший счётчик значит, что структура
    // «описание → картинки → подписи» где-то разошлась с разбором.
    expect(index.byCode.length, greaterThan(280));
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
    expect(info.chlan, '18');
    expect(info.paragraph, isNotNull);
  });

  test('варианты знака делят один абзац-описание', () {
    final base = lookupRoadSign(index, 'i-1')!;
    final variant = lookupRoadSign(index, 'i-1.1')!;
    expect(variant.descriptionSr, base.descriptionSr);
    expect(variant.nameSr, 'кривина надесно');
    expect(variant.asset, 'assets/signs/i-1.1.svg');
  });

  test('знак без официального SVG остаётся с картинкой самого документа', () {
    // III-201 (раскрсница) — знак образца 2017 года, официального SVG у него
    // нет; описание и адрес у него такие же полноправные.
    final info = index.byCode['III-201']!;
    expect(info.asset, startsWith('assets/pravilnik/'));
    expect(info.descriptionSr, isNotEmpty);
    expect(info.chlan, isNotNull);
  });

  test('описание предпочитает упоминание в формате «({код})»', () {
    // Описание каждого знака упоминает его код в скобках — «(I-1)»,
    // «(II-43), (II-43.1)…»; поиск в окне берёт такую строку первой, чтобы
    // случайное упоминание кода в чужом абзаце не перехватило описание.
    for (final code in ['I-1', 'II-43.2', 'III-68', 'II-2']) {
      final sr = index.byCode[code]!.descriptionSr!;
      expect(sr.replaceAll(' ', ''), contains('($code'), reason: code);
    }
    // Описание берётся из абзаца НАД рисунком: у «престанак свих забрана»
    // (III-17) — свой пункт перечня, а не соседний.
    expect(
      index.byCode['III-17']!.descriptionSr,
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

  test('нумерация файлов и документа совпадает: правилник 2017 года', () {
    // Файлы в assets/signs/ названы по нумерации 2017 года — той же, что в
    // документе, поэтому код файла и код знака теперь одно и то же.
    final autoput = lookupRoadSign(index, 'iii-68')!;
    expect(autoput.code, 'III-68');
    expect(autoput.descriptionSr, contains('аутопут'));
    final zonaSkole = lookupRoadSign(index, 'iii-28')!;
    expect(zonaSkole.code, 'III-28');
    expect(zonaSkole.descriptionSr, contains('зона школе'));
  });

  test('маркеры конспектов находят описание, кроме знаков 2010 года', () {
    // Каждый файл в assets/signs/ — потенциальный маркер anim/sign-*.
    final signs = Directory('assets/signs')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toList();
    expect(signs, isNotEmpty);

    // Знака нет в правилнике 2017 года: остался от правилника 2010-го
    // (см. legacy2010Files) или показан вариантом, которого документ не
    // называет отдельным номером.
    const absentFromDocument = {
      'iii-8.1',
      'iii-11.1',
      'iii-65.1',
      'iv-9',
    };
    final missing = signs
        .where((s) => !absentFromDocument.contains(s))
        .where((s) => !legacy2010Files.contains(s))
        .where((s) => !s.endsWith('-2017'))
        .where((s) => lookupRoadSign(index, s) == null)
        .toList();
    expect(missing, isEmpty);
    // …и наоборот: раз знак попал в список, описания у него правда нет —
    // найденное описание значит, что запись в списке устарела.
    final stale = {...absentFromDocument, ...legacy2010Files}
        .where((s) => lookupRoadSign(index, s) != null)
        .toList();
    expect(stale, isEmpty);
    // Вариант с числом находит базовый знак.
    expect(lookupRoadSign(index, 'ii-30-40')?.code, 'II-30');
  });

  test('знак образца 2017 стоит в документе под своим номером', () {
    // Зелёная «деца на путу» — III-11 по нумерации 2017, и документ теперь
    // 2017 года: описание находится прямо по коду.
    final deca = lookupRoadSign(index, 'iii-11-2017')!;
    expect(deca.code, 'III-11');
    expect(deca.descriptionSr, contains('школ'));
    // Знак 2010 года, чей номер в этом документе занят другим знаком, лучше
    // оставить без описания, чем дать чужое.
    for (final file in legacy2010Files) {
      expect(lookupRoadSign(index, file), isNull, reason: file);
    }
  });

  test('список знаков 2010 года выводится из имён файлов', () {
    // Плоский файл считается наследием правилника 2010 года ровно тогда,
    // когда рядом лежит его двойник «-2017»: одинаковый номер, разные знаки.
    // «e75-srb» — особый случай (номера в правилнике 2017 года у неё нет).
    final signs = Directory('assets/signs')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toSet();
    for (final file in legacy2010Files) {
      if (file == 'e75-srb') continue;
      // «iii-85-1» — вариант того же знака: двойник «-2017» есть у базового.
      final base =
          RegExp(r'^(.+-\d+)-\d+$').firstMatch(file)?.group(1) ?? file;
      expect(signs, contains('$base-2017'), reason: file);
    }
    for (final file in signs.where((s) => s.endsWith('-2017'))) {
      final plain = file.substring(0, file.length - '-2017'.length);
      if (!signs.contains(plain)) continue;
      expect(legacy2010Files, contains(plain), reason: plain);
    }
  });
}
