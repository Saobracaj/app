import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_list_share.freezed.dart';

/// An active share link of one of the user's custom lists — the
/// `QuestionListShare` GraphQL type of `saobracaj_backend`.
///
/// One share is active per list; sharing again returns the same code. The link
/// resolves the list's *current* state until the owner revokes it.
@freezed
abstract class QuestionListShare with _$QuestionListShare {
  const factory QuestionListShare({
    /// The short code (eight upper-case characters).
    required String code,

    /// The full link to hand out: `https://saobracaj.gleb.at/shared/<code>`.
    required String url,

    /// The list this share points at.
    required String listId,
  }) = _QuestionListShare;

  factory QuestionListShare.fromJson(Map<String, dynamic> json) {
    return QuestionListShare(
      code: json['code']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      listId: json['listId']?.toString() ?? '',
    );
  }
}

/// What a share link leads to — the `SharedQuestionListPreview` GraphQL type:
/// the owner's list as it is *right now*, plus who shared it.
@freezed
abstract class SharedListPreview with _$SharedListPreview {
  const factory SharedListPreview({
    required String code,
    @Default('') String name,

    /// ARGB, same encoding as `QuestionList.color`.
    @Default(0) int color,

    /// Every question id in the owner's order — needed to copy the list.
    @Default(<int>[]) List<int> questionIds,

    /// The owner's display name, or `null` when they never set one (never an
    /// e-mail).
    String? ownerDisplayName,

    /// Whether the viewer is looking at their own list.
    @Default(false) bool viewerIsOwner,

    /// The list's own id — only when [viewerIsOwner], `null` otherwise.
    String? listId,
  }) = _SharedListPreview;

  const SharedListPreview._();

  int get questionCount => questionIds.length;

  factory SharedListPreview.fromJson(Map<String, dynamic> json) {
    final rawIds = json['questionIds'];
    return SharedListPreview(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      color: (json['color'] as num?)?.toInt() ?? 0,
      questionIds: rawIds is List
          ? rawIds.map((e) => (e as num).toInt()).toList()
          : const [],
      ownerDisplayName: json['ownerDisplayName']?.toString(),
      viewerIsOwner: json['viewerIsOwner'] == true,
      listId: json['listId']?.toString(),
    );
  }
}
