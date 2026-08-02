import '../../../../feature_flags/domain/app_feature.dart';

sealed class QuestionFeaturesEvent {}

/// The user tapped a feature tab.
class TabSelected extends QuestionFeaturesEvent {
  TabSelected(this.feature);

  final AppFeature feature;
}
