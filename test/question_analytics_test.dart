import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Guards `assets/question_analytics.json` against the two assets it is derived
/// from (`tool/question_analytics.py` builds it from exactly those).
///
/// The point of the analytics tab is that its numbers are measured, so the
/// checks here are the ones the model itself has to pass: the exam blueprint it
/// was reverse-engineered from must still hold, and the probabilities it
/// assigns must reproduce a real exam — 41 questions and ~98 points — when
/// summed over the whole bank. A content update that ships without re-running
/// the script fails here rather than quietly showing stale percentages.
///
/// (This file replaces `practice_contains_all_questions_test.dart`, whose
/// premise — every question occurs somewhere in `practice.json` — is simply not
/// true: 144 do not, 142 of them because the exam never draws their category at
/// all. That is the fact the "Стоимость вопроса" block reports.)
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  late List<List<int>> exams;
  late List<Map<String, dynamic>> questions;
  late Map<String, dynamic> analytics;

  setUpAll(() async {
    exams = (jsonDecode(await rootBundle.loadString('assets/practice.json'))
            as List)
        .map((e) => List<int>.from(e as List))
        .toList();
    questions =
        (jsonDecode(await rootBundle.loadString('assets/allQuestions.json'))
                as List)
            .cast<Map<String, dynamic>>();
    analytics = jsonDecode(
      await rootBundle.loadString('assets/question_analytics.json'),
    ) as Map<String, dynamic>;
  });

  group('exam blueprint', () {
    test('every sampled exam has the same size', () {
      expect(exams.map((e) => e.length).toSet(), {41});
    });

    test('every sampled exam has the same category profile', () {
      final category = {
        for (final q in questions) q['qId'] as int: q['categoryId'] as String,
      };
      final profiles = exams.map((exam) {
        final counts = <String, int>{};
        for (final id in exam) {
          counts[category[id]!] = (counts[category[id]] ?? 0) + 1;
        }
        return counts.entries.map((e) => '${e.key}:${e.value}').toList()..sort();
      }).map((p) => p.join(',')).toSet();

      // One profile for all 699 variants — this is what makes a per-question
      // probability computable at all.
      expect(profiles, hasLength(1));
      expect(
        profiles.single,
        '25:1,26:1,28:1,29:2,30:18,32:13,33:1,34:2,35:1,36:1',
      );
    });
  });

  group('question_analytics.json', () {
    test('covers every question in the bank', () {
      final entries = analytics['questions'] as Map<String, dynamic>;
      expect(entries, hasLength(questions.length));
      for (final q in questions) {
        expect(
          entries.containsKey('${q['qId']}'),
          isTrue,
          reason: 'qId ${q['qId']} is missing — re-run tool/question_analytics.py',
        );
      }
    });

    test('was built from the bundled sample', () {
      final source = analytics['source'] as Map<String, dynamic>;
      expect(source['exams'], exams.length);
      expect(source['examSize'], exams.first.length);
      expect(source['questions'], questions.length);
    });

    test('probabilities reproduce one exam when summed over the bank', () {
      final entries = analytics['questions'] as Map<String, dynamic>;
      var total = 0.0;
      for (final entry in entries.values) {
        total += (entry as Map<String, dynamic>)['p'] as num;
      }
      // Rounding in the asset (6 decimals × 1701 entries) is the only slack.
      expect(total, closeTo(exams.first.length.toDouble(), 0.01));
    });

    test('expected points reproduce a real exam', () {
      final points = {
        for (final q in questions) q['qId'] as int: q['Points'] as int,
      };
      final actual =
          exams
              .map((e) => e.fold<int>(0, (sum, id) => sum + points[id]!))
              .reduce((a, b) => a + b) /
          exams.length;

      final entries = analytics['questions'] as Map<String, dynamic>;
      var modelled = 0.0;
      for (final entry in entries.values) {
        modelled += (entry as Map<String, dynamic>)['value'] as num;
      }
      expect(modelled, closeTo(actual, 0.05));
    });

    test('a question the model never draws never occurs in the sample', () {
      final seen = <int>{for (final exam in exams) ...exam};
      final entries = analytics['questions'] as Map<String, dynamic>;
      final unreachable = entries.entries
          .where((e) => (e.value as Map<String, dynamic>)['p'] as num == 0)
          .map((e) => int.parse(e.key))
          .toList();

      expect(unreachable, isNotEmpty, reason: 'category 38 is never examined');
      for (final id in unreachable) {
        expect(
          seen.contains(id),
          isFalse,
          reason: 'qId $id is modelled at p=0 but occurs in the sample',
        );
      }
    });

    test('as many drawable questions are missing from the sample as expected',
        () {
      // 144 of the 1701 questions never occur in the 699 variants. 142 of them
      // cannot: the exam does not draw their category. The remaining handful is
      // the model's own prediction — a question at p is absent from N variants
      // with probability (1-p)^N — and if the model were wrong about which
      // questions are rare, this count is where it would show.
      final seen = <int>{for (final exam in exams) ...exam};
      final entries = analytics['questions'] as Map<String, dynamic>;

      var expected = 0.0;
      var observed = 0;
      entries.forEach((id, entry) {
        final p = ((entry as Map<String, dynamic>)['p'] as num).toDouble();
        if (p <= 0) return;
        expected += pow(1 - p, exams.length);
        if (!seen.contains(int.parse(id))) observed++;
      });

      expect(observed, greaterThan(0), reason: 'the sample is not exhaustive');
      // A Poisson-ish band around the prediction: tight enough to catch a model
      // that has the rare questions wrong, loose enough not to be flaky.
      expect(
        observed,
        lessThanOrEqualTo((expected + 4 * sqrt(expected) + 2).ceil()),
        reason: 'expected about ${expected.toStringAsFixed(1)}',
      );
    });

    test('the value tier follows from the value', () {
      final mean =
          (analytics['source'] as Map<String, dynamic>)['meanValue'] as num;
      final entries = analytics['questions'] as Map<String, dynamic>;
      for (final entry in entries.values) {
        final e = entry as Map<String, dynamic>;
        final value = (e['value'] as num).toDouble();
        final expected = value <= 0
            ? 'none'
            : value >= 2 * mean
            ? 'high'
            : value >= 0.5 * mean
            ? 'medium'
            : 'low';
        expect(e['tier'], expected, reason: 'value $value against mean $mean');
      }
    });

    test('every marker hit points at a real marker and a real option', () {
      final markers = analytics['markers'] as Map<String, dynamic>;
      final choices = {
        for (final q in questions)
          q['qId'] as int: (q['Choices'] as List).length,
      };
      final entries = analytics['questions'] as Map<String, dynamic>;

      var hits = 0;
      entries.forEach((id, entry) {
        final byLocale = (entry as Map<String, dynamic>)['markers'];
        if (byLocale == null) return;
        (byLocale as Map<String, dynamic>).forEach((locale, list) {
          final catalogue = markers[locale] as List;
          for (final hit in list as List) {
            final h = hit as Map<String, dynamic>;
            expect(h['m'], lessThan(catalogue.length));
            expect(h['c'], lessThan(choices[int.parse(id)]!));
            hits++;
          }
        });
      });
      expect(hits, greaterThan(0), reason: 'no keyword markers were recorded');
    });

    test('only absolute markers are recorded, and their tally says so', () {
      (analytics['markers'] as Map<String, dynamic>).forEach((_, list) {
        expect(list, isNotEmpty);
        for (final marker in list as List) {
          final m = marker as Map<String, dynamic>;
          final correct = m['correct'] as int;
          final options = m['options'] as int;
          switch (m['kind']) {
            case 'alwaysCorrect':
              expect(correct, options);
            case 'alwaysWrong':
              expect(correct, 0);
            default:
              fail('unexpected marker kind ${m['kind']} — "mostly" cues are '
                  'not shown any more');
          }
        }
      });
    });

    test('a marker really is in the option it is attached to, with the '
        'correctness it claims', () {
      // Only the Serbian catalogue carries the texts, so only its markers can
      // be checked against the bank here; the Russian ones are built by the
      // same code from the translated catalogue.
      final markers = (analytics['markers'] as Map<String, dynamic>)['sr'] as List;
      final bank = {for (final q in questions) q['qId'] as int: q};
      final entries = analytics['questions'] as Map<String, dynamic>;

      var whole = 0;
      entries.forEach((id, entry) {
        final byLocale = (entry as Map<String, dynamic>)['markers'];
        if (byLocale == null) return;
        final list = (byLocale as Map<String, dynamic>)['sr'];
        if (list == null) return;
        final choices = bank[int.parse(id)]!['Choices'] as List;
        for (final hit in list as List) {
          final h = hit as Map<String, dynamic>;
          final m = markers[h['m'] as int] as Map<String, dynamic>;
          final choice = choices[h['c'] as int] as Map<String, dynamic>;
          final text = _normal(choice['Text'] as String);
          if (m['whole'] == true) {
            whole++;
            expect(text, m['phrase'], reason: 'qId $id: whole-answer marker');
          } else {
            expect(text, contains(m['phrase']), reason: 'qId $id');
          }
          expect(
            choice['isCorrect'],
            m['kind'] == 'alwaysCorrect',
            reason: 'qId $id, option ${h['c']}: "${m['phrase']}" is claimed '
                'to be ${m['kind']}',
          );
        }
      });
      expect(whole, greaterThan(0), reason: 'no whole-answer markers');
    });

    test('a link names a word of the question and its correct answer', () {
      final links = (analytics['links'] as Map<String, dynamic>)['sr'] as List;
      expect(links, isNotEmpty);
      final bank = {for (final q in questions) q['qId'] as int: q};
      final entries = analytics['questions'] as Map<String, dynamic>;

      var hits = 0;
      entries.forEach((id, entry) {
        final byLocale = (entry as Map<String, dynamic>)['links'];
        if (byLocale == null) return;
        final list = (byLocale as Map<String, dynamic>)['sr'];
        if (list == null) return;
        final question = bank[int.parse(id)]!;
        final choices = question['Choices'] as List;
        for (final hit in list as List) {
          final h = hit as Map<String, dynamic>;
          final l = links[h['l'] as int] as Map<String, dynamic>;
          final choice = choices[h['c'] as int] as Map<String, dynamic>;
          expect(
            _normal(question['Text'] as String),
            contains(l['stem']),
            reason: 'qId $id: link stem',
          );
          expect(_normal(choice['Text'] as String), l['answer']);
          expect(choice['isCorrect'], isTrue, reason: 'qId $id, option ${h['c']}');
          hits++;
        }
      });
      expect(hits, greaterThan(0));
    });
  });
}

/// The comparable form of a text, as `tool/question_analytics.py` computes it:
/// lower-case words separated by single spaces, punctuation dropped.
String _normal(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}_]+', unicode: true))
    .where((w) => w.isNotEmpty)
    .join(' ');
