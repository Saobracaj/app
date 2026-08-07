import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../auth/state_management/auth/auth_bloc.dart';
import '../data/question_analytics_repository.dart';
import '../data/question_difficulty_repository.dart';
import 'question_analytics_events.dart';
import 'question_analytics_state.dart';

/// Feeds the "Анализа" tab. The two halves are loaded independently: the
/// offline analytics come from a bundled asset and always arrive, while the
/// crowd difficulty needs the backend and a signed-in caller — so a guest, a
/// failed request or a question nobody has answered yet simply leaves that one
/// card out instead of failing the tab.
@injectable
class QuestionAnalyticsBloc
    extends Bloc<QuestionAnalyticsEvent, QuestionAnalyticsState> {
  QuestionAnalyticsBloc(
    this._analytics,
    this._difficulty,
    this._authBloc,
    @factoryParam this.questionId,
  ) : super(const QuestionAnalyticsState()) {
    on<QuestionAnalyticsRequested>(_onRequested);
  }

  final QuestionAnalyticsRepository _analytics;
  final QuestionDifficultyRepository _difficulty;
  final AuthBloc _authBloc;
  final int questionId;

  Future<void> _onRequested(
    QuestionAnalyticsRequested event,
    Emitter<QuestionAnalyticsState> emit,
  ) async {
    try {
      final analytics = await _analytics.forQuestion(
        questionId,
        event.languageCode,
      );
      final summary = await _analytics.summary();
      emit(
        state.copyWith(
          inProgress: false,
          analytics: analytics,
          summary: summary,
        ),
      );
    } catch (_) {
      // The asset is bundled, so this only happens if it is missing or
      // malformed — the tab then falls back to the attempt history alone.
      emit(state.copyWith(inProgress: false));
    }

    if (!_authBloc.state.isAuthenticated) {
      emit(
        state.copyWith(
          difficultyInProgress: false,
          difficultyRequiresSignIn: true,
        ),
      );
      return;
    }
    try {
      final difficulty = await _difficulty.forQuestion(questionId);
      emit(state.copyWith(difficultyInProgress: false, difficulty: difficulty));
    } catch (_) {
      emit(state.copyWith(difficultyInProgress: false, difficultyFailed: true));
    }
  }
}
