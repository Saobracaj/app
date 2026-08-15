import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';

import '../models/question_analytics.dart';

/// The offline half of a question's analytics, read from
/// `assets/question_analytics.json`.
///
/// That asset is built by `tool/question_analytics.py` out of the two bundled
/// data files and nothing else: `practice.json` (699 real exam variants) and
/// `allQuestions.json` (the question bank). It holds, per question, the
/// probability of it appearing on an exam, what it is worth in points, and the
/// keyword cues its answer options carry. Re-run the script after either of
/// those assets changes.
///
/// The file is ~250 KB of JSON, so it is decoded once on a background isolate
/// and kept for the session; concurrent callers share the one in-flight load.
@lazySingleton
class QuestionAnalyticsRepository {
  static const _asset = 'assets/question_analytics.json';

  _Analytics? _loaded;
  Future<_Analytics>? _inFlight;

  /// Bank-wide figures (sample size, averages, the keyword base rate).
  Future<AnalyticsSummary> summary() async => (await _load()).summary;

  /// Analytics for one question, or `null` when the question is not in the
  /// bank the asset was built from (a content update the asset predates).
  ///
  /// [languageCode] selects the marker set: the phrases are language-specific,
  /// because they are literal wordings found in the answer options. Anything
  /// other than `ru` falls back to the Serbian set — that is the language the
  /// real exam is sat in.
  Future<QuestionAnalytics?> forQuestion(
    int questionId,
    String languageCode,
  ) async {
    final analytics = await _load();
    final raw = analytics.questions[questionId.toString()];
    if (raw is! Map<String, dynamic>) return null;

    final locale = languageCode == 'ru' ? 'ru' : 'sr';
    final markers = analytics.markers[locale] ?? const <AnswerMarker>[];
    final links = analytics.links[locale] ?? const <AnswerLink>[];

    final hits = <QuestionMarkerHit>[];
    for (final hit in _list(raw['markers'], locale)) {
      final index = (hit['m'] as num).toInt();
      if (index < 0 || index >= markers.length) continue;
      hits.add(
        QuestionMarkerHit(
          marker: markers[index],
          choiceIndex: (hit['c'] as num).toInt(),
        ),
      );
    }
    final linkHits = <QuestionLinkHit>[];
    for (final hit in _list(raw['links'], locale)) {
      final index = (hit['l'] as num).toInt();
      if (index < 0 || index >= links.length) continue;
      linkHits.add(
        QuestionLinkHit(
          link: links[index],
          choiceIndex: (hit['c'] as num).toInt(),
        ),
      );
    }

    return QuestionAnalytics(
      probability: (raw['p'] as num).toDouble(),
      points: (raw['points'] as num).toInt(),
      value: (raw['value'] as num).toDouble(),
      tier: QuestionValueTier.parse(raw['tier'] as String?),
      ratio: (raw['ratio'] as num?)?.toDouble() ?? 0,
      poolSize: (raw['poolSize'] as num).toInt(),
      poolSlots: (raw['poolSlots'] as num).toInt(),
      sampleHits: (raw['sampleHits'] as num?)?.toInt() ?? 0,
      markers: hits,
      links: linkHits,
    );
  }

  /// `raw[key][locale]` as a list — the per-question marker/link entries are
  /// only written for the locales that have any, so both levels may be absent.
  List<dynamic> _list(dynamic byLocale, String locale) {
    if (byLocale is! Map<String, dynamic>) return const [];
    final entries = byLocale[locale];
    return entries is List ? entries : const [];
  }

  Future<_Analytics> _load() {
    final loaded = _loaded;
    if (loaded != null) return Future.value(loaded);
    // A failed read is not remembered: clearing the in-flight future lets the
    // next caller try again instead of pinning the failure for the session.
    return _inFlight ??= _read().then((value) {
      _loaded = value;
      return value;
    }).catchError((Object e) {
      _inFlight = null;
      throw e;
    });
  }

  Future<_Analytics> _read() async {
    final source = await rootBundle.loadString(_asset);
    return compute(_parse, source);
  }
}

/// The decoded asset, kept in the shape it is stored in: 1700 question entries
/// are only ever read one at a time, so turning all of them into objects up
/// front would cost more than it saves.
class _Analytics {
  const _Analytics({
    required this.summary,
    required this.markers,
    required this.links,
    required this.questions,
  });

  final AnalyticsSummary summary;

  /// Language code → the marker / link catalogues, indexed as the per-question
  /// entries reference them.
  final Map<String, List<AnswerMarker>> markers;
  final Map<String, List<AnswerLink>> links;
  final Map<String, dynamic> questions;
}

/// Runs on a background isolate — must stay a top-level function.
_Analytics _parse(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  final src = json['source'] as Map<String, dynamic>;
  // The keyword statistics are measured per language; the summary shows the
  // Serbian ones, which is the corpus the exam is actually written in.
  final stats = (json['stats'] as Map<String, dynamic>)['sr'] as Map<String, dynamic>;

  final markers = <String, List<AnswerMarker>>{};
  (json['markers'] as Map<String, dynamic>).forEach((locale, list) {
    markers[locale] = [
      for (final m in list as List)
        AnswerMarker(
          phrase: m['phrase'] as String,
          // Only absolute cues are written; an unknown kind means an asset
          // from a different schema, and reading it as "always" would be a
          // lie — fail the load, and the tab falls back to no analytics.
          kind:
              MarkerKind.parse(m['kind'] as String?) ??
              (throw FormatException('unknown marker kind: ${m['kind']}')),
          options: (m['options'] as num).toInt(),
          correct: (m['correct'] as num).toInt(),
          whole: m['whole'] == true,
        ),
    ];
  });
  final links = <String, List<AnswerLink>>{};
  ((json['links'] as Map<String, dynamic>?) ?? const {}).forEach((locale, list) {
    links[locale] = [
      for (final l in list as List)
        AnswerLink(
          stem: l['stem'] as String,
          answer: l['answer'] as String,
          questions: (l['questions'] as num).toInt(),
        ),
    ];
  });

  return _Analytics(
    summary: AnalyticsSummary(
      exams: (src['exams'] as num).toInt(),
      examSize: (src['examSize'] as num).toInt(),
      examPoints: (src['examPoints'] as num).toDouble(),
      questions: (src['questions'] as num).toInt(),
      meanValue: (src['meanValue'] as num).toDouble(),
      correctOptionRate: (stats['correctOptionRate'] as num).toDouble(),
      markerQuestions: (stats['markerQuestions'] as num?)?.toInt() ?? 0,
    ),
    markers: markers,
    links: links,
    questions: json['questions'] as Map<String, dynamic>,
  );
}
