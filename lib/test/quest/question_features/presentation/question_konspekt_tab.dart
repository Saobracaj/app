import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation.dart';
import '../../../../core/presentation/load_failed_view.dart';
import '../../../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../../../generated/locale_keys.g.dart';
import '../../../../konspekt/presentation/konspekt_inline_text.dart';
import '../../../../konspekt/presentation/konspekt_markdown.dart';
import '../../../../konspekt/presentation/konspekt_page.dart';
import '../../../../subscription/presentation/paywall.dart';
import '../state_management/question_konspekt_bloc.dart';
import '../state_management/question_konspekt_events.dart';
import '../state_management/question_konspekt_state.dart';

/// The "Конспект" tab: only the konspekt sections that reference this
/// question, with a link into the full category konspekt. The tab itself is
/// hidden by [QuestionFeaturesTabs] while there is nothing to show, so this
/// widget renders the loaded excerpts — or, when the fetch failed, the reason
/// and a retry (a failed load must not look like a question without notes).
class QuestionKonspektTab extends StatelessWidget {
  const QuestionKonspektTab({
    super.key,
    required this.categoryId,
    this.questionId,
    this.locked = false,
  });

  final String categoryId;
  final int? questionId;

  /// The category is behind the pass for this reader: the tab names the
  /// sections about this question and offers the pass instead of the text.
  /// Decided by the flags, not by the document — a cached full copy must not
  /// leak past an expired entitlement.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<QuestionKonspektBloc, QuestionKonspektState>(
      builder: (context, state) {
        if (state.failed) {
          // Same block as every other remote section: "no network" or the
          // konspekt's own message, plus a retry. The Bloc also reloads by
          // itself once the connection is back.
          return LoadFailedView(
            compact: true,
            offline: state.failedOffline,
            message: state.failedOffline
                ? LocaleKeys.network_noConnection.tr()
                : LocaleKeys.konspekt_loadFailed.tr(),
            onRetry: () => context.read<QuestionKonspektBloc>().add(
              QuestionKonspektRequested(),
            ),
          );
        }
        if (state.sections.isEmpty) return const SizedBox.shrink();
        if (locked) {
          final russian = context
              .watch<FeatureFlagsBloc>()
              .state
              .russianContentChosen;
          final titles = state.sections
              .map((s) => s.title.select(russian: russian))
              .where((t) => t.isNotEmpty)
              .join(' · ');
          return LockedContentCard(
            source: PaywallSource.konspekt,
            questionId: questionId,
            categoryId: categoryId,
            title: LocaleKeys.subscription_lockedKonspektTitle.tr(),
            body: titles.isEmpty
                ? LocaleKeys.subscription_lockedKonspektBody.tr()
                : '${LocaleKeys.subscription_lockedKonspektBody.tr()}\n'
                      '${LocaleKeys.subscription_lockedSections.tr(args: [titles])}',
          );
        }
        final russian = context
            .watch<FeatureFlagsBloc>()
            .state
            .russianContentForCategory(categoryId);
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
