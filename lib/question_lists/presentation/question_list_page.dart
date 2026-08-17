import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../../models/models.dart';
import '../../questions/presentation/question_list_tile.dart';
import '../../questions/state_management/all_questions_bloc.dart';
import '../domain/list_style.dart';
import '../models/question_list.dart';
import '../state_management/question_lists_bloc.dart';
import '../state_management/question_lists_events.dart';
import '../state_management/question_lists_state.dart';
import 'list_editor_dialog.dart';
import 'question_lists_section.dart';
import 'share_list_link.dart';
import 'package:saobracaj/test/start_test.dart';

/// A single question list: its questions plus a button that starts a test over
/// all of them — the same shape as the History screen.
///
/// A **custom** list gains editing while `custom_question_lists` is on: the
/// questions can be reordered and removed, and the app-bar menu offers renaming
/// / recolouring. With the flag off (premium expired) the list is read-only and
/// the menu only keeps "delete list", per the spec. **Automatic** lists are
/// always read-only.
///
/// A custom list can also be **shared**: the menu obtains a link
/// (`/shared/<code>`) and opens the system share sheet with it; while the link
/// is active the app bar shows a link icon (tap: share again) and the menu
/// offers to revoke it.
class QuestionListPage extends StatelessWidget {
  const QuestionListPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final canEdit = context.select(
      (FeatureFlagsBloc b) => b.state.isEnabled(AppFeature.customQuestionLists),
    );
    return BlocListener<QuestionListsBloc, QuestionListsState>(
      listenWhen: (prev, curr) =>
          prev.shareToPresent != curr.shareToPresent ||
          prev.shareRevoked != curr.shareRevoked ||
          prev.shareFailed != curr.shareFailed,
      listener: _onShareEffect,
      child: BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
        builder: (context, questionsState) {
          return BlocBuilder<QuestionListsBloc, QuestionListsState>(
            builder: (context, state) {
              final list = state.byId(listId);
              if (list == null) {
                // The list was deleted (possibly from this very screen) — there is
                // nothing left to show.
                return Scaffold(
                  appBar: AppBar(),
                  body: Center(
                    child: Text(LocaleKeys.questionLists_missing.tr()),
                  ),
                );
              }
              final all = questionsState.questionsData?.questions ?? const [];
              final questions = <Question>[
                for (final id in list.questionIds)
                  ...all.where((q) => q.id == id).take(1),
              ];
              final editable = canEdit && !list.isAuto;

              return Scaffold(
                appBar: AppBar(
                  title: Row(
                    children: [
                      QuestionListAvatar(list: list, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          list.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    if (!list.isAuto && state.shareOf(list.id) != null)
                      IconButton(
                        tooltip: LocaleKeys.questionLists_share_linkActive.tr(),
                        icon: const Icon(Icons.link),
                        onPressed: () => context.read<QuestionListsBloc>().add(
                          QuestionListShareRequested(list.id),
                        ),
                      ),
                    if (!list.isAuto)
                      _ListMenu(
                        list: list,
                        canEdit: canEdit,
                        shared: state.shareOf(list.id) != null,
                        busy: state.shareBusy,
                      ),
                  ],
                ),
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: questions.isEmpty
                              ? null
                              : () => openStartTest(
                                  context,
                                  questions.map((e) => e.id).toList(),
                                ),
                          child: Text(LocaleKeys.questionLists_startAll.tr()),
                        ),
                      ),
                    ),
                    Expanded(
                      child: questions.isEmpty
                          ? Center(
                              child: Text(LocaleKeys.questionLists_empty.tr()),
                            )
                          : editable
                          ? _EditableQuestions(list: list, questions: questions)
                          : _ReadOnlyQuestions(questions: questions),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// One-shot outcomes of the share actions: open the share sheet with the
  /// link, confirm a revoke, or report a failure.
  void _onShareEffect(BuildContext context, QuestionListsState state) {
    final bloc = context.read<QuestionListsBloc>();
    final share = state.shareToPresent;
    if (share != null && share.listId == listId) {
      bloc.add(QuestionListSharePresented());
      presentQuestionListShare(context, share);
    } else if (state.shareRevoked) {
      bloc.add(QuestionListSharePresented());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.questionLists_share_revoked.tr())),
      );
    } else if (state.shareFailed) {
      bloc.add(QuestionListsErrorShown());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.questionLists_share_failed.tr())),
      );
    }
  }
}

/// Read-only rendering of the list's questions (automatic lists, and custom ones
/// once `custom_question_lists` is off).
class _ReadOnlyQuestions extends StatelessWidget {
  const _ReadOnlyQuestions({required this.questions});

  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final question in questions)
          QuestionListTile(
            question: question,
            onTap: () => _openQuestion(context, question.id),
          ),
      ],
    );
  }
}

/// Drag-to-reorder + remove rendering, used for a custom list while editing is
/// allowed. Both actions write through the Bloc, which applies them optimistically.
class _EditableQuestions extends StatelessWidget {
  const _EditableQuestions({required this.list, required this.questions});

  final QuestionList list;
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      itemCount: questions.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = questions.map((q) => q.id).toList();
        ids.insert(newIndex, ids.removeAt(oldIndex));
        context.read<QuestionListsBloc>().add(
          QuestionListQuestionsChanged(listId: list.id, questionIds: ids),
        );
      },
      itemBuilder: (context, index) {
        final question = questions[index];
        return Dismissible(
          key: ValueKey('list_${list.id}_q_${question.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          onDismissed: (_) => context.read<QuestionListsBloc>().add(
            QuestionInListToggled(
              listId: list.id,
              questionId: question.id,
              included: false,
            ),
          ),
          child: ListTile(
            onTap: () => _openQuestion(context, question.id),
            leading: QuestionThumbnail(question: question),
            title: Text(
              question.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ),
        );
      },
    );
  }
}

/// The app-bar menu of a custom list: "edit" (name / colour) only while
/// `custom_question_lists` is on, "delete list" always — a user whose premium
/// expired must still be able to get rid of a list. Plus sharing: "share" (or
/// "share link" + "revoke link" once the list has an active link).
class _ListMenu extends StatelessWidget {
  const _ListMenu({
    required this.list,
    required this.canEdit,
    required this.shared,
    required this.busy,
  });

  final QuestionList list;
  final bool canEdit;

  /// Whether the list currently has an active share link.
  final bool shared;

  /// A share / revoke call is in flight — the share actions wait for it.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        final bloc = context.read<QuestionListsBloc>();
        if (value == 'share') {
          bloc.add(QuestionListShareRequested(list.id));
          return;
        }
        if (value == 'revoke') {
          bloc.add(QuestionListShareRevoked(list.id));
          return;
        }
        if (value == 'edit') {
          final draft = await showListEditorDialog(context, existing: list);
          if (draft == null) return;
          bloc.add(
            QuestionListEdited(
              id: list.id,
              name: draft.name,
              color: draft.color,
            ),
          );
          return;
        }
        if (!context.mounted) return;
        final confirmed = await _confirmDelete(context, list);
        if (confirmed != true) return;
        bloc.add(QuestionListDeleted(list.id));
        if (context.mounted) Routemaster.of(context).pop();
      },
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: Text(LocaleKeys.questionLists_edit.tr()),
          ),
        PopupMenuItem(
          value: 'share',
          enabled: !busy,
          child: Text(
            shared
                ? LocaleKeys.questionLists_share_shareLink.tr()
                : LocaleKeys.questionLists_share_share.tr(),
          ),
        ),
        if (shared)
          PopupMenuItem(
            value: 'revoke',
            enabled: !busy,
            child: Text(LocaleKeys.questionLists_share_revoke.tr()),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Text(LocaleKeys.questionLists_delete.tr()),
        ),
      ],
    );
  }
}

/// Deleting takes the questions in the list with it, so it is confirmed first.
Future<bool?> _confirmDelete(BuildContext context, QuestionList list) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(LocaleKeys.questionLists_deleteConfirmTitle.tr()),
      content: Text(
        LocaleKeys.questionLists_deleteConfirmBody.tr(args: [list.title]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(LocaleKeys.questionLists_cancel.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(LocaleKeys.questionLists_deleteConfirm.tr()),
        ),
      ],
    ),
  );
}

void _openQuestion(BuildContext context, int questionId) {
  Routemaster.of(context).push('q?q=$questionId&randomOptionsOrder=true');
}
