import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../feature_flags/domain/app_feature.dart';

part 'question_features_state.freezed.dart';

/// Which per-question feature tab is currently open. `selected` is `null` until
/// the user taps a tab, in which case the first visible tab is shown.
@freezed
abstract class QuestionFeaturesState with _$QuestionFeaturesState {
  const factory QuestionFeaturesState({AppFeature? selected}) =
      _QuestionFeaturesState;
}
