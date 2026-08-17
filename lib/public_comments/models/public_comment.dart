import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../generated/locale_keys.g.dart';

part 'public_comment.freezed.dart';

/// A public, user-written question comment, mirroring the `PublicComment`
/// GraphQL type in `saobracaj_backend`.
///
/// The tree is at most two levels deep: a top-level comment ([parentId] is
/// `null`) carries its [replies]; a reply has [parentId] set and no nested
/// replies of its own (the backend flattens deeper replies onto the thread).
/// Viewer-relative flags ([likedByMe], [subscribedByMe], [deletableByMe]) are
/// resolved for the calling user and are `false` for guests.
@freezed
abstract class PublicComment with _$PublicComment {
  const factory PublicComment({
    required String id,
    required int questionId,
    String? parentId,
    @Default('') String authorId,
    @Default('') String authorDisplayName,
    @Default('') String body,
    @Default(false) bool deleted,
    required DateTime createdAt,
    @Default(0) int likesCount,
    @Default(false) bool likedByMe,
    @Default(0) int repliesCount,
    @Default(false) bool subscribedByMe,
    @Default(false) bool deletableByMe,
    @Default(<PublicComment>[]) List<PublicComment> replies,
  }) = _PublicComment;

  const PublicComment._();

  factory PublicComment.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'];
    return PublicComment(
      id: json['id'].toString(),
      questionId: (json['questionId'] as num?)?.toInt() ?? 0,
      parentId: json['parentId']?.toString(),
      authorId: json['authorId']?.toString() ?? '',
      authorDisplayName: json['authorDisplayName']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      deleted: json['deleted'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
      repliesCount: (json['repliesCount'] as num?)?.toInt() ?? 0,
      subscribedByMe: json['subscribedByMe'] == true,
      deletableByMe: json['deletableByMe'] == true,
      replies: rawReplies is List
          ? rawReplies
                .whereType<Map>()
                .map((e) => PublicComment.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  /// Whether this is a reply (second level) rather than a top-level comment.
  bool get isReply => parentId != null;

  /// The author erased this comment along with their account: the backend
  /// blanks the body and flags the row (`PublicComment.deleted`), and we render
  /// a localised placeholder — see [displayBody].
  ///
  /// The flag is the only source of truth. Never infer deletion from the body
  /// text: a user is free to write a comment that literally says «deleted».
  bool get isDeleted => deleted;

  /// The text to show: the body, or the «message deleted» placeholder.
  String get displayBody =>
      isDeleted ? LocaleKeys.comments_deletedBody.tr() : body;
}
