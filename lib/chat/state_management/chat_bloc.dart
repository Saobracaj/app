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
import '../../question_lists/models/question_list.dart';
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
    @factoryParam ChatTarget? target,
  ) : target = target ?? const SupportChatTarget(),
      super(const ChatState()) {
    on<ChatOpened>(_onOpened);
    on<ChatChangedRemotely>(_onChangedRemotely);
    on<ChatLiveChanged>(_onLiveChanged);
    on<ChatRefreshed>(_onRefreshed);
    on<ChatBodyChanged>(_onBodyChanged);
    on<ChatFilePicked>(_onFilePicked);
    on<ChatPhotosPicked>(_onPhotosPicked);
    on<ChatAttachmentRemoved>(_onAttachmentRemoved);
    on<ChatListAttached>(_onListAttached);
    on<ChatListRemoved>(_onListRemoved);
    on<ChatSendPressed>(_onSendPressed);
    on<ChatEditStarted>(_onEditStarted);
    on<ChatEditCancelled>(_onEditCancelled);
    on<ChatNotificationsToggled>(_onNotificationsToggled);
    on<ChatNoticeShown>((_, emit) => emit(state.copyWith(notice: null)));
    on<ChatNotificationsDeclined>(_onNotificationsDeclined);
    on<ChatNotificationsAccepted>(_onNotificationsAccepted);
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

  /// A re-read is in flight; another event that lands meanwhile is remembered
  /// rather than run in parallel, so a burst of events costs one extra read.
  bool _syncing = false;
  bool _syncPending = false;

  /// How many messages one read carries. The server caps a page at 50.
  static const pageSize = 50;

  @override
  Future<void> close() {
    _live?.cancel();
    return super.close();
  }

  Future<void> _onOpened(
    ChatOpened event,
    Emitter<ChatState> emit,
  ) async {
    // Кто я — нужно раньше сообщений: по автору решается, чьё сообщение «моё».
    if (state.myUserId.isEmpty) {
      try {
        final me = await _authRepo.me();
        if (me != null && !emit.isDone) emit(state.copyWith(myUserId: me.id));
      } catch (_) {
        // Без него ленту всё равно видно; «моими» станут сообщения стороны.
      }
    }
    await _load(emit);
    // Подписка — после первого чтения: у своего чата и у треда идентификатор
    // разговора становится известен только оттуда.
    _listen();
    if (state.errorMessage != null) return;

    // Opening the chat is what marks the other side's messages read.
    await _markRead(emit);

    if (!_isModerator) await _maybeOfferNotifications(emit);
  }

  /// Go live. A failure here is silent on purpose: a chat that cannot subscribe
  /// still reads, sends and refreshes by hand, and the screen says so with the
  /// offline indicator instead of an error the reader can do nothing about.
  void _listen() {
    final chatId = _chatId;
    if (chatId == null) return;
    _live ??= _chat.changes(chatId: chatId).listen(
      (update) {
        switch (update) {
          case ChatChanged():
            add(ChatChangedRemotely());
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

  Future<void> _onRefreshed(
    ChatRefreshed event,
    Emitter<ChatState> emit,
  ) => _load(emit);

  /// Read the thread and the newest page of its messages.
  ///
  /// [silent] is for the live path: it neither shows the progress bar nor
  /// reports a failure, because a re-read triggered by an event the reader never
  /// asked for should not take over the screen — the next event tries again.
  Future<void> _load(
    Emitter<ChatState> emit, {
    bool silent = false,
  }) async {
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
        ),
      );
    } catch (e) {
      if (emit.isDone || silent) return;
      emit(state.copyWith(loading: false, errorMessage: _message(e)));
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
    };
  }

  /// Сообщение, ответы на которое собирает тред, — шапка над лентой ответов.
  /// Читается один раз: правки родителя приезжают своим событием в его чате.
  Future<ChatMessage?> _parentMessage(Chat chat) async {
    if (!chat.isThread || state.parentMessage != null) return null;
    final id = chat.parentMessageId;
    if (id == null) return null;
    try {
      final page = await _chat.messages(chat.id, offset: 0, limit: 1);
      // Родителя в самой ленте треда нет — он живёт в родительском чате, и
      // отдельного запроса «одно сообщение» в API нет; поэтому шапку рисуем из
      // того, что известно о треде, когда сообщение не пришло вместе с ним.
      return page.nodes.firstWhere(
        (m) => m.id == id,
        orElse: () => ChatMessage(id: id, createdAt: DateTime.now()),
      );
    } catch (_) {
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
    return _chat.messages(chat.id, offset: offset, limit: pageSize);
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
              if (_fromCounterpart(m)) m.copyWith(readAt: DateTime.now()) else m,
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

  void _onBodyChanged(
    ChatBodyChanged event,
    Emitter<ChatState> emit,
  ) {
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

  void _onListAttached(
    ChatListAttached event,
    Emitter<ChatState> emit,
  ) {
    if (state.pendingLists.any((l) => l.id == event.list.id)) return;
    emit(state.copyWith(pendingLists: [...state.pendingLists, event.list]));
  }

  void _onListRemoved(
    ChatListRemoved event,
    Emitter<ChatState> emit,
  ) {
    emit(
      state.copyWith(
        pendingLists: state.pendingLists
            .where((l) => l.id != event.listId)
            .toList(),
      ),
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
    final listIds = state.pendingLists.map((l) => l.id).toList();
    final editing = state.editing;

    emit(state.copyWith(sending: true, errorMessage: null));
    try {
      final message = editing == null
          ? await _chat.send(
              chatId: chatId,
              body: body,
              attachmentIds: attachmentIds,
              questionListIds: listIds,
            )
          // Правка отправляет весь желаемый набор вложений: то, что осталось от
          // прошлой версии, лежит в той же строке ввода, что и новое.
          : await _chat.edit(
              messageId: editing.id,
              body: body,
              attachmentIds: attachmentIds,
              questionListIds: listIds,
            );
      emit(
        state.copyWith(
          sending: false,
          body: '',
          pending: const [],
          pendingLists: const <QuestionList>[],
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
        pendingLists: const <QuestionList>[],
        errorMessage: null,
      ),
    );
  }

  void _onEditCancelled(ChatEditCancelled event, Emitter<ChatState> emit) {
    emit(
      state.copyWith(
        editing: null,
        body: '',
        pending: const [],
        pendingLists: const <QuestionList>[],
      ),
    );
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
    if (enabled) await _ensureSystemNotifications();
  }

  String _noticeKey({required bool enabled, required bool thread}) {
    if (thread) {
      return enabled ? 'support.notifyOnThread' : 'support.notifyOffThread';
    }
    return enabled ? 'support.notifyOnChat' : 'support.notifyOffChat';
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
}
