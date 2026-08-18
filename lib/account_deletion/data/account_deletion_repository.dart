import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../models/account_deletion_preview.dart';

/// The account-deletion API of `saobracaj_backend`: the preview, the e-mailed
/// confirmation code and the deletion itself. Every call needs a signed-in
/// session — the account deleted is always the caller's own.
@lazySingleton
class AccountDeletionRepository {
  AccountDeletionRepository(this._client);

  final GraphqlClient _client;

  static const _previewQuery = r'''
    query AccountDeletionPreview {
      accountDeletionPreview {
        email hasActiveSubscription subscriptionUntil
        publicCommentCount supportAttachmentCount supportMessageCount
        ownedGroupCount groupMembershipCount groupActivityCount
      }
    }
  ''';

  static const _requestMutation = r'''
    mutation RequestAccountDeletion { requestAccountDeletion }
  ''';

  static const _deleteMutation = r'''
    mutation DeleteAccount($input: DeleteAccountInput!) {
      deleteAccount(input: $input) { deleted }
    }
  ''';

  /// The counts and the subscription warning the deletion screen shows.
  Future<AccountDeletionPreview> preview() async {
    final data = await _client.run(_previewQuery, authenticated: true);
    final preview = data['accountDeletionPreview'];
    if (preview is! Map) return const AccountDeletionPreview();
    return AccountDeletionPreview.fromJson(preview.cast<String, dynamic>());
  }

  /// E-mail a fresh confirmation code to the account address.
  Future<void> requestCode() async {
    await _client.run(_requestMutation, authenticated: true);
  }

  /// Delete (anonymise) the account. Throws [GraphqlException] with the
  /// server's message on a wrong/expired code or a missing confirmation.
  Future<bool> deleteAccount({
    required String code,
    required bool deletePublicComments,
    required bool deleteChatAttachments,
    required bool deleteSupportChat,
    required bool deleteGroupHistory,
    required bool acceptIrreversible,
    required bool acceptSubscriptionLoss,
  }) async {
    final data = await _client.run(
      _deleteMutation,
      variables: {
        'input': {
          'code': code,
          'deletePublicComments': deletePublicComments,
          'deleteChatAttachments': deleteChatAttachments,
          'deleteSupportChat': deleteSupportChat,
          'deleteGroupHistory': deleteGroupHistory,
          'acceptIrreversible': acceptIrreversible,
          'acceptSubscriptionLoss': acceptSubscriptionLoss,
        },
      },
      authenticated: true,
    );
    final result = data['deleteAccount'];
    return result is Map && result['deleted'] == true;
  }
}
