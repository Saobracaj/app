import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/presentation/ask_ai_chat_widgets.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_events.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_state.dart';

/// The interactive chat under the static explanation on the "Спросить AI"
/// tab. The tab lives inside the question screen's own scroll view, so this
/// is a plain column of bubbles rather than its own list — the short
/// conversations a question invites don't need one.
class AskAiChatSection extends StatelessWidget {
  const AskAiChatSection({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AskAiChatBloc>(
        param1: AskAiChatScope.question,
        param2: '$questionId',
      ),
      child: const _SectionView(),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AskAiChatBloc, AskAiChatState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 24),
              Text(LocaleKeys.askAi_chatTitle.tr(), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (state.historyFailed)
                const _HistoryFailed()
              else ...[
                for (final message in state.messages)
                  AskAiMessageBubble(message: message),
                if (state.pendingUserText != null)
                  AskAiMessageBubble(
                    message: AskAiChatMessage(
                      id: 'pending',
                      role: AskAiChatRole.user,
                      content: state.pendingUserText!,
                      createdAt: DateTime.now(),
                    ),
                  ),
                if (state.sending)
                  AskAiThinkingBubble(
                    streamingText: state.streamingText,
                    tool: state.streamingTool,
                  ),
                if (state.isEmpty && !state.sending) ...[
                  Text(
                    LocaleKeys.askAi_emptyHint.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const AskAiSuggestions(scope: AskAiChatScope.question),
                ],
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                AskAiErrorBanner(message: state.errorMessage!),
              ],
              if (!state.historyFailed) ...[
                const SizedBox(height: 10),
                AskAiComposer(state: state),
                const SizedBox(height: 6),
                Text(
                  LocaleKeys.askAi_disclaimer.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The history would not load — a retry instead of a chat that looks empty
/// while it is not.
class _HistoryFailed extends StatelessWidget {
  const _HistoryFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.askAi_historyFailed.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(LocaleKeys.askAi_retry.tr()),
          onPressed: () => context.read<AskAiChatBloc>().add(AskAiChatOpened()),
        ),
      ],
    );
  }
}
