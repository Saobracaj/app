import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../data/public_comments_repository.dart';
import 'moderation_events.dart';
import 'moderation_state.dart';

/// Drives the moderation feed: loads every comment (newest first) with scroll
/// pagination, and lets a moderator delete a comment or ban its author from
/// commenting. Reachable only for users holding the `moderate_comments`
/// permission (the settings entry is gated on it).
@injectable
class ModerationBloc extends Bloc<ModerationEvent, ModerationState> {
  ModerationBloc(this._comments) : super(const ModerationState()) {
    on<ModerationStarted>(_onStarted);
    on<ModerationLoadMore>(_onLoadMore);
    on<ModerationCommentDeleted>(_onDeleted);
    on<ModerationUserBanned>(_onBanned);
  }

  final PublicCommentsRepository _comments;

  Future<void> _onStarted(
    ModerationStarted event,
    Emitter<ModerationState> emit,
  ) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final page = await _comments.allComments(offset: 0);
      emit(
        state.copyWith(
          loading: false,
          comments: page.nodes,
          hasNextPage: page.hasNextPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onLoadMore(
    ModerationLoadMore event,
    Emitter<ModerationState> emit,
  ) async {
    if (state.loadingMore || !state.hasNextPage) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _comments.allComments(offset: state.comments.length);
      emit(
        state.copyWith(
          loadingMore: false,
          comments: [...state.comments, ...page.nodes],
          hasNextPage: page.hasNextPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingMore: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onDeleted(
    ModerationCommentDeleted event,
    Emitter<ModerationState> emit,
  ) async {
    try {
      await _comments.moderateDeleteComment(event.id);
      emit(
        state.copyWith(
          comments: state.comments
              .where((c) => c.id != event.id)
              .toList(growable: false),
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
    }
  }

  Future<void> _onBanned(
    ModerationUserBanned event,
    Emitter<ModerationState> emit,
  ) async {
    try {
      await _comments.moderateSetCommentBan(event.userId, event.banned);
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
    }
  }

  String _message(Object e) =>
      e is GraphqlException ? e.message : 'Не удалось загрузить комментарии';
}
