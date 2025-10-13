import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bloc/bloc.dart';
import '../data/comment_ds.dart';

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

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final int questionId;

  CommentBloc({required this.questionId}) : super(const CommentState()) {
    on<_LoadComment>(_onLoadComment);
    add(_LoadComment());
  }

  Future<void> _onLoadComment(_LoadComment event, Emitter<CommentState> emit) async {
    emit(state.copyWith(isBusy: true, errorMessage: null));
    try {
      final comment = await commentDataSource.fetchComment(questionId);
      emit(state.copyWith(isBusy: false, text: comment, errorMessage: null));
    } catch (e) {
      emit(state.copyWith(isBusy: false, errorMessage: e.toString()));
    }
  }
}
