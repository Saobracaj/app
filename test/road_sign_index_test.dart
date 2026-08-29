import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/domain/road_sign_index.dart';

/// Индекс «код знака → описание из правилника» собирается по регулярной
/// структуре документа (картинки → подписи «**I-1**» → абзац-описание).
/// JSON читается с диска, как в pravilnik_test.dart: большие строки в
/// тестовой среде из rootBundle не возвращаются.
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
    expect(index.length, greaterThan(240));
    for (final group in ['I-', 'II-', 'III-', 'IV-']) {
      expect(
        index.keys.where((c) => c.startsWith(group)),
        isNotEmpty,
        reason: group,
      );
    }
  });

  test('I-1: название, описание, адрес и общий с конспектами файл', () {
    final info = index['I-1']!;
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
    final base = index['I-1']!;
    final variant = index['I-1.1']!;
    expect(variant.descriptionSr, base.descriptionSr);
    expect(variant.nameSr, 'кривина надесно');
    expect(variant.asset, 'assets/signs/i-1.1.svg');
  });

  test('знак без официального SVG остаётся с извлечённым из docx файлом', () {
    // II-43.2 нет в assets/signs/ — дедупликация его не тронула, но описание
    // и адрес у него такие же полноправные.
    final info = index['II-43.2']!;
    expect(info.asset, startsWith('assets/pravilnik/'));
    expect(info.descriptionSr, isNotEmpty);
    expect(info.chlan, isNotNull);
  });

  test('у каждого знака индекса есть описание и адрес для ссылки', () {
    for (final info in index.values) {
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

  test('маркеры конспектов находят описание, кроме знаков образца 2017', () {
    // Каждый файл в assets/signs/ — потенциальный маркер anim/sign-*.
    // Для «-2017» описания нет сознательно (другая нумерация), e75-srb — не
    // знак правилника; остальные обязаны находиться, при необходимости через
    // фолбэк вариантов («ii-30-40» → II-30).
    final signs = Directory('assets/signs')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toList();
    expect(signs, isNotEmpty);

    // Знаки, которых в правилнике 2010 года нет (нумерация поправок и знаки
    // 2017 года без суффикса в имени файла) — у них описания не будет, и это
    // честнее, чем описание чужого знака.
    const absentFromDocument = {
      'e75-srb',
      'ii-46',
      'ii-47',
      'iii-5',
      'iii-14-40',
      'iii-15-40',
      'iv-18',
    };
    final missing = signs
        .where((s) => !absentFromDocument.contains(s) && !s.endsWith('-2017'))
        .where((s) => lookupRoadSign(index, s) == null)
        .toList();
    expect(missing, isEmpty);
    // Вариант с числом находит базовый знак, «-2017» — сознательно ничего.
    expect(lookupRoadSign(index, 'ii-30-40')?.code, 'II-30');
    expect(lookupRoadSign(index, 'iii-11-2017'), isNull);
  });
}
