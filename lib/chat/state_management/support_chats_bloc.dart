import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/network/error_messages.dart';
import '../data/chat_repository.dart';
import 'support_chats_events.dart';
import 'support_chats_state.dart';

/// The moderator's list of support conversations, newest activity first.
///
/// Reading the list deliberately does **not** mark anything read — that only
/// happens when a moderator opens one conversation (see [ChatBloc]).
@injectable
class SupportChatsBloc extends Bloc<SupportChatsEvent, SupportChatsState> {
  SupportChatsBloc(this._chat) : super(const SupportChatsState()) {
    on<SupportChatsRequested>((_, emit) => _load(emit, state.onlyUnread));
    on<SupportChatsFilterToggled>(
      (event, emit) => _load(emit, event.onlyUnread),
    );
  }

  final ChatRepository _chat;

  Future<void> _load(
    Emitter<SupportChatsState> emit,
    bool onlyUnread,
  ) async {
    emit(
      state.copyWith(loading: true, onlyUnread: onlyUnread, errorMessage: null),
    );
    try {
      final page = await _chat.supportChats(onlyUnread: onlyUnread);
      emit(
        state.copyWith(
          loading: false,
          threads: page.nodes,
          totalCount: page.totalCount,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: describeError(e),
        ),
      );
    }
  }
}
