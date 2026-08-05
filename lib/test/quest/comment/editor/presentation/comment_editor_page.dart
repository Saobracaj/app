import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/test/quest/presentation/quest_markdown.dart';

import '../../../../../core/di.dart';
import '../../../../../generated/locale_keys.g.dart';
import '../state_management/comment_editor_bloc.dart';
import '../state_management/comment_editor_events.dart';
import '../state_management/comment_editor_state.dart';

/// Plain-text editor of a question comment draft (admin-only, behind the
/// `edit_comments` permission). No syntax highlighting on purpose — the
/// markdown is edited as raw text; a separate toolbar button switches to a
/// rendered preview where law links work: they push the law screen as a child
/// route, so "back" returns here with the editing state intact.
class CommentEditorPage extends StatelessWidget {
  const CommentEditorPage({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CommentEditorBloc>(param1: questionId),
      child: BlocConsumer<CommentEditorBloc, CommentEditorState>(
        listenWhen: (prev, curr) =>
            (!prev.saved && curr.saved) ||
            (curr.saveError != null && prev.saveError != curr.saveError),
        listener: (context, state) {
          if (state.saved) {
            // `true` tells the comment view behind this page to reload.
            Routemaster.of(context).pop(true);
            return;
          }
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.saveError!)));
        },
        builder: (context, state) {
          final bloc = context.read<CommentEditorBloc>();
          return Scaffold(
            appBar: AppBar(
              title: Text(
                LocaleKeys.commentAdmin_editorTitle.tr(args: ['$questionId']),
              ),
              actions: [
                if (!state.isLoading && state.loadError == null)
                  IconButton(
                    tooltip: state.isPreview
                        ? LocaleKeys.commentAdmin_backToEditing.tr()
                        : LocaleKeys.commentAdmin_preview.tr(),
                    icon: Icon(
                      state.isPreview
                          ? Icons.edit_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => bloc.add(EditorPreviewToggled()),
                  ),
              ],
            ),
            body: _Body(state: state),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Routemaster.of(context).pop(false),
                        child: Text(LocaleKeys.commentAdmin_cancel.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: state.isLoading ||
                                state.isSaving ||
                                state.loadError != null
                            ? null
                            : () => bloc.add(EditorSavePressed()),
                        child: state.isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(LocaleKeys.commentAdmin_save.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final CommentEditorState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: ${state.loadError}'),
        ),
      );
    }
    if (state.isPreview) {
      return SingleChildScrollView(
        child: QuestMarkdown(
          text: state.text,
          padding: const EdgeInsets.all(16),
          useLargeText: false,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextFormField(
        initialValue: state.text,
        onChanged: (value) =>
            context.read<CommentEditorBloc>().add(EditorTextChanged(value)),
        maxLines: null,
        minLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: LocaleKeys.commentAdmin_hint.tr(),
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
