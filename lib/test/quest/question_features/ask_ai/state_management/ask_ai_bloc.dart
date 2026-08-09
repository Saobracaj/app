import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/question_explanation_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_events.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_state.dart';

/// Loads the pre-generated explanation of one question for the "Спросить AI"
/// tab.
///
/// A *failure* is not an empty result: no network, no premium entitlement or a
/// server error set [AskAiState.failed] and the tab offers a retry, while a
/// question that genuinely has no explanation yet finishes with a `null`
/// [AskAiState.explanation] and gets the "not ready yet" stub.
@injectable
class AskAiBloc extends Bloc<AskAiEvent, AskAiState> {
  AskAiBloc(this._repository, @factoryParam this.questionId)
      : super(const AskAiState()) {
    on<AskAiRequested>(_onRequested);
    add(AskAiRequested());
  }

  final QuestionExplanationRepository _repository;

  final int questionId;

  Future<void> _onRequested(AskAiRequested event, Emitter<AskAiState> emit) async {
    emit(state.copyWith(inProgress: true, failed: false));
    try {
      final explanation = await _repository.load(questionId);
      if (emit.isDone) return;
      emit(state.copyWith(inProgress: false, explanation: explanation));
    } catch (_) {
      if (emit.isDone) return;
      emit(state.copyWith(inProgress: false, failed: true, explanation: null));
    }
  }
}
