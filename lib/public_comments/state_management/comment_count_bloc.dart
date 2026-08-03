import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../data/public_comments_repository.dart';
import 'comment_count_events.dart';
import 'comment_count_state.dart';

/// Loads the top-level comment count for a single question so the "Дискусија"
/// tab can show a badge. Kept separate from [CommentsBloc] because the badge
/// lives on the tab bar (outside the tab content, where the full comments Bloc
/// is scoped) and only needs the scalar count.
@injectable
class CommentCountBloc extends Bloc<CommentCountEvent, CommentCountState> {
  CommentCountBloc(
    this._comments,
    this._authBloc,
    @factoryParam this.questionId,
  ) : super(const CommentCountState()) {
    on<CommentCountRequested>((event, emit) async {
      try {
        final count = await _comments.questionCommentCount(
          questionId,
          authenticated: _authBloc.state.isAuthenticated,
        );
        emit(CommentCountState(count: count));
      } catch (_) {
        // Best-effort: on failure the badge just stays hidden.
      }
    });
  }

  final PublicCommentsRepository _comments;
  final AuthBloc _authBloc;
  final int questionId;
}
