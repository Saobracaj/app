import 'package:freezed_annotation/freezed_annotation.dart';

import '../../question_lists/models/question_list.dart';
import '../models/chat.dart';

part 'chat_state.freezed.dart';

/// Состояние одного разговора — своего чата с разработчиком, обращения глазами
/// модератора, треда на сообщение.
@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    @Default(true) bool loading,

    /// The conversation has been read at least once, so what is on screen is
    /// real and not just an empty start.
    @Default(false) bool loaded,

    /// The realtime subscription is up: new messages and read receipts arrive by
    /// themselves. While it is down the chat is readable but stale.
    @Default(false) bool live,
    Chat? thread,

    /// Сообщение, ответы на которое собирает этот чат, — показывается шапкой
    /// треда над лентой ответов.
    ChatMessage? parentMessage,

    /// Идентификатор пользователя, читающего этот чат: по нему решается, чьё
    /// сообщение «моё», а не по стороне поддержки.
    @Default('') String myUserId,

    /// Сообщение, которое сейчас правят; `null` — пишется новое.
    ChatMessage? editing,
    @Default(<ChatMessage>[]) List<ChatMessage> messages,

    /// Composer text.
    @Default('') String body,

    /// Uploaded but not yet sent attachments of the composed message.
    @Default(<ChatAttachment>[]) List<ChatAttachment> pending,

    /// Списки вопросов, приложенные к ещё не отправленному сообщению. Хранятся
    /// целиком, а не идентификаторами: строка ввода показывает название и цвет
    /// до того, как бэкенд снимет с них снимок.
    @Default(<QuestionList>[]) List<QuestionList> pendingLists,

    /// An upload is in flight; [uploadProgress] is 0..1 when known.
    @Default(false) bool uploading,
    @Default(0.0) double uploadProgress,
    @Default(false) bool sending,
    String? errorMessage,

    /// Show the "turn notifications on?" offer (owner's side, asked once).
    @Default(false) bool notificationsPrompt,

    /// Одноразовое сообщение для snackbar'а: «уведомления включены/выключены».
    String? notice,

    /// Уведомления запрещены в настройках системы: колокольчик показывает это
    /// отдельно, потому что включённые для чата оповещения всё равно не придут.
    @Default(false) bool systemNotificationsBlocked,
  }) = _ChatState;

  const ChatState._();

  /// Whether the composer has anything worth sending.
  bool get canSend =>
      !sending &&
      !uploading &&
      (body.trim().isNotEmpty || pending.isNotEmpty || pendingLists.isNotEmpty);

  /// Whether the screen is showing an empty conversation (no messages at all).
  bool get isEmpty => !loading && messages.isEmpty;

  /// Правится ли сейчас уже отправленное сообщение.
  bool get isEditing => editing != null;

  /// Тред ли открыт — внутри треда нет ни свайпа «ответить», ни пункта меню.
  bool get isThread => thread?.isThread ?? false;

  /// Моё ли это сообщение: у обычного чата — написанное мной, а не «стороной
  /// поддержки», чтобы то же правило работало и в групповом чате.
  bool isMine(ChatMessage message) =>
      myUserId.isNotEmpty && message.authorId == myUserId;
}
