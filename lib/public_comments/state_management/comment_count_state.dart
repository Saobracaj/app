import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_count_state.freezed.dart';

/// Number of top-level comments for one question, used to badge the "Дискусија"
/// tab. Loaded once when the question's feature tabs mount; the badge is hidden
/// while [count] is zero.
@freezed
abstract class CommentCountState with _$CommentCountState {
  const factory CommentCountState({@Default(0) int count}) = _CommentCountState;
}
