import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/shared_lists_repository.dart';
import '../models/question_list_share.dart';

part 'shared_list_state.freezed.dart';

/// State of the `/shared/<code>` screen: the preview a recipient sees and the
/// progress of "save to my lists".
@freezed
sealed class SharedListState with _$SharedListState {
  const SharedListState._();

  const factory SharedListState({
    /// The code from the URL, in the shape it arrived.
    required String code,

    /// The list behind the link, once resolved.
    SharedListPreview? preview,

    /// Whether the preview is being (re)loaded.
    @Default(true) bool loading,

    /// Why the link did not resolve, if it did not.
    SharedListFailure? failure,

    /// Whether the copy is being created.
    @Default(false) bool importing,

    /// One-shot: the id of the freshly created copy — the screen navigates to
    /// it. Cleared by `SharedListImportHandled`.
    String? importedListId,

    /// One-shot: the visitor is signed out and asked to save; the screen sends
    /// them to the login screen (the code is remembered meanwhile).
    @Default(false) bool signInRequired,

    /// One-shot: the copy could not be created (the optimistic list has been
    /// rolled back already); surfaced as a snackbar.
    @Default(false) bool importFailed,
  }) = _SharedListState;
}
