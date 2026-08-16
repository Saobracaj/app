import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/group_posts_repository.dart';
import 'post_comments_events.dart';
import 'post_comments_state.dart';

/// The discussion under one post.
///
/// Deliberately small: comments under a post are flat and few, so there is no
/// paging and no subscription — the sheet reads them when it opens, and the
/// wall's own refresh is what brings somebody else's comment into view.
@injectable
class PostCommentsBloc extends Bloc<PostCommentsBlocEvent, PostCommentsState> {
  PostCommentsBloc(this._posts, @factoryParam String postId)
    : super(PostCommentsState(postId: postId)) {
    on<PostCommentsLoaded>(_onLoaded);
    on<PostCommentSubmitted>(_onSubmitted);
    on<PostCommentDeleted>(_onDeleted);
    on<PostCommentsErrorShown>(
      (event, emit) => emit(state.copyWith(errorMessage: null)),
    );
  }

  final GroupPostsRepository _posts;

  Future<void> _onLoaded(
    PostCommentsLoaded event,
    Emitter<PostCommentsState> emit,
  ) async {
    emit(state.copyWith(loading: true));
    try {
      final comments = await _posts.comments(state.postId);
      emit(state.copyWith(comments: comments, loading: false, loaded: true));
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: '$e'));
    }
  }

  Future<void> _onSubmitted(
    PostCommentSubmitted event,
    Emitter<PostCommentsState> emit,
  ) async {
    final body = event.body.trim();
    if (body.isEmpty || state.submitting) return;
    emit(state.copyWith(submitting: true));
    try {
      final comment = await _posts.addComment(state.postId, body);
      emit(
        state.copyWith(
          comments: [...state.comments, comment],
          submitting: false,
          loaded: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: '$e'));
    }
  }

  Future<void> _onDeleted(
    PostCommentDeleted event,
    Emitter<PostCommentsState> emit,
  ) async {
    final previous = state.comments;
    emit(
      state.copyWith(
        comments: previous.where((c) => c.id != event.commentId).toList(),
      ),
    );
    try {
      await _posts.deleteComment(event.commentId);
    } catch (e) {
      emit(state.copyWith(comments: previous, errorMessage: '$e'));
    }
  }
}
