import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/comment_repository.dart';
import 'comment_editor_events.dart';
import 'comment_editor_state.dart';

/// Drives the plain-text draft editor of a question comment (an admin-only
/// screen behind the `edit_comments` permission). Loads the current draft,
/// tracks edits and the preview toggle, and saves via `saveCommentDraft`.
@injectable
class CommentEditorBloc extends Bloc<CommentEditorEvent, CommentEditorState> {
  CommentEditorBloc(
    this._repository,
    @factoryParam this.questionId,
  ) : super(const CommentEditorState()) {
    on<EditorStarted>(_onStarted);
    on<EditorTextChanged>((event, emit) => emit(state.copyWith(text: event.text)));
    on<EditorPreviewToggled>(
      (event, emit) => emit(state.copyWith(isPreview: !state.isPreview)),
    );
    on<EditorSavePressed>(_onSavePressed);
    add(EditorStarted());
  }

  final CommentRepository _repository;
  final int questionId;

  Future<void> _onStarted(
    EditorStarted event,
    Emitter<CommentEditorState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, loadError: null));
    try {
      final details = await _repository.fetchComment(questionId);
      emit(state.copyWith(
        isLoading: false,
        text: details?.draftRu ?? details?.textRu ?? '',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, loadError: e.toString()));
    }
  }

  Future<void> _onSavePressed(
    EditorSavePressed event,
    Emitter<CommentEditorState> emit,
  ) async {
    if (state.isSaving) return;
    emit(state.copyWith(isSaving: true, saveError: null));
    try {
      await _repository.saveDraft(questionId, state.text);
      emit(state.copyWith(isSaving: false, saved: true));
    } catch (e) {
      emit(state.copyWith(isSaving: false, saveError: e.toString()));
    }
  }
}
