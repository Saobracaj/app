import '../data/feature_flags_snapshot.dart';
import '../domain/app_feature.dart';

sealed class FeatureFlagsEvent {}

/// Subscribe to the repository's snapshot stream (dispatched once when the
/// bloc is created).
class FeatureFlagsStarted extends FeatureFlagsEvent {}

/// Emitted internally whenever the repository publishes a new snapshot.
class FeatureFlagsSnapshotChanged extends FeatureFlagsEvent {
  FeatureFlagsSnapshotChanged(this.snapshot);
  final FeatureFlagsSnapshot snapshot;
}

/// A screen is showing a lock on paid content: re-check the grants with the
/// backend (throttled — see `FeatureFlagsRepository.refreshIfStale`), so a
/// stale cache corrects itself where the user is looking instead of at the
/// next restart.
class FeatureGrantsRecheckRequested extends FeatureFlagsEvent {
  FeatureGrantsRecheckRequested({this.reason = 'locked_content'});

  /// What prompted the check — for analytics.
  final String reason;
}

/// User flipped a feature's local toggle in settings.
class FeatureToggled extends FeatureFlagsEvent {
  FeatureToggled(this.feature, this.enabled);
  final AppFeature feature;
  final bool enabled;
}

/// The «РУ» translation was switched on for free on a question where the
/// feature is locked — one of the free tries (`russianTranslationTrialUses`)
/// is spent.
class RussianTranslationTrialUsed extends FeatureFlagsEvent {
  RussianTranslationTrialUsed({this.questionId});

  /// The question the translation was opened on — for analytics only.
  final int? questionId;
}
