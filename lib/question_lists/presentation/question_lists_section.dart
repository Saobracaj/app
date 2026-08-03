import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../domain/list_style.dart';
import '../models/question_list.dart';
import '../state_management/question_lists_bloc.dart';
import '../state_management/question_lists_events.dart';
import '../state_management/question_lists_state.dart';
import 'list_editor_dialog.dart';

/// The "question lists" block of the home screen: a horizontally scrolling row
/// of small cards — the automatic lists first, then the user's custom ones, and
/// finally a "create list" card.
///
/// Feature flags:
///   * `auto_question_lists` — shows the automatic lists;
///   * `custom_question_lists` — shows the "create list" card. When it is off
///     (e.g. premium expired) the custom lists the user already made stay
///     visible and readable, they just cannot be created or edited any more.
///
/// With both flags off the whole block disappears.
class QuestionListsSection extends StatelessWidget {
  const QuestionListsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlagsBloc>().state;
    final autoEnabled = flags.isEnabled(AppFeature.autoQuestionLists);
    final customEnabled = flags.isEnabled(AppFeature.customQuestionLists);
    if (!autoEnabled && !customEnabled) return const SizedBox.shrink();

    return BlocBuilder<QuestionListsBloc, QuestionListsState>(
      builder: (context, state) {
        final lists = [
          if (autoEnabled) ...state.autoLists,
          ...state.customLists,
        ];
        if (lists.isEmpty && !customEnabled) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                LocaleKeys.questionLists_section.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final list in lists)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: QuestionListChip(
                        list: list,
                        onTap: () => Routemaster.of(
                          context,
                        ).push('/lists/${Uri.encodeComponent(list.id)}'),
                      ),
                    ),
                  if (customEnabled)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: _CreateListChip(),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One list rendered as a compact card: a round colour/icon avatar, the list's
/// title and how many questions it holds.
class QuestionListChip extends StatelessWidget {
  const QuestionListChip({super.key, required this.list, this.onTap});

  final QuestionList list;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            QuestionListAvatar(list: list),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    list.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    LocaleKeys.questionLists_questionsCount.tr(
                      args: ['${list.questionIds.length}'],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round leading avatar of a list: the user's colour for a custom list, the
/// theme colour plus a glyph for an automatic one.
class QuestionListAvatar extends StatelessWidget {
  const QuestionListAvatar({super.key, required this.list, this.size = 32});

  final QuestionList list;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = list.icon;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: list.avatarColor(context),
        shape: BoxShape.circle,
      ),
      child: icon == null
          ? null
          : Icon(icon, size: size * 0.55, color: Colors.white),
    );
  }
}

/// The trailing "create list" card. Only rendered while
/// `custom_question_lists` is on.
class _CreateListChip extends StatelessWidget {
  const _CreateListChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final draft = await showListEditorDialog(context);
        if (draft == null || !context.mounted) return;
        context.read<QuestionListsBloc>().add(
          QuestionListCreated(name: draft.name, color: draft.color),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LocaleKeys.questionLists_create.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
