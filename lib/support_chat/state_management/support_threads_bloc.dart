import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/network/error_messages.dart';
import '../data/support_chat_repository.dart';
import 'support_threads_events.dart';
import 'support_threads_state.dart';

/// The moderator's list of support conversations, newest activity first.
///
/// Reading the list deliberately does **not** mark anything read — that only
/// happens when a moderator opens one conversation (see [SupportChatBloc]).
@injectable
class SupportThreadsBloc extends Bloc<SupportThreadsEvent, SupportThreadsState> {
  SupportThreadsBloc(this._chat) : super(const SupportThreadsState()) {
    on<SupportThreadsRequested>((_, emit) => _load(emit, state.onlyUnread));
    on<SupportThreadsFilterToggled>(
      (event, emit) => _load(emit, event.onlyUnread),
    );
  }

  final SupportChatRepository _chat;

  Future<void> _load(
    Emitter<SupportThreadsState> emit,
    bool onlyUnread,
  ) async {
    emit(
      state.copyWith(loading: true, onlyUnread: onlyUnread, errorMessage: null),
    );
    try {
      final page = await _chat.threads(onlyUnread: onlyUnread);
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
