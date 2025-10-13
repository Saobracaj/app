import 'dart:convert';
import 'dart:io';

import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';

void main() async {
  final file = File('assets/parsed_zakon.json');
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
    if (chapterMatch != null) {
      if(text.contains('\\.')) {
        newParagraphs.add(p.copyWith(isTitle: true));
      } else {
        newParagraphs.add(p);
      }
    } else {
      final firstNum = intInStr.allMatches(text).map((m) => m.group(0)).firstOrNull;
      if (text.contains('Члан ') && firstNum != null) {
        final numPart = text.split(' ')[1];
        final regex = RegExp(r'^(\d+[a-zA-Zа-яА-Я]*)');
        final match = regex.firstMatch(numPart);
        cNumber = match?.group(1)  ?? numPart;
        pNumber = 0;
      }
      final newParagraph = p.copyWith(chlan: cNumber, paragraph: pNumber?.toString());
      if(text.contains('\\.')) {
        newParagraphs.add(newParagraph.copyWith(isTitle: true));
      } else {
        newParagraphs.add(newParagraph);
      }
    }

    if(pNumber != null) {
      pNumber++;
    }
  }

  var json = jsonEncode(newParagraphs.map((e) => e.toJson()).toList());
  final newFile = File('paragraphs.json');
  await newFile.create();
  await newFile.writeAsString(json);
}
