import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../chat/data/chat_repository.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/error_messages.dart';
import 'extension_request_events.dart';
import 'extension_request_state.dart';

/// Запрос бесплатного продления после несданного экзамена.
///
/// Тот же путь, что у жалобы на контент: сообщение в личный чат с
/// разработчиком, с нетранслируемой шапкой `Extension request` — её читает
/// оператор, и она должна выглядеть одинаково на любом языке приложения.
/// Проверку условий (пропуск был активен в день экзамена, одно продление на
/// покупку, не позже 14 дней после окончания) оператор делает глазами по
/// карточке пользователя.
@injectable
class ExtensionRequestBloc
    extends Bloc<ExtensionRequestEvent, ExtensionRequestState> {
  ExtensionRequestBloc(this._chat, this._authBloc)
    : super(const ExtensionRequestState()) {
    on<ExtensionRequestOpened>(
      (_, emit) =>
          emit(state.copyWith(signedIn: _authBloc.state.isAuthenticated)),
    );
    on<ExtensionExamDateChanged>(
      (event, emit) => emit(state.copyWith(examDate: event.text)),
    );
    on<ExtensionNoteChanged>(
      (event, emit) => emit(state.copyWith(note: event.text)),
    );
    on<ExtensionRequestSubmitted>(_onSubmitted);
  }

  final ChatRepository _chat;
  final AuthBloc _authBloc;

  Future<void> _onSubmitted(
    ExtensionRequestSubmitted event,
    Emitter<ExtensionRequestState> emit,
  ) async {
    if (!state.canSend) return;
    emit(state.copyWith(sending: true, errorMessage: null));
    try {
      final chat = await _chat.supportChat();
      await _chat.send(chatId: chat.id, body: composeBody());
      analytics.logExtensionRequested();
      if (emit.isDone) return;
      emit(state.copyWith(sending: false, sent: true));
    } catch (e) {
      if (emit.isDone) return;
      emit(
        state.copyWith(sending: false, errorMessage: describeActionError(e)),
      );
    }
  }

  @visibleForTesting
  String composeBody() => [
    'Extension request',
    'Exam date: ${state.examDate.trim()}',
    if (state.note.trim().isNotEmpty) ...['', state.note.trim()],
  ].join('\n');
}
