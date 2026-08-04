import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';

void main() {
  // The konspekts themselves are served by the backend (published from these
  // files with `konspekt_cli.py publish`); `konspekt_content/` is the authored
  // source kept in git, so it is what there is to validate here.
  test('Authored konspekt sources parse into the model and are internally consistent', () {
    final dir = Directory('konspekt_content');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files, isNotEmpty, reason: 'konspekt_content must contain at least one konspekt');

    for (final file in files) {
      final konspekt = Konspekt.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);

      final expectedId = file.uri.pathSegments.last.replaceAll('.json', '');
      expect(konspekt.categoryId, expectedId, reason: 'categoryId must match the file name');
      expect(konspekt.sections, isNotEmpty);
      expect(konspekt.categoryName.text, isNotEmpty);
      expect(konspekt.dictionary, isNotNull);
      expect(konspekt.dictionary!.content.text, isNotEmpty);

      final sectionIds = konspekt.sections.map((s) => s.id).toSet();
      expect(sectionIds.length, konspekt.sections.length, reason: 'section ids must be unique');

      final sectionLink = RegExp(r'\(konspekt\?category=([^&)]+)&section=([a-z0-9-]+)\)');
      final illustrationMarker = RegExp(r'!\[[^\]]*\]\(illustration:([a-z0-9-]+)\)');
      for (final section in konspekt.sections) {
        expect(section.title.text, isNotEmpty);
        expect(section.content.text, isNotEmpty);
        expect(section.questionIds, isNotEmpty);

        // Same-category section links must resolve to an existing section.
        for (final match in sectionLink.allMatches(section.content.text)) {
          if (match.group(1) == konspekt.categoryId) {
            expect(sectionIds, contains(match.group(2)));
          }
        }

        // Every illustration marker must have a matching illustrations[] entry.
        final declared = section.illustrations.map((i) => i.id).toSet();
        for (final match in illustrationMarker.allMatches(section.content.text)) {
          expect(declared, contains(match.group(1)));
        }

        // Blocks, when present, must partition the content and reproduce the
        // section's question mapping — the per-question excerpt relies on both.
        if (section.blocks.isNotEmpty) {
          expect(
            section.blocks.map((b) => b.content.text).join('\n\n'),
            section.content.text,
            reason: '${section.id}: content must be the blocks joined with blank lines',
          );
          expect(
            section.blocks.expand((b) => b.questionIds).toSet(),
            section.questionIds.toSet(),
            reason: '${section.id}: union of block questionIds must equal section questionIds',
          );
        }
      }
    }
  });
}
