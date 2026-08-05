import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/comment_repository.dart';

part 'comment_bloc.freezed.dart';

@freezed
abstract class CommentState with _$CommentState {
  const factory CommentState({
    @Default(false) bool isBusy,
    @Default(false) bool isPublishing,
    QuestionCommentDetails? details,
    String? errorMessage,
    /// One-shot error of the publish action, surfaced via a snackbar; the
    /// loaded comment stays on screen.
    String? publishError,
  }) = _CommentState;
}

sealed class CommentEvent {}

class _LoadComment extends CommentEvent {}

/// Re-fetches the comment — dispatched after the draft editor pops with a
/// saved result.
class CommentReloadRequested extends CommentEvent {}

/// Editor action: move the comment to READY (the backend applies the draft
/// over the live text as part of the transition).
class CommentPublishPressed extends CommentEvent {}

@injectable
class CommentBloc extends Bloc<CommentEvent, CommentState> {
  CommentBloc(
    this._repository,
    @factoryParam this.questionId,
  ) : super(const CommentState()) {
    on<_LoadComment>(_onLoadComment);
    on<CommentReloadRequested>(_onLoadComment);
    on<CommentPublishPressed>(_onPublishPressed);
    add(_LoadComment());
  }

  final CommentRepository _repository;
  final int questionId;

  Future<void> _onLoadComment(CommentEvent event, Emitter<CommentState> emit) async {
    emit(state.copyWith(isBusy: true, errorMessage: null));
    try {
      final details = await _repository.fetchComment(questionId);
      emit(state.copyWith(isBusy: false, details: details, errorMessage: null));
    } catch (e) {
      emit(state.copyWith(isBusy: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onPublishPressed(
    CommentPublishPressed event,
    Emitter<CommentState> emit,
  ) async {
    if (state.isPublishing) return;
    emit(state.copyWith(isPublishing: true, publishError: null));
    try {
      final details = await _repository.publish(questionId);
      emit(state.copyWith(isPublishing: false, details: details));
    } catch (e) {
      emit(state.copyWith(isPublishing: false, publishError: e.toString()));
    }
  }
}
