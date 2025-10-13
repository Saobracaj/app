import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/zakon o bezbednosti.md');
  final content = await file.readAsString();

  final lines = content.split('\n');
  final output = <Map<String, dynamic>>[];

  final chapterRegex = RegExp(r'^([IVXLCDM]+)\.\s+.+$'); // Пример: II. ОСНОВНА НАЧЕЛА...
  final chlanRegex = RegExp(r'^Члан\s+(\d+)\.?$');        // Пример: Члан 3.

  String? currentChapter;
  String? currentChlan;
  int? paragraphCounter;

  for (final line in lines) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      // Пропускаем пустые строки (или можно включать их с nullами, если нужно всё)
      continue;
    }

    final chapterMatch = chapterRegex.firstMatch(trimmed);
    if (chapterMatch != null) {
      currentChapter = chapterMatch.group(1);
      currentChlan = null;
      paragraphCounter = null;

      output.add({
        'chapter': currentChapter,
        'chlan': null,
        'paragraph': null,
        'sr': trimmed,
      });
      continue;
    }

    final chlanMatch = chlanRegex.firstMatch(trimmed);
    if (chlanMatch != null) {
      currentChlan = chlanMatch.group(1);
      paragraphCounter = 1;

      output.add({
        'chapter': currentChapter,
        'chlan': currentChlan,
        'paragraph': '0',
        'sr': trimmed,
      });
      continue;
    }

    // Обычная строка текста (параграф)
    output.add({
      'chapter': currentChapter,
      'chlan': currentChlan,
      'paragraph': currentChlan != null ? '${paragraphCounter ?? 1}' : null,
      'sr': trimmed,
    });

    if (currentChlan != null) {
      paragraphCounter = (paragraphCounter ?? 1) + 1;
    }
  }

  final jsonOutput = const JsonEncoder.withIndent('  ').convert(output);
  final outFile = File('assets/parsed_zakon.json');
  await outFile.writeAsString(jsonOutput);

  print('✅ Готово! JSON сохранён в assets/parsed_zakon.json');
}
