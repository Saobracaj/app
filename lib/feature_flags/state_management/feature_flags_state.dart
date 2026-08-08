import 'package:flutter/foundation.dart';

import '../data/feature_flags_snapshot.dart';
import '../domain/app_feature.dart';

/// App-wide feature-availability state: just the latest resolved snapshot from
/// [FeatureFlagsRepository].
@immutable
class FeatureFlagsState {
  FeatureFlagsState({FeatureFlagsSnapshot? snapshot})
    : snapshot = snapshot ?? FeatureFlagsSnapshot.initial();

  final FeatureFlagsSnapshot snapshot;

  /// Whether [feature] is available to the user right now. The one call most
  /// widgets need: `context.select((FeatureFlagsBloc b) => b.state.isEnabled(x))`.
  bool isEnabled(AppFeature feature) => snapshot.isEnabled(feature);

  /// Convenience mirror of [FeatureFlagsSnapshot.russianContent]: whether the
  /// study content (konspekts, explanations, RU translations) is shown in
  /// Russian rather than Serbian.
  bool get russianContent => snapshot.russianContent;

  FeatureFlagsState copyWith({FeatureFlagsSnapshot? snapshot}) =>
      FeatureFlagsState(snapshot: snapshot ?? this.snapshot);
}
