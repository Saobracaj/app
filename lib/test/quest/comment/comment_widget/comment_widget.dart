import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/test/quest/presentation/quest_markdown.dart';

import '../../../../auth/state_management/auth/auth_bloc.dart';
import '../../../../core/di.dart';
import '../../../../generated/locale_keys.g.dart';
import '../data/comment_repository.dart';
import '../state_management/comment_bloc.dart';

class CommentWidget extends StatelessWidget {
  final int questionId;

  const CommentWidget({super.key, required this.questionId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CommentBloc>(param1: questionId),
      child: BlocConsumer<CommentBloc, CommentState>(
        listenWhen: (prev, curr) =>
            curr.publishError != null && prev.publishError != curr.publishError,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.publishError!)));
        },
        builder: (context, state) {
          if (state.isBusy) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Text('Error: ${state.errorMessage}');
          }

          // Editors (backend `edit_comments` permission) see the unpublished
          // draft instead of the applied text, plus the admin strip.
          final isEditor = context
                  .watch<AuthBloc>()
                  .state
                  .viewer
                  ?.permissions
                  .contains('edit_comments') ??
              false;
          final details = state.details;
          final showingDraft = isEditor &&
              details != null &&
              !details.isReady &&
              (details.draft?.isNotEmpty ?? false);
          final text = showingDraft ? details.draft : details?.text;

          if (!isEditor && (text == null || text.isEmpty)) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEditor)
                _EditorPanel(
                  questionId: questionId,
                  details: details,
                  isPublishing: state.isPublishing,
                ),
              if (text != null && text.isNotEmpty)
                QuestMarkdown(
                  text: text,
                  padding: const EdgeInsets.all(16),
                  useLargeText: false,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Admin strip above the comment for `edit_comments` holders: the status mark
/// (signalling that the content below is a draft, not what learners see) and
/// the publish/edit actions.
class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.questionId,
    required this.details,
    required this.isPublishing,
  });

  final int questionId;
  final QuestionCommentDetails? details;
  final bool isPublishing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isReady = details?.isReady ?? false;
    final hasContent = (details?.draft ?? details?.text)?.isNotEmpty ?? false;

    final mark = switch (details?.status ?? 'PENDING') {
      'READY' => null,
      'MODERATION' => LocaleKeys.commentAdmin_moderation.tr(),
      'DRAFT' => LocaleKeys.commentAdmin_draft.tr(),
      _ => LocaleKeys.commentAdmin_noComment.tr(),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (mark != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 18,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mark,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          if (!isReady && hasContent)
            FilledButton.tonalIcon(
              onPressed: isPublishing
                  ? null
                  : () => context
                      .read<CommentBloc>()
                      .add(CommentPublishPressed()),
              icon: isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish, size: 18),
              label: Text(LocaleKeys.commentAdmin_publish.tr()),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final bloc = context.read<CommentBloc>();
              // The editor is a child route of the current question screen, so
              // "back" from it (and from the law screen inside it) unwinds to
              // this screen. A `true` result means the draft was saved.
              final result = await Routemaster.of(context)
                  .push('commentEdit?id=$questionId')
                  .result;
              if (result == true && !bloc.isClosed) {
                bloc.add(CommentReloadRequested());
              }
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(LocaleKeys.commentAdmin_edit.tr()),
          ),
        ],
      ),
    );
  }
}
