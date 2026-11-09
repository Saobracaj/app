import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/chat.dart';

part 'support_unread_state.freezed.dart';

/// Непрочитанное в чате с разработчиком — то, что стоит за кнопкой со
/// счётчиком на главной.
///
/// [chats] — разговоры, в которых есть непрочитанное (свой чат и треды его
/// сообщений; у модератора — обращения и их треды), как их отдал бэкенд.
/// [moderator] — читаю ли я со стороны поддержки: от этого зависит, куда
/// ведёт кнопка.
@freezed
abstract class SupportUnreadState with _$SupportUnreadState {
  const factory SupportUnreadState({
    @Default(<Chat>[]) List<Chat> chats,
    @Default(false) bool moderator,
  }) = _SupportUnreadState;

  const SupportUnreadState._();

  /// Сколько сообщений не прочитано во всех разговорах вместе — цифра на кнопке.
  int get total => chats.fold(0, (sum, chat) => sum + chat.unreadCount);

  /// Есть ли что показывать: без непрочитанного на месте кнопки стоит аватар.
  bool get hasUnread => total > 0;

  /// Куда ведёт кнопка, либо `null`, когда непрочитанного нет.
  ///
  /// Один разговор — открывается он сам: тред по его адресу, своё обращение —
  /// чатом с разработчиком, чужое (у модератора) — из списка обращений. Когда
  /// разговоров несколько, открывается корень: пользователю — его чат (ссылки
  /// на треды стоят под сообщениями), модератору — список обращений.
  String? get destination {
    final unread = chats.where((chat) => chat.unreadCount > 0).toList();
    if (unread.isEmpty) return null;
    if (unread.length == 1) {
      final chat = unread.single;
      if (chat.isThread) return '/chat/${chat.id}';
      return moderator ? '/support/threads/${chat.id}' : '/support';
    }
    return moderator ? '/support/threads' : '/support';
  }
}
