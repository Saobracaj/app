import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/deep_links.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/feature_gate.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/question_lists/presentation/add_to_lists_button.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';

/// Top app bar of the training quiz: back, the "question N of M" title
/// (jumping between questions happens on the progress strip below, not here)
/// and the three always-visible actions — translation toggle, add to list,
/// share. No overflow menu by design.
class QuestAppBar extends StatelessWidget implements PreferredSizeWidget {
  const QuestAppBar({
    super.key,
    required this.questionNumber,
    required this.questionCount,
    required this.points,
    required this.questionId,
  });

  /// 1-based position of the current question in the run.
  final int questionNumber;
  final int questionCount;
  final int points;
  final int questionId;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // "N / M" is navigation chrome — with a single question there is
            // nothing to count through, so only the points remain.
            if (questionCount > 1) ...[
              Text(
                LocaleKeys.quest_title.tr(
                  args: ['$questionNumber', '$questionCount'],
                ),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              LocaleKeys.quest_points.plural(points),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        const FeatureGate(
          feature: AppFeature.russianContent,
          child: _TranslationChip(),
        ),
        // Ticking lists here keeps the menu open — see AddToListsButton.
        AddToListsButton(questionId: questionId),
        IconButton(
          tooltip: LocaleKeys.quest_share.tr(),
          icon: const Icon(Icons.share_outlined),
          // Stopgap until share_plus lands: the deep link goes to the
          // clipboard instead of a system share sheet.
          onPressed: () {
            final link = appLink('/question/$questionId').toString();
            Clipboard.setData(ClipboardData(text: link)).then((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(LocaleKeys.quest_linkCopied.tr())),
              );
            });
          },
        ),
      ],
    );
  }
}

/// The "РУ" toggle: outlined while off, filled with primary while on.
class _TranslationChip extends StatelessWidget {
  const _TranslationChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<TranslationsBloc, TranslationsState>(
      builder: (context, state) {
        final on = state.showTranslation;
        return Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () =>
                context.read<TranslationsBloc>().add(ToggleShowTranslation()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: on ? scheme.primary : null,
                border: on
                    ? null
                    : Border.all(color: scheme.onSurfaceVariant, width: 1.5),
              ),
              child: Text(
                LocaleKeys.quest_ruToggle.tr(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
