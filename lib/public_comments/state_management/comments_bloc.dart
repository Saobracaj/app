import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../../profile/data/profile_repository.dart';
import '../data/public_comments_repository.dart';
import '../models/public_comment.dart';
import 'comments_events.dart';
import 'comments_state.dart';

/// Drives the public-comments panel for a single question.
///
/// Reads are public (sent authenticated only when a session exists, to populate
/// the viewer-relative flags). Likes are **optimistic**: the UI flips
/// immediately and rolls back if the request fails. Writes (post/reply/delete)
/// refetch the first page so the server-side ordering (by likes) stays correct.
///
/// The backend also offers a realtime `questionCommentsChanged` subscription;
/// the HTTP-only [GraphqlClient] can't consume it yet, so this Bloc refreshes
/// after its own mutations instead (true realtime is a follow-up).
@injectable
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc(
    this._comments,
    this._profiles,
    this._authBloc,
    @factoryParam this.questionId,
  ) : super(const CommentsState()) {
    on<CommentsStarted>(_onStarted);
    on<CommentsRefreshed>(_onRefreshed);
    on<CommentsLoadMore>(_onLoadMore);
    on<CommentSubmitted>(_onSubmitted);
    on<CommentDeleted>(_onDeleted);
    on<CommentLikeToggled>(_onLikeToggled);
    on<CommentSubscriptionToggled>(_onSubscriptionToggled);
    on<RepliesExpanded>(_onRepliesExpanded);
  }

  final PublicCommentsRepository _comments;
  final ProfileRepository _profiles;
  final AuthBloc _authBloc;
  final int questionId;

  bool get _isAuthenticated => _authBloc.state.isAuthenticated;

  Future<void> _onStarted(
    CommentsStarted event,
    Emitter<CommentsState> emit,
  ) async {
    final authed = _isAuthenticated;
    emit(state.copyWith(isAuthenticated: authed));
    if (authed) {
      try {
        emit(state.copyWith(profile: await _profiles.myProfile()));
      } catch (_) {
        // best-effort; the composer just stays hidden until it loads.
      }
    }
    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
    CommentsRefreshed event,
    Emitter<CommentsState> emit,
  ) => _loadFirstPage(emit);

  Future<void> _loadFirstPage(Emitter<CommentsState> emit) async {
    try {
      final page = await _comments.questionComments(
        questionId,
        offset: 0,
        authenticated: _isAuthenticated,
      );
      emit(
        state.copyWith(
          loading: false,
          comments: page.nodes,
          totalCount: page.totalCount,
          hasNextPage: page.hasNextPage,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onLoadMore(
    CommentsLoadMore event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.loadingMore || !state.hasNextPage) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _comments.questionComments(
        questionId,
        offset: state.comments.length,
        authenticated: _isAuthenticated,
      );
      emit(
        state.copyWith(
          loadingMore: false,
          comments: [...state.comments, ...page.nodes],
          totalCount: page.totalCount,
          hasNextPage: page.hasNextPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingMore: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onSubmitted(
    CommentSubmitted event,
    Emitter<CommentsState> emit,
  ) async {
    emit(state.copyWith(submitting: true, errorMessage: null));
    try {
      await _comments.addComment(
        questionId: questionId,
        parentId: event.parentId,
        body: event.body,
      );
      // Reveal the thread the reply landed in so the new reply is visible.
      final expanded = event.parentId == null
          ? state.expandedThreads
          : {...state.expandedThreads, event.parentId!};
      emit(state.copyWith(submitting: false, expandedThreads: expanded));
      await _loadFirstPage(emit);
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onDeleted(
    CommentDeleted event,
    Emitter<CommentsState> emit,
  ) async {
    try {
      await _comments.deleteComment(event.id);
      await _loadFirstPage(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
    }
  }

  Future<void> _onLikeToggled(
    CommentLikeToggled event,
    Emitter<CommentsState> emit,
  ) async {
    final original = event.comment;
    final liked = !original.likedByMe;
    final delta = liked ? 1 : -1;

    // Optimistic: flip and adjust the count right away.
    emit(
      state.copyWith(
        comments: _updateOne(
          state.comments,
          original.id,
          (c) => c.copyWith(
            likedByMe: liked,
            likesCount: (c.likesCount + delta).clamp(0, 1 << 31),
          ),
        ),
      ),
    );

    try {
      final server = liked
          ? await _comments.likeComment(original.id)
          : await _comments.unlikeComment(original.id);
      // Reconcile the count with the server (without touching replies).
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            original.id,
            (c) => c.copyWith(
              likedByMe: server.likedByMe,
              likesCount: server.likesCount,
            ),
          ),
        ),
      );
    } catch (_) {
      // Roll back to the pre-tap values.
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            original.id,
            (c) => c.copyWith(
              likedByMe: original.likedByMe,
              likesCount: original.likesCount,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _onSubscriptionToggled(
    CommentSubscriptionToggled event,
    Emitter<CommentsState> emit,
  ) async {
    final id = event.comment.id;
    emit(
      state.copyWith(
        comments: _updateOne(
          state.comments,
          id,
          (c) => c.copyWith(subscribedByMe: event.subscribed),
        ),
      ),
    );
    try {
      await _comments.setCommentSubscription(id, event.subscribed);
    } catch (_) {
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            id,
            (c) => c.copyWith(subscribedByMe: !event.subscribed),
          ),
        ),
      );
    }
  }

  void _onRepliesExpanded(RepliesExpanded event, Emitter<CommentsState> emit) {
    emit(
      state.copyWith(
        expandedThreads: {...state.expandedThreads, event.topLevelId},
      ),
    );
  }

  /// Apply [fn] to the comment with [id], whether it is top-level or a reply,
  /// returning a new list (replies are searched one level deep — the tree is at
  /// most two deep).
  List<PublicComment> _updateOne(
    List<PublicComment> list,
    String id,
    PublicComment Function(PublicComment) fn,
  ) {
    return [
      for (final c in list)
        if (c.id == id)
          fn(c)
        else if (c.replies.any((r) => r.id == id))
          c.copyWith(
            replies: [
              for (final r in c.replies)
                if (r.id == id) fn(r) else r,
            ],
          )
        else
          c,
    ];
  }

  String _message(Object e) =>
      e is GraphqlException ? e.message : 'Не удалось загрузить комментарии';
}
