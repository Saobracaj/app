import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/graphql_client.dart';
import '../../notifications/data/notification_permissions.dart';
import '../data/support_chat_repository.dart';
import '../models/support_chat.dart';
import '../models/support_chat_update.dart';
import 'support_chat_events.dart';
import 'support_chat_state.dart';

/// One support conversation.
///
/// The same Bloc drives both sides: with [threadId] `null` it is the caller's
/// own chat (the backend resolves the thread from the token and there is no id
/// to send), and with a thread id it is a moderator answering that user. The
/// difference shows up in exactly three places — which read is used, which send
/// mutation is used, and whether the notification offer is made.
///
/// Opening the chat marks the counterpart's messages read, which is what makes
/// the user's side automatic and the moderator's side deliberate: a moderator
/// only ever gets here by opening a specific conversation.
///
/// While the screen is open the conversation follows the backend live. The
/// server's event says only *what* changed, never the message itself, so every
/// event re-reads the tail of the thread — one code path for a new message, for
/// read receipts and for a reconnect, and no way for the two sources to disagree
/// about what the conversation looks like.
@injectable
class SupportChatBloc extends Bloc<SupportChatEvent, SupportChatState> {
  SupportChatBloc(
    this._chat,
    this._permissions,
    this._authRepo,
    @factoryParam this.threadId,
  ) : super(const SupportChatState()) {
    on<SupportChatOpened>(_onOpened);
    on<SupportChatChangedRemotely>(_onChangedRemotely);
    on<SupportChatLiveChanged>(_onLiveChanged);
    on<SupportChatRefreshed>(_onRefreshed);
    on<SupportChatBodyChanged>(_onBodyChanged);
    on<SupportChatAttachPressed>(_onAttachPressed);
    on<SupportChatAttachmentRemoved>(_onAttachmentRemoved);
    on<SupportChatSendPressed>(_onSendPressed);
    on<SupportChatNotificationsDeclined>(_onNotificationsDeclined);
    on<SupportChatNotificationsAccepted>(_onNotificationsAccepted);
    on<SupportChatErrorDismissed>(
      (_, emit) => emit(state.copyWith(errorMessage: null)),
    );
    on<SupportChatUploadProgress>(
      (event, emit) => emit(state.copyWith(uploadProgress: event.value)),
    );
  }

  final SupportChatRepository _chat;
  final NotificationPermissions _permissions;
  final AuthRepository _authRepo;

  /// The conversation to show, or `null` for the caller's own.
  final String? threadId;

  /// Shared with the notifications screen and the comments Bloc — one app-level
  /// push preference, not one per feature.
  static const _pushNotifKey = 'notif_push_enabled';

  /// Remembers that the chat already made its notification offer, so it is asked
  /// once and never again.
  static const _supportPromptKey = 'support_chat_notifications_asked';

  bool get _isModerator => threadId != null;

  /// The live subscription, alive for as long as the screen is.
  StreamSubscription<SupportChatUpdate>? _live;

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
    SupportChatOpened event,
    Emitter<SupportChatState> emit,
  ) async {
    // Subscribe before reading, so a message sent between the two lands as an
    // event rather than in the gap between them.
    _listen();
    await _load(emit);
    if (state.errorMessage != null) return;

    // Opening the chat is what marks the other side's messages read.
    await _markRead(emit);

    if (!_isModerator) await _maybeOfferNotifications(emit);
  }

  /// Go live. A failure here is silent on purpose: a chat that cannot subscribe
  /// still reads, sends and refreshes by hand, and the screen says so with the
  /// offline indicator instead of an error the reader can do nothing about.
  void _listen() {
    _live ??= _chat.changes(threadId: threadId).listen(
      (update) {
        switch (update) {
          case SupportChatChanged():
            add(SupportChatChangedRemotely());
          case SupportChatLive(:final firstConnect):
            add(SupportChatLiveChanged(live: true, missed: !firstConnect));
          case SupportChatOffline():
            add(SupportChatLiveChanged(live: false));
        }
      },
      onError: (_) => add(SupportChatLiveChanged(live: false)),
      onDone: () => add(SupportChatLiveChanged(live: false)),
    );
  }

  /// Something changed in the conversation. What exactly is not interesting —
  /// the event carries no message, so the tail is re-read either way.
  Future<void> _onChangedRemotely(
    SupportChatChangedRemotely event,
    Emitter<SupportChatState> emit,
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
        add(SupportChatChangedRemotely());
      }
    }
  }

  Future<void> _onLiveChanged(
    SupportChatLiveChanged event,
    Emitter<SupportChatState> emit,
  ) async {
    emit(state.copyWith(live: event.live));
    // A reconnect means the socket was down for a while and the server keeps no
    // backlog — re-read instead of leaving a hole in the conversation.
    if (event.missed && state.loaded) add(SupportChatChangedRemotely());
  }

  Future<void> _onRefreshed(
    SupportChatRefreshed event,
    Emitter<SupportChatState> emit,
  ) => _load(emit);

  /// Read the thread and the newest page of its messages.
  ///
  /// [silent] is for the live path: it neither shows the progress bar nor
  /// reports a failure, because a re-read triggered by an event the reader never
  /// asked for should not take over the screen — the next event tries again.
  Future<void> _load(
    Emitter<SupportChatState> emit, {
    bool silent = false,
  }) async {
    if (!silent) emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final thread = _isModerator
          ? await _chat.thread(threadId!)
          : await _chat.myThread();
      final page = await _tail(thread);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          loading: false,
          loaded: true,
          thread: thread,
          messages: _merge(page.nodes),
        ),
      );
    } catch (e) {
      if (emit.isDone || silent) return;
      emit(state.copyWith(loading: false, errorMessage: _message(e)));
    }
  }

  /// The last page of the conversation. Pages come oldest-first, so the newest
  /// messages — the ones an open chat is about — sit at the *end*, and reading
  /// from offset 0 would show the beginning of a long conversation forever.
  Future<SupportMessagePage> _tail(SupportThread thread) {
    final offset = thread.messagesCount > pageSize
        ? thread.messagesCount - pageSize
        : 0;
    return _isModerator
        ? _chat.threadMessages(threadId!, offset: offset, limit: pageSize)
        : _chat.myMessages(offset: offset, limit: pageSize);
  }

  /// Fold a freshly-read page into what is on screen, keyed by id: the server's
  /// copy wins (it carries the current read receipt), and anything already shown
  /// and not in the page — a message just sent, an older one above the window —
  /// stays where it is.
  List<SupportMessage> _merge(List<SupportMessage> incoming) {
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
  Future<void> _markRead(Emitter<SupportChatState> emit) async {
    try {
      await _chat.markRead(threadId: threadId);
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

  /// An unread message written by the other side of this conversation.
  bool _fromCounterpart(SupportMessage message) =>
      message.fromStaff != _isModerator && !message.isRead;

  void _onBodyChanged(
    SupportChatBodyChanged event,
    Emitter<SupportChatState> emit,
  ) {
    emit(state.copyWith(body: event.body));
  }

  /// Pick a file and upload it right away, so sending the message afterwards is
  /// instant and the user sees the attachment before committing to it.
  Future<void> _onAttachPressed(
    SupportChatAttachPressed event,
    Emitter<SupportChatState> emit,
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

    emit(state.copyWith(uploading: true, uploadProgress: 0, errorMessage: null));
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxAttachmentBytes) {
        emit(
          state.copyWith(
            uploading: false,
            errorMessage: 'support.attachmentTooLarge',
          ),
        );
        return;
      }
      final mimeType = file.mimeType;
      final attachment = await _chat.uploadAttachment(
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
        threadId: threadId,
        // Progress ticks arrive from Dio, outside this handler's emit window,
        // so they come back in as their own event.
        onProgress: (sent, total) {
          if (total > 0 && !isClosed) {
            add(SupportChatUploadProgress(sent / total));
          }
        },
      );
      emit(
        state.copyWith(
          uploading: false,
          uploadProgress: 1,
          pending: [...state.pending, attachment],
        ),
      );
    } catch (e) {
      emit(state.copyWith(uploading: false, errorMessage: _message(e)));
    }
  }

  void _onAttachmentRemoved(
    SupportChatAttachmentRemoved event,
    Emitter<SupportChatState> emit,
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
    SupportChatSendPressed event,
    Emitter<SupportChatState> emit,
  ) async {
    if (!state.canSend) return;
    final body = state.body.trim();
    final attachmentIds = state.pending.map((a) => a.id).toList();

    emit(state.copyWith(sending: true, errorMessage: null));
    try {
      final message = _isModerator
          ? await _chat.reply(
              threadId: threadId!,
              body: body,
              attachmentIds: attachmentIds,
            )
          : await _chat.send(body: body, attachmentIds: attachmentIds);
      emit(
        state.copyWith(
          sending: false,
          body: '',
          pending: const [],
          // Through the same merge as a live update: the subscription is about
          // to deliver this very message back, and it must not double up.
          messages: _merge([message]),
        ),
      );
    } catch (e) {
      emit(state.copyWith(sending: false, errorMessage: _message(e)));
    }
  }

  /// Ask about notifications the first time the user opens their chat — the same
  /// offer the question discussion makes, and for the same reason: an answer
  /// that arrives hours later is worthless if nothing tells them about it.
  Future<void> _maybeOfferNotifications(Emitter<SupportChatState> emit) async {
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
    SupportChatNotificationsDeclined event,
    Emitter<SupportChatState> emit,
  ) async {
    emit(state.copyWith(notificationsPrompt: false));
    await _rememberAsked();
  }

  /// Accepted: ask the OS, then turn the app-level push preference on and
  /// register the device. Best-effort throughout — the chat works without it.
  Future<void> _onNotificationsAccepted(
    SupportChatNotificationsAccepted event,
    Emitter<SupportChatState> emit,
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

  String _message(Object e) =>
      e is GraphqlException ? e.message : e.toString();

  /// Mirrors the backend's cap, so an oversized file is refused before it is
  /// pushed over the wire.
  static const _maxAttachmentBytes = 20 * 1024 * 1024;
}
