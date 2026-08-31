import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'zakon_o_bezbednosti_data_source.freezed.dart';

part 'zakon_o_bezbednosti_data_source.g.dart';

final zakonOBezbednostiDataSource = ZakonDataSource('assets/parsed_zakon.json');

/// «Правилник о саобраћајној сигнализацији» — та же схема строк, что и у
/// закона, плюс поле `images` (SVG знаков, извлечённые из docx правилника
/// скриптом tool/parse_pravilnik.py).
final pravilnikDataSource = ZakonDataSource('assets/parsed_pravilnik.json');

class ZakonDataSource {
  ZakonDataSource(this.assetPath) {
    _init();
  }

  final String assetPath;
  List<BezbParagraph>? _paragraphs;

  Future<void> _init() async {
    final translationsString = await rootBundle.loadString(assetPath);

    final translationsJson = jsonDecode(translationsString) as List;
    _paragraphs = translationsJson.map((e) => BezbParagraph.fromJson(e)).toList();
  }

  Future<List<BezbParagraph>> get paragraphs async {
    if (_paragraphs != null) return _paragraphs!;
    final translationsString = await rootBundle.loadString(assetPath);
    final translationsJson = jsonDecode(translationsString) as List;
    _paragraphs = translationsJson.map((e) => BezbParagraph.fromJson(e)).toList();
    return _paragraphs!;
  }
}

@freezed
abstract class BezbParagraph with _$BezbParagraph {
  const factory BezbParagraph({
    String? chapter,
    String? paragraph,
    String? chlan,
    String? sr,
    String? ru,
    @Default(false) isTitle,
    // Изображения, показываемые под текстом строки (знаки и рисунки
    // правилника).
    @Default(<ParagraphImage>[]) List<ParagraphImage> images,
  }) = _BezbParagraph;

  factory BezbParagraph.fromJson(Map<String, dynamic> json) => _$BezbParagraphFromJson(json);
}

/// Изображение строки правилника. [w]×[h] — размер рисунка на странице docx
/// (px): официальные SVG знаков из assets/signs/ огромны в собственных
/// координатах, и без размера документа раздули бы колонку.
@freezed
abstract class ParagraphImage with _$ParagraphImage {
  const factory ParagraphImage({
    required String src,
    double? w,
    double? h,
  }) = _ParagraphImage;

  factory ParagraphImage.fromJson(Map<String, dynamic> json) => _$ParagraphImageFromJson(json);
}
