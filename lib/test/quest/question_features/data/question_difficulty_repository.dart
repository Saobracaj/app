import 'package:injectable/injectable.dart';

import '../../../../auth/data/graphql_client.dart';
import '../models/question_analytics.dart';

/// Crowd difficulty of a question — the one analytic the app cannot compute
/// offline, because it is derived from every learner's answers.
///
/// Backed by `questionDifficulty` in `saobracaj_backend`, which aggregates the
/// answer log that `syncStatistics` already collects. The whole bank comes back
/// in one call, so the first question screen of a session fetches it once and
/// every later one reads it from memory; a failure is not remembered, so the
/// next question retries.
///
/// The query requires a signed-in caller (the aggregate is anonymous, but not
/// public), so [forQuestion] answers `null` for a guest instead of throwing.
@lazySingleton
class QuestionDifficultyRepository {
  QuestionDifficultyRepository(this._client);

  final GraphqlClient _client;

  static const _query = r'''
    query QuestionDifficulty {
      questionDifficulty {
        baseline { wrongRate }
        questions {
          questionId
          attempts
          wrongAttempts
          learners
          wrongRate
          difficulty
        }
      }
    }''';

  Map<int, QuestionDifficulty>? _loaded;
  Future<Map<int, QuestionDifficulty>>? _inFlight;
  double _baseline = 0;

  /// Difficulty of one question, or `null` when the server has never seen an
  /// answer to it. Throws whatever [GraphqlClient] throws when the snapshot has
  /// to be fetched and that fails.
  Future<QuestionDifficulty?> forQuestion(int questionId) async =>
      (await _snapshot())[questionId];

  /// Drops the cached snapshot — used when the session changes, since a guest
  /// and a signed-in user get different answers (none vs the aggregate).
  void invalidate() {
    _loaded = null;
    _inFlight = null;
  }

  Future<Map<int, QuestionDifficulty>> _snapshot() {
    final loaded = _loaded;
    if (loaded != null) return Future.value(loaded);
    return _inFlight ??= _fetch().then((value) {
      _loaded = value;
      return value;
    }).catchError((Object e) {
      _inFlight = null;
      throw e;
    });
  }

  Future<Map<int, QuestionDifficulty>> _fetch() async {
    final data = await _client.run(_query, authenticated: true);
    final report = data['questionDifficulty'] as Map<String, dynamic>;
    _baseline =
        ((report['baseline'] as Map<String, dynamic>)['wrongRate'] as num)
            .toDouble();

    final out = <int, QuestionDifficulty>{};
    for (final raw in report['questions'] as List) {
      final q = raw as Map<String, dynamic>;
      out[(q['questionId'] as num).toInt()] = QuestionDifficulty(
        attempts: (q['attempts'] as num).toInt(),
        wrongAttempts: (q['wrongAttempts'] as num).toInt(),
        learners: (q['learners'] as num).toInt(),
        wrongRate: (q['wrongRate'] as num).toDouble(),
        difficulty: (q['difficulty'] as num).toDouble(),
        baseline: _baseline,
      );
    }
    return out;
  }
}
