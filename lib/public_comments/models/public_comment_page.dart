import 'package:freezed_annotation/freezed_annotation.dart';

import 'public_comment.dart';

part 'public_comment_page.freezed.dart';

/// One offset-paginated page of top-level comments, mirroring the
/// `PublicCommentConnection` GraphQL type: the [nodes], the [totalCount] of
/// top-level comments for the question, and whether a [hasNextPage] follows.
@freezed
abstract class PublicCommentPage with _$PublicCommentPage {
  const factory PublicCommentPage({
    @Default(<PublicComment>[]) List<PublicComment> nodes,
    @Default(0) int totalCount,
    @Default(false) bool hasNextPage,
  }) = _PublicCommentPage;

  factory PublicCommentPage.fromJson(Map<String, dynamic> json) {
    final nodes = json['nodes'];
    return PublicCommentPage(
      nodes: nodes is List
          ? nodes
                .whereType<Map>()
                .map((e) => PublicComment.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      hasNextPage: json['hasNextPage'] == true,
    );
  }
}
