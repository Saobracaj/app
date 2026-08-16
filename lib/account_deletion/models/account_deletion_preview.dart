import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_deletion_preview.freezed.dart';

/// What deleting the account would affect — mirrors the backend's
/// `AccountDeletionPreview` (`accountDeletionPreview` query).
@freezed
abstract class AccountDeletionPreview with _$AccountDeletionPreview {
  const factory AccountDeletionPreview({
    @Default('') String email,
    @Default(false) bool hasActiveSubscription,
    DateTime? subscriptionUntil,
    @Default(0) int publicCommentCount,
    @Default(0) int supportAttachmentCount,
    @Default(0) int supportMessageCount,
    @Default(0) int ownedGroupCount,
    @Default(0) int groupMembershipCount,
    @Default(0) int groupActivityCount,
  }) = _AccountDeletionPreview;

  const AccountDeletionPreview._();

  factory AccountDeletionPreview.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    return AccountDeletionPreview(
      email: json['email']?.toString() ?? '',
      hasActiveSubscription: json['hasActiveSubscription'] == true,
      subscriptionUntil: DateTime.tryParse(
        json['subscriptionUntil']?.toString() ?? '',
      )?.toLocal(),
      publicCommentCount: count('publicCommentCount'),
      supportAttachmentCount: count('supportAttachmentCount'),
      supportMessageCount: count('supportMessageCount'),
      ownedGroupCount: count('ownedGroupCount'),
      groupMembershipCount: count('groupMembershipCount'),
      groupActivityCount: count('groupActivityCount'),
    );
  }
}
