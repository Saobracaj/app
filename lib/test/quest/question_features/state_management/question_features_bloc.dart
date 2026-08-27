import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../feature_flags/domain/app_feature.dart';
import '../../../data/quiz_preferences_repository.dart';
import 'question_features_events.dart';
import 'question_features_state.dart';

/// Holds the selected per-question feature tab, and remembers it across
/// questions and launches via [QuizPreferencesRepository].
///
/// An explicit [initial] tab (a deep link into the discussion) wins over the
/// remembered one and is not itself remembered — it says where *this* link
/// points, not what the user usually reads. Whether the resulting tab is
/// actually available is decided by the widget, which falls back to the first
/// visible tab when it isn't.
@injectable
class QuestionFeaturesBloc
    extends Bloc<QuestionFeaturesEvent, QuestionFeaturesState> {
  QuestionFeaturesBloc(
    this._preferences,
    @factoryParam AppFeature? initial, [
    @factoryParam this.questionId,
  ]) : super(
        QuestionFeaturesState(selected: initial ?? _preferences.questionTab),
      ) {
    on<TabSelected>((event, emit) {
      _preferences.setQuestionTab(event.feature);
      analytics.logQuestionTabOpened(
        tab: event.feature.key,
        questionId: questionId,
      );
      emit(QuestionFeaturesState(selected: event.feature));
    });
  }

  final QuizPreferencesRepository _preferences;

  /// The question whose tabs these are — analytics context only.
  final int? questionId;
}
