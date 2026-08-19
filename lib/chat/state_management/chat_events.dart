import '../../question_lists/models/question_list.dart';
import '../models/chat.dart';

/// User actions of the support-chat screen.
sealed class ChatEvent {}

/// The screen appeared: load the thread and its messages, mark the counterpart's
/// messages read, and — for the thread's owner — offer notifications once.
class ChatOpened extends ChatEvent {}

/// Pull-to-refresh / retry after an error.
class ChatRefreshed extends ChatEvent {}

/// Показать сообщения старше самого раннего показанного: нажали «показать
/// ещё» или прокрутили до конца уже загруженного.
class ChatOlderRequested extends ChatEvent {}

/// The composer's text changed.
class ChatBodyChanged extends ChatEvent {
  ChatBodyChanged(this.body);
  final String body;
}

/// Пункт «Файл» меню вложений: системный выбор файла, загрузка байт в байт.
class ChatFilePicked extends ChatEvent {}

/// Пункт «Фотография» меню вложений: системный выбор из галереи, пережатие в
/// JPEG на устройстве и загрузка. Можно выбрать несколько снимков сразу.
class ChatPhotosPicked extends ChatEvent {}

/// Пункт «Список вопросов»: пользователь выбрал один из своих списков. Список
/// уходит ссылкой шаринга — той же самой, что и при «поделиться» с экрана
/// списка: Bloc просит у бэкенда код и дописывает адрес в строку ввода.
class ChatListShared extends ChatEvent {
  ChatListShared(this.list);
  final QuestionList list;
}

/// Drop a not-yet-sent attachment from the composer.
class ChatAttachmentRemoved extends ChatEvent {
  ChatAttachmentRemoved(this.attachment);
  final ChatAttachment attachment;
}

/// Send the composed message with whatever is attached — или сохранить правку,
/// если сейчас правится уже отправленное сообщение.
class ChatSendPressed extends ChatEvent {}

/// «Изменить» в меню сообщения: текст и вложения переезжают в строку ввода.
class ChatEditStarted extends ChatEvent {
  ChatEditStarted(this.message);
  final ChatMessage message;
}

/// Отказ от правки: строка ввода снова пустая.
class ChatEditCancelled extends ChatEvent {}

/// Колокольчик в шапке: включить или выключить оповещения об этом разговоре.
class ChatNotificationsToggled extends ChatEvent {}

/// Snackbar про оповещения показан.
class ChatNoticeShown extends ChatEvent {}

/// The notification offer was declined (or dismissed).
class ChatNotificationsDeclined extends ChatEvent {}

/// The notification offer was accepted: ask the OS and turn push on.
class ChatNotificationsAccepted extends ChatEvent {}

/// «Удалить» в меню своего сообщения — после подтверждения.
class ChatMessageDeleted extends ChatEvent {
  ChatMessageDeleted(this.message);
  final ChatMessage message;
}

/// Реакция на сообщение: нажали эмодзи — в меню сообщения или по уже
/// стоящему значку под ним. Одно и то же событие и ставит реакцию, и снимает
/// свою.
class ChatReactionToggled extends ChatEvent {
  ChatReactionToggled(this.message, this.emoji);
  final ChatMessage message;
  final String emoji;
}

/// «Пожаловаться» в меню сообщения: причина уходит модератору.
class ChatMessageReported extends ChatEvent {
  ChatMessageReported(this.message, this.reason);
  final ChatMessage message;
  final String reason;
}

/// Clear the inline error banner.
class ChatErrorDismissed extends ChatEvent {}

/// The backend says the conversation changed (a message was added, or somebody
/// read one). Not dispatched by the UI — it comes off the subscription.
class ChatChangedRemotely extends ChatEvent {
  ChatChangedRemotely({this.deletedMessageId});

  /// Сообщение, которое автор удалил, — его нужно убрать из ленты: перечитанная
  /// страница молчит о том, чего в ней больше нет.
  final String? deletedMessageId;
}

/// The realtime connection came up or went down. [missed] is set when it is a
/// reconnect: the server keeps no backlog, so whatever happened while the socket
/// was down has to be re-read.
class ChatLiveChanged extends ChatEvent {
  ChatLiveChanged({required this.live, this.missed = false});

  final bool live;
  final bool missed;
}

/// Upload progress, fed back in from Dio's callback rather than dispatched by
/// the UI. It lives here only because the event hierarchy is sealed.
class ChatUploadProgress extends ChatEvent {
  ChatUploadProgress(this.value);

  /// Fraction of the file already sent, 0..1.
  final double value;
}
