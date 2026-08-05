import 'package:injectable/injectable.dart';

import '../../../../auth/data/graphql_client.dart';
import '../../../../core/app_language.dart';

/// The editorial comment of one question as the app needs it: the applied
/// [text], the unapplied [draft] and the moderation [status]. Editors (the
/// `edit_comments` permission) additionally get the RU-first picks
/// ([draftRu]/[textRu]) to prefill the draft editor — drafts are saved back in
/// RU, so the editor must not start from another language's fragment.
class QuestionCommentDetails {
  const QuestionCommentDetails({
    required this.status,
    this.text,
    this.draft,
    this.textRu,
    this.draftRu,
  });

  /// `PENDING` | `DRAFT` | `MODERATION` | `READY`.
  final String status;

  /// The live, applied text in the UI language (fallback RU → first).
  final String? text;

  /// The unapplied draft in the UI language (fallback RU → first).
  final String? draft;

  /// RU-first picks used as the editing source.
  final String? textRu;
  final String? draftRu;

  bool get isReady => status == 'READY';
}

/// Reads the moderated explanation ("comment") for a question from the backend.
///
/// Replaces the old REST `GET /comment?qid=` data source: the comment now comes
/// from the `questionComment(id:)` GraphQL query, which requires an authenticated
/// user (any logged-in learner can read). Learners are shown the live, applied
/// `text` block; users holding `edit_comments` also see the `draft`/`status`
/// and can save a new draft or publish the comment (the READY transition
/// applies the draft server-side).
@lazySingleton
class CommentRepository {
  CommentRepository(this._client);

  final GraphqlClient _client;

  static const _fields = r'''
    status
    text { items { lang text } }
    draft { items { lang text } }
  ''';

  static const _query =
      '''
    query QuestionComment(\$id: Int!) {
      questionComment(id: \$id) { $_fields }
    }
  ''';

  static const _saveDraftMutation =
      '''
    mutation SaveCommentDraft(\$id: Int!, \$draft: String!) {
      saveCommentDraft(id: \$id, draft: \$draft) { $_fields }
    }
  ''';

  static const _publishMutation =
      '''
    mutation PublishComment(\$id: Int!) {
      setCommentStatus(id: \$id, status: READY) { $_fields }
    }
  ''';

  /// Returns the comment for [questionId], or `null` when none exists yet.
  Future<QuestionCommentDetails?> fetchComment(int questionId) async {
    final data = await _client.run(
      _query,
      variables: {'id': questionId},
      authenticated: true,
    );
    return _parse(data['questionComment']);
  }

  /// Saves (replaces) the RU draft for [questionId] and returns the updated
  /// comment. Requires the `edit_comments` permission.
  Future<QuestionCommentDetails?> saveDraft(int questionId, String draft) async {
    final data = await _client.run(
      _saveDraftMutation,
      variables: {'id': questionId, 'draft': draft},
      authenticated: true,
    );
    return _parse(data['saveCommentDraft']);
  }

  /// Moves the comment to `READY`; the backend applies the pending draft over
  /// the live text as part of this transition. Requires `edit_comments`.
  Future<QuestionCommentDetails?> publish(int questionId) async {
    final data = await _client.run(
      _publishMutation,
      variables: {'id': questionId},
      authenticated: true,
    );
    return _parse(data['setCommentStatus']);
  }

  QuestionCommentDetails? _parse(dynamic comment) {
    if (comment is! Map) return null;
    return QuestionCommentDetails(
      status: comment['status']?.toString() ?? 'PENDING',
      text: _pick(comment['text'], preferUiLanguage: true),
      draft: _pick(comment['draft'], preferUiLanguage: true),
      textRu: _pick(comment['text'], preferUiLanguage: false),
      draftRu: _pick(comment['draft'], preferUiLanguage: false),
    );
  }

  /// Picks one fragment out of a `{ items: [{lang, text}] }` block: the UI
  /// language when [preferUiLanguage], then `RU` (the only fully-populated
  /// language), then the first non-empty fragment.
  String? _pick(dynamic block, {required bool preferUiLanguage}) {
    if (block is! Map) return null;
    final items = block['items'];
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
    return (preferUiLanguage ? byLang : null) ?? ru ?? first;
  }
}
