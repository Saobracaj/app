import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../public_comments/presentation/relative_time.dart';
import '../models/support_chat.dart';
import '../state_management/support_chat_bloc.dart';
import '../state_management/support_chat_events.dart';
import '../state_management/support_chat_state.dart';
import 'linked_text.dart';
import 'support_attachment_views.dart';

/// One support conversation.
///
/// The user reaches it from settings with no [threadId]; a moderator opens a
/// specific one from the list of обращения. Everything else — who is on which
/// side of the bubble, which mutation sends — is the Bloc's business.
class SupportChatPage extends StatelessWidget {
  const SupportChatPage({super.key, this.threadId});

  /// The conversation to show, or `null` for the caller's own.
  final String? threadId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<SupportChatBloc>(param1: threadId)..add(SupportChatOpened()),
      child: const _SupportChatView(),
    );
  }
}

/// Собственный разговор пользователя с собственным [SupportChatBloc], но без
/// Scaffold — встраивается в правую панель настроек на широком экране. Роль
/// AppBar (индикатор загрузки и потерянного live-соединения) берут на себя
/// полосы внутри тела чата.
class SupportChatContent extends StatelessWidget {
  const SupportChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<SupportChatBloc>(param1: null)..add(SupportChatOpened()),
      child: const _SupportChatBody(embedded: true),
    );
  }
}

class _SupportChatView extends StatelessWidget {
  const _SupportChatView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportChatBloc, SupportChatState>(
      builder: (context, state) {
        final bloc = context.read<SupportChatBloc>();
        final isModerator = bloc.threadId != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              isModerator
                  ? (state.thread?.title ?? 'support.threadTitle'.tr())
                  : 'support.title'.tr(),
            ),
            actions: [
              // Honest about the live connection: while it is down the chat is
              // still readable, it just stops updating by itself.
              if (state.loaded && !state.live)
                IconButton(
                  tooltip: 'support.offline'.tr(),
                  icon: const Icon(Icons.cloud_off_outlined),
                  onPressed: () => bloc.add(SupportChatRefreshed()),
                ),
            ],
            bottom: state.loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: const SafeArea(child: _SupportChatBody(embedded: false)),
        );
      },
    );
  }
}

/// Тело чата: баннеры, лента сообщений, поле ввода. В [embedded]-режиме (без
/// AppBar) сверху добавляются индикатор загрузки и строка про потерянное
/// live-соединение — та же честность, что и у иконки в AppBar.
class _SupportChatBody extends StatelessWidget {
  const _SupportChatBody({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SupportChatBloc, SupportChatState>(
      listenWhen: (a, b) => a.notificationsPrompt != b.notificationsPrompt,
      listener: (context, state) {
        if (state.notificationsPrompt) _askAboutNotifications(context);
      },
      builder: (context, state) {
        final bloc = context.read<SupportChatBloc>();
        final isModerator = bloc.threadId != null;
        return Column(
          children: [
            if (embedded && state.loading)
              const LinearProgressIndicator(minHeight: 2),
            if (embedded && state.loaded && !state.live)
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.cloud_off_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'support.offline'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => bloc.add(SupportChatRefreshed()),
                      child: Text('support.refresh'.tr()),
                    ),
                  ],
                ),
              ),
            if (state.errorMessage != null)
              _ErrorBanner(message: state.errorMessage!),
            Expanded(
              // A tap on the free space around the messages dismisses the
              // keyboard, same as on the auth screens.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: state.isEmpty
                    ? _EmptyState(isModerator: isModerator)
                    : _MessageList(messages: state.messages),
              ),
            ),
            _Composer(state: state),
          ],
        );
      },
    );
  }

  /// The same offer the question discussion makes: an answer that lands hours
  /// later is worthless if nothing tells the user about it.
  Future<void> _askAboutNotifications(BuildContext context) async {
    final bloc = context.read<SupportChatBloc>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('support.notifyTitle'.tr()),
        content: Text('support.notifyBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('support.notifyDecline'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('support.notifyAccept'.tr()),
          ),
        ],
      ),
    );
    bloc.add(
      accepted == true
          ? SupportChatNotificationsAccepted()
          : SupportChatNotificationsDeclined(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // Client-side messages are translation keys; the server's are
                // already human-readable, and `tr` returns the key unchanged
                // when it is not one.
                message.startsWith('support.') ? message.tr() : message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: scheme.onErrorContainer,
              onPressed: () => context.read<SupportChatBloc>().add(
                SupportChatErrorDismissed(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isModerator});
  final bool isModerator;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              isModerator
                  ? 'support.emptyThread'.tr()
                  : 'support.emptyOwn'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});
  final List<SupportMessage> messages;

  @override
  Widget build(BuildContext context) {
    final isModerator = context.read<SupportChatBloc>().threadId != null;
    return ListView.builder(
      // Newest at the bottom, and the view starts there — a chat's natural
      // reading position without measuring anything.
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return _MessageBubble(
          message: message,
          // "Mine" is whichever side this screen is being read from.
          mine: message.fromStaff == isModerator,
        );
      },
    );
  }
}

/// Who wrote a message, as it is shown above the bubble.
///
/// The display name whenever the account has one; failing that the side it came
/// from — a nameless user is «Без имени» rather than a blank line, so the
/// authorship of every message is always stated.
String authorName(SupportMessage message) {
  if (message.authorDisplayName.trim().isNotEmpty) {
    return message.authorDisplayName.trim();
  }
  return message.fromStaff
      ? 'support.staffName'.tr()
      : 'support.unknownUser'.tr();
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final SupportMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = mine
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = mine ? scheme.onPrimaryContainer : scheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: background,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Both sides are named, not just the other one: a moderator
                // reading a thread needs to see whose words these are, and the
                // user's own name is what tells them the account they wrote
                // from.
                Text(
                  authorName(message),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: mine
                        ? foreground.withValues(alpha: 0.8)
                        : scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (message.body.isNotEmpty)
                  LinkedText(
                    text: message.body,
                    style: TextStyle(color: foreground),
                    linkColor: mine ? foreground : scheme.primary,
                  ),
                for (final attachment in message.attachments)
                  SupportAttachmentView(
                    attachment: attachment,
                    onSurface: foreground,
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      relativeTime(message.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.6),
                      ),
                    ),
                    // Read receipts are only meaningful on one's own messages.
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: foreground.withValues(alpha: 0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.state});
  final SupportChatState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SupportChatBloc>();
    void send() {
      if (state.canSend) bloc.add(SupportChatSendPressed());
    }

    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            if (state.uploading)
              LinearProgressIndicator(
                value: state.uploadProgress > 0 ? state.uploadProgress : null,
              ),
            if (state.pending.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final attachment in state.pending)
                      Chip(
                        avatar: Icon(
                          attachment.isImage
                              ? Icons.image_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 18,
                        ),
                        label: Text(attachment.fileName),
                        onDeleted: () =>
                            bloc.add(SupportChatAttachmentRemoved(attachment)),
                      ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'support.attach'.tr(),
                  icon: const Icon(Icons.attach_file),
                  onPressed: state.uploading
                      ? null
                      : () => bloc.add(SupportChatAttachPressed()),
                ),
                Expanded(
                  child: _ComposerField(
                    text: state.body,
                    onChanged: (value) =>
                        bloc.add(SupportChatBodyChanged(value)),
                    onSend: send,
                  ),
                ),
                IconButton.filled(
                  tooltip: 'support.sendTooltip'.tr(),
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
          ],
        ),
      ),
    );
  }
}

/// The text field. Stateful only to own its `TextEditingController` — the value
/// itself lives in the Bloc, and the controller is re-synced when the Bloc
/// clears it after a send.
class _ComposerField extends StatefulWidget {
  const _ComposerField({
    required this.text,
    required this.onChanged,
    required this.onSend,
  });

  final String text;
  final ValueChanged<String> onChanged;

  /// Fired by ⌘/Ctrl+Enter. Plain Enter stays a newline — a chat message here is
  /// often several lines of a bug report, and losing them to a stray Enter is
  /// worse than one extra keystroke.
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
      // Both modifiers, and both Enters: whichever keyboard the writer has in
      // front of them, the combination they already know sends the message.
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
        // Поле начинается с одной строки и растёт под текст: пустое поле в три
        // строки съедало половину переписки на веб-версии.
        minLines: 1,
        maxLines: 8,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintText: 'support.hint'.tr(),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
