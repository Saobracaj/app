import 'package:injectable/injectable.dart';

import '../../../../auth/data/graphql_client.dart';
import '../../../../core/app_language.dart';

/// Reads the moderated explanation ("comment") for a question from the backend.
///
/// Replaces the old REST `GET /comment?qid=` data source: the comment now comes
/// from the `questionComment(id:)` GraphQL query, which requires an authenticated
/// user (any logged-in learner can read). Only the live, applied `text` block is
/// shown; the language fragment matching the current UI language is preferred,
/// falling back to `RU` (the only fully-populated language) and then to the first
/// available fragment.
@lazySingleton
class CommentRepository {
  CommentRepository(this._client);

  final GraphqlClient _client;

  static const _query = r'''
    query QuestionComment($id: Int!) {
      questionComment(id: $id) {
        text {
          items { lang text }
        }
      }
    }
  ''';

  /// Returns the markdown comment for [questionId], or `null` when no comment
  /// (or no applied text) exists.
  Future<String?> fetchComment(int questionId) async {
    final data = await _client.run(
      _query,
      variables: {'id': questionId},
      authenticated: true,
    );

    final comment = data['questionComment'];
    if (comment is! Map) return null;
    final text = comment['text'];
    if (text is! Map) return null;
    final items = text['items'];
    if (items is! List || items.isEmpty) return null;

    final lang = appLanguageCode.toUpperCase();
    String? byLang;
    String? ru;
    String? first;
    for (final raw in items) {
      if (raw is! Map) continue;
      final value = raw['text']?.toString();
      if (value == null || value.isEmpty) continue;
      first ??= value;
      final itemLang = raw['lang']?.toString().toUpperCase();
      if (itemLang == lang) byLang = value;
      if (itemLang == 'RU') ru = value;
    }
    return byLang ?? ru ?? first;
  }
}
