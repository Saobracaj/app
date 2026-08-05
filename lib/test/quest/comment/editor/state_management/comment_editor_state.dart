import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_editor_state.freezed.dart';

@freezed
abstract class CommentEditorState with _$CommentEditorState {
  const factory CommentEditorState({
    @Default(true) bool isLoading,
    @Default(false) bool isSaving,
    /// When true the current [text] is rendered as markdown instead of being
    /// editable — the "предпросмотр" mode.
    @Default(false) bool isPreview,
    /// The draft being edited (RU fragment — drafts are saved back in RU).
    @Default('') String text,
    String? loadError,
    /// One-shot save failure, surfaced via a snackbar.
    String? saveError,
    /// Set after a successful save; the page pops itself with a `true` result
    /// so the comment view behind it reloads.
    @Default(false) bool saved,
  }) = _CommentEditorState;
}
