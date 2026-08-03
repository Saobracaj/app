import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../feature_flags/domain/app_feature.dart';
import 'question_features_events.dart';
import 'question_features_state.dart';

/// Holds the selected per-question feature tab. Built with no dependencies
/// (screen-local UI state only), so it is constructed directly in
/// `BlocProvider(create:)` rather than resolved from `getIt`. An [initial] tab
/// (e.g. from a deep link into the discussion) pre-selects that feature.
class QuestionFeaturesBloc
    extends Bloc<QuestionFeaturesEvent, QuestionFeaturesState> {
  QuestionFeaturesBloc({AppFeature? initial})
      : super(QuestionFeaturesState(selected: initial)) {
    on<TabSelected>(
      (event, emit) => emit(QuestionFeaturesState(selected: event.feature)),
    );
  }
}
