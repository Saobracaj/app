import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_markdown.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_events.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_state.dart';

/// The building blocks of the Ask-AI chat, shared by the question tab's
/// embedded section and the exam-result chat screen. Everything reads the
/// [AskAiChatBloc] from the surrounding context.

/// One bubble. The user's words sit right in `primaryContainer`; the
/// assistant's answer sits left and renders through [KonspektMarkdown], so its
/// law, question and konspekt links open exactly like the ones of the static
/// explanation above it.
class AskAiMessageBubble extends StatelessWidget {
  const AskAiMessageBubble({super.key, required this.message});

  final AskAiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.role == AskAiChatRole.user;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (mine ? 0.82 : 0.94),
        ),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: mine
                ? Text(
                    message.content,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  )
                : KonspektMarkdown(text: message.content),
          ),
        ),
      ),
    );
  }
}

/// The assistant-side placeholder while the model is thinking — an agentic
/// answer takes long enough that a silent screen reads as broken.
class AskAiThinkingBubble extends StatelessWidget {
  const AskAiThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                LocaleKeys.askAi_thinking.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ready questions of the empty state — tapping one sends it as-is, so
/// the first message costs a single tap.
class AskAiSuggestions extends StatelessWidget {
  const AskAiSuggestions({super.key, required this.scope});

  final AskAiChatScope scope;

  static const _byScope = {
    AskAiChatScope.question: [
      LocaleKeys.askAi_suggestWhy,
      LocaleKeys.askAi_suggestSimple,
      LocaleKeys.askAi_suggestExample,
    ],
    AskAiChatScope.examResult: [
      LocaleKeys.askAi_suggestMistakes,
      LocaleKeys.askAi_suggestTopics,
      LocaleKeys.askAi_suggestPlan,
    ],
    AskAiChatScope.category: [
      LocaleKeys.askAi_suggestWhy,
      LocaleKeys.askAi_suggestSimple,
      LocaleKeys.askAi_suggestExample,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AskAiChatBloc>();
    final sending = context.select((AskAiChatBloc b) => b.state.sending);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in _byScope[scope]!)
          ActionChip(
            avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(key.tr()),
            onPressed: sending
                ? null
                : () => bloc.add(AskAiChatSendPressed(text: key.tr())),
          ),
      ],
    );
  }
}

/// A failed send, dismissible; the conversation and the draft stay put.
class AskAiErrorBanner extends StatelessWidget {
  const AskAiErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // Client-side messages are translation keys; the server's are
                // already human-readable, and `tr` returns the key unchanged
                // when it is not one.
                message.startsWith('askAi.') ? message.tr() : message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: scheme.onErrorContainer,
              onPressed: () =>
                  context.read<AskAiChatBloc>().add(AskAiChatErrorDismissed()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The composer, or — once the daily quota is spent — the stated "come back
/// tomorrow" notice in its place. A low remaining count is announced under the
/// field before it runs out.
class AskAiComposer extends StatelessWidget {
  const AskAiComposer({super.key, required this.state});

  final AskAiChatState state;

  /// From how many remaining messages the counter becomes visible.
  static const _lowQuota = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<AskAiChatBloc>();

    if (state.quotaExhausted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_disabled_outlined,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LocaleKeys.askAi_quotaExhausted.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    void send() {
      if (state.canSend) bloc.add(AskAiChatSendPressed());
    }

    final remaining = state.quota?.remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _ComposerField(
                text: state.body,
                enabled: !state.sending,
                onChanged: (value) => bloc.add(AskAiChatBodyChanged(value)),
                onSend: send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: LocaleKeys.askAi_send.tr(),
              icon: state.sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: state.canSend ? send : null,
            ),
          ],
        ),
        if (remaining != null && remaining <= _lowQuota) ...[
          const SizedBox(height: 4),
          Text(
            LocaleKeys.askAi_quotaLeft.plural(remaining),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The text field. Stateful only to own its `TextEditingController` — the
/// value itself lives in the Bloc, and the controller is re-synced when the
/// Bloc clears it after a send.
class _ComposerField extends StatefulWidget {
  const _ComposerField({
    required this.text,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
  });

  final String text;
  final bool enabled;
  final ValueChanged<String> onChanged;

  /// Fired by ⌘/Ctrl+Enter — same combination as the support chat, so one
  /// habit serves both. Plain Enter stays a newline.
  final VoidCallback onSend;

  @override
  State<_ComposerField> createState() => _ComposerFieldState();
}

class _ComposerFieldState extends State<_ComposerField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(_ComposerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) _controller.text = widget.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        for (final key in const [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
        ]) ...{
          SingleActivator(key, meta: true): widget.onSend,
          SingleActivator(key, control: true): widget.onSend,
        },
      },
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        enabled: widget.enabled,
        minLines: 1,
        maxLines: 5,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintText: LocaleKeys.askAi_hint.tr(),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
