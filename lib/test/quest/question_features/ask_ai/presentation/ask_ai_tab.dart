import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di.dart';
import '../../../../../generated/locale_keys.g.dart';
import '../../../../../konspekt/presentation/konspekt_inline_text.dart';
import '../../../../../konspekt/presentation/konspekt_markdown.dart';
import '../models/question_explanation.dart';
import 'ask_ai_chat_section.dart';
import '../state_management/ask_ai_bloc.dart';
import '../state_management/ask_ai_events.dart';
import '../state_management/ask_ai_state.dart';

/// The "Спросить AI" tab: the pre-generated explanation of the question — why
/// the correct answer is correct, why the others are not, with links into the
/// deciding law paragraph and konspekt section — with the interactive chat
/// about this question underneath it.
///
/// The markdown reuses [KonspektMarkdown], so the document's `zakon?…`,
/// `question?id=…` and `konspekt?…` links open exactly like konspekt ones.
class AskAiTab extends StatelessWidget {
  const AskAiTab({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AskAiBloc>(param1: questionId),
      child: BlocBuilder<AskAiBloc, AskAiState>(
        builder: (context, state) {
          if (state.inProgress) return const _Loading();
          final explanation = state.explanation;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.failed)
                const _LoadFailed()
              else if (explanation == null)
                const _NoExplanationYet()
              else
                _Explanation(explanation: explanation),
              // The chat stands on its own: a question with no explanation —
              // or one whose explanation would not load — is still worth
              // asking about.
              AskAiChatSection(questionId: questionId),
            ],
          );
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Shown when the load failed: the reason and a retry, mirroring the konspekt
/// tab — a failed load must not look like a question without an explanation.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.askAi_loadFailed.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(LocaleKeys.askAi_retry.tr()),
              onPressed: () => context.read<AskAiBloc>().add(AskAiRequested()),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stub for a question whose explanation is not generated yet — a stated
/// answer, not a blank tab.
class _NoExplanationYet extends StatelessWidget {
  const _NoExplanationYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.askAi_noExplanation.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.explanation});

  final QuestionExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (explanation.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: KonspektInlineText(
              text: explanation.summary,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        if (explanation.explanation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: KonspektMarkdown(text: explanation.explanation),
          ),
        if (explanation.wrongChoices.isNotEmpty) ...[
          const Divider(height: 24, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(LocaleKeys.askAi_wrongChoices.tr(), style: theme.textTheme.titleSmall),
          ),
          for (final choice in explanation.wrongChoices)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (choice.text.isNotEmpty)
                    Text(
                      choice.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (choice.why.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    KonspektMarkdown(text: choice.why),
                  ],
                ],
              ),
            ),
        ],
        if (explanation.sources.isNotEmpty) ...[
          const Divider(height: 24, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(LocaleKeys.askAi_sources.tr(), style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            // A markdown link list, so the sources open through the same link
            // handling as the text above them.
            child: KonspektMarkdown(
              text: [
                for (final source in explanation.sources)
                  '- [${source.title}](${source.uri})',
              ].join('\n'),
            ),
          ),
        ] else
          const SizedBox(height: 4),
      ],
    );
  }
}
