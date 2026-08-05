sealed class CommentEditorEvent {}

/// Initial load (and retry): fetches the comment and prefills the editor with
/// the pending draft, falling back to the applied text.
class EditorStarted extends CommentEditorEvent {}

class EditorTextChanged extends CommentEditorEvent {
  EditorTextChanged(this.text);

  final String text;
}

class EditorPreviewToggled extends CommentEditorEvent {}

class EditorSavePressed extends CommentEditorEvent {}
