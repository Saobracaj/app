import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/ask_ai_chat_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_events.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_state.dart';

/// One Ask-AI conversation — a question, an exam result or a category.
///
/// The `askAi` mutation returns the assistant's reply only, so a successful
/// send appends two bubbles at once: the user's words (kept optimistically in
/// [AskAiChatState.pendingUserText] while the model thinks) and the reply. A
/// failed send drops the optimistic bubble and keeps the draft, so nothing
/// typed is ever lost. The daily quota is re-read after every send — an
/// agentic answer may cost more than one unit, and only the backend knows.
///
/// While the chat is open the Bloc also holds the `askAiStream` subscription:
/// the reply streams into the thinking bubble as it is generated, with tool
/// statuses in between. The stream is presentation only — the mutation's
/// return stays the sole source of the finished conversation, so a dropped
/// websocket degrades to the old wait-for-the-whole-reply behaviour.
@injectable
class AskAiChatBloc extends Bloc<AskAiChatEvent, AskAiChatState> {
  AskAiChatBloc(
    this._repository,
    @factoryParam this.scope,
    @factoryParam this.scopeId,
  ) : super(const AskAiChatState()) {
    on<AskAiChatOpened>(_onOpened);
    on<AskAiChatBodyChanged>(_onBodyChanged);
    on<AskAiChatSendPressed>(_onSendPressed);
    on<AskAiChatErrorDismissed>(_onErrorDismissed);
    on<AskAiChatStreamed>(_onStreamed);
    add(AskAiChatOpened());
  }

  final AskAiChatRepository _repository;

  final AskAiChatScope scope;
  final String scopeId;

  /// Synthetic ids for the locally appended user bubbles; the server ones are
  /// numeric, so `local-N` can never collide.
  int _localSeq = 0;

  StreamSubscription<AskAiStreamUpdate>? _live;

  Future<void> _onOpened(
    AskAiChatOpened event,
    Emitter<AskAiChatState> emit,
  ) async {
    // Opened ahead of the first send so the socket is already up when the
    // reply starts streaming; errors are irrelevant here — no stream simply
    // means no live preview. `onDone` lets a retry re-open it: the client
    // closes the stream when the server refuses the subscription.
    _live ??= _repository
        .replyStream(scope, scopeId)
        .listen(
          (update) => add(AskAiChatStreamed(update)),
          onError: (_) {},
          onDone: () => _live = null,
        );
    emit(state.copyWith(loading: true, historyFailed: false));
    try {
      final history = _repository.history(scope, scopeId);
      final quota = _quietQuota();
      emit(
        state.copyWith(
          loading: false,
          messages: await history,
          quota: await quota ?? state.quota,
        ),
      );
    } catch (_) {
      if (emit.isDone) return;
      emit(state.copyWith(loading: false, historyFailed: true));
    }
  }

  void _onBodyChanged(AskAiChatBodyChanged event, Emitter<AskAiChatState> emit) {
    emit(state.copyWith(body: event.body));
  }

  Future<void> _onSendPressed(
    AskAiChatSendPressed event,
    Emitter<AskAiChatState> emit,
  ) async {
    final fromDraft = event.text == null;
    final text = (event.text ?? state.body).trim();
    if (text.isEmpty || state.sending || state.quotaExhausted) return;

    emit(
      state.copyWith(sending: true, pendingUserText: text, errorMessage: null),
    );
    try {
      final reply = await _repository.ask(scope, scopeId, text);
      final userBubble = AskAiChatMessage(
        id: 'local-${_localSeq++}',
        role: AskAiChatRole.user,
        content: text,
        createdAt: DateTime.now(),
      );
      emit(
        state.copyWith(
          sending: false,
          pendingUserText: null,
          streamingText: '',
          streamingTool: null,
          body: fromDraft ? '' : state.body,
          messages: [...state.messages, userBubble, reply],
        ),
      );
      analytics.logAskAiQuestion(scope: scope.name, scopeId: scopeId);
      final quota = await _quietQuota();
      if (quota != null && !emit.isDone) emit(state.copyWith(quota: quota));
    } catch (e) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          sending: false,
          pendingUserText: null,
          streamingText: '',
          streamingTool: null,
          errorMessage: _message(e),
        ),
      );
    }
  }

  /// Fold one live frame into the thinking bubble. Only while a send is in
  /// flight — a frame streamed to another device's turn has no bubble here.
  void _onStreamed(AskAiChatStreamed event, Emitter<AskAiChatState> emit) {
    if (!state.sending) return;
    switch (event.update) {
      case AskAiStreamDelta(:final text):
        emit(
          state.copyWith(
            streamingText: state.streamingText + text,
            streamingTool: null,
          ),
        );
      case AskAiStreamTool(:final tool):
        // Whatever streamed before a tool call was the model's commentary on
        // the way to it; the answer starts over after the last tool round.
        emit(state.copyWith(streamingText: '', streamingTool: tool));
      case AskAiStreamCompleted() || AskAiStreamFailed():
        // The mutation's own return settles the conversation; acting on these
        // too would append the reply twice.
        break;
    }
  }

  void _onErrorDismissed(
    AskAiChatErrorDismissed event,
    Emitter<AskAiChatState> emit,
  ) {
    emit(state.copyWith(errorMessage: null));
  }

  @override
  Future<void> close() async {
    await _live?.cancel();
    return super.close();
  }

  /// The quota is auxiliary: failing to read it must break neither the history
  /// load nor a completed send.
  Future<AskAiQuota?> _quietQuota() async {
    try {
      return await _repository.quota();
    } catch (_) {
      return null;
    }
  }

  /// A server error arrives human-readable (the quota text, the validation
  /// text); everything network-shaped gets the translated fallback key, which
  /// the banner runs through `tr()`.
  String _message(Object e) {
    if (e is GraphqlException && !e.network && e.message.trim().isNotEmpty) {
      return e.message;
    }
    return 'askAi.sendFailed';
  }
}
