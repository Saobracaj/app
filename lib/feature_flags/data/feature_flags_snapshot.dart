import 'package:flutter/foundation.dart';

import '../domain/app_feature.dart';

/// An immutable resolved view of every feature for the current user, published
/// by [FeatureFlagsRepository]. `isEnabled` is the single question widgets ask;
/// the extra fields let a settings screen explain *why* a feature is on/off.
@immutable
class FeatureFlagsSnapshot {
  const FeatureFlagsSnapshot({
    required this.enabled,
    required this.localOverrides,
    required this.grants,
    required this.authenticated,
  });

  /// The empty starting point: guest tier on, nothing granted, signed out.
  factory FeatureFlagsSnapshot.initial() => FeatureFlagsSnapshot.resolve(
    localOverrides: const {},
    grants: const {},
    authenticated: false,
  );

  /// Resolve the whole catalog: a feature is on when its tier is satisfied
  /// (guest → always, authenticated → signed in, premium → signed in *and*
  /// granted) **and** the local toggle for it is not turned off.
  factory FeatureFlagsSnapshot.resolve({
    required Map<String, bool> localOverrides,
    required Set<String> grants,
    required bool authenticated,
  }) {
    final resolved = <AppFeature, bool>{};
    for (final f in AppFeature.values) {
      final tierOk = switch (f.access) {
        FeatureAccess.guest => true,
        FeatureAccess.authenticated => authenticated,
        FeatureAccess.premium => authenticated && grants.contains(f.key),
      };
      final localOk = localOverrides[f.key] ?? true;
      resolved[f] = tierOk && localOk;
    }
    return FeatureFlagsSnapshot(
      enabled: Map.unmodifiable(resolved),
      localOverrides: Map.unmodifiable(localOverrides),
      grants: Set.unmodifiable(grants),
      authenticated: authenticated,
    );
  }

  /// The final on/off decision per feature.
  final Map<AppFeature, bool> enabled;

  /// The user's local toggles (`key` → enabled); absent = default on.
  final Map<String, bool> localOverrides;

  /// Premium feature keys the backend granted to the signed-in user.
  final Set<String> grants;

  /// Whether a session is currently active.
  final bool authenticated;

  /// Whether [feature] is available to the user right now.
  bool isEnabled(AppFeature feature) => enabled[feature] ?? false;

  /// The user's local toggle for [feature] (defaults to on).
  bool localEnabled(AppFeature feature) =>
      localOverrides[feature.key] ?? true;

  /// Convenience mirror of the standalone Russian-content option.
  bool get russianContent => isEnabled(AppFeature.russianContent);
}
