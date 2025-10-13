import 'dart:convert';
import 'package:collection/collection.dart';

import 'package:flutter/services.dart';
import 'package:saobracaj/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'zakon_o_bezbednosti_data_source.freezed.dart';

part 'zakon_o_bezbednosti_data_source.g.dart';

final zakonOBezbednostiDataSource = ZakonDataSource();

class ZakonDataSource {
  List<BezbParagraph>? _paragraphs;

  ZakonDataSource() {
    _init();
  }

  Future<void> _init() async {
    final translationsString = await rootBundle.loadString('assets/parsed_zakon.json');

    final translationsJson = jsonDecode(translationsString) as List;
    _paragraphs = translationsJson.map((e) => BezbParagraph.fromJson(e)).toList();
  }

  Future<List<BezbParagraph>> get paragraphs async {
    if (_paragraphs != null) return _paragraphs!;
    final translationsString = await rootBundle.loadString('assets/parsed_zakon.json');
    final translationsJson = jsonDecode(translationsString) as List;
    _paragraphs = translationsJson.map((e) => BezbParagraph.fromJson(e)).toList();
    return _paragraphs!;
  }
}

@freezed
abstract class BezbParagraph with _$BezbParagraph {
  const factory BezbParagraph({String? chapter, String? paragraph, String? chlan, String? sr, String? ru, @Default(false) isTitle}) = _BezbParagraph;

  factory BezbParagraph.fromJson(Map<String, dynamic> json) => _$BezbParagraphFromJson(json);
}
