import 'package:flutter_bloc/flutter_bloc.dart';

import 'question_features_events.dart';
import 'question_features_state.dart';

/// Holds the selected per-question feature tab. Built with no dependencies
/// (screen-local UI state only), so it is constructed directly in
/// `BlocProvider(create:)` rather than resolved from `getIt`.
class QuestionFeaturesBloc
    extends Bloc<QuestionFeaturesEvent, QuestionFeaturesState> {
  QuestionFeaturesBloc() : super(const QuestionFeaturesState()) {
    on<TabSelected>(
      (event, emit) => emit(QuestionFeaturesState(selected: event.feature)),
    );
  }
}
