import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../core/network/error_messages.dart';
import '../../notifications/data/notification_permissions.dart';
import '../../question_lists/data/shared_lists_repository.dart';
import '../data/chat_repository.dart';
import '../data/photo_compressor.dart';
import '../models/chat.dart';
import '../models/chat_target.dart';
import '../models/chat_update.dart';
import 'chat_events.dart';
import 'chat_state.dart';

/// Один разговор — какой именно, говорит [target].
///
/// Bloc ничего не знает про поддержку: он открывает чат (свой с разработчиком,
/// чужое обращение, тред на сообщение), читает его сообщения, шлёт и правит их,
/// подписывается на изменения и переключает колокольчик. Поэтому тот же Bloc
/// ведёт и тред, и — когда такие появятся — чат группы.
///
/// «Моё» сообщение определяется автором, а не стороной поддержки: в групповом
/// разговоре сторон больше двух, и правило «сравни с моим id» единственное,
/// которое там продолжает работать.
///
/// Opening the chat marks the counterpart's messages read, which is what makes
/// the user's side automatic and the moderator's side deliberate: a moderator
/// only ever gets here by opening a specific conversation.
///
/// While the screen is open the conversation follows the backend live. The
/// server's event says only *what* changed, never the message itself, so every
/// event re-reads the tail of the chat — one code path for a new message, for
/// an edit, for read receipts and for a reconnect, and no way for the two
/// sources to disagree about what the conversation looks like.
@injectable
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(
    this._chat,
    this._permissions,
    this._authRepo,
    this._sharedLists,
    @factoryParam ChatTarget? target,
  ) : target = target ?? const SupportChatTarget(),
      super(const ChatState()) {
    on<ChatOpened>(_onOpened);
    on<ChatChangedRemotely>(_onChangedRemotely);
    on<ChatLiveChanged>(_onLiveChanged);
    on<ChatRefreshed>(_onRefreshed);
    on<ChatOlderRequested>(_onOlderRequested);
    on<ChatBodyChanged>(_onBodyChanged);
    on<ChatFilePicked>(_onFilePicked);
    on<ChatPhotosPicked>(_onPhotosPicked);
    on<ChatAttachmentRemoved>(_onAttachmentRemoved);
    on<ChatListShared>(_onListShared);
    on<ChatSendPressed>(_onSendPressed);
    on<ChatEditStarted>(_onEditStarted);
    on<ChatEditCancelled>(_onEditCancelled);
    on<ChatNotificationsToggled>(_onNotificationsToggled);
    on<ChatNoticeShown>((_, emit) => emit(state.copyWith(notice: null)));
    on<ChatNotificationsDeclined>(_onNotificationsDeclined);
    on<ChatNotificationsAccepted>(_onNotificationsAccepted);
    on<ChatMessageDeleted>(_onMessageDeleted);
    on<ChatMessageReported>(_onMessageReported);
    on<ChatReactionToggled>(_onReactionToggled);
    on<ChatErrorDismissed>(
      (_, emit) => emit(state.copyWith(errorMessage: null)),
    );
    on<ChatUploadProgress>(
      (event, emit) => emit(state.copyWith(uploadProgress: event.value)),
    );
  }

  final ChatRepository _chat;
  final NotificationPermissions _permissions;

  /// Системный выбор фотографий. Создаётся здесь, а не приходит из getIt:
  /// `ImagePicker` — тонкая обёртка над каналом платформы без состояния.
  final ImagePicker _picker = ImagePicker();

  final AuthRepository _authRepo;

  /// Ссылки шаринга на списки вопросов — единственный способ приложить список
  /// к сообщению.
  final SharedListsRepository _sharedLists;

  /// Какой разговор показывает экран.
  final ChatTarget target;

  /// Идентификатор открытого чата: у цели-идентификатора известен сразу, у
  /// своего чата и треда — после первого чтения.
  String? _chatId;

  /// Shared with the notifications screen and the comments Bloc — one app-level
  /// push preference, not one per feature.
  static const _pushNotifKey = 'notif_push_enabled';

  /// Remembers that the chat already made its notification offer, so it is asked
  /// once and never again.
  static const _supportPromptKey = 'support_chat_notifications_asked';

  /// Читаю ли я этот разговор со стороны поддержки: чат с разработчиком, но не
  /// мой собственный. От этого зависит только то, помечаются ли чужие
  /// сообщения прочитанными сами собой.
  bool get _isModerator {
    final chat = state.thread;
    if (chat == null) return target is! SupportChatTarget;
    if (chat.isThread) return false;
    return chat.entityType == ChatEntityType.support &&
        chat.userId != state.myUserId;
  }

  /// The live subscription, alive for as long as the screen is.
  StreamSubscription<ChatUpdate>? _live;

  /// Сообщения, удалённые с этого экрана. Страница с сервера их уже не
  /// содержит, а [_merge] сохраняет всё, чего в странице нет, — без этого
  /// списка удалённое сообщение возвращалось бы на экран при первом же
  /// перечитывании переписки.
  final Set<String> _deleted = {};

  /// A re-read is in flight; another event that lands meanwhile is remembered
  /// rather than run in parallel, so a burst of events costs one extra read.
  bool _syncing = false;
  bool _syncPending = false;

  /// How many messages one read carries. The server caps a page at 50.
  static const pageSize = 50;

  /// Смещение первого показанного сообщения от начала разговора: `0` — видно
  /// самое первое, `null` — разговор ещё ни разу не читали. По нему и решается,
  /// есть ли что подгружать выше.
  int? _windowOffset;

  @override
  Future<void> close() {
    _live?.cancel();
    return super.close();
  }

  Future<void> _onOpened(ChatOpened event, Emitter<ChatState> emit) async {
    // Кто я — нужно раньше сообщений: по автору решается, чьё сообщение «моё».
    if (state.myUserId.isEmpty) {
      try {
        final me = await _authRepo.me();
        if (me != null && !emit.isDone) emit(state.copyWith(myUserId: me.id));
      } catch (_) {
        // Без него ленту всё равно видно; «моими» станут сообщения стороны.
      }
    }
    await _refreshSystemNotifications(emit);
    await _load(emit);
    // Подписка — после первого чтения: у своего чата и у треда идентификатор
    // разговора становится известен только оттуда.
    _listen();
    if (state.errorMessage != null) return;

    // Opening the chat is what marks the other side's messages read.
    await _markRead(emit);

    // Разговор о вопросе открывается заодно с самим вопросом, а предложение
    // про оповещения делается один раз на всё приложение: тратить его на
    // случайную страницу нельзя — там оно и не к месту.
    if (!_isModerator && target is! QuestionChatTarget) {
      await _maybeOfferNotifications(emit);
    }
  }

  /// Go live. A failure here is silent on purpose: a chat that cannot subscribe
  /// still reads, sends and refreshes by hand, and the screen says so with the
  /// offline indicator instead of an error the reader can do nothing about.
  void _listen() {
    final chatId = _chatId;
    if (chatId == null) return;
    _live ??= _chat
        .changes(chatId: chatId)
        .listen(
          (update) {
            switch (update) {
              case ChatChanged(:final kind, :final messageId):
                // Удалённое сообщение уносится по идентификатору из события:
                // перечитанная страница о нём молчит, и без этого чужое
                // удаление оставалось бы на экране до перезахода.
                add(
                  ChatChangedRemotely(
                    deletedMessageId: kind == ChatChangeKind.messageDeleted
                        ? messageId
                        : null,
                  ),
                );
              case ChatLive(:final firstConnect):
                add(ChatLiveChanged(live: true, missed: !firstConnect));
              case ChatOffline():
                add(ChatLiveChanged(live: false));
            }
          },
          onError: (_) => add(ChatLiveChanged(live: false)),
          onDone: () => add(ChatLiveChanged(live: false)),
        );
  }

  /// Something changed in the conversation. What exactly is not interesting —
  /// the event carries no message, so the tail is re-read either way.
  Future<void> _onChangedRemotely(
    ChatChangedRemotely event,
    Emitter<ChatState> emit,
  ) async {
    final deleted = event.deletedMessageId;
    if (deleted != null) {
      // Удалённое сообщение уносим сразу: страница с сервера о нём молчит, а
      // `_merge` сохраняет всё, чего в странице нет.
      _deleted.add(deleted);
      if (!emit.isDone) {
        emit(
          state.copyWith(
            messages: state.messages.where((m) => m.id != deleted).toList(),
          ),
        );
      }
    }
    // Before the first read there is nothing to keep in sync; the read itself
    // brings whatever the event was about.
    if (!state.loaded) return;
    if (_syncing) {
      _syncPending = true;
      return;
    }
    _syncing = true;
    try {
      await _load(emit, silent: true);
      // A reply that arrives while the user is looking at it is read, and their
      // side marks read automatically. A moderator's side does not: there it is
      // a deliberate act, and opening the conversation is what performs it.
      if (!_isModerator && state.messages.any(_fromCounterpart)) {
        await _markRead(emit);
      }
    } finally {
      _syncing = false;
      if (_syncPending && !isClosed) {
        _syncPending = false;
        add(ChatChangedRemotely());
      }
    }
  }

  Future<void> _onLiveChanged(
    ChatLiveChanged event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(live: event.live));
    // A reconnect means the socket was down for a while and the server keeps no
    // backlog — re-read instead of leaving a hole in the conversation.
    if (event.missed && state.loaded) add(ChatChangedRemotely());
  }

  Future<void> _onRefreshed(ChatRefreshed event, Emitter<ChatState> emit) =>
      _load(emit);

  /// Read the thread and the newest page of its messages.
  ///
  /// [silent] is for the live path: it neither shows the progress bar nor
  /// reports a failure, because a re-read triggered by an event the reader never
  /// asked for should not take over the screen — the next event tries again.
  Future<void> _load(Emitter<ChatState> emit, {bool silent = false}) async {
    if (!silent) emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final chat = await _openChat();
      _chatId = chat.id;
      final page = await _tail(chat);
      final parent = await _parentMessage(chat);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          loading: false,
          loaded: true,
          thread: chat,
          parentMessage: parent ?? state.parentMessage,
          messages: _merge(page.nodes),
          hasOlder: (_windowOffset ?? 0) > 0,
        ),
      );
    } catch (e) {
      if (emit.isDone || silent) return;
      emit(
        state.copyWith(
          loading: false,
          errorMessage: _message(e),
          loadFailedOffline: isNetworkError(e),
        ),
      );
    }
  }

  /// Открыть разговор, о котором просили. Тред бэкенд создаёт при первом
  /// обращении, поэтому «открыть» и «создать» — одно и то же действие.
  Future<Chat> _openChat() async {
    final id = _chatId;
    if (id != null) return _chat.chat(id);
    return switch (target) {
      SupportChatTarget() => _chat.supportChat(),
      ChatIdTarget(:final chatId) => _chat.chat(chatId),
      MessageThreadTarget(:final messageId) => _chat.messageThread(messageId),
      GroupChatTarget(:final groupId) => _chat.groupChat(groupId),
      QuestionChatTarget(:final questionId) => _chat.questionChat(questionId),
    };
  }

  /// Сообщение, ответы на которое собирает тред, — шапка над лентой ответов.
  ///
  /// Читается отдельным запросом: в самой ленте треда родителя нет, он живёт в
  /// родительском чате. Один раз за открытие — правки родителя приезжают своим
  /// событием в его чате, а не сюда.
  Future<ChatMessage?> _parentMessage(Chat chat) async {
    if (!chat.isThread || state.parentMessage != null) return null;
    final id = chat.parentMessageId;
    if (id == null) return null;
    try {
      return await _chat.message(id);
    } catch (_) {
      // Пустая шапка честнее выдуманной: лучше показать одни ответы, чем
      // пузырь «Без имени, только что» вместо настоящего сообщения.
      return null;
    }
  }

  /// The last page of the conversation. Pages come oldest-first, so the newest
  /// messages — the ones an open chat is about — sit at the *end*, and reading
  /// from offset 0 would show the beginning of a long conversation forever.
  Future<ChatMessagePage> _tail(Chat chat) {
    final offset = chat.messagesCount > pageSize
        ? chat.messagesCount - pageSize
        : 0;
    // Сервер отдаёт не больше 50 сообщений за раз, поэтому перечитывается
    // всегда хвост, а уже подгруженная история остаётся на экране: [_merge]
    // хранит всё, чего в странице нет. Граница окна только опускается — вверх
    // её двигает лишь «показать ещё».
    _windowOffset = _windowOffset == null || offset < _windowOffset!
        ? offset
        : _windowOffset;
    return _chat.messages(chat.id, offset: offset, limit: pageSize);
  }

  /// Ещё одна страница — та, что старше самой старой показанной.
  ///
  /// Страницы у сервера считаются от начала разговора, поэтому «старше» — это
  /// шаг назад по смещению: окно растёт вверх, к первому сообщению.
  Future<void> _onOlderRequested(
    ChatOlderRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = _chatId;
    final offset = _windowOffset;
    if (chatId == null || offset == null || offset <= 0) return;
    if (state.loadingOlder) return;
    emit(state.copyWith(loadingOlder: true));
    final next = offset > pageSize ? offset - pageSize : 0;
    try {
      final page = await _chat.messages(
        chatId,
        offset: next,
        limit: offset - next,
      );
      if (emit.isDone) return;
      _windowOffset = next;
      emit(
        state.copyWith(
          loadingOlder: false,
          messages: _merge(page.nodes),
          hasOlder: next > 0,
        ),
      );
    } catch (e) {
      if (emit.isDone) return;
      // Не дочитанная история — не повод рушить экран: то, что уже видно,
      // остаётся на месте, а кнопка «показать ещё» пробует снова.
      emit(state.copyWith(loadingOlder: false, errorMessage: _message(e)));
    }
  }

  /// Fold a freshly-read page into what is on screen, keyed by id: the server's
  /// copy wins (it carries the current read receipt), and anything already shown
  /// and not in the page — a message just sent, an older one above the window —
  /// stays where it is.
  List<ChatMessage> _merge(List<ChatMessage> incoming) {
    final byId = {for (final m in state.messages) m.id: m};
    for (final message in incoming) {
      byId[message.id] = message;
    }
    for (final id in _deleted) {
      byId.remove(id);
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return merged;
  }

  /// Mark the counterpart's messages read and show it right away, without
  /// waiting for the re-read the server's own event will bring.
  Future<void> _markRead(Emitter<ChatState> emit) async {
    final chatId = _chatId;
    if (chatId == null) return;
    try {
      await _chat.markRead(chatId);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          thread: state.thread?.copyWith(unreadCount: 0),
          messages: [
            for (final m in state.messages)
              if (_fromCounterpart(m))
                m.copyWith(readAt: DateTime.now())
              else
                m,
          ],
        ),
      );
    } catch (_) {
      // Read receipts are never worth an error banner over.
    }
  }

  /// Непрочитанное сообщение, написанное не мной.
  bool _fromCounterpart(ChatMessage message) =>
      !state.isMine(message) && !message.isRead;

  void _onBodyChanged(ChatBodyChanged event, Emitter<ChatState> emit) {
    emit(state.copyWith(body: event.body));
  }

  /// «Файл»: системный выбор, загрузка байт в байт — файл должен дойти до
  /// получателя ровно таким, каким его выбрали.
  Future<void> _onFilePicked(
    ChatFilePicked event,
    Emitter<ChatState> emit,
  ) async {
    if (state.uploading) return;
    final XFile? file;
    try {
      file = await openFile();
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType;
    await _upload(
      emit,
      bytes: bytes,
      fileName: file.name,
      // The backend decides whether an attachment is a picture purely from
      // the MIME type it is told, and `XFile.mimeType` is null on every
      // platform except the web — without the fallback every screenshot sent
      // from a phone arrived as `application/octet-stream` and was filed away
      // as a plain download instead of being shown in the bubble.
      contentType: mimeType == null || mimeType.isEmpty
          ? contentTypeForFileName(file.name)
          : mimeType,
    );
  }

  /// «Фотография»: системная галерея, пережатие в JPEG на устройстве, загрузка.
  ///
  /// Можно выбрать сразу несколько — они загружаются по очереди и по очереди
  /// появляются в строке ввода, так что уже загруженное не теряется, если на
  /// третьем снимке пропала связь.
  Future<void> _onPhotosPicked(
    ChatPhotosPicked event,
    Emitter<ChatState> emit,
  ) async {
    if (state.uploading) return;
    final List<XFile> photos;
    try {
      photos = await _picker.pickMultiImage(
        // Уменьшение и качество на Android/iOS делает системный кодек — почти
        // бесплатно; в вебе эти параметры игнорируются, и всю работу берёт на
        // себя `compressPhoto`.
        maxWidth: kPhotoMaxDimension.toDouble(),
        maxHeight: kPhotoMaxDimension.toDouble(),
        imageQuality: kPhotoJpegQuality,
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
      return;
    }
    if (photos.isEmpty) return;
    for (final photo in photos) {
      if (isClosed || emit.isDone) return;
      final compressed = await compressPhoto(
        bytes: await photo.readAsBytes(),
        fileName: photo.name,
      );
      final ok = await _upload(
        emit,
        bytes: compressed.bytes,
        fileName: compressed.fileName,
        contentType: compressed.contentType,
      );
      if (!ok) return;
    }
  }

  /// Загрузить готовые байты и показать их в строке ввода. Возвращает `false`,
  /// если не вышло, — тогда очередь из нескольких фотографий останавливается.
  Future<bool> _upload(
    Emitter<ChatState> emit, {
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    if (state.pending.length >= maxAttachments) {
      emit(
        state.copyWith(
          uploading: false,
          errorMessage: 'support.tooManyAttachments',
        ),
      );
      return false;
    }
    if (bytes.length > _maxAttachmentBytes) {
      emit(
        state.copyWith(
          uploading: false,
          errorMessage: 'support.attachmentTooLarge',
        ),
      );
      return false;
    }
    emit(
      state.copyWith(uploading: true, uploadProgress: 0, errorMessage: null),
    );
    try {
      final chatId = _chatId;
      if (chatId == null) return false;
      final attachment = await _chat.uploadAttachment(
        chatId: chatId,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        // Progress ticks arrive from Dio, outside this handler's emit window,
        // so they come back in as their own event.
        onProgress: (sent, total) {
          if (total > 0 && !isClosed) {
            add(ChatUploadProgress(sent / total));
          }
        },
      );
      if (emit.isDone) return false;
      emit(
        state.copyWith(
          uploading: false,
          uploadProgress: 1,
          pending: [...state.pending, attachment],
        ),
      );
      return true;
    } catch (e) {
      if (!emit.isDone) {
        emit(state.copyWith(uploading: false, errorMessage: _message(e)));
      }
      return false;
    }
  }

  /// «Список вопросов» в меню вложений: список уходит ссылкой шаринга.
  ///
  /// Способ приложить список ровно один — тот же, которым список отдают кому
  /// угодно ещё: получатель видит текущее содержимое списка, может его
  /// сохранить себе, а ссылка живёт и после того, как переписку закрыли.
  /// Ссылка дописывается в строку ввода, откуда её видно до отправки.
  Future<void> _onListShared(
    ChatListShared event,
    Emitter<ChatState> emit,
  ) async {
    if (state.sharingList) return;
    emit(state.copyWith(sharingList: true, errorMessage: null));
    try {
      final share = await _sharedLists.share(event.list.id);
      if (emit.isDone) return;
      final body = state.body.trimRight();
      emit(
        state.copyWith(
          sharingList: false,
          body: body.isEmpty ? share.url : '$body\n${share.url}',
        ),
      );
    } catch (e) {
      if (!emit.isDone) {
        emit(state.copyWith(sharingList: false, errorMessage: _message(e)));
      }
    }
  }

  /// «Удалить» — только своё сообщение, и целиком: бэкенд убирает и вложения.
  Future<void> _onMessageDeleted(
    ChatMessageDeleted event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.isMine(event.message)) return;
    try {
      await _chat.deleteMessage(event.message.id);
    } catch (e) {
      if (!emit.isDone) emit(state.copyWith(errorMessage: _message(e)));
      return;
    }
    _deleted.add(event.message.id);
    if (emit.isDone) return;
    // Убираем сразу, не дожидаясь события подписки: удаливший должен увидеть
    // результат своего действия и без живого соединения.
    emit(
      state.copyWith(
        messages: state.messages
            .where((m) => m.id != event.message.id)
            .toList(),
        editing: state.editing?.id == event.message.id ? null : state.editing,
      ),
    );
  }

  /// «Пожаловаться»: жалоба уходит модератору, автору сообщения об этом ничего
  /// не сообщается.
  Future<void> _onMessageReported(
    ChatMessageReported event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chat.reportMessage(
        messageId: event.message.id,
        reason: event.reason,
      );
      if (!emit.isDone) emit(state.copyWith(notice: 'support.reportSent'));
    } catch (e) {
      if (!emit.isDone) emit(state.copyWith(errorMessage: _message(e)));
    }
  }

  /// Реакция ставится и снимается одним нажатием, и на экране это видно
  /// сразу — до ответа сервера.
  ///
  /// Иначе значок «залипает» на время запроса, а нажимают его быстро и по
  /// нескольку раз. Если запрос не прошёл, лента возвращается к тому, что было:
  /// показывать реакцию, которой на сервере нет, хуже, чем не показать её
  /// вовсе.
  Future<void> _onReactionToggled(
    ChatReactionToggled event,
    Emitter<ChatState> emit,
  ) async {
    emit(_withReaction(event.message.id, event.emoji));
    try {
      await _chat.toggleReaction(
        messageId: event.message.id,
        emoji: event.emoji,
      );
    } catch (e) {
      if (emit.isDone) return;
      // Откатываем тем же переключателем, а не подменой всей ленты на снимок
      // до нажатия: пока летел запрос, в разговор могло приехать сообщение, и
      // снимок унёс бы его с экрана.
      emit(
        _withReaction(
          event.message.id,
          event.emoji,
        ).copyWith(errorMessage: _message(e)),
      );
    }
  }

  /// Состояние с переключённой реакцией — и в ленте, и в шапке треда: одно и то
  /// же сообщение может быть показано в обоих местах.
  ChatState _withReaction(String messageId, String emoji) {
    final parent = state.parentMessage;
    return state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == messageId) m.withToggledReaction(emoji) else m,
      ],
      parentMessage: parent?.id == messageId
          ? parent!.withToggledReaction(emoji)
          : parent,
    );
  }

  void _onAttachmentRemoved(
    ChatAttachmentRemoved event,
    Emitter<ChatState> emit,
  ) {
    // The uploaded object is left to the backend's sweeper: dropping it from the
    // composer is a UI decision, and there is no "unsend" to make server-side.
    emit(
      state.copyWith(
        pending: state.pending
            .where((a) => a.id != event.attachment.id)
            .toList(),
      ),
    );
  }

  Future<void> _onSendPressed(
    ChatSendPressed event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.canSend) return;
    final chatId = _chatId;
    if (chatId == null) return;
    final body = state.body.trim();
    final attachmentIds = state.pending.map((a) => a.id).toList();
    final editing = state.editing;

    emit(state.copyWith(sending: true, errorMessage: null));
    try {
      final message = editing == null
          ? await _chat.send(
              chatId: chatId,
              body: body,
              attachmentIds: attachmentIds,
            )
          // Правка отправляет весь желаемый набор вложений: то, что осталось от
          // прошлой версии, лежит в той же строке ввода, что и новое.
          : await _chat.edit(
              messageId: editing.id,
              body: body,
              attachmentIds: attachmentIds,
            );
      emit(
        state.copyWith(
          sending: false,
          body: '',
          pending: const [],
          editing: null,
          // Through the same merge as a live update: the subscription is about
          // to deliver this very message back, and it must not double up.
          messages: _merge([message]),
        ),
      );
    } catch (e) {
      emit(state.copyWith(sending: false, errorMessage: _message(e)));
    }
  }

  /// «Изменить»: текст и вложения отправленного сообщения переезжают в строку
  /// ввода, откуда их правят теми же кнопками, что и при обычной отправке.
  void _onEditStarted(ChatEditStarted event, Emitter<ChatState> emit) {
    emit(
      state.copyWith(
        editing: event.message,
        body: event.message.body,
        // Ссылки на вопросы и списки пересобираются бэкендом из нового текста,
        // так что в строку ввода переезжают только настоящие файлы и картинки.
        pending: [
          for (final a in event.message.attachments)
            if (!a.isReference && !a.deleted) a,
        ],
        errorMessage: null,
      ),
    );
  }

  void _onEditCancelled(ChatEditCancelled event, Emitter<ChatState> emit) {
    emit(state.copyWith(editing: null, body: '', pending: const []));
  }

  /// Колокольчик: переключить оповещения об этом разговоре и сказать об этом
  /// snackbar'ом — ровно тем текстом, который просили в задаче.
  Future<void> _onNotificationsToggled(
    ChatNotificationsToggled event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.thread;
    final chatId = _chatId;
    if (chat == null || chatId == null) return;
    // Колокольчик, перечёркнутый системой, сначала занимается системой:
    // включать оповещения чата, которые всё равно не придут, бессмысленно.
    if (state.systemNotificationsBlocked) {
      await _ensureSystemNotifications();
      await _refreshSystemNotifications(emit);
      if (state.systemNotificationsBlocked) return;
    }
    final enabled = !chat.notificationsEnabled;
    try {
      await _chat.setNotifications(chatId: chatId, enabled: enabled);
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
      return;
    }
    if (emit.isDone) return;
    emit(
      state.copyWith(
        thread: chat.copyWith(notificationsEnabled: enabled),
        notice: _noticeKey(enabled: enabled, thread: chat.isThread),
      ),
    );
    // Включённые для чата оповещения бесполезны, пока выключены системные:
    // спрашиваем разрешение ровно тогда, когда пользователь их включил.
    if (enabled) {
      await _ensureSystemNotifications();
      await _refreshSystemNotifications(emit);
    }
  }

  String _noticeKey({required bool enabled, required bool thread}) {
    if (thread) {
      return enabled ? 'support.notifyOnThread' : 'support.notifyOffThread';
    }
    return enabled ? 'support.notifyOnChat' : 'support.notifyOffChat';
  }

  /// Разрешены ли уведомления системой — от этого зависит вид колокольчика.
  Future<void> _refreshSystemNotifications(Emitter<ChatState> emit) async {
    try {
      final status = await _permissions.status();
      if (emit.isDone) return;
      emit(state.copyWith(systemNotificationsBlocked: !status.granted));
    } catch (_) {
      // На вебе и в тестах разрешения может не быть вовсе — тогда молчим.
    }
  }

  /// Спросить систему про уведомления (или отправить в настройки, если в них
  /// отказано навсегда) и включить push для устройства.
  Future<void> _ensureSystemNotifications() async {
    try {
      var status = await _permissions.status();
      if (status.permanentlyDenied) {
        await _permissions.openSettings();
        return;
      }
      if (!status.granted) status = await _permissions.request();
      if (!status.granted) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pushNotifKey) != true) {
        await prefs.setBool(_pushNotifKey, true);
        await _authRepo.registerDevice(platform: _platform());
        await _authRepo.setDevicePushEnabled(true);
      }
    } catch (_) {
      // Requires a configured FCM token to fully take effect.
    }
  }

  /// Ask about notifications the first time the user opens their chat — the same
  /// offer the question discussion makes, and for the same reason: an answer
  /// that arrives hours later is worthless if nothing tells them about it.
  Future<void> _maybeOfferNotifications(Emitter<ChatState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_supportPromptKey) == true) return;
      if (prefs.getBool(_pushNotifKey) == true) return;
      final status = await _permissions.status();
      if (status.granted) return;
      emit(state.copyWith(notificationsPrompt: true));
    } catch (_) {
      // Best-effort: never block the chat over the offer.
    }
  }

  Future<void> _onNotificationsDeclined(
    ChatNotificationsDeclined event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(notificationsPrompt: false));
    await _rememberAsked();
  }

  /// Accepted: ask the OS, then turn the app-level push preference on and
  /// register the device. Best-effort throughout — the chat works without it.
  Future<void> _onNotificationsAccepted(
    ChatNotificationsAccepted event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(notificationsPrompt: false));
    await _rememberAsked();
    try {
      var status = await _permissions.status();
      if (!status.granted && !status.permanentlyDenied) {
        status = await _permissions.request();
      } else if (status.permanentlyDenied) {
        await _permissions.openSettings();
      }
      if (!status.granted) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pushNotifKey) != true) {
        await prefs.setBool(_pushNotifKey, true);
        await _authRepo.registerDevice(platform: _platform());
        await _authRepo.setDevicePushEnabled(true);
      }
    } catch (_) {
      // Requires a configured FCM token to fully take effect.
    }
  }

  Future<void> _rememberAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_supportPromptKey, true);
    } catch (_) {}
  }

  String _platform() => kIsWeb ? 'web' : defaultTargetPlatform.name;

  String _message(Object e) => describeError(e);

  /// Mirrors the backend's cap, so an oversized file is refused before it is
  /// pushed over the wire.
  static const _maxAttachmentBytes = 20 * 1024 * 1024;

  /// Сколько файлов и картинок помещается в одно сообщение — столько же, сколько
  /// принимает бэкенд. Больше просто не влезает на экран получателя.
  static const maxAttachments = 15;
}
