import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/graphql_client.dart';
import '../models/question_list_share.dart';

/// Why a share link did not resolve — the two `extensions.code` values
/// `saobracaj_backend` tells apart, plus everything else.
enum SharedListFailure {
  /// Unknown code, or the owner revoked the link.
  linkInvalid,

  /// The link is live but the author has deleted the list.
  listDeleted,

  /// Network, server, anything else — worth a retry.
  other,
}

/// A share link that did not resolve. Carries the [SharedListFailure] the UI
/// picks its wording by.
class SharedListException implements Exception {
  SharedListException(this.failure, [this.cause]);

  final SharedListFailure failure;
  final Object? cause;

  @override
  String toString() => 'SharedListException($failure, $cause)';
}

/// The share links of the user's custom question lists, and the preview a
/// recipient sees — the client side of `saobracaj_backend`'s `shared_lists`.
///
/// Sharing produces a short code pointing at the owner's list (the link shows
/// the list's *current* state); "save to my lists" is an ordinary
/// `createQuestionList` done through [QuestionListsRepository] with a fresh id,
/// after which the copy has no tie to the original.
///
/// The repository also remembers the code a signed-out visitor wanted to save,
/// so the import can be finished right after they sign in (the code must not be
/// lost across the redirect to the login screen).
@lazySingleton
class SharedListsRepository {
  SharedListsRepository(this._client);

  final GraphqlClient _client;

  static const _pendingImportKey = 'shared_list_pending_import';
  static const _pendingImportAtKey = 'shared_list_pending_import_at';

  /// A pending import older than this is forgotten: the visitor who wanted the
  /// list an hour ago and signs in next week should not get it silently.
  static const pendingImportTtl = Duration(hours: 1);

  static const _shareFields = 'code url listId';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Share a list: the backend returns its active share, creating one if
  /// there is none — sharing twice hands back the same code.
  Future<QuestionListShare> share(String listId) async {
    final data = await _client.run(
      '''
        mutation ShareQuestionList(\$listId: ID!) {
          shareQuestionList(listId: \$listId) { $_shareFields }
        }
      ''',
      variables: {'listId': listId},
      authenticated: true,
    );
    final raw = data['shareQuestionList'];
    if (raw is! Map) throw GraphqlException('Empty server response');
    return QuestionListShare.fromJson(raw.cast<String, dynamic>());
  }

  /// Withdraw a list's link. Sharing again afterwards mints a new code; the
  /// old link stays dead.
  Future<void> revoke(String listId) async {
    await _client.run(
      r'''
        mutation RevokeQuestionListShare($listId: ID!) {
          revokeQuestionListShare(listId: $listId)
        }
      ''',
      variables: {'listId': listId},
      authenticated: true,
    );
  }

  /// The caller's active shares, one per shared list.
  Future<List<QuestionListShare>> myShares() async {
    final data = await _client.run(
      'query MyQuestionListShares { myQuestionListShares { $_shareFields } }',
      authenticated: true,
    );
    final raw = data['myQuestionListShares'];
    if (raw is! List) return const [];
    return raw
        .map(
          (e) => QuestionListShare.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// What a link leads to. Works for guests; a signed-in viewer's token is sent
  /// along (when there is one) so the backend can tell an owner they are looking
  /// at their own list. Throws [SharedListException] with the failure kind.
  Future<SharedListPreview> preview(String code) async {
    try {
      final data = await _client.run(
        r'''
          query SharedQuestionList($code: String!) {
            sharedQuestionList(code: $code) {
              code name color questionIds ownerDisplayName viewerIsOwner listId
            }
          }
        ''',
        variables: {'code': code},
        // Goes out anonymously when there is no session — see
        // `GraphqlClient._ensureFreshAccessToken`.
        authenticated: true,
      );
      final raw = data['sharedQuestionList'];
      if (raw is! Map) throw GraphqlException('Empty server response');
      return SharedListPreview.fromJson(raw.cast<String, dynamic>());
    } on GraphqlException catch (e) {
      throw SharedListException(switch (e.code) {
        'share_link_invalid' => SharedListFailure.linkInvalid,
        'share_list_deleted' => SharedListFailure.listDeleted,
        // A malformed code is rejected by the server's validation before any
        // lookup; to the recipient that is the same "this link is no good".
        'validation_error' => SharedListFailure.linkInvalid,
        _ => SharedListFailure.other,
      }, e);
    }
  }

  // ---- the import a guest asked for before signing in ----

  /// Remember that the visitor wants to save the list behind [code] as soon as
  /// they are signed in.
  Future<void> setPendingImport(String code) async {
    final prefs = await _prefs;
    await prefs.setString(_pendingImportKey, code);
    await prefs.setInt(
      _pendingImportAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// The code waiting to be imported, if any and not stale — without
  /// consuming it (see [takePendingImport]).
  Future<String?> peekPendingImport() async {
    final prefs = await _prefs;
    final code = prefs.getString(_pendingImportKey);
    if (code == null || code.isEmpty) return null;
    final at = prefs.getInt(_pendingImportAtKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    if (age > pendingImportTtl.inMilliseconds) {
      await clearPendingImport();
      return null;
    }
    return code;
  }

  /// Consume the pending code: returns it once and forgets it.
  Future<String?> takePendingImport() async {
    final code = await peekPendingImport();
    if (code != null) await clearPendingImport();
    return code;
  }

  Future<void> clearPendingImport() async {
    final prefs = await _prefs;
    await prefs.remove(_pendingImportKey);
    await prefs.remove(_pendingImportAtKey);
  }
}
