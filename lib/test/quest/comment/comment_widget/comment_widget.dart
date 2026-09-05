import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/test/quest/presentation/quest_markdown.dart';

import '../../../../auth/state_management/auth/auth_bloc.dart';
import '../../../../core/di.dart';
import '../../../../core/presentation/load_failed_view.dart';
import '../../../../generated/locale_keys.g.dart';
import '../../../../subscription/presentation/paywall.dart';
import '../state_management/comment_bloc.dart';
import 'comment_editor_panel.dart';

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.publishError!)));
        },
        builder: (context, state) {
          if (state.isBusy) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            // Inline "no network" / error with a retry; the Bloc also reloads
            // by itself once the connection is back.
            return LoadFailedView(
              compact: true,
              offline: state.offline,
              message: state.errorMessage,
              onRetry: () =>
                  context.read<CommentBloc>().add(CommentReloadRequested()),
            );
          }

          // Editors (backend `edit_comments` permission) see the unpublished
          // draft instead of the applied text, plus the admin strip. This also
          // covers an already-published (READY) comment: an edit is saved as a
          // draft over the live text, so without this the editor would keep
          // seeing the old text and think the change was lost.
          final isEditor =
              context.watch<AuthBloc>().state.viewer?.permissions.contains(
                'edit_comments',
              ) ??
              false;
          final details = state.details;
          final showingDraft = isEditor && (details?.showsDraft ?? false);
          final text = showingDraft ? details!.draft : details?.text;

          if (!isEditor && (text == null || text.isEmpty)) {
            return const SizedBox.shrink();
          }
          // Outside the free categories and without the pass the backend sends
          // the first lines only — the point of pain is exactly here, after a
          // wrong answer, so this is where the offer stands.
          if (!isEditor && (details?.locked ?? false)) {
            return LockedContentCard(
              source: PaywallSource.explanation,
              questionId: questionId,
              title: LocaleKeys.subscription_lockedExplanationTitle.tr(),
              body: LocaleKeys.subscription_lockedExplanationBody.tr(),
              preview: QuestMarkdown(
                text: text!,
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                useLargeText: false,
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEditor)
                CommentEditorPanel(
                  details: details,
                  isPublishing: state.isPublishing,
                  onPublish: () =>
                      context.read<CommentBloc>().add(CommentPublishPressed()),
                  onEdit: () => _openEditor(context),
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

  Future<void> _openEditor(BuildContext context) async {
    final bloc = context.read<CommentBloc>();
    // The editor is a child route of the current question screen, so "back"
    // from it (and from the law screen inside it) unwinds to this screen. A
    // `true` result means the draft was saved.
    final result = await Routemaster.of(
      context,
    ).push('commentEdit?id=$questionId').result;
    if (result == true && !bloc.isClosed) {
      bloc.add(CommentReloadRequested());
    }
  }
}
