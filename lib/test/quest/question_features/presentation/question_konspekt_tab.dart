import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation.dart';
import '../../../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../../../generated/locale_keys.g.dart';
import '../../../../konspekt/presentation/konspekt_inline_text.dart';
import '../../../../konspekt/presentation/konspekt_markdown.dart';
import '../../../../konspekt/presentation/konspekt_page.dart';
import '../state_management/question_konspekt_bloc.dart';
import '../state_management/question_konspekt_events.dart';
import '../state_management/question_konspekt_state.dart';

/// The "Конспект" tab: only the konspekt sections that reference this
/// question, with a link into the full category konspekt. The tab itself is
/// hidden by [QuestionFeaturesTabs] while there is nothing to show, so this
/// widget renders the loaded excerpts — or, when the fetch failed, the reason
/// and a retry (a failed load must not look like a question without notes).
class QuestionKonspektTab extends StatelessWidget {
  const QuestionKonspektTab({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<QuestionKonspektBloc, QuestionKonspektState>(
      builder: (context, state) {
        if (state.failed) return const _KonspektLoadFailed();
        if (state.sections.isEmpty) return const SizedBox.shrink();
        final russian = context.watch<FeatureFlagsBloc>().state.russianContent;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < state.sections.length; i++) ...[
              if (i > 0) const Divider(height: 24, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KonspektInlineText(
                      text: state.sections[i].title.select(russian: russian),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    KonspektMarkdown(
                      text: state.sections[i].content.select(russian: russian),
                      categoryId: categoryId,
                    ),
                  ],
                ),
              ),
            ],
            Align(
              // Кнопка перехода к полному конспекту — по правому краю вкладки.
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: TextButton.icon(
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(LocaleKeys.konspekt_openFull.tr()),
                  // Relative, so the konspekt opens on top of this question and
                  // "back" comes back to it. Pushing '/konspekt' used to replace
                  // the whole stack, which sent "back" to the home screen.
                  onPressed: () => pushScreen(
                    context,
                    path: 'konspekt',
                    queryParameters: {
                      'category': categoryId,
                      'section': state.sections.first.id,
                    },
                    screen: () => KonspektPage(
                      categoryId: categoryId,
                      section: state.sections.first.id,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shown instead of the excerpts when they could not be fetched: the same
/// message the full konspekt page uses, plus a retry that re-runs the load.
class _KonspektLoadFailed extends StatelessWidget {
  const _KonspektLoadFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.konspekt_loadFailed.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(LocaleKeys.konspekt_retry.tr()),
              onPressed: () => context.read<QuestionKonspektBloc>().add(
                QuestionKonspektRequested(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
