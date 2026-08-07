import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/graphql_client.dart';
import '../../notifications/data/notification_permissions.dart';
import '../data/support_chat_repository.dart';
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
@injectable
class SupportChatBloc extends Bloc<SupportChatEvent, SupportChatState> {
  SupportChatBloc(
    this._chat,
    this._permissions,
    this._authRepo,
    @factoryParam this.threadId,
  ) : super(const SupportChatState()) {
    on<SupportChatOpened>(_onOpened);
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

  Future<void> _onOpened(
    SupportChatOpened event,
    Emitter<SupportChatState> emit,
  ) async {
    await _load(emit);
    if (state.errorMessage != null) return;

    // Opening the chat is what marks the other side's messages read.
    try {
      await _chat.markRead(threadId: threadId);
      emit(
        state.copyWith(
          thread: state.thread?.copyWith(unreadCount: 0),
          messages: [
            for (final m in state.messages)
              if (m.fromStaff != _isModerator && !m.isRead)
                m.copyWith(readAt: DateTime.now())
              else
                m,
          ],
        ),
      );
    } catch (_) {
      // Read receipts are never worth an error banner over.
    }

    if (!_isModerator) await _maybeOfferNotifications(emit);
  }

  Future<void> _onRefreshed(
    SupportChatRefreshed event,
    Emitter<SupportChatState> emit,
  ) => _load(emit);

  Future<void> _load(Emitter<SupportChatState> emit) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final thread = _isModerator
          ? await _chat.thread(threadId!)
          : await _chat.myThread();
      final page = _isModerator
          ? await _chat.threadMessages(threadId!)
          : await _chat.myMessages();
      emit(
        state.copyWith(loading: false, thread: thread, messages: page.nodes),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: _message(e)));
    }
  }

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
      final attachment = await _chat.uploadAttachment(
        bytes: bytes,
        fileName: file.name,
        contentType: file.mimeType,
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
          messages: [...state.messages, message],
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
