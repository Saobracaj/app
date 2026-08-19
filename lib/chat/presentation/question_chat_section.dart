import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../core/presentation/load_failed_view.dart';
import '../../generated/locale_keys.g.dart';
import '../models/chat_target.dart';
import '../state_management/chat_bloc.dart';
import '../state_management/chat_events.dart';
import '../state_management/chat_state.dart';
import 'chat_page.dart';

/// Обсуждение одного вопроса — чат, живущий на вкладке самого вопроса.
///
/// Это тот же разговор, что и везде в приложении (тот же [ChatBloc], те же
/// пузыри, реакции, треды и вложения), но перевёрнутый: страница вопроса
/// прокручивается сверху вниз, поэтому первым идёт поле ввода, под ним — самое
/// свежее сообщение, дальше всё более старые. Прокрутка вниз — это прокрутка в
/// прошлое, и подгружает она именно его.
///
/// Своей прокрутки у ленты нет: она разворачивается колонкой внутри прокрутки
/// страницы, а следующая страница истории просится, когда читатель до неё
/// добрался ([_LoadOlderWhenReached]).
class QuestionChatSection extends StatelessWidget {
  const QuestionChatSection({
    super.key,
    required this.questionId,
    this.messageId,
  });

  final int questionId;

  /// Сообщение из ссылки-оповещения: лента доматывается до него и подсвечивает
  /// его, а если оно старше загруженного — история дочитывается до него.
  final String? messageId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<ChatBloc>(param1: QuestionChatTarget(questionId))
            ..add(ChatOpened()),
      child: QuestionChatView(messageId: messageId),
    );
  }
}

/// Сама перевёрнутая лента, без создания [ChatBloc] — он берётся из контекста.
/// Отдельно от [QuestionChatSection], чтобы разговор можно было открыть
/// снаружи (и чтобы вёрстку можно было проверить на готовом состоянии).
class QuestionChatView extends StatelessWidget {
  const QuestionChatView({super.key, this.messageId});

  final String? messageId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      // Ошибка отправки — снекбаром, ошибка чтения — блоком с повтором (её
      // показывает `build`), поэтому слушается только вторая половина.
      listenWhen: (a, b) =>
          b.loaded &&
          a.errorMessage != b.errorMessage &&
          b.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.errorMessage!.startsWith('support.')
                  ? state.errorMessage!.tr()
                  : state.errorMessage!,
            ),
          ),
        );
        context.read<ChatBloc>().add(ChatErrorDismissed());
      },
      builder: (context, state) {
        final bloc = context.read<ChatBloc>();
        if (!state.loaded && state.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!state.loaded) {
          // Не прочиталось — это не «здесь пусто»: место занимает блок с
          // повтором, а не приглашение написать первым.
          return LoadFailedView(
            compact: true,
            offline: state.loadFailedOffline,
            message:
                state.errorMessage ?? LocaleKeys.questionChat_loadError.tr(),
            onRetry: () => bloc.add(ChatRefreshed()),
          );
        }
        // Сверху вниз: поле ввода, самое свежее сообщение, всё более старые.
        final messages = state.messages.reversed.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChatComposer(state: state),
            // Своё «Без имени» под своим же сообщением объясняется прямо здесь:
            // имя ставится в настройках, и туда ведёт эта строка. Показывается
            // только тому, кто уже написал безымянным — до первого сообщения
            // просить имя не за что.
            if (state.messages.any(
              (m) => state.isMine(m) && m.authorDisplayName.trim().isEmpty,
            ))
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        LocaleKeys.questionChat_noName.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Routemaster.of(context).push('/displayName'),
                      child: Text(LocaleKeys.questionChat_setName.tr()),
                    ),
                  ],
                ),
              ),
            if (messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 24,
                ),
                child: Text(
                  LocaleKeys.questionChat_empty.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final message in messages)
                      _Anchored(
                        key: ValueKey(message.id),
                        anchored: message.id == messageId,
                        child: ChatMessageBubble(
                          message: message,
                          mine: state.isMine(message),
                        ),
                      ),
                  ],
                ),
              ),
            if (state.hasOlder)
              _LoadOlderWhenReached(
                enabled: !state.loadingOlder,
                onLoad: () => bloc.add(ChatOlderRequested()),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: state.loadingOlder
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => bloc.add(ChatOlderRequested()),
                            child: Text(LocaleKeys.common_loadMore.tr()),
                          ),
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            // Ссылка вела на сообщение, которого в загруженном хвосте нет:
            // история дочитывается назад, пока оно не найдётся.
            if (messageId != null &&
                state.hasOlder &&
                !state.loadingOlder &&
                !state.messages.any((m) => m.id == messageId))
              // Ключ — сколько сообщений уже прочитано: с приходом очередной
              // страницы виджет пересоздаётся и просит следующую, пока
              // сообщение не найдётся или история не кончится.
              _RequestOnce(
                key: ValueKey(state.messages.length),
                onRequest: () => bloc.add(ChatOlderRequested()),
              ),
          ],
        );
      },
    );
  }
}

/// Сообщение, на которое привела ссылка: подсвечено и один раз показано.
class _Anchored extends StatefulWidget {
  const _Anchored({super.key, required this.anchored, required this.child});

  final bool anchored;
  final Widget child;

  @override
  State<_Anchored> createState() => _AnchoredState();
}

class _AnchoredState extends State<_Anchored> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.anchored) _revealOnce();
  }

  @override
  void didUpdateWidget(_Anchored oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anchored && !oldWidget.anchored) _revealOnce();
  }

  void _revealOnce() {
    if (_shown) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        alignment: 0.3,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.anchored) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: widget.child,
    );
  }
}

/// Просит следующую (более старую) страницу, когда читатель до неё
/// прокрутил — и сразу, если она попала на экран без всякой прокрутки.
///
/// Своей прокрутки у чата на странице вопроса нет, поэтому
/// [NotificationListener] здесь бесполезен: уведомления идут вверх по дереву,
/// а прокрутка — снаружи. Виджет вместо этого подписывается на прокрутку
/// страницы и спрашивает у неё, на каком смещении его собственная нижняя
/// граница дойдёт до низа окна.
class _LoadOlderWhenReached extends StatefulWidget {
  const _LoadOlderWhenReached({
    required this.enabled,
    required this.onLoad,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onLoad;
  final Widget child;

  @override
  State<_LoadOlderWhenReached> createState() => _LoadOlderWhenReachedState();
}

class _LoadOlderWhenReachedState extends State<_LoadOlderWhenReached> {
  ScrollPosition? _position;

  /// За сколько пикселей до края просить страницу, чтобы прокрутка не
  /// упиралась в ожидание ответа.
  static const _lookahead = 300.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_check);
    _position = position?..addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(_LoadOlderWhenReached oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted || !widget.enabled) return;
    final position = _position;
    final box = context.findRenderObject();
    if (position == null || box is! RenderBox || !box.hasSize) return;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    // Смещение, на котором низ этого блока совпадёт с низом окна: пока до него
    // дальше, чем [_lookahead], читателю ещё есть что читать.
    final reveal = viewport.getOffsetToReveal(box, 1.0).offset;
    if (position.pixels >= reveal - _lookahead) widget.onLoad();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Отправляет запрос один раз за появление — чтобы дочитывание истории до
/// сообщения из ссылки не превратилось в цикл на каждую перерисовку.
class _RequestOnce extends StatefulWidget {
  const _RequestOnce({super.key, required this.onRequest});

  final VoidCallback onRequest;

  @override
  State<_RequestOnce> createState() => _RequestOnceState();
}

class _RequestOnceState extends State<_RequestOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRequest();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
