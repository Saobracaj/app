import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/question_explanation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Source of the pre-generated question explanations (the "Спросить AI" tab's
/// static content). They live in `saobracaj_backend` behind the premium
/// `ask_ai` flag — `questionExplanation(questionId:, lang:)` returns the
/// document, or `null` for a question whose explanation is not generated yet.
///
/// The display language follows the study-content language: Russian when the
/// `russian_content` feature is resolved on, Serbian otherwise — falling back
/// to the other language while the preferred one has no document yet (only the
/// Russian ones exist until the Serbian generation catches up).
///
/// Like the konspekts, a downloaded document is cached in shared preferences
/// and kept in memory for the session, so an already-opened explanation still
/// opens offline. "The question has no explanation" is remembered only in
/// memory: it must not outlive the session, or a later generation run would
/// stay invisible until a reinstall. Failures are never remembered as answers.
@lazySingleton
class QuestionExplanationRepository {
  QuestionExplanationRepository(this._client, this._flags);

  final GraphqlClient _client;
  final FeatureFlagsRepository _flags;

  static const _cachePrefix = 'question_explanation.';

  /// Session cache per `<lang>.<questionId>`; a stored `null` is a real
  /// "the backend has none" answer, not a failure.
  final Map<String, QuestionExplanation?> _loaded = {};

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// The explanation to show for [questionId], or `null` when neither language
  /// has one. Throws whatever [GraphqlClient] throws when the document had to
  /// be downloaded and that failed with nothing usable cached — the caller
  /// turns it into a retryable message.
  Future<QuestionExplanation?> load(int questionId) async {
    final preferred = _flags.snapshot.russianContent ? 'ru' : 'sr';
    final fallback = preferred == 'ru' ? 'sr' : 'ru';
    return await _load(questionId, preferred) ?? await _load(questionId, fallback);
  }

  Future<QuestionExplanation?> _load(int questionId, String lang) async {
    final key = '$lang.$questionId';
    if (_loaded.containsKey(key)) return _loaded[key];

    try {
      final data = await _client.run(
        r'''
          query QuestionExplanation($questionId: Int!, $lang: String!) {
            questionExplanation(questionId: $questionId, lang: $lang) {
              questionId version document
            }
          }
        ''',
        variables: {'questionId': questionId, 'lang': lang},
        authenticated: true,
      );
      final raw = data['questionExplanation'];
      final document = raw is Map ? raw['document'] : null;
      if (document is! Map) {
        // The backend answered "no explanation": a session-long answer, and
        // any cached copy is stale (the explanation was unpublished).
        _loaded[key] = null;
        unawaited(_dropCached(key));
        return null;
      }
      final explanation = QuestionExplanation.fromJson(document.cast<String, dynamic>());
      _loaded[key] = explanation;
      unawaited(_cache(key, document));
      return explanation;
    } catch (_) {
      // Offline or a transient failure: a stale cached copy beats nothing.
      final cached = await _readCached(key);
      if (cached != null) {
        _loaded[key] = cached;
        return cached;
      }
      rethrow;
    }
  }

  Future<QuestionExplanation?> _readCached(String key) async {
    try {
      final raw = (await _prefs).getString('$_cachePrefix$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return QuestionExplanation.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // A corrupt cache entry is not worth crashing over.
      return null;
    }
  }

  Future<void> _cache(String key, Map<dynamic, dynamic> document) async {
    try {
      (await _prefs).setString('$_cachePrefix$key', jsonEncode(document));
    } catch (_) {
      // Best-effort cache.
    }
  }

  Future<void> _dropCached(String key) async {
    try {
      (await _prefs).remove('$_cachePrefix$key');
    } catch (_) {
      // Best-effort cache.
    }
  }
}
