import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/deep_links/deep_link_path.dart';
import '../../core/network/error_messages.dart';
import '../../notifications/data/push_message.dart';
import '../../notifications/data/push_message_service.dart';
import '../data/chat_repository.dart';
import 'support_chats_events.dart';
import 'support_chats_state.dart';

/// The moderator's list of support conversations, newest activity first.
///
/// Reading the list deliberately does **not** mark anything read — that only
/// happens when a moderator opens one conversation (see [ChatBloc]).
///
/// Список читается один раз при открытии, а дальше **догоняет сам**: у списка
/// нет realtime-подписки (она есть только у открытого чата), поэтому открытый
/// экран со временем расходится с сервером — пуш о новом обращении уже пришёл,
/// а в списке его нет, пока модератор не нажмёт «Обновить» (SAOBR-522; сама
/// жалоба тогда объяснилась сборкой, смотревшей на dev, но расхождение открытого
/// списка с сервером от этого не исчезает). Поэтому список незаметно
/// перечитывается, когда:
///   * приходит пуш про обращение, а приложение на экране (система такой пуш
///     не показывает — его видно лишь как снекбар);
///   * приложение возвращается из фона (экран был спрятан или приостановлен);
///   * экран просят об этом явно — [SupportChatsRefreshed] после возврата из
///     открытого обращения.
///
/// [watchLifecycle] — следить ли за возвратом из фона; в тестах без биндинга
/// виджетов его выключают.
@injectable
class SupportChatsBloc extends Bloc<SupportChatsEvent, SupportChatsState> {
  SupportChatsBloc(
    this._chat,
    PushMessageService pushes, {
    @factoryParam bool? watchLifecycle,
  }) : super(const SupportChatsState()) {
    on<SupportChatsRequested>((_, emit) => _load(emit, state.onlyUnread));
    on<SupportChatsFilterToggled>(
      (event, emit) => _load(emit, event.onlyUnread),
    );
    // Тихие перечитывания идут подряд (пуш и возврат из фона могут совпасть):
    // пока одно в работе, следующее ждёт — последовательный обработчик Bloc'а
    // не даёт им перемешаться.
    on<SupportChatsRefreshed>(
      (_, emit) => _load(emit, state.onlyUnread, silent: true),
    );

    _pushes = pushes.foreground
        .where(_isAboutSupport)
        .listen((_) => add(SupportChatsRefreshed()));

    if (watchLifecycle ?? true) {
      // Возврат после «спрятали» (фон на телефоне, скрытая вкладка) — не после
      // любого `inactive → resumed` (системный диалог поверх). И onHide, и
      // onPause: без известного предыдущего состояния слушатель не достраивает
      // промежуточные переходы и зовёт только конечный.
      _lifecycle = AppLifecycleListener(
        onHide: () => _hidden = true,
        onPause: () => _hidden = true,
        onResume: () {
          if (!_hidden) return;
          _hidden = false;
          add(SupportChatsRefreshed());
        },
      );
    }
  }

  final ChatRepository _chat;
  StreamSubscription<PushMessage>? _pushes;
  AppLifecycleListener? _lifecycle;
  bool _hidden = false;

  /// Пуш про обращение — тот, чья ссылка ведёт в чат с разработчиком
  /// (`saobracaj://support`, `…/support/threads/<id>`). Пуши про обсуждения
  /// вопросов и треды список не трогают.
  static bool _isAboutSupport(PushMessage push) {
    final link = push.link;
    if (link == null) return false;
    final path = deepLinkPathFor(link);
    return path != null && (path == '/support' || path.startsWith('/support/'));
  }

  Future<void> _load(
    Emitter<SupportChatsState> emit,
    bool onlyUnread, {
    bool silent = false,
  }) async {
    if (!silent) {
      emit(
        state.copyWith(
          loading: true,
          onlyUnread: onlyUnread,
          errorMessage: null,
        ),
      );
    }
    try {
      final page = await _chat.supportChats(onlyUnread: onlyUnread);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          loading: false,
          threads: page.nodes,
          totalCount: page.totalCount,
          errorMessage: null,
        ),
      );
    } catch (e) {
      // Тихое перечитывание не отнимает экран: список останется прежним, а
      // следующий повод перечитать его попробует снова.
      if (emit.isDone || silent) return;
      emit(state.copyWith(loading: false, errorMessage: describeError(e)));
    }
  }

  @override
  Future<void> close() async {
    await _pushes?.cancel();
    _lifecycle?.dispose();
    return super.close();
  }
}
