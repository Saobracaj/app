import 'package:injectable/injectable.dart';

import '../../../../auth/data/graphql_client.dart';
import '../../../../feature_flags/data/feature_flags_repository.dart';
import '../../../../feature_flags/domain/app_feature.dart';

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
    this.locked = false,
  });

  /// `PENDING` | `DRAFT` | `MODERATION` | `READY`.
  final String status;

  /// The caller may not read this explanation in full: [text] is only its
  /// first lines (the backend cut them at a word boundary), shown under a blur
  /// with the offer of the pass. Outside the free categories and without the
  /// entitlement — a guest included.
  final bool locked;

  /// The live, applied text in the study-content language — Serbian unless the
  /// `russian_content` feature is resolved on (falls back to the other
  /// language, then to the first non-empty fragment).
  final String? text;

  /// The unapplied draft in the study-content language (same fallbacks).
  final String? draft;

  /// RU-first picks used as the editing source.
  final String? textRu;
  final String? draftRu;

  bool get isReady => status == 'READY';

  /// Есть ли у комментария неопубликованный черновик: непустой и отличающийся
  /// от применённого текста. Сравниваются именно RU-фрагменты — редактор
  /// правит и сохраняет RU, поэтому расхождение возникает только там.
  ///
  /// Ключевой случай — уже опубликованный (`READY`) комментарий: правка
  /// уходит в `draft`, `text` остаётся прежним, и без этого признака редактор
  /// не видел бы ни своей правки, ни способа её опубликовать.
  bool get hasUnpublishedDraft {
    final draft = draftRu?.trim() ?? '';
    if (draft.isEmpty) return false;
    return draft != (textRu?.trim() ?? '');
  }

  /// Есть ли у комментария хоть какое-то содержимое (черновик или текст).
  bool get hasContent =>
      (draft?.isNotEmpty ?? false) || (text?.isNotEmpty ?? false);

  /// Показывать ли редактору черновик вместо применённого текста: только
  /// когда черновик действительно расходится с опубликованным текстом.
  bool get showsDraft => hasUnpublishedDraft && (draft?.isNotEmpty ?? false);

  /// Доступно ли действие «Опубликовать»: либо есть неопубликованный черновик
  /// (в том числе поверх `READY`-комментария), либо комментарий с содержимым
  /// ещё не переведён в `READY`.
  bool get canPublish => hasUnpublishedDraft || (!isReady && hasContent);
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
  CommentRepository(this._client, this._flags);

  final GraphqlClient _client;

  /// Decides the display language: Russian only when `russian_content` is
  /// resolved on (backend grant + the user's popup/settings opt-in), Serbian
  /// otherwise.
  final FeatureFlagsRepository _flags;

  static const _fields = r'''
    status
    locked
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
  Future<QuestionCommentDetails?> saveDraft(
    int questionId,
    String draft,
  ) async {
    final data = await _client.run(
      _saveDraftMutation,
      variables: {'id': questionId, 'draft': draft},
      authenticated: true,
    );
    return _parse(data['saveCommentDraft']);
  }

  /// Moves the comment to `READY`; the backend applies the pending draft over
  /// the live text as part of this transition (archiving the previous text in
  /// `history`). A comment that is already `READY` stays `READY` — the call is
  /// then a "publish the draft over the published text" action, which is how an
  /// editor republishes an edited comment. Requires `edit_comments`.
  Future<QuestionCommentDetails?> publish(int questionId) async {
    final data = await _client.run(
      _publishMutation,
      variables: {'id': questionId},
      authenticated: true,
    );
    return _parse(data['setCommentStatus']);
  }

  /// The text block with the comment's `locked` flag folded in, so the
  /// language pick knows it is choosing for a preview.
  dynamic _withLock(dynamic block, dynamic locked) {
    if (block is! Map || locked != true) return block;
    return {...block, 'locked': true};
  }

  QuestionCommentDetails? _parse(dynamic comment) {
    if (comment is! Map) return null;
    return QuestionCommentDetails(
      status: comment['status']?.toString() ?? 'PENDING',
      text: _pick(
        _withLock(comment['text'], comment['locked']),
        forDisplay: true,
      ),
      draft: _pick(comment['draft'], forDisplay: true),
      textRu: _pick(comment['text'], forDisplay: false),
      draftRu: _pick(comment['draft'], forDisplay: false),
      locked: comment['locked'] == true,
    );
  }

  /// Picks one fragment out of a `{ items: [{lang, text}] }` block.
  ///
  /// [forDisplay] picks the study-content language — `RU` when the
  /// `russian_content` feature is resolved on **or** merely chosen (a locked
  /// preview shows the reader the language they asked for, which is the point
  /// of the preview), `SR` otherwise — falling back to the other language while
  /// the preferred one has no fragment yet, then to the first non-empty item.
  /// The non-display variant is the RU-first editing source (drafts are edited
  /// in RU in the app).
  String? _pick(dynamic block, {required bool forDisplay}) {
    if (block is! Map) return null;
    final items = block['items'];
    if (items is! List || items.isEmpty) return null;

    final snapshot = _flags.snapshot;
    final russian =
        snapshot.russianContent ||
        (block['locked'] == true &&
            snapshot.localEnabled(AppFeature.russianContent));
    final preferred = russian ? 'RU' : 'SR';
    String? byPreferred;
    String? ru;
    String? sr;
    String? first;
    for (final raw in items) {
      if (raw is! Map) continue;
      final value = raw['text']?.toString();
      if (value == null || value.isEmpty) continue;
      first ??= value;
      final itemLang = raw['lang']?.toString().toUpperCase();
      if (itemLang == preferred) byPreferred = value;
      if (itemLang == 'RU') ru = value;
      if (itemLang == 'SR') sr = value;
    }
    if (!forDisplay) return ru ?? first;
    return byPreferred ?? (preferred == 'RU' ? sr : ru) ?? first;
  }
}
