import 'dart:convert';
import 'dart:io';

import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';

void main() async {
  final file = File('paragraphs.json');
  final content = await file.readAsString();

  final translationsJson = jsonDecode(content) as List;
  final paragraphs = translationsJson.map((e) => BezbParagraph.fromJson(e)).toList();

  final newParagraphs = <BezbParagraph>[];
  int? pNumber = null;
  String? cNumber = null;
  final intInStr = RegExp(r'\d+');
  final chapterRegex = RegExp(r'^([IVXLCDM]+)\.\s+.+$');

  for (var i = 0; i < paragraphs.length; i++) {
    final p = paragraphs[i];
    final text = p.sr ?? '';
    final chapterMatch = chapterRegex.firstMatch(text.trim());

    if (p.isTitle) {
      final newTextSr = text.replaceAll('*', '').replaceAll('\\', '').replaceAll('#', '');
      final newTextRu = p.ru?.replaceAll('*', '').replaceAll('\\', '').replaceAll('#', '');
      newParagraphs.add(p.copyWith(sr: newTextSr, ru: newTextRu));
    } else {
      newParagraphs.add(p);
    }
  }

  var json = jsonEncode(newParagraphs.map((e) => e.toJson()).toList());
  final newFile = File('paragraphs_new.json');
  await newFile.create();
  await newFile.writeAsString(json);
}
