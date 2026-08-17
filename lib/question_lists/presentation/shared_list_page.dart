import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../core/di.dart';
import '../../core/responsive.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../../models/models.dart';
import '../../questions/presentation/question_list_tile.dart';
import '../../questions/state_management/all_questions_bloc.dart';
import '../data/shared_lists_repository.dart';
import '../models/question_list.dart';
import '../models/question_list_share.dart';
import '../state_management/shared_list_bloc.dart';
import '../state_management/shared_list_events.dart';
import '../state_management/shared_list_state.dart';
import 'question_lists_section.dart';

/// How many of the list's questions the preview lists before "and N more".
const int kSharedListPreviewQuestions = 5;

/// Where a share link lands: `https://saobracaj.gleb.at/shared/<code>` — both
/// the web page a messenger opens and the deep link the app claims.
///
/// Shows the owner's list as it is right now (name, colour, author, how many
/// questions, the first few of them) and offers to save a copy. A guest sees
/// everything and is sent to sign in on "save"; the code is remembered so the
/// import finishes once they are back. The owner is offered to open the list
/// instead of copying it.
class SharedListPage extends StatelessWidget {
  const SharedListPage({super.key, required this.code});

  /// The code as it came out of the URL.
  final String code;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<SharedListBloc>(param1: code)..add(SharedListStarted()),
      child: BlocConsumer<SharedListBloc, SharedListState>(
        listenWhen: (prev, curr) =>
            prev.importedListId != curr.importedListId ||
            prev.signInRequired != curr.signInRequired ||
            prev.importFailed != curr.importFailed,
        listener: (context, state) {
          final bloc = context.read<SharedListBloc>();
          if (state.importedListId != null) {
            final id = state.importedListId!;
            bloc.add(SharedListImportHandled());
            // The copy replaces this screen: "back" from the new list should
            // not return to the preview and offer a second copy.
            Routemaster.of(context).replace('/lists/$id');
          } else if (state.signInRequired) {
            bloc.add(SharedListImportHandled());
            Routemaster.of(context).push('/login');
          } else if (state.importFailed) {
            bloc.add(SharedListImportHandled());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  LocaleKeys.questionLists_shared_importFailed.tr(),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(LocaleKeys.questionLists_shared_title.tr()),
            ),
            body: _Body(state: state),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final SharedListState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final failure = state.failure;
    if (failure != null) return _FailureView(failure: failure);
    final preview = state.preview;
    if (preview == null) {
      return const _FailureView(failure: SharedListFailure.other);
    }
    return _PreviewView(preview: preview, state: state);
  }
}

/// A dead link, a deleted list, or a load that did not go through — one line
/// of text and a way out (retry, or home).
class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure});

  final SharedListFailure failure;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure) {
      SharedListFailure.linkInvalid =>
        LocaleKeys.questionLists_shared_linkInvalid.tr(),
      SharedListFailure.listDeleted =>
        LocaleKeys.questionLists_shared_listDeleted.tr(),
      SharedListFailure.other =>
        LocaleKeys.questionLists_shared_loadFailed.tr(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failure == SharedListFailure.other
                  ? Icons.cloud_off_outlined
                  : Icons.link_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (failure == SharedListFailure.other)
              FilledButton(
                onPressed: () =>
                    context.read<SharedListBloc>().add(SharedListStarted()),
                child: Text(LocaleKeys.questionLists_shared_retry.tr()),
              )
            else
              FilledButton(
                onPressed: () => Routemaster.of(context).replace('/home'),
                child: Text(LocaleKeys.questionLists_shared_openApp.tr()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({required this.preview, required this.state});

  final SharedListPreview preview;
  final SharedListState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = context.select(
      (AuthBloc b) => b.state.status == AuthStatus.authenticated,
    );
    final flags = context.watch<FeatureFlagsBloc>().state;
    final all = context.select(
      (AllQuestionsBloc b) => b.state.questionsData?.questions,
    );
    // The bank is a bundled asset; `null` only while it is still being read.
    final questions = <Question>[
      if (all != null)
        for (final id in preview.questionIds)
          ...all.where((q) => q.id == id).take(1),
    ];
    // "Available for free" = the question's premium content is open to this
    // viewer (free category, or a subscription). Every question is answerable
    // regardless — the gate sits on the question, not on the list.
    final free = questions
        .where(
          (q) => flags.isEnabledForCategory(
            AppFeature.questionComments,
            q.categoryId,
          ),
        )
        .length;
    final showFreeCounter = all != null && free < questions.length;

    final asList = QuestionList(
      id: 'shared:${preview.code}',
      name: preview.name,
      color: preview.color,
      questionIds: preview.questionIds,
    );

    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                QuestionListAvatar(list: asList, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.name,
                        style: theme.textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (preview.ownerDisplayName != null)
                        Text(
                          LocaleKeys.questionLists_shared_by.tr(
                            args: [preview.ownerDisplayName!],
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        LocaleKeys.questionLists_questionsCount.tr(
                          args: ['${preview.questionCount}'],
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showFreeCounter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _FreeCounter(free: free, total: questions.length),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _SaveArea(
              preview: preview,
              state: state,
              signedIn: signedIn,
            ),
          ),
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            for (final question in questions.take(kSharedListPreviewQuestions))
              QuestionListTile(
                question: question,
                onTap: () => _openQuestion(context, question.id),
              ),
            if (questions.length > kSharedListPreviewQuestions)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  LocaleKeys.questionLists_shared_andMore.tr(
                    args: ['${questions.length - kSharedListPreviewQuestions}'],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// «12 из 30 доступны бесплатно» — an honest count for a viewer without a
/// subscription when the list holds questions from paid categories. Not a
/// blocker: the list is saved whole, the gate stays on the questions.
class _FreeCounter extends StatelessWidget {
  const _FreeCounter({required this.free, required this.total});

  final int free;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_open_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              LocaleKeys.questionLists_shared_freeCount.tr(
                args: ['$free', '$total'],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The call to action: "save to my lists" (with a sign-in hint for guests), or
/// "open" when the viewer owns the list.
class _SaveArea extends StatelessWidget {
  const _SaveArea({
    required this.preview,
    required this.state,
    required this.signedIn,
  });

  final SharedListPreview preview;
  final SharedListState state;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (preview.viewerIsOwner) {
      final ownId = preview.listId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.questionLists_shared_yourOwn.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (ownId != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => Routemaster.of(context).replace('/lists/$ownId'),
              child: Text(LocaleKeys.questionLists_shared_openList.tr()),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: state.importing
              ? null
              : () => context.read<SharedListBloc>().add(
                  SharedListSaveRequested(),
                ),
          icon: state.importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add),
          label: Text(LocaleKeys.questionLists_shared_save.tr()),
        ),
        if (!signedIn) ...[
          const SizedBox(height: 8),
          Text(
            LocaleKeys.questionLists_shared_signInToSave.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

void _openQuestion(BuildContext context, int questionId) {
  Routemaster.of(context).push('q?q=$questionId&randomOptionsOrder=true');
}
