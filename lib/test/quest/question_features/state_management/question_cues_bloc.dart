import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/question_analytics_repository.dart';
import 'question_cues_events.dart';
import 'question_cues_state.dart';

/// Feeds the key-phrase highlights on the question screen — the same cues the
/// "Анализа" tab lists, but for the text and the answer cards themselves.
///
/// Deliberately separate from [QuestionAnalyticsBloc]: that one also asks the
/// backend for the crowd difficulty, which the highlights have no use for, and
/// it lives inside the tab, whereas the cards sit outside it (and, on a wide
/// screen, in another pane). This bloc reads only the bundled asset, so it is
/// cheap enough to create for every revealed question.
@injectable
class QuestionCuesBloc extends Bloc<QuestionCuesEvent, QuestionCuesState> {
  QuestionCuesBloc(this._analytics, @factoryParam this.questionId)
    : super(const QuestionCuesState()) {
    on<QuestionCuesRequested>(_onRequested);
  }

  final QuestionAnalyticsRepository _analytics;
  final int questionId;

  Future<void> _onRequested(
    QuestionCuesRequested event,
    Emitter<QuestionCuesState> emit,
  ) async {
    try {
      final analytics = await _analytics.forQuestion(questionId);
      emit(state.copyWith(inProgress: false, analytics: analytics));
    } catch (_) {
      // A missing or malformed asset only means no highlights.
      emit(state.copyWith(inProgress: false));
    }
  }
}
