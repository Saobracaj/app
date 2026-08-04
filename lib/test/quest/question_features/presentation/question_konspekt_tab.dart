import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../../../generated/locale_keys.g.dart';
import '../../../../konspekt/presentation/konspekt_markdown.dart';
import '../state_management/question_konspekt_bloc.dart';
import '../state_management/question_konspekt_state.dart';

/// The "Конспект" tab: only the konspekt sections that reference this
/// question, with a link into the full category konspekt. The tab itself is
/// hidden by [QuestionFeaturesTabs] while there is nothing to show, so this
/// widget only renders the loaded excerpts.
class QuestionKonspektTab extends StatelessWidget {
  const QuestionKonspektTab({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<QuestionKonspektBloc, QuestionKonspektState>(
      builder: (context, state) {
        if (state.sections.isEmpty) return const SizedBox.shrink();
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
                    Text(state.sections[i].title.text, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    KonspektMarkdown(
                      text: state.sections[i].content.text,
                      categoryId: categoryId,
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
              child: TextButton.icon(
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(LocaleKeys.konspekt_openFull.tr()),
                onPressed: () => Routemaster.of(context).push('/konspekt', queryParameters: {
                  'category': categoryId,
                  'section': state.sections.first.id,
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}
