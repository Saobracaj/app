import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../core/navigation.dart';
import '../../public_comments/presentation/relative_time.dart';
import '../models/chat.dart';
import '../models/chat_target.dart';
import '../state_management/chat_bloc.dart';
import '../state_management/chat_events.dart';
import '../state_management/chat_state.dart';
import 'chat_attach_menu.dart';
import 'linked_text.dart';
import 'shared_list_chip.dart';
import 'chat_attachment_views.dart';

/// Один разговор.
///
/// Экран ничего не знает про поддержку: ему дают [target] — свой чат с
/// разработчиком (по умолчанию), конкретное обращение, тред на сообщение. Всё
/// остальное — кто на какой стороне пузыря, какой мутацией уходит сообщение —
/// дело Bloc'а, поэтому тот же экран показывает и тред, и будущие чаты групп.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key, this.target, this.focusComposer = false});

  /// Разговор, который нужно открыть; `null` — свой чат с разработчиком.
  final ChatTarget? target;

  /// Поставить курсор в поле ввода сразу: так открывается тред, вызванный
  /// свайпом по сообщению, — жест означает «хочу ответить», и печатать надо
  /// начинать, ничего больше не нажимая.
  final bool focusComposer;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ChatBloc>(param1: target)..add(ChatOpened()),
      child: _ChatView(focusComposer: focusComposer),
    );
  }
}

/// Собственный разговор пользователя с собственным [ChatBloc], но без
/// Scaffold — встраивается в правую панель настроек на широком экране. Роль
/// AppBar (индикатор загрузки и потерянного live-соединения) берут на себя
/// полосы внутри тела чата.
class ChatContent extends StatelessWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ChatBloc>(param1: null)..add(ChatOpened()),
      child: const _ChatBody(embedded: true),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView({this.focusComposer = false});

  final bool focusComposer;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final bloc = context.read<ChatBloc>();
        return Scaffold(
          appBar: AppBar(
            title: Text(_titleOf(state, bloc.target)),
            actions: [
              const _NotificationsBell(),
              // Honest about the live connection: while it is down the chat is
              // still readable, it just stops updating by itself.
              if (state.loaded && !state.live)
                IconButton(
                  tooltip: 'support.offline'.tr(),
                  icon: const Icon(Icons.cloud_off_outlined),
                  onPressed: () => bloc.add(ChatRefreshed()),
                ),
            ],
            bottom: state.loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: SafeArea(
            child: _ChatBody(embedded: false, focusComposer: focusComposer),
          ),
        );
      },
    );
  }

  /// Заголовок разговора: тред — «Тред», чужое обращение — имя собеседника,
  /// свой чат — «Чат с разработчиком».
  String _titleOf(ChatState state, ChatTarget target) {
    if (state.isThread) return 'support.threadHeader'.tr();
    final chat = state.thread;
    if (chat != null &&
        chat.entityType == ChatEntityType.support &&
        chat.userId != state.myUserId &&
        chat.title.isNotEmpty) {
      return chat.title;
    }
    if (target is SupportChatTarget) return 'support.title'.tr();
    return (chat?.title ?? '').isNotEmpty
        ? chat!.title
        : 'support.threadTitle'.tr();
  }
}

/// Колокольчик в шапке: включает и выключает оповещения об этом разговоре.
/// По умолчанию они выключены — и у чатов, и у тредов, поэтому иконка почти
/// всегда начинается с перечёркнутой.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (a, b) =>
          a.thread?.notificationsEnabled != b.thread?.notificationsEnabled ||
          a.systemNotificationsBlocked != b.systemNotificationsBlocked ||
          a.loaded != b.loaded,
      builder: (context, state) {
        final chat = state.thread;
        if (chat == null) return const SizedBox.shrink();
        final blocked = state.systemNotificationsBlocked;
        final on = chat.notificationsEnabled;
        if (blocked) {
          // Запрет системы важнее переключателя чата: показываем именно его, а
          // нажатие ведёт в системный диалог (или в настройки).
          return IconButton(
            tooltip: 'support.notifyBlocked'.tr(),
            icon: Icon(
              Icons.notifications_off,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () =>
                context.read<ChatBloc>().add(ChatNotificationsToggled()),
          );
        }
        return IconButton(
          tooltip: on ? 'support.notifyOff'.tr() : 'support.notifyOn'.tr(),
          icon: Icon(on ? Icons.notifications : Icons.notifications_off),
          onPressed: () =>
              context.read<ChatBloc>().add(ChatNotificationsToggled()),
        );
      },
    );
  }
}

/// Тело чата: баннеры, лента сообщений, поле ввода. В [embedded]-режиме (без
/// AppBar) сверху добавляются индикатор загрузки и строка про потерянное
/// live-соединение — та же честность, что и у иконки в AppBar.
class _ChatBody extends StatelessWidget {
  const _ChatBody({required this.embedded, this.focusComposer = false});

  final bool embedded;

  /// Ставить ли курсор в поле ввода при открытии — см. [ChatPage.focusComposer].
  final bool focusComposer;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (a, b) =>
          a.notificationsPrompt != b.notificationsPrompt ||
          a.notice != b.notice,
      listener: (context, state) {
        if (state.notificationsPrompt) _askAboutNotifications(context);
        if (state.notice != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.notice!.tr())));
          context.read<ChatBloc>().add(ChatNoticeShown());
        }
      },
      builder: (context, state) {
        final bloc = context.read<ChatBloc>();
        final isModerator = state.thread?.userId != state.myUserId;
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
                      onPressed: () => bloc.add(ChatRefreshed()),
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
                child: state.isEmpty && !state.isThread
                    ? _EmptyState(isModerator: isModerator)
                    : _MessageList(state: state),
              ),
            ),
            _Composer(state: state, focusComposer: focusComposer),
          ],
        );
      },
    );
  }

  /// The same offer the question discussion makes: an answer that lands hours
  /// later is worthless if nothing tells the user about it.
  Future<void> _askAboutNotifications(BuildContext context) async {
    final bloc = context.read<ChatBloc>();
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
          ? ChatNotificationsAccepted()
          : ChatNotificationsDeclined(),
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
              onPressed: () =>
                  context.read<ChatBloc>().add(ChatErrorDismissed()),
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
  const _MessageList({required this.state});
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages;
    // В треде над лентой стоит само сообщение, на которое отвечают, и заголовок
    // «Ответы» — дальше идёт обычный чат.
    final header = state.isThread ? 2 : 0;
    return ListView.builder(
      // Newest at the bottom, and the view starts there — a chat's natural
      // reading position without measuring anything.
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount:
          messages.length +
          header +
          (state.isThread && messages.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        final total =
            messages.length +
            header +
            (state.isThread && messages.isEmpty ? 1 : 0);
        final position = total - 1 - index;
        if (state.isThread) {
          if (position == 0) {
            final parent = state.parentMessage;
            return parent == null
                ? const SizedBox.shrink()
                : _MessageBubble(
                    message: parent,
                    mine: state.isMine(parent),
                    // Родитель показан как есть: свайп и «ответить» на нём
                    // открыли бы тред внутри треда.
                    inThread: true,
                  );
          }
          if (position == 1) return const _RepliesHeader();
          if (messages.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'support.noReplies'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            );
          }
        }
        final message = messages[position - header];
        return _MessageBubble(
          message: message,
          mine: state.isMine(message),
          inThread: state.isThread,
        );
      },
    );
  }
}

/// Разделитель «Ответы» между главным сообщением треда и лентой ответов.
class _RepliesHeader extends StatelessWidget {
  const _RepliesHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Text(
            'support.replies'.tr(),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.outline),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

/// Who wrote a message, as it is shown above the bubble.
///
/// The display name whenever the account has one; failing that the side it came
/// from — a nameless user is «Без имени» rather than a blank line, so the
/// authorship of every message is always stated.
String authorName(ChatMessage message) {
  if (message.authorDisplayName.trim().isNotEmpty) {
    return message.authorDisplayName.trim();
  }
  return message.fromStaff
      ? 'support.staffName'.tr()
      : 'support.unknownUser'.tr();
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.inThread = false,
  });

  final ChatMessage message;
  final bool mine;

  /// Внутри треда «ответить» не бывает: ни свайпа, ни пункта меню — тредов
  /// внутри тредов не существует.
  final bool inThread;

  @override
  Widget build(BuildContext context) {
    final bubble = _bubble(context);
    if (inThread) {
      return GestureDetector(
        onLongPress: () => _showMenu(context),
        child: bubble,
      );
    }
    // Свайп влево открывает тред: сообщение уезжает за пальцем, но только до
    // границы — на ней тред открывается сам, не дожидаясь, пока палец отпустят.
    return _SwipeToOpenThread(
      onTriggered: () =>
          openMessageThread(context, message, focusComposer: true),
      child: GestureDetector(
        onLongPress: () => _showMenu(context),
        child: bubble,
      ),
    );
  }

  /// Меню по долгому тапу: ответить (тред), скопировать текст, пожаловаться и —
  /// для своих сообщений — изменить и удалить.
  ///
  /// «Пожаловаться» есть только на чужих сообщениях: жаловаться на себя не на
  /// что, а «удалить» модератор чужого сообщения не получает — снимает его тот,
  /// кто написал.
  Future<void> _showMenu(BuildContext context) async {
    final bloc = context.read<ChatBloc>();
    final messenger = ScaffoldMessenger.of(context);
    // Результат — либо пункт меню, либо эмодзи из верхней строки: реакция
    // ставится тем же нажатием, что и любое другое действие, и лист за собой
    // закрывает.
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReactionRow(
              message: message,
              onPicked: (emoji) => Navigator.of(ctx).pop(emoji),
            ),
            if (!inThread)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text('support.reply'.tr()),
                onTap: () => Navigator.of(ctx).pop(_MessageAction.reply),
              ),
            if (message.body.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text('support.copy'.tr()),
                onTap: () => Navigator.of(ctx).pop(_MessageAction.copy),
              ),
            if (mine) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('support.edit'.tr()),
                onTap: () => Navigator.of(ctx).pop(_MessageAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('support.delete'.tr()),
                onTap: () => Navigator.of(ctx).pop(_MessageAction.delete),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('support.report'.tr()),
                onTap: () => Navigator.of(ctx).pop(_MessageAction.report),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case String emoji:
        bloc.add(ChatReactionToggled(message, emoji));
      case _MessageAction.reply:
        openMessageThread(context, message, focusComposer: true);
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.body));
        messenger.showSnackBar(SnackBar(content: Text('support.copied'.tr())));
      case _MessageAction.edit:
        bloc.add(ChatEditStarted(message));
      case _MessageAction.delete:
        final confirmed = await _confirmDelete(context);
        if (confirmed) bloc.add(ChatMessageDeleted(message));
      case _MessageAction.report:
        final reason = await _askReportReason(context);
        if (reason != null) bloc.add(ChatMessageReported(message, reason));
      // Меню возвращает только эти два вида значений; ветка нужна анализатору.
      default:
        break;
    }
  }

  /// Удаление необратимо и уносит вложения — спрашиваем один раз.
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('support.deleteTitle'.tr()),
        content: Text('support.deleteBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('support.deleteCancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('support.deleteConfirm'.tr()),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Причина жалобы — готовым списком, а не полем ввода: модератору нужен
  /// повод, а жалующемуся — одно нажатие.
  Future<String?> _askReportReason(BuildContext context) {
    const reasons = ['spam', 'abuse', 'other'];
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'support.reportTitle'.tr(),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final reason in reasons)
              ListTile(
                title: Text('support.reportReason.$reason'.tr()),
                onTap: () => Navigator.of(ctx).pop(reason),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context) {
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
                // Ссылка на расшаренный список — это тот же вложенный список,
                // просто присланный ссылкой: показываем его так же, как чип
                // вложения, а не голым URL.
                for (final code in sharedListCodesIn(message.body))
                  SharedListChip(code: code, onSurface: foreground),
                for (final attachment in message.attachments)
                  ChatAttachmentView(
                    attachment: attachment,
                    onSurface: foreground,
                    gallery: [
                      for (final a in message.attachments)
                        if (a.isImage && !a.deleted) a,
                    ],
                  ),
                if (message.reactions.isNotEmpty)
                  _MessageReactions(message: message, onSurface: foreground),
                const SizedBox(height: 2),
                // Нижняя строка пузыря: время, отметка о правке, галочки — и
                // ссылка на тред в самом правом углу, на одном уровне с ними.
                // Wrap, а не Row: у длинного «Изменено» рядом с «10 ответов» на
                // узком экране строка иначе вылезает за край пузыря.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    Text(
                      relativeTime(message.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.6),
                      ),
                    ),
                    if (message.isEdited)
                      Text(
                        'support.edited'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.6),
                        ),
                      ),
                    // Read receipts are only meaningful on one's own messages.
                    if (mine) ...[
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: foreground.withValues(alpha: 0.6),
                      ),
                    ],
                    if (message.hasThread && !inThread)
                      _ThreadLink(message: message, onSurface: foreground),
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

/// Маленькая ссылка на тред в правом нижнем углу пузыря, рядом со временем.
///
/// Без [Align] и без растяжек: пузырь должен оставаться шириной по своему
/// содержимому, а не разъезжаться на всю ленту из-за одной этой строчки.
class _ThreadLink extends StatelessWidget {
  const _ThreadLink({required this.message, required this.onSurface});

  final ChatMessage message;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: onSurface,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.forum_outlined, size: 16),
      label: Text(
        'support.threadReplies'.plural(message.replyCount),
        style: Theme.of(context).textTheme.labelMedium,
      ),
      onPressed: () => openMessageThread(context, message),
    );
  }
}

/// Строка эмодзи в верху меню сообщения.
///
/// Набор маленький и закрытый ([chatReactionEmojis]) — ровно на одну строку,
/// без «ещё» и без клавиатуры: выбор из шести значков делается одним движением,
/// а всё, что шире, бэкенд всё равно не примет. Уже поставленная своя реакция
/// подсвечена, и нажатие на неё её снимает.
class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.message, required this.onPicked});

  final ChatMessage message;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in chatReactionEmojis)
            IconButton(
              onPressed: () => onPicked(emoji),
              icon: Text(emoji, style: const TextStyle(fontSize: 24)),
              style: IconButton.styleFrom(
                backgroundColor: message.hasMyReaction(emoji)
                    ? scheme.primaryContainer
                    : null,
              ),
              tooltip: emoji,
            ),
        ],
      ),
    );
  }
}

/// Реакции под сообщением: значок и сколько человек его поставили.
///
/// Нажатие делает то же, что и строка в меню: ставит свою реакцию или снимает
/// её — присоединиться к чужой реакции должно быть одним касанием, без меню.
class _MessageReactions extends StatelessWidget {
  const _MessageReactions({required this.message, required this.onSurface});

  final ChatMessage message;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final reaction in message.reactions)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.read<ChatBloc>().add(
                ChatReactionToggled(message, reaction.emoji),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: reaction.mine
                      ? scheme.primary.withValues(alpha: 0.18)
                      : onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: reaction.mine ? scheme.primary : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${reaction.emoji} ${reaction.count}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: onSurface),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Что можно сделать с сообщением из меню по долгому тапу.
enum _MessageAction { reply, copy, edit, delete, report }

/// Свайп влево по сообщению — «ответить».
///
/// Сообщение уезжает за пальцем не дальше [_maxOffset], и на этой границе тред
/// открывается сам: жест доводится до конца рукой, а не отпусканием, поэтому
/// понятно, куда тянуть и когда отпустить. Stateful ровно ради одного числа —
/// текущего сдвига.
class _SwipeToOpenThread extends StatefulWidget {
  const _SwipeToOpenThread({required this.onTriggered, required this.child});

  final VoidCallback onTriggered;
  final Widget child;

  @override
  State<_SwipeToOpenThread> createState() => _SwipeToOpenThreadState();
}

class _SwipeToOpenThreadState extends State<_SwipeToOpenThread> {
  /// Дальше этого сообщение не уедет — и ровно здесь открывается тред.
  static const double _maxOffset = 72;

  double _offset = 0;

  /// Тред за один жест открывается один раз: палец может остаться на границе.
  bool _fired = false;

  void _update(DragUpdateDetails details) {
    if (_fired) return;
    final next = (_offset + details.delta.dx).clamp(-_maxOffset, 0.0);
    if (next != _offset) setState(() => _offset = next);
    if (_offset <= -_maxOffset) {
      _fired = true;
      HapticFeedback.selectionClick();
      setState(() => _offset = 0);
      widget.onTriggered();
    }
  }

  void _reset() {
    _fired = false;
    if (_offset != 0) setState(() => _offset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_offset.abs() / _maxOffset).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: (_) => _reset(),
      onHorizontalDragCancel: _reset,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Opacity(
                  opacity: progress,
                  child: Icon(
                    Icons.reply,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          // Сдвиг в пикселях, а не в долях ширины: пузырь у каждого сообщения
          // своей ширины, а граница жеста у всех одна.
          Transform.translate(offset: Offset(_offset, 0), child: widget.child),
        ],
      ),
    );
  }
}

/// Открыть тред на сообщение поверх текущего экрана.
///
/// Через [pushScreen], поэтому «назад» возвращает в переписку, откуда пришли, —
/// и так же работает, из какого бы экрана чат ни переиспользовали.
///
/// На возврате переписка перечитывается: пока читатель был в треде, у сообщения
/// прибавилось ответов, и ссылка «N ответов» под ним должна это показывать.
/// Живое событие из треда делает то же самое, но только пока socket жив, —
/// а вернуться из треда можно и без связи.
Future<void> openMessageThread(
  BuildContext context,
  ChatMessage message, {
  bool focusComposer = false,
}) async {
  final chatId = message.threadChatId;
  final bloc = context.read<ChatBloc>();
  await pushScreen(
    context,
    // Адрес есть только у уже созданного треда; новый создаётся бэкендом при
    // открытии, и экран приходится толкать императивно.
    path: chatId == null ? 'thread/${message.id}' : 'chat/$chatId',
    // Фокус — часть адреса, а не только императивного вызова: стек у роутера
    // строится из URL, и иначе открытый через него тред терял бы курсор.
    queryParameters: focusComposer ? const {'focus': '1'} : null,
    screen: () => ChatPage(
      target: MessageThreadTarget(message.id),
      focusComposer: focusComposer,
    ),
  );
  if (!bloc.isClosed) bloc.add(ChatRefreshed());
}

class _Composer extends StatelessWidget {
  const _Composer({required this.state, this.focusComposer = false});
  final ChatState state;
  final bool focusComposer;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ChatBloc>();
    void send() {
      if (state.canSend) bloc.add(ChatSendPressed());
    }

    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            // Полоска «правится сообщение» — единственное, чем режим правки
            // отличается от обычной отправки: поля и кнопки те же.
            if (state.isEditing)
              Row(
                spacing: 8,
                children: [
                  const Icon(Icons.edit_outlined, size: 18),
                  Expanded(
                    child: Text(
                      'support.editing'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'support.editCancel'.tr(),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => bloc.add(ChatEditCancelled()),
                  ),
                ],
              ),
            if (state.uploading || state.sharingList)
              LinearProgressIndicator(
                value: state.uploading && state.uploadProgress > 0
                    ? state.uploadProgress
                    : null,
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
                        // Имя файла обрезается по ширине чипа: полтора десятка
                        // вложений с длинными именами иначе занимают экран
                        // целиком и выдавливают из него саму переписку.
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            attachment.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onDeleted: () =>
                            bloc.add(ChatAttachmentRemoved(attachment)),
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
                  onPressed: state.uploading || state.sharingList
                      ? null
                      : () => showChatAttachMenu(context),
                ),
                Expanded(
                  child: _ComposerField(
                    autofocus: focusComposer,
                    text: state.body,
                    onChanged: (value) => bloc.add(ChatBodyChanged(value)),
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
                      : Icon(state.isEditing ? Icons.check : Icons.send),
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
    this.autofocus = false,
  });

  final String text;

  /// Забрать фокус сразу после открытия экрана.
  final bool autofocus;
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
        autofocus: widget.autofocus,
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
