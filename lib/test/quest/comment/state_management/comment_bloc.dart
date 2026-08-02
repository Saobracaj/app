import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/comment_repository.dart';

part 'comment_bloc.freezed.dart';

@freezed
abstract class CommentState with _$CommentState {
  const factory CommentState({
    @Default(false) bool isBusy,
    String? text,
    String? errorMessage,
  }) = _CommentState;
}

sealed class CommentEvent {}
class _LoadComment extends CommentEvent {}

@injectable
class CommentBloc extends Bloc<CommentEvent, CommentState> {
  CommentBloc(
    this._repository,
    @factoryParam this.questionId,
  ) : super(const CommentState()) {
    on<_LoadComment>(_onLoadComment);
    add(_LoadComment());
  }

  final CommentRepository _repository;
  final int questionId;

  Future<void> _onLoadComment(_LoadComment event, Emitter<CommentState> emit) async {
    emit(state.copyWith(isBusy: true, errorMessage: null));
    try {
      final comment = await _repository.fetchComment(questionId);
      emit(state.copyWith(isBusy: false, text: comment, errorMessage: null));
    } catch (e) {
      emit(state.copyWith(isBusy: false, errorMessage: e.toString()));
    }
  }
}
