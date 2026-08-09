import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/presentation/ask_ai_chat_widgets.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_events.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_state.dart';

/// The full-screen Ask-AI chat opened from the exam result. The scope is the
/// attempt: the backend preloads the attempt's numbers and every wrongly
/// answered question into the prompt, so «разбери мои ошибки» works with no
/// further context from the client.
class AskAiChatPage extends StatelessWidget {
  const AskAiChatPage({super.key, required this.scope, required this.scopeId});

  final AskAiChatScope scope;
  final String scopeId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AskAiChatBloc>(param1: scope, param2: scopeId),
      child: Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.questionTabs_askAi.tr())),
        body: ReadableWidth(child: _ChatView(scope: scope)),
      ),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView({required this.scope});

  final AskAiChatScope scope;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AskAiChatBloc, AskAiChatState>(
      builder: (context, state) {
        return Column(
          children: [
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AskAiErrorBanner(message: state.errorMessage!),
              ),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.historyFailed
                      ? _HistoryFailed(
                          onRetry: () => context
                              .read<AskAiChatBloc>()
                              .add(AskAiChatOpened()),
                        )
                      : state.isEmpty && !state.sending
                          ? _EmptyState(scope: scope)
                          : _Messages(state: state),
            ),
            if (!state.loading && !state.historyFailed)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: AskAiComposer(state: state),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({required this.state});

  final AskAiChatState state;

  @override
  Widget build(BuildContext context) {
    // The optimistic bubble and the thinking indicator live at the fresh end
    // of the same reversed list, so the newest is always on screen.
    final tail = [
      if (state.pendingUserText != null)
        AskAiMessageBubble(
          message: AskAiChatMessage(
            id: 'pending',
            role: AskAiChatRole.user,
            content: state.pendingUserText!,
            createdAt: DateTime.now(),
          ),
        ),
      if (state.sending) const AskAiThinkingBubble(),
    ];
    final count = state.messages.length + tail.length;
    return ListView.builder(
      // Newest at the bottom, and the view starts there — a chat's natural
      // reading position without measuring anything.
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) {
        final position = count - 1 - index;
        if (position >= state.messages.length) {
          return tail[position - state.messages.length];
        }
        return AskAiMessageBubble(message: state.messages[position]);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scope});

  final AskAiChatScope scope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              LocaleKeys.askAi_examEmptyHint.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            AskAiSuggestions(scope: scope),
          ],
        ),
      ),
    );
  }
}

class _HistoryFailed extends StatelessWidget {
  const _HistoryFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocaleKeys.askAi_historyFailed.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(LocaleKeys.askAi_retry.tr()),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
