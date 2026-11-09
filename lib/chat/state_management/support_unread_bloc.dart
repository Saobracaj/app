import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../core/network/network_status.dart';
import '../../notifications/data/push_message_service.dart';
import '../data/chat_repository.dart';
import 'support_unread_events.dart';
import 'support_unread_state.dart';

/// Непрочитанное в чате с разработчиком — кнопка со счётчиком на главной.
///
/// Живёт на уровне приложения: кнопку показывают шапка главной и боковая
/// колонка широкого окна. Список разговоров с непрочитанным читается с
/// бэкенда (`mySupportUnreadChats`): свой чат и треды его сообщений, у
/// модератора — обращения и их треды.
///
/// Подписки «на все мои разговоры» у бэкенда нет, поэтому счётчик
/// перечитывается по поводам: вход и выход, возврат сети, возврат приложения
/// из фона, пуш, пришедший на открытое приложение, и пометка «прочитано» из
/// открытого здесь же чата ([ChatRepository.readStateChanged]).
@injectable
class SupportUnreadBloc extends Bloc<SupportUnreadEvent, SupportUnreadState> {
  SupportUnreadBloc(this._chat, this._authBloc, this._network, this._pushes)
    : super(const SupportUnreadState()) {
    on<SupportUnreadStarted>(_onStarted);
    on<SupportUnreadSessionChanged>(_onSessionChanged);
    on<SupportUnreadRefreshRequested>(_onRefresh);
  }

  /// Право, с которым чат с разработчиком читается со стороны поддержки — то
  /// же, по которому бэкенд выбирает сторону для `mySupportUnreadChats`.
  static const moderatorPermission = 'moderate_support';

  final ChatRepository _chat;
  final AuthBloc _authBloc;
  final NetworkStatus _network;
  final PushMessageService _pushes;

  final List<StreamSubscription<void>> _subscriptions = [];
  AppLifecycleListener? _lifecycle;

  /// Номер последнего запроса: ответ на устаревший запрос не должен затереть
  /// более свежий (обработчики событий идут параллельно).
  int _generation = 0;

  /// Кто вошёл и с какой стороны читает — при смене список перечитывается.
  String? _sessionKey;

  Future<void> _onStarted(
    SupportUnreadStarted event,
    Emitter<SupportUnreadState> emit,
  ) async {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions.add(_authBloc.stream.listen(_onAuth));
    _subscriptions.add(_network.onReconnected.listen((_) => _refreshLater()));
    _subscriptions.add(_pushes.foreground.listen((_) => _refreshLater()));
    _subscriptions.add(_chat.readStateChanged.listen((_) => _refreshLater()));
    if (event.watchLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: _refreshLater);
    }
    _onAuth(_authBloc.state);
  }

  void _refreshLater() {
    if (isClosed) return;
    add(const SupportUnreadRefreshRequested());
  }

  void _onAuth(AuthState auth) {
    // Пока сессия не определена, спрашивать нечего: ответ всё равно будет
    // гостевым, а настоящий придёт следом.
    if (auth.status == AuthStatus.unknown) return;
    final moderator =
        auth.viewer?.permissions.contains(moderatorPermission) ?? false;
    final key = '${auth.isAuthenticated}:${auth.viewer?.id ?? ''}:$moderator';
    if (key == _sessionKey) return;
    _sessionKey = key;
    add(
      SupportUnreadSessionChanged(
        authenticated: auth.isAuthenticated,
        moderator: moderator,
      ),
    );
  }

  Future<void> _onSessionChanged(
    SupportUnreadSessionChanged event,
    Emitter<SupportUnreadState> emit,
  ) async {
    if (!event.authenticated) {
      // Гостю показывать нечего, и запрос в полёте уже не нужен.
      _generation++;
      emit(const SupportUnreadState());
      return;
    }
    emit(state.copyWith(moderator: event.moderator));
    await _refresh(emit);
  }

  Future<void> _onRefresh(
    SupportUnreadRefreshRequested event,
    Emitter<SupportUnreadState> emit,
  ) async {
    if (!_authBloc.state.isAuthenticated) return;
    await _refresh(emit);
  }

  Future<void> _refresh(Emitter<SupportUnreadState> emit) async {
    final generation = ++_generation;
    try {
      final chats = await _chat.unreadSupportChats();
      if (generation != _generation || emit.isDone) return;
      emit(state.copyWith(chats: chats));
    } catch (_) {
      // Счётчик — не то, ради чего показывать ошибку: не прочитался — остаётся
      // прежним и перечитается при следующем поводе.
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _lifecycle?.dispose();
    return super.close();
  }
}
